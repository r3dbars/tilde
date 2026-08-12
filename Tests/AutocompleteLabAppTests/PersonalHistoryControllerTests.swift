import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Personal History ingestion")
struct PersonalHistoryControllerTests {
    @Test("Disabled history acknowledges but never persists")
    func disabledDoesNotPersist() async {
        let fixture = Fixture()
        #expect(await fixture.controller.ingest([fixture.event()]))
        #expect(await fixture.store.events.isEmpty)
    }

    @Test("Enabled history persists allowed events")
    func enabledPersists() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        let event = fixture.event()

        #expect(await fixture.controller.ingest([event]))
        #expect(await fixture.store.events == [event])
    }

    @Test("Excluded apps are discarded before storage")
    func excludedAppDoesNotPersist() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        fixture.controller.excludedApps = ["com.example.Editor"]

        #expect(await fixture.controller.ingest([fixture.event()]))
        #expect(await fixture.store.events.isEmpty)
    }

    @Test("Deletion disables capture and rejects queued events from the old history")
    func deletionRotatesHistory() async throws {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        let eventBeforeDeletion = fixture.event()
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))

        try await fixture.controller.deleteAll()
        #expect(!fixture.controller.isEnabled)
        #expect(await fixture.store.events.isEmpty)

        fixture.controller.isEnabled = true
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))
        #expect(await fixture.store.events.isEmpty)

        let eventAfterDeletion = fixture.event()
        #expect(await fixture.controller.ingest([eventAfterDeletion]))
        #expect(await fixture.store.events == [eventAfterDeletion])
    }

    private actor MemoryStore: PersonalHistoryStore {
        nonisolated let location = URL(fileURLWithPath: "/tmp/tilde-personal-history-test")
        private(set) var events: [PersonalHistoryEvent] = []

        func append(_ events: [PersonalHistoryEvent]) async throws {
            self.events.append(contentsOf: events)
        }

        func loadEvents() async throws -> [PersonalHistoryEvent] { events }
        func deleteAll() async throws { events = [] }
        func summary() async throws -> PersonalHistorySummary {
            PersonalHistorySummary(location: location, approximateBytes: Int64(events.count))
        }
    }

    private struct Fixture {
        let defaults: UserDefaults
        let store: MemoryStore
        let controller: PersonalHistoryController

        init() {
            let name = "tilde.tests.personal-history.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            store = MemoryStore()
            controller = PersonalHistoryController(
                store: store,
                settings: TildeSettings(keyboard: defaults)
            )
        }

        func event() -> PersonalHistoryEvent {
            PersonalHistoryEvent(
                id: "event",
                timestampMilliseconds: 1_786_485_600_000,
                historyIdentifier: defaults.string(
                    forKey: PersonalHistorySettingsContract.historyIdentifierKey
                )!,
                sessionIdentifier: "session",
                appBundleIdentifier: "com.example.Editor",
                source: .typed,
                text: "hello"
            )!
        }
    }
}
