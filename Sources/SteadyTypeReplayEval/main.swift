import AutocompleteLabCore
import Darwin
import Foundation

private let defaultCaptureURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/SteadyType/Personal Capture")

private struct Options {
    var liveScorecard = false
    var corpusURL = defaultCaptureURL
    var fixtureURL: URL?
    var engine = "mock"
    var model = "gemma-4-e4b-it-optiq"
    var variant = "both"
    var promptFormats: [ReplayPromptFormat] = [.chatInstruct]
    var promptConfiguration = ReplayPromptConfiguration()
    var decodingConfiguration = ReplayDecodingConfiguration()
    var maxCases = 150
    var seed: UInt64 = 0
    var outputMarkdownURL: URL?
    var trendRequested = false
    var trendURL: URL?
}

private enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case input(String)

    var description: String {
        switch self {
        case .usage(let detail), .input(let detail): detail
        }
    }
}

private let usage = """
Usage:
  SteadyTypeReplayEval [--corpus DIR | --fixture FILE] [--engine mock|batch]
    [--model ALIAS] [--variant baseline|personalized|both]
    [--prompt-format chat-instruct|raw-completion|minimal-rules|all] [--max-cases N]
    [--context-chars N] [--suffix on|off] [--few-shot-source built-in|none]
    [--max-tokens N] [--temperature N] [--top-p N] [--repetition-penalty N]
    [--seed N] [--out-md FILE] [--trend [FILE]]
  SteadyTypeReplayEval live-scorecard [--corpus DIR] [--trend [FILE]] [--out-md FILE]
"""

let commandFinished = DispatchSemaphore(value: 0)
Task.detached {
    do {
        var options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
        if options.liveScorecard {
            try runLiveScorecard(options: options)
        } else {
            if options.engine == "batch" {
                let pythonURL = try BatchModelEngine.resolvePythonInterpreter()
                options.model = try preflightModelAlias(options.model, pythonURL: pythonURL)
            }
            try await runReplay(options: options)
        }
        commandFinished.signal()
    } catch {
        FileHandle.standardError.write(Data("\(error)\n\n\(usage)\n".utf8))
        Foundation.exit(64)
    }
}
commandFinished.wait()

