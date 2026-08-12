import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Personal History ingestion")
struct PersonalHistoryControllerTests {
    @Test("Storage operations preserve order and recover after failure")
    func orderedStorageTail() async {
        enum ExpectedFailure: Error { case value }
        actor Log {
            var entries: [String] = []
            var gateOpen = false
            func add(_ value: String) { entries.append(value) }
            func open() { gateOpen = true }
            func waitUntilOpen() async {
                while !gateOpen { await Task.yield() }
            }
        }
        let log = Log()
        var tail = OrderedAsyncTaskTail()
        let first = tail.enqueue {
            await log.add("append-start")
            await log.waitUntilOpen()
            await log.add("append-end")
        }
        let second = tail.enqueue { await log.add("delete") }
        while await log.entries.isEmpty { await Task.yield() }
        await log.open()
        _ = await first.result
        _ = await second.result
        let failure = tail.enqueue { throw ExpectedFailure.value }
        let afterFailure = tail.enqueue { await log.add("after-failure") }
        _ = await failure.result
        _ = await afterFailure.result

        #expect(await log.entries == [
            "append-start", "append-end", "delete", "after-failure",
        ])
    }

    @Test("Disabled history acknowledges but never persists")
    func disabledDoesNotPersist() async {
        let fixture = Fixture()
        #expect(await fixture.controller.ingest([fixture.event()]))
        #expect(await fixture.store.events.isEmpty)
        #expect(await fixture.controller.shadowStatus().snapshot.opportunities == 0)
    }

    @Test("Enabled history persists allowed events")
    func enabledPersists() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        let event = fixture.event(text: " Transcripted ")

        #expect(await fixture.controller.ingest([event]))
        #expect(await fixture.store.events == [event])
        #expect(await settledStatus(fixture.controller).snapshot.opportunities == 1)
    }

    @Test("Excluded apps are discarded before storage")
    func excludedAppDoesNotPersist() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        fixture.controller.excludedApps = ["com.example.Editor"]

        #expect(await fixture.controller.ingest([fixture.event()]))
        #expect(await fixture.store.events.isEmpty)
        #expect(await settledStatus(fixture.controller).snapshot.opportunities == 0)
    }

    @Test("Deletion disables capture and rejects queued events from the old history")
    func deletionRotatesHistory() async throws {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        let eventBeforeDeletion = fixture.event(text: " Transcripted ")
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))
        #expect(await settledStatus(fixture.controller).snapshot.opportunities == 1)

        try await fixture.controller.deleteAll()
        #expect(!fixture.controller.isEnabled)
        #expect(await fixture.store.events.isEmpty)
        #expect(await fixture.controller.shadowStatus().snapshot.opportunities == 0)

        fixture.controller.isEnabled = true
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))
        #expect(await fixture.store.events.isEmpty)

        let eventAfterDeletion = fixture.event()
        #expect(await fixture.controller.ingest([eventAfterDeletion]))
        #expect(await fixture.store.events == [eventAfterDeletion])
    }

    @Test("Menu copy stays honest until the shadow has enough predictions")
    func shadowStatusCopy() {
        let empty = PersonalVocabularyShadowSnapshot(
            opportunities: 0,
            predictions: 0,
            exactHits: 0,
            learnedWords: 0
        )
        #expect(PersonalVocabularyShadowStatus(phase: .ready, snapshot: empty).menuLine
            == "Personal vocabulary: waiting for writing")

        let early = PersonalVocabularyShadowSnapshot(
            opportunities: 20,
            predictions: 7,
            exactHits: 3,
            learnedWords: 12
        )
        #expect(PersonalVocabularyShadowStatus(phase: .ready, snapshot: early).menuLine
            == "Personal vocabulary: 12 words · 7/200 checks")
        #expect(PersonalVocabularyShadowStatus(phase: .unavailable, snapshot: empty).menuLine
            == "Personal vocabulary: unavailable")

        let reportable = PersonalVocabularyShadowSnapshot(
            opportunities: 400,
            predictions: 200,
            exactHits: 100,
            learnedWords: 80
        )
        #expect(PersonalVocabularyShadowStatus(phase: .ready, snapshot: reportable).menuLine
            == "Personal vocabulary: 50% exact · 50% coverage · 200 checks")
    }

    @Test("Enabled startup replays only allowed encrypted history")
    func enabledStartupReplay() async {
        let fixture = Fixture(
            enabled: true,
            excludedApps: ["com.example.Excluded"],
            preloaded: [
                ("excluded", " Transcripted Transcripted ", "com.example.Excluded"),
                ("allowed", " Personalized Personalized ", "com.example.Editor"),
            ]
        )

        let status = await settledStatus(fixture.controller)
        #expect(status.phase == .ready)
        #expect(status.snapshot.opportunities == 2)
        #expect(status.snapshot.learnedWords == 1)
    }

    @Test("Truncated startup replay censors the first possible word fragment")
    func truncatedStartupReplay() async {
        let fixture = Fixture(
            enabled: true,
            preloaded: [
                ("tail-a", "scrip", "com.example.Editor"),
                ("tail-b", "ted Personalized ", "com.example.Editor"),
            ]
        )

        let status = await settledStatus(fixture.controller)
        #expect(status.snapshot.opportunities == 1)
        #expect(status.snapshot.learnedWords == 1)
    }

    @Test("A newer off setting rejects work queued under an older revision")
    func disableWinsOverQueuedIngest() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        fixture.controller.isEnabled = false

        #expect(await fixture.controller.ingest([fixture.event(text: "Transcripted ")]))
        #expect(await fixture.store.events.isEmpty)
        #expect(await fixture.controller.shadowStatus().phase == .inactive)
    }

    @Test("Consent rotation prevents partial words crossing off and on")
    func consentRotationBreaksPartialWords() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        #expect(await fixture.controller.ingest([fixture.event(id: "before", text: " Tra")]))
        let firstConsent = fixture.defaults.string(
            forKey: PersonalHistorySettingsContract.consentIdentifierKey
        )

        fixture.controller.isEnabled = false
        fixture.controller.isEnabled = true
        let secondConsent = fixture.defaults.string(
            forKey: PersonalHistorySettingsContract.consentIdentifierKey
        )
        #expect(firstConsent != secondConsent)
        #expect(await fixture.controller.ingest([
            fixture.event(id: "after", text: "nscripted "),
        ]))

        #expect(await settledStatus(fixture.controller).snapshot.opportunities == 0)
    }

    private actor MemoryStore: PersonalHistoryStore {
        nonisolated let location = URL(fileURLWithPath: "/tmp/tilde-personal-history-test")
        private(set) var events: [PersonalHistoryEvent]

        init(events: [PersonalHistoryEvent] = []) {
            self.events = events
        }

        func append(_ events: [PersonalHistoryEvent]) async throws {
            self.events.append(contentsOf: events)
        }

        func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
            PersonalHistoryReplay(events: events)
        }
        func deleteAll() async throws { events = [] }
        func summary() async throws -> PersonalHistorySummary {
            PersonalHistorySummary(location: location, approximateBytes: Int64(events.count))
        }
    }

    private struct Fixture {
        let defaults: UserDefaults
        let store: MemoryStore
        let controller: PersonalHistoryController

        init(
            enabled: Bool = false,
            excludedApps: Set<String> = [],
            preloaded: [(id: String, text: String, app: String)] = []
        ) {
            let name = "tilde.tests.personal-history.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            let historyIdentifier = "history"
            defaults.set(
                historyIdentifier,
                forKey: PersonalHistorySettingsContract.historyIdentifierKey
            )
            defaults.set(
                "consent",
                forKey: PersonalHistorySettingsContract.consentIdentifierKey
            )
            defaults.set(enabled, forKey: PersonalHistorySettingsContract.enabledKey)
            defaults.set(
                Array(excludedApps).sorted(),
                forKey: PersonalHistorySettingsContract.excludedAppsKey
            )
            store = MemoryStore(events: preloaded.map {
                PersonalHistoryEvent(
                    id: $0.id,
                    timestampMilliseconds: 1_786_485_600_000,
                    historyIdentifier: historyIdentifier,
                    consentIdentifier: "consent",
                    sessionIdentifier: "session-\($0.id)",
                    appBundleIdentifier: $0.app,
                    source: .typed,
                    text: $0.text
                )!
            })
            controller = PersonalHistoryController(
                store: store,
                settings: TildeSettings(keyboard: defaults)
            )
        }

        func event(
            id: String = "event",
            text: String = "hello"
        ) -> PersonalHistoryEvent {
            PersonalHistoryEvent(
                id: id,
                timestampMilliseconds: 1_786_485_600_000,
                historyIdentifier: defaults.string(
                    forKey: PersonalHistorySettingsContract.historyIdentifierKey
                )!,
                consentIdentifier: defaults.string(
                    forKey: PersonalHistorySettingsContract.consentIdentifierKey
                )!,
                sessionIdentifier: "session",
                appBundleIdentifier: "com.example.Editor",
                source: .typed,
                text: text
            )!
        }
    }

    private func settledStatus(
        _ controller: PersonalHistoryController
    ) async -> PersonalVocabularyShadowStatus {
        for _ in 0..<100 {
            let status = await controller.shadowStatus()
            if status.phase == .ready || status.phase == .unavailable { return status }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return await controller.shadowStatus()
    }
}
