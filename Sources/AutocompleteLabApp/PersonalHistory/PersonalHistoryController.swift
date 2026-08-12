import AutocompleteLabCore
import Foundation

protocol PersonalHistoryIngesting: Sendable {
    func ingest(_ events: [PersonalHistoryEvent]) async -> Bool
}

enum PersonalVocabularyShadowPhase: Equatable, Sendable {
    case inactive
    case loading
    case ready
    case unavailable
}

struct PersonalVocabularyShadowStatus: Equatable, Sendable {
    static let reportingPredictionMinimum = 200

    let phase: PersonalVocabularyShadowPhase
    let snapshot: PersonalVocabularyShadowSnapshot

    var menuLine: String {
        switch phase {
        case .inactive:
            return "Personal vocabulary: off"
        case .loading:
            return "Personal vocabulary: loading history…"
        case .unavailable:
            return "Personal vocabulary: unavailable"
        case .ready where snapshot.opportunities == 0:
            return "Personal vocabulary: waiting for writing"
        case .ready where snapshot.predictions < Self.reportingPredictionMinimum:
            return "Personal vocabulary: \(snapshot.learnedWords) words · \(snapshot.predictions)/\(Self.reportingPredictionMinimum) checks"
        case .ready:
            let exact = Int((snapshot.precision * 100).rounded())
            let coverage = Int((snapshot.coverage * 100).rounded())
            return "Personal vocabulary: \(exact)% exact · \(coverage)% coverage · \(snapshot.predictions) checks"
        }
    }
}

enum PersonalHistoryStorageHealth: String, Equatable, Sendable {
    case healthy
    case storeCorrupt = "store-corrupt"
    case keyUnavailable = "key-unavailable"
    case storageUnavailable = "storage-unavailable"
    case internalError = "internal-error"

    static func failure(error: any Error, duringReplay: Bool = false) -> Self? {
        guard let storageError = error as? PersonalHistoryStorageError else {
            if error is CocoaError || error is POSIXError { return .storageUnavailable }
            return duringReplay ? nil : .internalError
        }
        switch storageError {
        case .corruptStore: return .storeCorrupt
        case .invalidKey, .missingKey: return .keyUnavailable
        case .keychain: return .storageUnavailable
        case .invalidEvent: return duringReplay ? nil : .internalError
        }
    }

    var menuLine: String? {
        switch self {
        case .healthy: return nil
        case .storeCorrupt, .keyUnavailable: return "History: not saving — reset required"
        case .storageUnavailable: return "History: not saving — storage unavailable"
        case .internalError: return "History: not saving — restart Tilde"
        }
    }
}

private final class PersonalHistoryStorageHealthState: @unchecked Sendable {
    private let lock = NSLock()
    private let diagnostics: DiagnosticsLog
    private var health = PersonalHistoryStorageHealth.healthy

    init(diagnostics: DiagnosticsLog) { self.diagnostics = diagnostics }

    func snapshot() -> PersonalHistoryStorageHealth { lock.withLock { health } }

    func recordFailure(_ error: any Error, duringReplay: Bool = false) {
        guard let next = PersonalHistoryStorageHealth.failure(
            error: error,
            duringReplay: duringReplay
        ) else { return }
        record(next)
    }

    func recordSuccess() { record(.healthy) }
    func reset() { lock.withLock { health = .healthy } }

    private func record(_ next: PersonalHistoryStorageHealth) {
        let changed = lock.withLock {
            guard health != next else { return false }
            health = next
            return true
        }
        guard changed else { return }
        if next == .healthy {
            diagnostics.record("personal-history-write-recovered")
        } else {
            diagnostics.record("personal-history-write-failed", metadata: ["reason": next.rawValue])
        }
    }
}

private struct PersonalHistoryConfiguration: Equatable, Sendable {
    let revision: Int
    let enabled: Bool
    let excludedApps: Set<String>
    let consentIdentifier: String
}

private final class PersonalHistoryConfigurationState: @unchecked Sendable {
    private let lock = NSLock()
    private var configuration: PersonalHistoryConfiguration

    init(enabled: Bool, excludedApps: Set<String>, consentIdentifier: String) {
        configuration = PersonalHistoryConfiguration(
            revision: 1,
            enabled: enabled,
            excludedApps: excludedApps,
            consentIdentifier: consentIdentifier
        )
    }

    func snapshot() -> PersonalHistoryConfiguration {
        lock.withLock { configuration }
    }

    func update(enabled: Bool, excludedApps: Set<String>) -> PersonalHistoryConfiguration {
        lock.withLock {
            configuration = PersonalHistoryConfiguration(
                revision: configuration.revision + 1,
                enabled: enabled,
                excludedApps: excludedApps,
                consentIdentifier: UUID().uuidString
            )
            return configuration
        }
    }
}