private func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    if arguments.first == "live-scorecard" {
        options.liveScorecard = true
        index = 1
    }

    func requiredValue(for flag: String) throws -> String {
        guard index + 1 < arguments.count else { throw CLIError.usage("Missing value for \(flag)") }
        index += 1
        return arguments[index]
    }

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--corpus":
            options.corpusURL = URL(fileURLWithPath: try requiredValue(for: argument), isDirectory: true)
        case "--fixture":
            options.fixtureURL = URL(fileURLWithPath: try requiredValue(for: argument))
        case "--engine":
            options.engine = try requiredValue(for: argument)
        case "--model":
            options.model = try requiredValue(for: argument)
        case "--variant":
            options.variant = try requiredValue(for: argument)
        case "--prompt-format":
            let value = try requiredValue(for: argument)
            if value == "all" {
                options.promptFormats = ReplayPromptFormat.allCases
            } else if let format = ReplayPromptFormat(rawValue: value) {
                options.promptFormats = [format]
            } else {
                throw CLIError.usage("Invalid --prompt-format: \(value)")
            }
        case "--max-cases":
            let value = try requiredValue(for: argument)
            guard let parsed = Int(value), parsed > 0 else { throw CLIError.usage("Invalid --max-cases: \(value)") }
            options.maxCases = parsed
        case "--context-chars":
            let value = try requiredValue(for: argument)
            guard let parsed = Int(value), parsed >= 80 else { throw CLIError.usage("Invalid --context-chars: \(value)") }
            options.promptConfiguration.contextCharacters = parsed
        case "--suffix":
            let value = try requiredValue(for: argument)
            guard ["on", "off"].contains(value) else { throw CLIError.usage("Invalid --suffix: \(value)") }
            options.promptConfiguration.includesTextAfterCursor = value == "on"
        case "--few-shot-source":
            let value = try requiredValue(for: argument)
            guard ["built-in", "none"].contains(value) else { throw CLIError.usage("Invalid --few-shot-source: \(value)") }
            options.promptConfiguration.includesBuiltInExamples = value == "built-in"
        case "--max-tokens":
            let value = try requiredValue(for: argument)
            guard let parsed = Int(value), parsed > 0 else { throw CLIError.usage("Invalid --max-tokens: \(value)") }
            options.decodingConfiguration.maxTokens = parsed
        case "--temperature":
            let value = try requiredValue(for: argument)
            guard let parsed = Double(value), parsed >= 0 else { throw CLIError.usage("Invalid --temperature: \(value)") }
            options.decodingConfiguration.temperature = parsed
        case "--top-p":
            let value = try requiredValue(for: argument)
            guard let parsed = Double(value), (0...1).contains(parsed) else { throw CLIError.usage("Invalid --top-p: \(value)") }
            options.decodingConfiguration.topP = parsed
        case "--repetition-penalty":
            let value = try requiredValue(for: argument)
            guard let parsed = Double(value), parsed > 0 else { throw CLIError.usage("Invalid --repetition-penalty: \(value)") }
            options.decodingConfiguration.repetitionPenalty = parsed
        case "--seed":
            let value = try requiredValue(for: argument)
            guard let parsed = UInt64(value) else { throw CLIError.usage("Invalid --seed: \(value)") }
            options.seed = parsed
        case "--out-md":
            options.outputMarkdownURL = URL(fileURLWithPath: try requiredValue(for: argument))
        case "--trend":
            options.trendRequested = true
            if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("-") {
                index += 1
                options.trendURL = URL(fileURLWithPath: arguments[index])
            }
        case "-h", "--help":
            print(usage)
            Foundation.exit(0)
        default:
            throw CLIError.usage("Unknown argument: \(argument)")
        }
        index += 1
    }

    guard ["mock", "batch"].contains(options.engine) else {
        throw CLIError.usage("Invalid --engine: \(options.engine)")
    }
    guard ["baseline", "personalized", "both"].contains(options.variant) else {
        throw CLIError.usage("Invalid --variant: \(options.variant)")
    }
    if options.liveScorecard, options.fixtureURL != nil {
        throw CLIError.usage("live-scorecard reads episode files, not --fixture")
    }
    return options
}

