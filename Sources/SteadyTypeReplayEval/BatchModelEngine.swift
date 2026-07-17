import AutocompleteLabCore
import Darwin
import Foundation

enum ReplayPromptFormat: String, CaseIterable {
    case chatInstruct = "chat-instruct"
    case rawCompletion = "raw-completion"
    case minimalRules = "minimal-rules"
}

struct ReplayPromptConfiguration: Equatable, Sendable {
    var contextCharacters = 360
    var includesTextAfterCursor = false
    var includesBuiltInExamples = true

    var fewShotSource: String { includesBuiltInExamples ? "built-in" : "none" }
}

struct ReplayDecodingConfiguration: Equatable, Sendable {
    var maxTokens = 20
    var temperature = 0.0
    var topP = 0.0
    var repetitionPenalty = 1.0

    var identifier: String {
        "tokens-\(maxTokens)-temp-\(temperature)-top-p-\(topP)-repeat-\(repetitionPenalty)"
    }
}

struct BatchModelEngine {
    struct Result: Sendable {
        let suggestionsByID: [String: String]
        let latencyMillisecondsByID: [String: Int]
    }

    enum Error: Swift.Error, CustomStringConvertible {
        case launch(String)
        case failed(status: Int32)
        case missingResponses([String])

        var description: String {
            switch self {
            case .launch(let detail):
                "Could not launch batch model: \(detail)"
            case .failed(let status):
                "Batch model exited with status \(status)"
            case .missingResponses(let ids):
                "Batch model returned no valid response for: \(ids.joined(separator: ", "))"
            }
        }
    }

    let modelAlias: String
    let scriptURL: URL
    let pythonURL: URL

    init(modelAlias: String, scriptURL: URL, pythonURL: URL) {
        self.modelAlias = modelAlias
        self.scriptURL = scriptURL
        self.pythonURL = pythonURL
    }

    /// `local_completion_batch.py` intentionally buffers stdin until EOF, so every prompt
    /// is written first and stdin is closed before output is read. This loads the model once
    /// without creating a request/response deadlock.
    func suggestions(
        for requests: [CompletionRequest],
        promptFormatByID: [String: ReplayPromptFormat],
        promptConfiguration: ReplayPromptConfiguration = ReplayPromptConfiguration(),
        decodingConfiguration: ReplayDecodingConfiguration = ReplayDecodingConfiguration()
    ) throws -> Result {
        guard !requests.isEmpty else { return Result(suggestionsByID: [:], latencyMillisecondsByID: [:]) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let input = try requests.map { request -> Data in
            let productionPrompt = CompletionPromptBuilder(
                maxContextCharacters: promptConfiguration.contextCharacters,
                includesBuiltInExamples: promptConfiguration.includesBuiltInExamples,
                includesTextAfterCursor: promptConfiguration.includesTextAfterCursor
            ).prompt(for: request)
            let formatted: FormattedCompletionPrompt
            switch promptFormatByID[request.suggestionID] ?? .chatInstruct {
            case .chatInstruct:
                formatted = productionPrompt.formatted(using: .chatInstruct)
            case .rawCompletion:
                formatted = productionPrompt.formatted(using: .rawCompletion)
            case .minimalRules:
                formatted = CompletionPrompt(
                    system: "Continue the text with the next 12 words or fewer. Return only the suffix, or <NO_SUGGESTION>.",
                    user: productionPrompt.user
                ).formatted(using: .chatInstruct)
            }
            return try encoder.encode(BatchRequest(
                id: request.suggestionID,
                system: formatted.system,
                user: formatted.user,
                template: formatted.templateIdentifier,
                rawPrompt: formatted.rawPrompt,
                promptIsBuilt: true,
                maxTokens: decodingConfiguration.maxTokens,
                temperature: decodingConfiguration.temperature,
                topP: decodingConfiguration.topP,
                repetitionPenalty: decodingConfiguration.repetitionPenalty
            ))
        }.reduce(into: Data()) { data, row in
            data.append(row)
            data.append(0x0A)
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        process.executableURL = pythonURL
        process.arguments = [scriptURL.path, "--model", modelAlias]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = FileHandle.standardError
        signal(SIGPIPE, SIG_IGN)

        do {
            try process.run()
        } catch {
            throw Error.launch(String(describing: error))
        }
        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }

        do {
            try standardInput.fileHandleForWriting.write(contentsOf: input)
            try standardInput.fileHandleForWriting.close()
        } catch {
            try? standardInput.fileHandleForWriting.close()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw Error.failed(status: process.terminationStatus)
            }
            throw Error.launch("failed to write prompts: \(error)")
        }

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Error.failed(status: process.terminationStatus)
        }

        let decoder = JSONDecoder()
        var responses: [String: BatchResponse] = [:]
        for line in String(decoding: output, as: UTF8.self).split(whereSeparator: \Character.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let response = try? decoder.decode(BatchResponse.self, from: data) else {
                continue
            }
            responses[response.id] = response
        }

        let missingIDs = requests.map(\.suggestionID).filter { responses[$0] == nil }
        guard missingIDs.isEmpty else { throw Error.missingResponses(missingIDs) }

        var suggestions: [String: String] = [:]
        var latencies: [String: Int] = [:]
        for request in requests {
            guard let response = responses[request.suggestionID] else { continue }
            if let latency = response.latencyMilliseconds { latencies[request.suggestionID] = latency }
            guard response.ok == true, let output = response.output else { continue }
            let cleaner = CompletionOutputCleaner(maxVisibleWords: request.maxVisibleWords)
            if let suggestion = cleaner.cleanBestCandidate(
                output,
                after: request.textBeforeCursor,
                mode: request.mode,
                behaviorProfileID: request.behaviorProfile.id
            ).suggestion {
                suggestions[request.suggestionID] = suggestion.visibleText
            }
        }
        return Result(suggestionsByID: suggestions, latencyMillisecondsByID: latencies)
    }

    static func resolvePythonInterpreter(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        let override = environment["STEADYTYPE_REPLAY_PYTHON"]
        let candidates = [override, "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
            .compactMap { $0 }
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            guard FileManager.default.isExecutableFile(atPath: url.path) else { continue }
            let probe = Process()
            probe.executableURL = url
            probe.arguments = ["-c", "import mlx_lm"]
            probe.standardOutput = FileHandle.nullDevice
            probe.standardError = FileHandle.nullDevice
            guard (try? probe.run()) != nil else { continue }
            probe.waitUntilExit()
            if probe.terminationStatus == 0 { return url }
            if override != nil { break }
        }
        throw Error.launch("no Python interpreter with mlx_lm; set STEADYTYPE_REPLAY_PYTHON")
    }

}

private struct BatchRequest: Encodable {
    let id: String
    let system: String
    let user: String
    let template: String
    let rawPrompt: String?
    let promptIsBuilt: Bool
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let repetitionPenalty: Double

    enum CodingKeys: String, CodingKey {
        case id, system, user, template, rawPrompt, promptIsBuilt
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case repetitionPenalty = "repetition_penalty"
    }
}

private struct BatchResponse: Decodable {
    let id: String
    let output: String?
    let ok: Bool?
    let latencyMilliseconds: Int?

    enum CodingKeys: String, CodingKey {
        case id, output, ok
        case latencyMilliseconds = "latency_ms"
    }
}