struct OrderedAsyncTaskTail: Sendable {
    private var tail: Task<Void, Never>?

    mutating func enqueue<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) -> Task<Value, Error> {
        let predecessor = tail
        let current = Task {
            if let predecessor { await predecessor.value }
            return try await operation()
        }
        tail = Task { _ = await current.result }
        return current
    }
}

final class PersonalHistoryController: PersonalHistoryIngesting, @unchecked Sendable {
    private let store: any PersonalHistoryStore
    private let settings: TildeSettings
    private let operations: PersistenceOperations
    private let configurationState: PersonalHistoryConfigurationState
    private let storageHealthState: PersonalHistoryStorageHealthState

    init(
        store: any PersonalHistoryStore = EncryptedPersonalHistoryStore(),
        settings: TildeSettings = TildeSettings(),
        diagnostics: DiagnosticsLog = .shared
    ) {
        self.store = store
        self.settings = settings
        let storageHealthState = PersonalHistoryStorageHealthState(diagnostics: diagnostics)
        self.storageHealthState = storageHealthState
        let consentIdentifier = settings.personalHistoryConsentIdentifier ?? UUID().uuidString
        settings.personalHistoryConsentIdentifier = consentIdentifier
        let initialConfiguration = PersonalHistoryConfigurationState(
            enabled: settings.personalHistoryEnabled,
            excludedApps: settings.personalHistoryExcludedApps,
            consentIdentifier: consentIdentifier
        )
        self.configurationState = initialConfiguration
        let historyIdentifier = settings.personalHistoryIdentifier ?? UUID().uuidString
        settings.personalHistoryIdentifier = historyIdentifier
        self.operations = PersistenceOperations(
            store: store,
            historyIdentifier: historyIdentifier,
            configurationState: initialConfiguration,
            storageHealthState: storageHealthState
        )
        let configuration = initialConfiguration.snapshot()
        if configuration.enabled {
            scheduleConfiguration(configuration)
        }
    }

    var isEnabled: Bool {
        get { settings.personalHistoryEnabled }
        set {
            let configuration = configurationState.update(
                enabled: newValue,
                excludedApps: settings.personalHistoryExcludedApps
            )
            settings.personalHistoryConsentIdentifier = configuration.consentIdentifier
            settings.personalHistoryEnabled = newValue
            scheduleConfiguration(configuration)
        }
    }

    var excludedApps: Set<String> {
        get { settings.personalHistoryExcludedApps }
        set {
            let normalized = Set(PersonalHistoryCapturePolicy.normalizedExcludedApps(newValue))
            let configuration = configurationState.update(
                enabled: settings.personalHistoryEnabled,
                excludedApps: normalized
            )
            settings.personalHistoryConsentIdentifier = configuration.consentIdentifier
            settings.personalHistoryExcludedApps = normalized
            scheduleConfiguration(configuration)
        }
    }

    var location: URL { store.location }

    var storageHealthSnapshot: PersonalHistoryStorageHealth { storageHealthState.snapshot() }