private func runReplay(options: Options) async throws {
    let entries: [PersonalCaptureJournalEntry]
    let replayCases: [TypingReplayCase]
    let corpusKind: String
    if let fixtureURL = options.fixtureURL {
        entries = []
        replayCases = Array(try decodeJSONLines(TypingReplayCase.self, at: fixtureURL).prefix(options.maxCases))
        corpusKind = "fixture"
    } else {
        entries = try loadJournalEntries(from: options.corpusURL)
        replayCases = TypingReplayCaseExtractor().cases(
            from: entries,
            seed: options.seed,
            maxCases: options.maxCases
        )
        corpusKind = "personal"
    }
    guard !replayCases.isEmpty else { throw CLIError.input("No replay cases were found") }

    let variants = options.variant == "both" ? ["baseline", "personalized"] : [options.variant]
    let memoryByDay = personalizedMemoryByDay(cases: replayCases, entries: entries)
    var requestsByFormat: [ReplayPromptFormat: [CompletionRequest]] = [:]
    for promptFormat in options.promptFormats {
        for variant in variants {
            for replayCase in replayCases {
                let requestID = "\(promptFormat.rawValue):\(variant):\(options.decodingConfiguration.identifier):\(replayCase.id)"
                let personalContext = variant == "personalized"
                    ? memoryByDay[replayCase.dayString]?.personalContext(for: PersonalContextQuery(
                        textBeforeCursor: replayCase.contextBefore,
                        appBundleIdentifier: replayCase.appBundleIdentifier
                    ))
                    : nil
                requestsByFormat[promptFormat, default: []].append(CompletionRequest(
                    textBeforeCursor: replayCase.contextBefore,
                    textAfterCursor: options.promptConfiguration.includesTextAfterCursor ? replayCase.contextAfter : "",
                    appBundleIdentifier: replayCase.appBundleIdentifier,
                    fieldKind: AXFieldKind(rawValue: replayCase.fieldKind) ?? .unknown,
                    personalContext: personalContext,
                    maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords,
                    mode: .phraseContinuation,
                    suggestionID: requestID
                ))
            }
        }
    }

    var suggestions: [String: String] = [:]
    var latencies: [String: Int] = [:]
    let allRequests = options.promptFormats.flatMap { requestsByFormat[$0] ?? [] }
    let promptFormatByID = Dictionary(uniqueKeysWithValues: options.promptFormats.flatMap { promptFormat in
        (requestsByFormat[promptFormat] ?? []).map { ($0.suggestionID, promptFormat) }
    })
    var effectiveModel = options.model
    if options.engine == "batch" {
        let scriptURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("script/local_completion_batch.py")
        let pythonURL = try BatchModelEngine.resolvePythonInterpreter()
        do {
            let result = try BatchModelEngine(
                modelAlias: effectiveModel,
                scriptURL: scriptURL,
                pythonURL: pythonURL
            ).suggestions(
                for: allRequests,
                promptFormatByID: promptFormatByID,
                promptConfiguration: options.promptConfiguration,
                decodingConfiguration: options.decodingConfiguration
            )
            suggestions = result.suggestionsByID
            latencies = result.latencyMillisecondsByID
        } catch BatchModelEngine.Error.failed(status: 70) where effectiveModel == "gemma-4-e4b-it-optiq" {
            effectiveModel = "qwen3.5-4b"
            FileHandle.standardError.write(Data("Gemma OptiQ load failed; retrying identical replay requests with documented qwen3.5-4b proxy.\n".utf8))
            let result = try BatchModelEngine(
                modelAlias: effectiveModel,
                scriptURL: scriptURL,
                pythonURL: pythonURL
            ).suggestions(
                for: allRequests,
                promptFormatByID: promptFormatByID,
                promptConfiguration: options.promptConfiguration,
                decodingConfiguration: options.decodingConfiguration
            )
            suggestions = result.suggestionsByID
            latencies = result.latencyMillisecondsByID
        }
    } else {
        let engine = MockCompletionEngine()
        for requests in requestsByFormat.values {
            for request in requests {
                if let suggestion = try await engine.suggestion(for: request) {
                    suggestions[request.suggestionID] = suggestion.visibleText
                }
            }
        }
    }

    let scorer = TypingReplayScorer()
    let now = ISO8601DateFormatter().string(from: Date())
    let sha = gitSHA()
    var markdownSections: [String] = []
    var trendRows: [TypingReplayTrendRow] = []
    let gate = TypingReplayGateEvaluator()
    for promptFormat in options.promptFormats {
        for variant in variants {
            let prefix = "\(promptFormat.rawValue):\(variant):\(options.decodingConfiguration.identifier):"
            let scores = replayCases.map { replayCase in
                let requestID = prefix + replayCase.id
                let raw = suggestions[requestID]
                let gated = raw.flatMap {
                    gate.shouldDisplay(
                        suggestionText: $0,
                        replayCase: replayCase,
                        latencyMilliseconds: latencies[requestID] ?? 0
                    ) ? $0 : nil
                }
                return scorer.score(rawSuggestionText: raw, gatedSuggestionText: gated, for: replayCase)
            }
            let scorecard = TypingReplayScorecard(scores: scores)
            markdownSections.append("## \(promptFormat.rawValue) / \(variant.capitalized)\n\n" + scorecard.markdown)
            let formatLatencies = replayCases.compactMap { latencies[prefix + $0.id] }
            trendRows.append(scorecard.trendRow(
                dateISO: now,
                gitSHA: sha,
                engine: options.engine,
                model: options.engine == "mock" ? "mock" : effectiveModel,
                promptFormat: promptFormat.rawValue,
                variant: variant,
                corpusKind: corpusKind,
                promptContextCharacters: options.promptConfiguration.contextCharacters,
                suffixEnabled: options.promptConfiguration.includesTextAfterCursor,
                fewShotSource: options.promptConfiguration.fewShotSource,
                decodingVariant: options.decodingConfiguration.identifier,
                endToEndP95LatencyMs: percentile95(formatLatencies)
            ))
        }
    }
    let runMetadata = """
    - Engine: \(options.engine)
    - Model: \(options.engine == "mock" ? "mock" : effectiveModel)
    - Corpus: \(corpusKind)
    - Cases: \(replayCases.count)
    - Seed: \(options.seed)
    - Prompt context characters: \(options.promptConfiguration.contextCharacters)
    - Text after cursor: \(options.promptConfiguration.includesTextAfterCursor ? "enabled" : "disabled")
    - Few-shot source: \(options.promptConfiguration.fewShotSource)
    - Decoding: \(options.decodingConfiguration.identifier)
    """
    let markdown = "# SteadyType Replay Eval\n\n" + runMetadata + "\n\n" + markdownSections.joined(separator: "\n\n") + "\n"
    if options.trendRequested {
        let destination = options.trendURL ?? defaultTrendURL(corpusKind: corpusKind)
        try appendTrendRows(trendRows, to: destination, ownerOnly: corpusKind == "personal")
    }
    try emitMarkdown(markdown, to: options.outputMarkdownURL, ownerOnly: corpusKind == "personal")
}

