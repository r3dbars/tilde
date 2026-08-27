import TildeCore
import Foundation

/// The one HTTP call replay-eval makes: "what would the production recipe
/// have suggested here?" `LlamaCompletionEngine` already has this exact
/// signature, so it conforms directly — tests inject a fake instead.
protocol CompletionSuggesting: Sendable {
    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?
    ) async throws -> CompletionSuggestion?
}

extension LlamaCompletionEngine: CompletionSuggesting {}

struct ReplayEvalReport: Encodable {
    enum State: String, Encodable { case ready, unavailable }
    enum Reason: String, Encodable {
        case ready
        case historyDisabled = "history-disabled"
        case historyEmpty = "history-empty"
        case noEligibleBoundaries = "no-eligible-boundaries"
        case storeCorrupt = "store-corrupt", keyUnavailable = "key-unavailable"
        case storageUnavailable = "storage-unavailable"
        case serverUnavailable = "server-unavailable"
        case internalError = "internal-error"
    }

    let schema = "tilde.replay-eval.v1"
    let state: State
    let reason: Reason
    let limit: Int
    let counts: Nullable<Counts>
    let exactMatchAtOne: Nullable<RateCount>
    let keystrokesSaved: Nullable<KeystrokesSaved>
    let latencyMilliseconds: Nullable<Latency>
    let registers: Nullable<Registers>
    let privacy = Privacy()

    enum Nullable<Value: Encodable>: Encodable {
        case value(Value), null
        func encode(to encoder: Encoder) throws {
            var output = encoder.singleValueContainer()
            switch self {
            case let .value(value): try output.encode(value)
            case .null: try output.encodeNil()
            }
        }
    }

    struct Counts: Encodable {
        let segments, boundariesScored, suggestionsNonempty, suggestionsSilent: Int
    }

    struct RateCount: Encodable { let count: Int; let rate: Double }

    struct KeystrokesSaved: Encodable { let total: Int; let perBoundary: Double }

    struct Latency: Encodable { let p50Milliseconds: Int?; let p95Milliseconds: Int? }

    struct RegisterStats: Encodable { let count: Int; let exactMatchAtOne: RateCount }

    struct Registers: Encodable { let chat, email, prose: RegisterStats }

    struct Privacy: Encodable {
        let aggregateOnly = true, localOnly = true
        let containsRawText = false, containsCandidates = false, containsTargets = false,
            containsPerCaseData = false, containsRecordIdentifiers = false, containsPaths = false
    }
}

enum ReplayEvalCommandResult: Equatable { case output(String), failure(String) }

/// Headless, side-effect-free CLI: never launches the app, never mutates the
/// Personal History store, and never writes anything but the one aggregate
/// JSON line to stdout. Mirrors `PersonalBrainStatusCommand`'s shape.
struct ReplayEvalCommand {
    /// Matches `PersistenceOperations.maximumReplayBytes` — the same bounded
    /// tail the live paired shadow rebuilds from on launch.
    static let maximumReplayBytes: Int64 = 4 * 1_024 * 1_024

    private let settings: TildeSettings
    private let store: any PersonalHistoryStore
    private let limit: Int
    private let ownedServer: @Sendable () -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure>
    private let engineFactory: @Sendable (URL) -> any CompletionSuggesting

    init(
        settings: TildeSettings = TildeSettings(),
        // `.disabled`: matches `engineFactory` below — this command never
        // mutates the store (read-only replay), but keep the same "no
        // synthetic diagnostics" contract in case that ever changes.
        store: any PersonalHistoryStore = EncryptedPersonalHistoryStore(diagnostics: .disabled),
        limit: Int = PersonalReplayEval.defaultLimit,
        ownedServer: @escaping @Sendable ()
            -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure> = ReplayEvalCommand
            .defaultOwnedServer,
        engineFactory: @escaping @Sendable (URL) -> any CompletionSuggesting = {
            // `.disabled`: this command's contract is "no side effects but
            // the one JSON line on stdout" — never contaminate the shared
            // operational diagnostics log with synthetic timing/rejection
            // entries from a replay run.
            LlamaCompletionEngine(baseURL: $0, diagnostics: .disabled)
        }
    ) {
        self.settings = settings
        self.store = store
        self.limit = max(1, limit)
        self.ownedServer = ownedServer
        self.engineFactory = engineFactory
    }