    func ingest(_ events: [PersonalHistoryEvent]) async -> Bool {
        guard PersonalHistoryEvent.validBatch(events) else { return false }
        let configuration = configurationState.snapshot()
        do {
            try await operations.ingest(events, configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    func summary() async -> PersonalHistorySummary? {
        try? await store.summary()
    }

    func shadowStatus() async -> PersonalVocabularyShadowStatus {
        let status = await operations.shadowStatus()
        guard configurationState.snapshot().enabled else {
            return PersonalVocabularyShadowStatus(
                phase: .inactive,
                snapshot: PersonalVocabularyShadow().snapshot
            )
        }
        return status.phase == .inactive
            ? PersonalVocabularyShadowStatus(phase: .loading, snapshot: status.snapshot)
            : status
    }

    private func scheduleConfiguration(_ configuration: PersonalHistoryConfiguration) {
        Task {
            await operations.configure(configuration)
        }
    }

    func deleteAll() async throws {
        let configuration = configurationState.update(
            enabled: false,
            excludedApps: settings.personalHistoryExcludedApps
        )
        settings.personalHistoryConsentIdentifier = configuration.consentIdentifier
        settings.personalHistoryEnabled = false
        let nextIdentifier = UUID().uuidString
        settings.personalHistoryIdentifier = nextIdentifier
        try await operations.deleteAll(
            nextHistoryIdentifier: nextIdentifier,
            configuration: configuration
        )
        if configurationState.snapshot() == configuration,
           settings.personalHistoryIdentifier == nextIdentifier {
            storageHealthState.reset()
        }
    }
}

private actor PersistenceOperations {
    private static let maximumReplayBytes: Int64 = 4 * 1_024 * 1_024
    private static let maximumReplayBacklogEvents = 192

    private let store: any PersonalHistoryStore
    private let configurationState: PersonalHistoryConfigurationState
    private let storageHealthState: PersonalHistoryStorageHealthState
    private var historyIdentifier: String
    private var shadow = PersonalVocabularyShadow()
    private var shadowPhase: PersonalVocabularyShadowPhase = .inactive
    private var configurationRevision = 0
    private var replayBacklog: [PersonalHistoryEvent] = []
    private var replayBacklogOverflowed = false
    private var storageOperations = OrderedAsyncTaskTail()

    init(
        store: any PersonalHistoryStore,
        historyIdentifier: String,
        configurationState: PersonalHistoryConfigurationState,
        storageHealthState: PersonalHistoryStorageHealthState
    ) {
        self.store = store
        self.historyIdentifier = historyIdentifier
        self.configurationState = configurationState
        self.storageHealthState = storageHealthState
    }

    func ingest(
        _ events: [PersonalHistoryEvent],
        configuration: PersonalHistoryConfiguration
    ) async throws {
        guard events.allSatisfy({ $0.historyIdentifier == historyIdentifier }) else {
            return
        }
        guard configuration.enabled,
              configurationState.snapshot() == configuration else { return }
        let allowed = events.filter {
            $0.consentIdentifier == configuration.consentIdentifier
                && !configuration.excludedApps.contains($0.appBundleIdentifier)
        }
        guard !allowed.isEmpty else { return }
        let store = store
        let append = storageOperations.enqueue { try await store.append(allowed) }
        do {
            try await append.value
            guard configurationState.snapshot() == configuration else { return }
            storageHealthState.recordSuccess()
        } catch {
            guard configurationState.snapshot() == configuration else { throw error }
            storageHealthState.recordFailure(error)
            throw error
        }

        let latest = configurationState.snapshot()
        guard latest == configuration,
              configurationRevision == configuration.revision else { return }
        switch shadowPhase {
        case .loading:
            replayBacklog.append(contentsOf: allowed)
            if replayBacklog.count > Self.maximumReplayBacklogEvents {
                replayBacklog.removeAll(keepingCapacity: true)
                replayBacklogOverflowed = true
                shadowPhase = .unavailable
            }
        case .ready:
            shadow.consume(allowed)
        case .inactive:
            break
        case .unavailable:
            break
        }
    }

    func configure(_ configuration: PersonalHistoryConfiguration) async {
        guard configuration.revision > configurationRevision else { return }
        configurationRevision = configuration.revision
        replayBacklog.removeAll(keepingCapacity: true)
        replayBacklogOverflowed = false
        shadow.reset()
        shadowPhase = configuration.enabled ? .loading : .inactive
        guard configuration.enabled else { return }

        do {
            let store = store
            let replayTask = storageOperations.enqueue {
                try await store.loadReplay(maximumBytes: Self.maximumReplayBytes)
            }
            let replay = try await replayTask.value
            guard configurationRevision == configuration.revision,
                  configurationState.snapshot() == configuration else { return }
            guard !replayBacklogOverflowed else { return }
            let events = replay.events.filter {
                $0.historyIdentifier == historyIdentifier
                    && !configuration.excludedApps.contains($0.appBundleIdentifier)
            }
            guard configurationRevision == configuration.revision,
                  configurationState.snapshot() == configuration else { return }
            var rebuilt = PersonalVocabularyShadow()
            rebuilt.consume(events)
            guard configurationRevision == configuration.revision,
                  configurationState.snapshot() == configuration else { return }
            var current = rebuilt
            let backlog = replayBacklog
            current.consume(backlog)
            guard configurationRevision == configuration.revision,
                  configurationState.snapshot() == configuration else { return }
            replayBacklog.removeAll(keepingCapacity: true)
            shadow = current
            shadowPhase = .ready
        } catch {
            guard configurationRevision == configuration.revision,
                  configurationState.snapshot() == configuration else { return }
            storageHealthState.recordFailure(error, duringReplay: true)
            replayBacklog.removeAll(keepingCapacity: true)
            shadow.reset()
            shadowPhase = .unavailable
        }
    }

    func shadowStatus() -> PersonalVocabularyShadowStatus {
        PersonalVocabularyShadowStatus(phase: shadowPhase, snapshot: shadow.snapshot)
    }

    func deleteAll(
        nextHistoryIdentifier: String,
        configuration: PersonalHistoryConfiguration
    ) async throws {
        configurationRevision = max(configurationRevision, configuration.revision)
        replayBacklog.removeAll(keepingCapacity: true)
        replayBacklogOverflowed = false
        shadow.reset()
        shadowPhase = .inactive
        historyIdentifier = nextHistoryIdentifier
        let store = store
        let deletion = storageOperations.enqueue { try await store.deleteAll() }
        try await deletion.value
    }
}
