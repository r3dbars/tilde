import AutocompleteLabCore
import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

struct RuntimeProbeConfiguration {
    var samples = 5
}

let usage = "Usage: AutocompleteRuntimeProbe [--samples N]\n"

func fail(_ message: String, status: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data("\(message)\n\(usage)".utf8))
    Foundation.exit(status)
}

func parseConfiguration() -> RuntimeProbeConfiguration {
    var configuration = RuntimeProbeConfiguration()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--samples":
            guard let value = iterator.next(), let samples = Int(value), samples > 0 else {
                fail("Invalid --samples value")
            }
            configuration.samples = samples
        case let value where value.hasPrefix("--samples="):
            let rawValue = String(value.dropFirst("--samples=".count))
            guard let samples = Int(rawValue), samples > 0 else {
                fail("Invalid --samples value")
            }
            configuration.samples = samples
        case "-h", "--help":
            FileHandle.standardOutput.write(Data(usage.utf8))
            Foundation.exit(0)
        default:
            fail("Unknown argument: \(argument)")
        }
    }

    return configuration
}

struct DiagnosticsLineWriter {
    let logURL: URL
    private let timestampFormatter = ISO8601DateFormatter()

    init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/diagnostics.log")
    }

    func record(_ event: String, metadata: [String: String]) throws {
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(sanitize($0.value))" }
            .joined(separator: " ")
        let line = "\(timestampFormatter.string(from: Date())) \(event) \(fields)\n"

        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: " ", with: "_")
    }
}

struct ProbeCompletionResult {
    let suggestion: CompletionSuggestion?
    let latencyMilliseconds: Int
}

final class ProbeMLXRuntime {
    private let modelDirectoryURL: URL
    private let lengthConfiguration: CompletionLengthConfiguration
    private let diagnostics: DiagnosticsLineWriter
    private let promptBuilder: CompletionPromptBuilder
    private let cleaner: CompletionOutputCleaner
    private var container: ModelContainer?

    init(
        modelDirectoryURL: URL,
        lengthConfiguration: CompletionLengthConfiguration,
        diagnostics: DiagnosticsLineWriter
    ) {
        self.modelDirectoryURL = modelDirectoryURL
        self.lengthConfiguration = lengthConfiguration
        self.diagnostics = diagnostics
        self.promptBuilder = CompletionPromptBuilder(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.cleaner = CompletionOutputCleaner(maxVisibleWords: lengthConfiguration.maxVisibleWords)
    }

    func warm() async throws {
        if container != nil {
            return
        }

        container = try await LLMModelFactory.shared.loadContainer(
            from: modelDirectoryURL,
            using: #huggingFaceTokenizerLoader()
        )

        guard let container else {
            throw RuntimeProbeError.warmCompletedWithoutContainer
        }
        _ = try await complete(
            CompletionRequest(
                textBeforeCursor: "A quiet local autocomplete should",
                appBundleIdentifier: "app.transcripted.autocomplete-lab.runtime-warmup",
                maxVisibleWords: lengthConfiguration.maxVisibleWords,
                mode: .phraseContinuation,
                suggestionID: "runtime-warmup-\(UUID().uuidString)"
            ),
            using: container,
            timingEventName: "mlx-warmup-generation"
        )
    }

    func complete(_ request: CompletionRequest) async throws -> ProbeCompletionResult {
        try await warm()
        guard let container else {
            throw RuntimeProbeError.warmCompletedWithoutContainer
        }

        return try await complete(request, using: container, timingEventName: "mlx-completion-timing")
    }

    private func complete(
        _ request: CompletionRequest,
        using container: ModelContainer,
        timingEventName: String
    ) async throws -> ProbeCompletionResult {
        let startedAt = Date()
        let prompt = promptBuilder.prompt(for: request)
        let promptBuiltAt = Date()
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: GenerateParameters(
                maxTokens: maxGeneratedTokens(for: request.mode),
                temperature: 0
            ),
            additionalContext: ["enable_thinking": false]
        )
        let sessionBuiltAt = Date()

        var rawOutput = ""
        var firstChunkMilliseconds: Int?
        for try await chunk in session.streamResponse(to: prompt.user) {
            if firstChunkMilliseconds == nil {
                firstChunkMilliseconds = Self.milliseconds(from: sessionBuiltAt, to: Date())
            }

            rawOutput += chunk
            if shouldStopEarly(rawOutput, request: request) {
                break
            }
        }
        let generatedAt = Date()
        let cleanedSuggestion = cleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode)
        let cleanedAt = Date()
        let totalMilliseconds = Self.milliseconds(from: startedAt, to: cleanedAt)

        try diagnostics.record(
            timingEventName,
            metadata: [
                "app": request.appBundleIdentifier ?? "unknown",
                "mode": request.mode.rawValue,
                "promptMilliseconds": String(Self.milliseconds(from: startedAt, to: promptBuiltAt)),
                "sessionMilliseconds": String(Self.milliseconds(from: promptBuiltAt, to: sessionBuiltAt)),
                "firstChunkMilliseconds": firstChunkMilliseconds.map(String.init) ?? "none",
                "generationMilliseconds": String(Self.milliseconds(from: sessionBuiltAt, to: generatedAt)),
                "cleanupMilliseconds": String(Self.milliseconds(from: generatedAt, to: cleanedAt)),
                "totalMilliseconds": String(totalMilliseconds),
                "maxTokens": String(maxGeneratedTokens(for: request.mode)),
                "maxVisibleWords": String(lengthConfiguration.maxVisibleWords),
                "rawChars": String(rawOutput.count),
                "cleanedChars": String(cleanedSuggestion?.visibleText.count ?? 0),
                "probe": "runtime-latency"
            ]
        )

