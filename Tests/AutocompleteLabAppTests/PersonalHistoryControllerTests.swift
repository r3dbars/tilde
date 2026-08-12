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
        #expect(await fixture.controller.nextWordStatus().snapshot.opportunities == 0)
    }

    @Test("Enabled history persists allowed events")
    func enabledPersists() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        let event = fixture.event(text: " personal writing helps personal writing helps ")

        #expect(await fixture.controller.ingest([event]))
        #expect(await fixture.store.events == [event])
        #expect(await settledStatus(fixture.controller).snapshot.learnedTransitions > 0)
    }

    @Test("Storage errors map to fixed privacy-safe menu copy")
    func storageErrorCopy() {
        enum UnexpectedFailure: Error { case value }
        let corrupt = PersonalHistoryStorageHealth.failure(
            error: PersonalHistoryStorageError.corruptStore
        )
        let transientKeychain = PersonalHistoryStorageHealth.failure(
            error: PersonalHistoryStorageError.keychain(-50)
        )

        #expect(corrupt == .storeCorrupt)
        #expect(corrupt?.menuLine == "History: not saving — reset required")
        #expect(PersonalHistoryStorageHealth.failure(
            error: PersonalHistoryStorageError.missingKey
        ) == .keyUnavailable)
        #expect(PersonalHistoryStorageHealth.failure(
            error: PersonalHistoryStorageError.invalidKey
        ) == .keyUnavailable)
        #expect(transientKeychain == .storageUnavailable)
        #expect(transientKeychain?.menuLine == "History: not saving — storage unavailable")
        #expect(PersonalHistoryStorageHealth.failure(
            error: CocoaError(.fileWriteNoPermission)
        ) == .storageUnavailable)
        #expect(PersonalHistoryStorageHealth.failure(
            error: UnexpectedFailure.value
        ) == .internalError)
        #expect(PersonalHistoryStorageHealth.healthy.menuLine == nil)
        #expect(PersonalHistoryStorageHealth.internalError.menuLine
            == "History: not saving — restart Tilde")
    }

    @Test("Repeated failures log once and the next stored event logs recovery")
    func storageFailureDeduplicationAndRecovery() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-history-health-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diagnostics = DiagnosticsLog(logURL: root.appendingPathComponent("diagnostics.log"))
        let fixture = Fixture(diagnostics: diagnostics)
        fixture.controller.isEnabled = true
        #expect(await settledStatus(fixture.controller).phase == .ready)
        await fixture.store.setAppendFailure(.corruptStore)

        #expect(!(await fixture.controller.ingest([fixture.event(id: "failure-one")])))
        #expect(!(await fixture.controller.ingest([fixture.event(id: "failure-two")])))
        #expect(fixture.controller.storageHealthSnapshot == .storeCorrupt)

        await fixture.store.setAppendFailure(nil)
        #expect(await fixture.controller.ingest([fixture.event(id: "recovery")]))
        #expect(await fixture.controller.ingest([fixture.event(id: "healthy")]))
        #expect(fixture.controller.storageHealthSnapshot == .healthy)
        diagnostics.flush()

        let contents = try String(
            contentsOf: root.appendingPathComponent("diagnostics.log"),
            encoding: .utf8
        )
        #expect(contents.components(separatedBy: "personal-history-write-failed").count == 2)
        #expect(contents.contains("reason=store-corrupt"))
        #expect(contents.components(separatedBy: "personal-history-write-recovered").count == 2)
    }

    @Test("Startup replay failure surfaces once as storage health")
    func startupReplayFailure() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-history-replay-health-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diagnostics = DiagnosticsLog(logURL: root.appendingPathComponent("diagnostics.log"))
        let fixture = Fixture(
            enabled: true,
            appendFailure: .missingKey,
            replayFailure: .missingKey,
            diagnostics: diagnostics
        )

        #expect(await settledStatus(fixture.controller).phase == .unavailable)
        #expect(fixture.controller.storageHealthSnapshot == .keyUnavailable)
        #expect(fixture.controller.storageHealthSnapshot.menuLine
            == "History: not saving — reset required")
        #expect(!(await fixture.controller.ingest([fixture.event(id: "same-failure")])))

        diagnostics.flush()

        let contents = try String(
            contentsOf: root.appendingPathComponent("diagnostics.log"),
            encoding: .utf8
        )
        #expect(contents.components(separatedBy: "personal-history-write-failed").count == 2)
        #expect(contents.contains("reason=key-unavailable"))
        #expect(!contents.contains("personal-history-write-recovered"))
    }

    @Test("Empty replay cannot recover an append failure")
    func emptyReplayDoesNotRecoverAppendFailure() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-history-empty-replay-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diagnostics = DiagnosticsLog(logURL: root.appendingPathComponent("diagnostics.log"))
        let fixture = Fixture(diagnostics: diagnostics)
        fixture.controller.isEnabled = true
        #expect(await settledStatus(fixture.controller).phase == .ready)
        await fixture.store.setAppendFailure(.keychain(-50))

        #expect(!(await fixture.controller.ingest([fixture.event(id: "failed-append")])))
        #expect(fixture.controller.storageHealthSnapshot == .storageUnavailable)
        let replayCount = await fixture.store.replayCount
        await fixture.store.setAppendFailure(nil)
        fixture.controller.excludedApps = ["com.example.Other"]
        for _ in 0..<100 {
            if await fixture.store.replayCount > replayCount { break }
            try? await Task.sleep(for: .milliseconds(1))
        }

        #expect(await fixture.store.replayCount > replayCount)
        #expect(await fixture.store.events.isEmpty)
        #expect(fixture.controller.storageHealthSnapshot == .storageUnavailable)
        diagnostics.flush()
        let contents = try String(
            contentsOf: root.appendingPathComponent("diagnostics.log"),
            encoding: .utf8
        )
        #expect(contents.contains("reason=storage-unavailable"))
        #expect(!contents.contains("personal-history-write-recovered"))
    }

    @Test("Deletion dominates a stale write failure")
    func deletionDominatesStaleWriteFailure() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-history-stale-health-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diagnostics = DiagnosticsLog(logURL: root.appendingPathComponent("diagnostics.log"))
        let fixture = Fixture(
            appendFailure: .corruptStore,
            blockAppends: true,
            diagnostics: diagnostics
        )
        fixture.controller.isEnabled = true
        #expect(await settledStatus(fixture.controller).phase == .ready)
        let controller = fixture.controller
        let event = fixture.event(id: "old-generation")
        let ingest = Task { await controller.ingest([event]) }
        await fixture.store.waitForAppendStart()

        let deletion = Task { try await controller.deleteAll() }
        while controller.isEnabled { await Task.yield() }
        await fixture.store.releaseAppends()

        #expect(!(await ingest.value))
        try await deletion.value
        #expect(controller.storageHealthSnapshot == .healthy)
        diagnostics.flush()
        #expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent("diagnostics.log").path
        ))
    }

    @Test("Delayed deletion cannot erase reenabled write health")
    func delayedDeletionPreservesReenabledHealth() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-history-delete-health-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diagnostics = DiagnosticsLog(logURL: root.appendingPathComponent("diagnostics.log"))
        let fixture = Fixture(blockDeletes: true, diagnostics: diagnostics)
        fixture.controller.isEnabled = true
        #expect(await settledStatus(fixture.controller).phase == .ready)
        await fixture.store.setAppendFailure(.corruptStore)
        #expect(!(await fixture.controller.ingest([fixture.event(id: "first-failure")])))

        let controller = fixture.controller
        let deletion = Task { try await controller.deleteAll() }
        await fixture.store.waitForDeleteStart()
        controller.isEnabled = true
        let newEvent = fixture.event(id: "new-generation-failure")
        let newIngest = Task { await controller.ingest([newEvent]) }
        await fixture.store.releaseDeletes()

        try await deletion.value
        #expect(!(await newIngest.value))
        #expect(controller.storageHealthSnapshot == .storeCorrupt)
        diagnostics.flush()
        let contents = try String(
            contentsOf: root.appendingPathComponent("diagnostics.log"),
            encoding: .utf8
        )
        #expect(contents.components(separatedBy: "personal-history-write-failed").count == 2)
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
        let eventBeforeDeletion = fixture.event(
            text: " personal writing helps personal writing helps "
        )
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))
        #expect(await settledStatus(fixture.controller).snapshot.learnedTransitions > 0)

        try await fixture.controller.deleteAll()
        #expect(!fixture.controller.isEnabled)
        #expect(await fixture.store.events.isEmpty)
        #expect(await fixture.controller.nextWordStatus().snapshot.opportunities == 0)

        fixture.controller.isEnabled = true
        #expect(await fixture.controller.ingest([eventBeforeDeletion]))
        #expect(await fixture.store.events.isEmpty)

        let eventAfterDeletion = fixture.event()
        #expect(await fixture.controller.ingest([eventAfterDeletion]))
        #expect(await fixture.store.events == [eventAfterDeletion])
    }

    @Test("Menu copy stays honest until the next-word shadow has enough predictions")
    func nextWordStatusCopy() {
        let empty = PersonalNextWordShadow(evaluationStartMilliseconds: 0).snapshot
        #expect(PersonalNextWordShadowStatus(phase: .ready, snapshot: empty).menuLine
            == "Personal next word: waiting for writing")
        #expect(PersonalNextWordShadowStatus(phase: .inactive, snapshot: empty).menuLine
            == "Personal next word: off")
        #expect(PersonalNextWordShadowStatus(phase: .loading, snapshot: empty).menuLine
            == "Personal next word: loading recent history…")

        let early = PersonalNextWordShadowSnapshot(
            opportunities: 20,
            predictions: 7,
            exactHits: 3,
            learnedContexts: 12,
            learnedTransitions: 18,
            capacityLimited: false
        )
        #expect(PersonalNextWordShadowStatus(phase: .ready, snapshot: early).menuLine
            == "Personal next word: 12 contexts · 7/200 checks")
        #expect(PersonalNextWordShadowStatus(phase: .unavailable, snapshot: empty).menuLine
            == "Personal next word: unavailable")

        let reportable = PersonalNextWordShadowSnapshot(
            opportunities: 400,
            predictions: 200,
            exactHits: 100,
            learnedContexts: 80,
            learnedTransitions: 120,
            capacityLimited: false
        )
        #expect(PersonalNextWordShadowStatus(phase: .ready, snapshot: reportable).menuLine
            == "Personal next word: 50% exact · 50% coverage · 200 checks")

        let capacityLimited = PersonalNextWordShadowSnapshot(
            opportunities: 20,
            predictions: 7,
            exactHits: 3,
            learnedContexts: 12,
            learnedTransitions: 18,
            capacityLimited: true
        )
        #expect(PersonalNextWordShadowStatus(
            phase: .ready,
            snapshot: capacityLimited
        ).menuLine == "Personal next word: 12 contexts · 7/200 checks · memory limit reached")
    }

    @Test("Enabled startup replays only allowed encrypted history")
    func enabledStartupReplay() async {
        let fixture = Fixture(
            enabled: true,
            excludedApps: ["com.example.Excluded"],
            preloaded: [
                ("excluded", " private excluded history repeats ", "com.example.Excluded"),
                ("allowed", " personal writing helps personal writing helps ", "com.example.Editor"),
            ]
        )

        let status = await settledStatus(fixture.controller)
        #expect(status.phase == .ready)
        var expected = PersonalNextWordShadow()
        expected.consume(await fixture.store.events.filter {
            $0.appBundleIdentifier == "com.example.Editor"
        })
        #expect(status.snapshot == expected.snapshot)
    }

    @Test("Startup replay uses a bounded recent tail and censors its first fragment")
    func startupReplayUsesBoundedTail() async {
        let fixture = Fixture(
            enabled: true,
            preloaded: [
                ("tail", "gment complete word ", "com.example.Editor"),
            ]
        )

        let status = await settledStatus(fixture.controller)
        #expect(status.phase == .ready)
        #expect(await fixture.store.replayMaximumBytes == [4 * 1_024 * 1_024])
        #expect(status.snapshot.learnedContexts == 2)
        #expect(status.snapshot.learnedTransitions == 3)
    }

    @Test("A retry overlapping startup replay reaches the shadow exactly once")
    func replayLiveOverlapIsIdempotent() async {
        let text = " personal writing helps "
        let fixture = Fixture(
            enabled: true,
            preloaded: [("overlap", text, "com.example.Editor")],
            blockReplays: true
        )
        await fixture.store.waitForReplayStart()
        let retry = fixture.event(id: "overlap", text: text)
        let controller = fixture.controller
        let store = fixture.store
        let ingest = Task { await controller.ingest([retry]) }

        await store.releaseReplays()

        #expect(await ingest.value)
        #expect(await store.events.count == 2)
        var expected = PersonalNextWordShadow()
        expected.consume([retry])
        #expect(await settledStatus(controller).snapshot == expected.snapshot)
    }

    @Test("A newer off setting rejects work queued under an older revision")
    func disableWinsOverQueuedIngest() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        fixture.controller.isEnabled = false

        #expect(await fixture.controller.ingest([fixture.event(text: "personal writing ")]))
        #expect(await fixture.store.events.isEmpty)
        #expect(await fixture.controller.nextWordStatus().phase == .inactive)
    }

    @Test("Consent rotation prevents next-word contexts crossing off and on")
    func consentRotationBreaksContexts() async {
        let fixture = Fixture()
        fixture.controller.isEnabled = true
        #expect(await fixture.controller.ingest([fixture.event(id: "before", text: " alpha ")]))
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
            fixture.event(id: "after", text: " beta "),
        ]))

        let status = await settledStatus(fixture.controller).snapshot
        #expect(status.opportunities == 0)
        #expect(status.predictions == 0)
    }

    private actor MemoryStore: PersonalHistoryStore {
        nonisolated let location = URL(fileURLWithPath: "/tmp/tilde-personal-history-test")
        private(set) var events: [PersonalHistoryEvent]
        private var appendFailure: PersonalHistoryStorageError?
        private var replayFailure: PersonalHistoryStorageError?
        private var replayBlocked: Bool
        private var replayStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var replayWaiters: [CheckedContinuation<Void, Never>] = []
        private var replayStarted = false
        private var appendBlocked: Bool
        private var appendStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var appendWaiters: [CheckedContinuation<Void, Never>] = []
        private var appendStarted = false
        private(set) var replayCount = 0
        private(set) var replayMaximumBytes: [Int64] = []
        private var deleteBlocked: Bool
        private var deleteStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var deleteWaiters: [CheckedContinuation<Void, Never>] = []
        private var deleteStarted = false

        init(
            events: [PersonalHistoryEvent] = [],
            appendFailure: PersonalHistoryStorageError? = nil,
            replayFailure: PersonalHistoryStorageError? = nil,
            replayBlocked: Bool = false,
            appendBlocked: Bool = false,
            deleteBlocked: Bool = false
        ) {
            self.events = events
            self.appendFailure = appendFailure
            self.replayFailure = replayFailure
            self.replayBlocked = replayBlocked
            self.appendBlocked = appendBlocked
            self.deleteBlocked = deleteBlocked
        }

        func append(_ events: [PersonalHistoryEvent]) async throws {
            appendStarted = true
            appendStartWaiters.forEach { $0.resume() }
            appendStartWaiters.removeAll()
            if appendBlocked {
                await withCheckedContinuation { appendWaiters.append($0) }
            }
            if let appendFailure { throw appendFailure }
            self.events.append(contentsOf: events)
        }

        func setAppendFailure(_ failure: PersonalHistoryStorageError?) {
            appendFailure = failure
        }

        func setReplayFailure(_ failure: PersonalHistoryStorageError?) {
            replayFailure = failure
        }

        func waitForReplayStart() async {
            guard !replayStarted else { return }
            await withCheckedContinuation { replayStartWaiters.append($0) }
        }

        func releaseReplays() {
            replayBlocked = false
            replayWaiters.forEach { $0.resume() }
            replayWaiters.removeAll()
        }

        func waitForAppendStart() async {
            guard !appendStarted else { return }
            await withCheckedContinuation { appendStartWaiters.append($0) }
        }

        func releaseAppends() {
            appendBlocked = false
            appendWaiters.forEach { $0.resume() }
            appendWaiters.removeAll()
        }

        func waitForDeleteStart() async {
            guard !deleteStarted else { return }
            await withCheckedContinuation { deleteStartWaiters.append($0) }
        }

        func releaseDeletes() {
            deleteBlocked = false
            deleteWaiters.forEach { $0.resume() }
            deleteWaiters.removeAll()
        }

        func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
            replayCount += 1
            replayMaximumBytes.append(maximumBytes)
            replayStarted = true
            replayStartWaiters.forEach { $0.resume() }
            replayStartWaiters.removeAll()
            if replayBlocked {
                await withCheckedContinuation { replayWaiters.append($0) }
            }
            if let replayFailure { throw replayFailure }
            return PersonalHistoryReplay(events: events)
        }
        func deleteAll() async throws {
            deleteStarted = true
            deleteStartWaiters.forEach { $0.resume() }
            deleteStartWaiters.removeAll()
            if deleteBlocked {
                await withCheckedContinuation { deleteWaiters.append($0) }
            }
            events = []
        }
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
            preloaded: [(id: String, text: String, app: String)] = [],
            appendFailure: PersonalHistoryStorageError? = nil,
            replayFailure: PersonalHistoryStorageError? = nil,
            blockReplays: Bool = false,
            blockAppends: Bool = false,
            blockDeletes: Bool = false,
            diagnostics: DiagnosticsLog = .shared
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
            store = MemoryStore(
                events: preloaded.map {
                    PersonalHistoryEvent(
                        id: $0.id,
                        timestampMilliseconds: 1_786_485_600_000,
                        historyIdentifier: historyIdentifier,
                        consentIdentifier: "consent",
                        sessionIdentifier: "session",
                        appBundleIdentifier: $0.app,
                        source: .typed,
                        text: $0.text
                    )!
                },
                appendFailure: appendFailure,
                replayFailure: replayFailure,
                replayBlocked: blockReplays,
                appendBlocked: blockAppends,
                deleteBlocked: blockDeletes
            )
            controller = PersonalHistoryController(
                store: store,
                settings: TildeSettings(keyboard: defaults),
                diagnostics: diagnostics
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
    ) async -> PersonalNextWordShadowStatus {
        for _ in 0..<100 {
            let status = await controller.nextWordStatus()
            if status.phase == .ready || status.phase == .unavailable { return status }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return await controller.nextWordStatus()
    }

}