private func percentile95(_ values: [Int]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let index = max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)
    return Double(sorted[index])
}

private func runLiveScorecard(options: Options) throws {
    let episodesURL = options.corpusURL.appendingPathComponent("Episodes", isDirectory: true)
    let files = ((try? FileManager.default.contentsOfDirectory(
        at: episodesURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )) ?? []).filter { $0.lastPathComponent.hasSuffix(".episodes.jsonl") }.sorted { $0.path < $1.path }
    var latestByID: [String: SuggestionEpisodeRecord] = [:]
    for file in files {
        for record in try decodeJSONLines(SuggestionEpisodeRecord.self, at: file) {
            latestByID[record.id] = record
        }
    }
    let records = Array(latestByID.values)
    guard !records.isEmpty else { throw CLIError.input("No episode records were found in \(episodesURL.path)") }
    let scorecard = SuggestionEpisodeScorecard(records: records)
    let modelNames = Set(records.map(\.model.modelName).filter { !$0.isEmpty })
    let model = modelNames.count == 1 ? modelNames.first! : "mixed"
    let row = TypingReplayTrendRow.live(
        dateISO: ISO8601DateFormatter().string(from: Date()),
        gitSHA: gitSHA(),
        model: model,
        corpusKind: "personal",
        scorecard: scorecard
    )
    let destination = options.trendURL ?? defaultTrendURL(corpusKind: "personal")
    try appendTrendRows([row], to: destination, ownerOnly: true)
    try emitMarkdown(scorecard.markdown + "\n", to: options.outputMarkdownURL, ownerOnly: true)
}