    func execute() async -> ReplayEvalCommandResult {
        guard settings.personalHistoryEnabled, let historyID = settings.personalHistoryIdentifier else {
            return unavailable(.historyDisabled)
        }
        let excludedApps = settings.personalHistoryExcludedApps

        let replay: PersonalHistoryReplay
        do {
            replay = try await store.loadReplay(maximumBytes: Self.maximumReplayBytes)
        } catch {
            return unavailable(Self.safeReason(for: error))
        }
        let events = replay.events.filter {
            $0.historyIdentifier == historyID
                && !DefaultExcludedApps.isExcluded($0.appBundleIdentifier, configuredExcludedApps: excludedApps)
        }
        guard !events.isEmpty else { return unavailable(.historyEmpty) }

        let extraction = PersonalReplayEval.extract(from: events, limit: limit)
        guard !extraction.boundaries.isEmpty else { return unavailable(.noEligibleBoundaries) }

        guard case let .success(server) = ownedServer() else {
            return unavailable(.serverUnavailable)
        }
        let engine = engineFactory(server.baseURL)

        var tally = Tally()
        for boundary in extraction.boundaries {
            let started = Date()
            let text = await Self.suggestionText(engine: engine, boundary: boundary)
            tally.record(
                boundary: boundary,
                suggestionText: text,
                elapsedMilliseconds: Int(Date().timeIntervalSince(started) * 1_000)
            )
        }

        return encode(ReplayEvalReport(
            state: .ready,
            reason: .ready,
            limit: limit,
            counts: .value(.init(
                segments: extraction.totalSegments,
                boundariesScored: extraction.boundaries.count,
                suggestionsNonempty: tally.nonempty,
                suggestionsSilent: tally.silent
            )),
            exactMatchAtOne: .value(.init(
                count: tally.exactMatches,
                rate: Self.rate(tally.exactMatches, extraction.boundaries.count)
            )),
            keystrokesSaved: .value(.init(
                total: tally.keystrokesTotal,
                perBoundary: extraction.boundaries.isEmpty
                    ? 0 : Double(tally.keystrokesTotal) / Double(extraction.boundaries.count)
            )),
            latencyMilliseconds: .value(.init(
                p50Milliseconds: Self.percentile(tally.latencies, 0.50),
                p95Milliseconds: Self.percentile(tally.latencies, 0.95)
            )),
            registers: .value(.init(
                chat: tally.chat.report(), email: tally.email.report(), prose: tally.prose.report()
            ))
        ))
    }

    private static func suggestionText(
        engine: any CompletionSuggesting,
        boundary: PersonalReplayBoundary
    ) async -> String {
        let suggestion = try? await engine.suggestion(
            textBeforeCursor: boundary.context,
            appBundleIdentifier: boundary.appBundleIdentifier
        )
        guard let suggestion = suggestion ?? nil else { return "" }
        return String(suggestion.visibleText.drop(while: \Character.isWhitespace))
    }

    private struct RegisterTally {
        var count = 0, exact = 0
        mutating func record(exactMatch: Bool) {
            count += 1
            if exactMatch { exact += 1 }
        }
        func report() -> ReplayEvalReport.RegisterStats {
            .init(count: count, exactMatchAtOne: .init(count: exact, rate: ReplayEvalCommand.rate(exact, count)))
        }
    }

    private struct Tally {
        var nonempty = 0, silent = 0, exactMatches = 0, keystrokesTotal = 0
        var latencies: [Int] = []
        var chat = RegisterTally(), email = RegisterTally(), prose = RegisterTally()

        mutating func record(
            boundary: PersonalReplayBoundary,
            suggestionText: String,
            elapsedMilliseconds: Int
        ) {
            latencies.append(elapsedMilliseconds)
            if suggestionText.isEmpty { silent += 1 } else { nonempty += 1 }
            let exact = PersonalReplayEval.exactMatchAtOne(
                suggestion: suggestionText, golden: boundary.golden
            )
            if exact { exactMatches += 1 }
            keystrokesTotal += PersonalReplayEval.keystrokesSaved(
                suggestion: suggestionText, golden: boundary.golden
            )
            switch ContinuationRegister.from(bundleIdentifier: boundary.appBundleIdentifier) {
            case .chat: chat.record(exactMatch: exact)
            case .email: email.record(exactMatch: exact)
            case .prose: prose.record(exactMatch: exact)
            }
        }
    }

    private static func rate(_ count: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(count) / Double(denominator)
    }

    private static func percentile(_ values: [Int], _ fraction: Double) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int((fraction * Double(sorted.count - 1)).rounded()))
        return sorted[index]
    }

    private func unavailable(_ reason: ReplayEvalReport.Reason) -> ReplayEvalCommandResult {
        encode(ReplayEvalReport(
            state: .unavailable, reason: reason, limit: limit,
            counts: .null, exactMatchAtOne: .null, keystrokesSaved: .null,
            latencyMilliseconds: .null, registers: .null
        ))
    }

    private func encode(_ report: ReplayEvalReport) -> ReplayEvalCommandResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(report), let json = String(data: data, encoding: .utf8)
        else { return .failure("{\"reason\":\"internal-error\",\"state\":\"unavailable\"}") }
        return report.state == .ready ? .output(json) : .failure(json)
    }

    private static func safeReason(for error: any Error) -> ReplayEvalReport.Reason {
        switch error {
        case PersonalHistoryStorageError.corruptStore: .storeCorrupt
        case PersonalHistoryStorageError.invalidKey, PersonalHistoryStorageError.missingKey,
             PersonalHistoryStorageError.keychain: .keyUnavailable
        case is CocoaError, is POSIXError: .storageUnavailable
        default: .internalError
        }
    }

    private static func defaultOwnedServer() -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure> {
        let bundlePath = Bundle.main.bundlePath
        return ReplayEvalServerOwnership.verifyOwnedServer(
            inspector: SystemReplayEvalProcessInspector(),
            appExecutablePath: bundlePath + "/Contents/MacOS/Tilde",
            serverExecutablePath: bundlePath + "/Contents/Helpers/llama-server",
            port: TildeLaunchMode.production.llamaServerPort
        )
    }
}