        return ProbeCompletionResult(
            suggestion: cleanedSuggestion,
            latencyMilliseconds: totalMilliseconds
        )
    }

    private func shouldStopEarly(_ rawOutput: String, request: CompletionRequest) -> Bool {
        guard let suggestion = cleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode) else {
            return false
        }

        if request.mode == .wordCompletion {
            return true
        }

        return suggestion.visibleWordCount >= CompletionModelPolicy.minimumVisibleWords
            && (suggestion.visibleWordCount >= lengthConfiguration.maxVisibleWords
                || rawOutput.contains(where: { [".", "!", "?", "\n"].contains($0) }))
    }

    private func maxGeneratedTokens(for mode: CompletionRequestMode) -> Int {
        switch mode {
        case .wordCompletion:
            return 3
        case .phraseContinuation, .sentenceContinuation:
            return lengthConfiguration.maxGeneratedTokens
        }
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1_000))
    }
}

enum RuntimeProbeError: LocalizedError {
    case warmCompletedWithoutContainer

    var errorDescription: String? {
        switch self {
        case .warmCompletedWithoutContainer:
            return "MLX warm completed without a loaded model container."
        }
    }
}

let configuration = parseConfiguration()
let manifest = LocalModelAssetManifest.preferredMLX
let appSupportURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
let modelDirectoryURL = appSupportURL
    .appendingPathComponent("AutocompleteLab", isDirectory: true)
    .appendingPathComponent(manifest.cacheDirectoryName, isDirectory: true)
    .appendingPathComponent(manifest.fileName, isDirectory: true)
let lengthConfiguration = CompletionLengthConfiguration.default
let diagnostics = DiagnosticsLineWriter()
let runtime = ProbeMLXRuntime(
    modelDirectoryURL: modelDirectoryURL,
    lengthConfiguration: lengthConfiguration,
    diagnostics: diagnostics
)

let prompts = [
    "I think we should",
    "The next step is",
    "This makes the workflow",
    "For the beta test",
    "The app should",
    "The safest answer is",
    "When the model is ready",
    "A quiet suggestion"
]

do {
    try await runtime.warm()
    try diagnostics.record(
        "runtime-bootstrap",
        metadata: [
            "preferredCandidate": CompletionRuntimeCandidate.mlx.rawValue,
            "fallbackCandidate": CompletionRuntimeCandidate.liteRTLM.rawValue,
            "activeCandidate": CompletionRuntimeCandidate.mlx.rawValue,
            "model": manifest.model.rawValue,
            "asset": manifest.fileName,
            "assetDirectory": modelDirectoryURL.path,
            "assetSourceRepoID": manifest.source?.repoID ?? "",
            "assetSourceRevision": manifest.source?.revision ?? "",
            "modelOverride": "",
            "experimentArm": lengthConfiguration.experimentArm.rawValue,
            "maxVisibleWords": String(lengthConfiguration.maxVisibleWords),
            "maxGeneratedTokens": String(lengthConfiguration.maxGeneratedTokens),
            "promptStyle": CompletionPromptBuilder.promptStyleIdentifier,
            "nativeRuntimeAvailable": "true",
            "canAttemptPreferredRuntime": "true",
            "mockFallbackAllowed": "false",
            "allowsUserManagedServer": "false",
            "probe": "runtime-latency"
        ]
    )

    var shownCount = 0
    for index in 0..<configuration.samples {
        let prompt = prompts[index % prompts.count]
        let suggestionID = "runtime-probe-\(UUID().uuidString)"
        let request = CompletionRequest(
            textBeforeCursor: prompt,
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: lengthConfiguration.maxVisibleWords,
            mode: .phraseContinuation,
            suggestionID: suggestionID
        )
        let startedAt = Date()
        let result = try await runtime.complete(request)
        let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        let shown = result.suggestion?.isEmpty == false

        if shown {
            shownCount += 1
            try diagnostics.record(
                "suggestion-presented",
                metadata: [
                    "app": "com.apple.TextEdit",
                    "requestMode": request.mode.rawValue,
                    "latencyMilliseconds": String(latencyMilliseconds),
                    "traceID": suggestionID,
                    "probe": "runtime-latency"
                ]
            )
        }

        print("sample \(index + 1)/\(configuration.samples): \(latencyMilliseconds)ms shown=\(shown)")
    }

    try await Task.sleep(for: .milliseconds(300))
    print("Runtime probe complete: samples=\(configuration.samples) shown=\(shownCount) log=\(diagnostics.logURL.path)")
} catch {
    FileHandle.standardError.write(Data("Runtime probe failed: \(error.localizedDescription)\n".utf8))
    Foundation.exit(1)
}