private func loadJournalEntries(from corpusURL: URL) throws -> [PersonalCaptureJournalEntry] {
    let files = try FileManager.default.contentsOfDirectory(
        at: corpusURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).filter { $0.pathExtension.lowercased() == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    let parser = PersonalCaptureJournalParser()
    return files.flatMap { file -> [PersonalCaptureJournalEntry] in
        guard let markdown = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return parser.entries(inDailyMarkdown: markdown, dayString: file.deletingPathExtension().lastPathComponent)
    }
}

private func personalizedMemoryByDay(
    cases: [TypingReplayCase],
    entries: [PersonalCaptureJournalEntry]
) -> [String: PersonalWritingMemory] {
    var memories: [String: PersonalWritingMemory] = [:]
    for day in Set(cases.map(\.dayString)) {
        guard let replayDate = date(fromDayString: day) else { continue }
        let priorEntries = entries.filter { entry in
            guard let entryDate = date(fromDayString: entry.dayString) else { return false }
            return entryDate < replayDate
        }
        memories[day] = PersonalWritingMemoryBuilder().build(
            entries: priorEntries,
            now: replayDate
        )
    }
    return memories
}

private func decodeJSONLines<Value: Decodable>(_ type: Value.Type, at url: URL) throws -> [Value] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    let decoder = JSONDecoder()
    return contents.split(whereSeparator: \Character.isNewline).compactMap { line in
        try? decoder.decode(Value.self, from: Data(line.utf8))
    }
}

private func appendTrendRows(_ rows: [TypingReplayTrendRow], to url: URL, ownerOnly: Bool) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: ownerOnly ? [.posixPermissions: 0o700] : nil
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var payload = Data()
    for row in rows {
        payload.append(try encoder.encode(row))
        payload.append(0x0A)
    }
    let mode: mode_t = ownerOnly ? 0o600 : 0o644
    let descriptor = open(url.path, O_WRONLY | O_CREAT | O_APPEND, mode)
    guard descriptor >= 0 else { throw CLIError.input("Could not append trend file: \(url.path)") }
    defer { close(descriptor) }
    if ownerOnly { _ = fchmod(descriptor, 0o600) }
    let written = payload.withUnsafeBytes { bytes in
        write(descriptor, bytes.baseAddress, bytes.count)
    }
    guard written == payload.count else { throw CLIError.input("Incomplete trend append: \(url.path)") }
}

private func defaultTrendURL(corpusKind: String) -> URL {
    if corpusKind == "fixture" {
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evals/replay-trend-fixture.jsonl")
    }
    return defaultCaptureURL.appendingPathComponent("Evals/replay-trend.jsonl")
}

private func emitMarkdown(_ markdown: String, to url: URL?, ownerOnly: Bool) throws {
    guard let url else { print(markdown, terminator: ""); return }
    let directory = url.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: ownerOnly ? [.posixPermissions: 0o700] : nil
        )
    }
    let mode: mode_t = ownerOnly ? 0o600 : 0o644
    let descriptor = open(url.path, O_WRONLY | O_CREAT | O_TRUNC, mode)
    guard descriptor >= 0 else { throw CLIError.input("Could not write report file: \(url.path)") }
    defer { close(descriptor) }
    if ownerOnly { _ = fchmod(descriptor, 0o600) }
    let data = Data(markdown.utf8)
    let written = data.withUnsafeBytes { bytes in write(descriptor, bytes.baseAddress, bytes.count) }
    guard written == data.count else { throw CLIError.input("Incomplete report write: \(url.path)") }
}

private func date(fromDayString value: String) -> Date? {
    guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
        return nil
    }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let parsed = formatter.date(from: value), formatter.string(from: parsed) == value else {
        return nil
    }
    return parsed
}

private func gitSHA() -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["rev-parse", "--short", "HEAD"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return "unknown" }
    process.waitUntilExit()
    return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func preflightModelAlias(_ requested: String, pythonURL: URL) throws -> String {
    guard requested == "gemma-4-e4b-it-optiq" else { return requested }
    let process = Process()
    let output = Pipe()
    process.executableURL = pythonURL
    process.arguments = [
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("script/local_completion_batch.py").path,
        "--model", requested,
        "--print-source"
    ]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        throw CLIError.input("Could not run model preflight: \(error)")
    }
    process.waitUntilExit()
    let source = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    if process.terminationStatus != 0 || !source.contains("kind=local-asset") {
        FileHandle.standardError.write(Data("Gemma OptiQ local asset unavailable; using documented qwen3.5-4b replay proxy.\n".utf8))
        return "qwen3.5-4b"
    }
    return requested
}
