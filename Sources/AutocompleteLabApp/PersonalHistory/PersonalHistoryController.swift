import AutocompleteLabCore
import Foundation

protocol PersonalHistoryIngesting: Sendable {
    func ingest(_ events: [PersonalHistoryEvent]) async -> Bool
}

final class PersonalHistoryController: PersonalHistoryIngesting, @unchecked Sendable {
    private let store: any PersonalHistoryStore
    private let settings: TildeSettings
    private let operations: PersistenceOperations
    private let policy = PersonalHistoryCapturePolicy()

    init(
        store: any PersonalHistoryStore = EncryptedPersonalHistoryStore(),
        settings: TildeSettings = TildeSettings()
    ) {
        self.store = store
        self.settings = settings
        let historyIdentifier = settings.personalHistoryIdentifier ?? UUID().uuidString
        settings.personalHistoryIdentifier = historyIdentifier
        self.operations = PersistenceOperations(
            store: store,
            historyIdentifier: historyIdentifier
        )
    }

    var isEnabled: Bool {
        get { settings.personalHistoryEnabled }
        set { settings.personalHistoryEnabled = newValue }
    }

    var excludedApps: Set<String> {
        get { settings.personalHistoryExcludedApps }
        set { settings.personalHistoryExcludedApps = newValue }
    }

    var location: URL { store.location }

    func ingest(_ events: [PersonalHistoryEvent]) async -> Bool {
        guard PersonalHistoryEvent.validBatch(events) else { return false }
        let enabled = settings.personalHistoryEnabled
        let excluded = settings.personalHistoryExcludedApps
        let allowed = events.filter { event in
            policy.decision(
                enabled: enabled,
                secureInput: false,
                appBundleIdentifier: event.appBundleIdentifier,
                excludedApps: excluded
            ) == .allowed(appBundleIdentifier: event.appBundleIdentifier)
        }
        guard !allowed.isEmpty else { return true }
        do {
            return try await operations.ingest(allowed)
        } catch {
            DiagnosticsLog.shared.record("personal-history-write-failed", metadata: [:])
            return false
        }
    }

    func summary() async -> PersonalHistorySummary? {
        try? await store.summary()
    }

    func deleteAll() async throws {
        isEnabled = false
        let nextIdentifier = UUID().uuidString
        settings.personalHistoryIdentifier = nextIdentifier
        try await operations.deleteAll(nextHistoryIdentifier: nextIdentifier)
    }
}

private actor PersistenceOperations {
    private let store: any PersonalHistoryStore
    private var historyIdentifier: String

    init(store: any PersonalHistoryStore, historyIdentifier: String) {
        self.store = store
        self.historyIdentifier = historyIdentifier
    }

    func ingest(_ events: [PersonalHistoryEvent]) async throws -> Bool {
        guard events.allSatisfy({ $0.historyIdentifier == historyIdentifier }) else {
            return true
        }
        try await store.append(events)
        return true
    }

    func deleteAll(nextHistoryIdentifier: String) async throws {
        historyIdentifier = nextHistoryIdentifier
        try await store.deleteAll()
    }
}
