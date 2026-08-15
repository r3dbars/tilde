import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Personal History replay-eval command", .serialized)
struct ReplayEvalCommandTests {
    @Test("Disabled capture is reported as unavailable without touching the store")
    func disabledCaptureIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.settings.personalHistoryEnabled = false

        let result = await fixture.command().execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "history-disabled")))
    }

    @Test("A missing history identifier is reported as unavailable")
    func missingIdentifierIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.settings.personalHistoryEnabled = true
        fixture.settings.personalHistoryIdentifier = nil

        let result = await fixture.command().execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "history-disabled")))
    }

    @Test("An empty store is reported as unavailable")
    func emptyStoreIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let result = await fixture.command().execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "history-empty")))
    }

    @Test("A corrupt store fails safely with no private data")
    func corruptStoreIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        chmod(fixture.file.deletingLastPathComponent().path, 0o700)
        try Data("not the real header".utf8).write(to: fixture.file)
        chmod(fixture.file.path, 0o600)

        let result = await fixture.command().execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "store-corrupt")))
    }

    @Test("A store with only a single-word stream has no eligible boundaries")
    func noEligibleBoundariesIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(text: "hi ")])

        let result = await fixture.command().execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "no-eligible-boundaries")))
    }

    @Test("An unowned server is reported as unavailable")
    func unownedServerIsUnavailable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(text: "hello world foo ")])

        let result = await fixture.command(
            ownedServer: { .failure(.noRunningApp) }
        ).execute()

        #expect(result == .failure(Self.unavailableJSON(reason: "server-unavailable")))
    }

    @Test("A ready report scores boundaries and contains only aggregate JSON")
    func readyReportScoresBoundaries() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([
            fixture.event(text: "hello world foo ", app: "com.apple.mail"),
        ])
        let engine = FakeEngine(reply: "world there")

        let result = await fixture.command(engine: engine).execute()

        guard case let .output(json) = result else {
            Issue.record("expected a ready output, got \(result)")
            return
        }
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(object["schema"] as? String == "tilde.replay-eval.v1")
        #expect(object["state"] as? String == "ready")
        let counts = try #require(object["counts"] as? [String: Any])
        #expect(counts["boundariesScored"] as? Int == 2)
        #expect(counts["suggestionsNonempty"] as? Int == 2)
        #expect(counts["suggestionsSilent"] as? Int == 0)
        let em1 = try #require(object["exactMatchAtOne"] as? [String: Any])
        // Boundary 1 golden="world foo", suggestion="world there" -> first word matches.
        // Boundary 2 golden="foo", suggestion="world there" -> no match.
        #expect(em1["count"] as? Int == 1)
        let registers = try #require(object["registers"] as? [String: Any])
        let email = try #require(registers["email"] as? [String: Any])
        #expect(email["count"] as? Int == 2)
        for sentinel in fixture.privateSentinels {
            #expect(!json.contains(sentinel))
        }
        #expect(engine.calls.count == 2)
        #expect(engine.calls.allSatisfy { $0.appBundleIdentifier == "com.apple.mail" })
    }

    @Test("An engine failure counts as silent, not a crash")
    func engineFailureCountsAsSilent() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(text: "hello world foo ")])
        let engine = FakeEngine(reply: nil, throwing: true)

        let result = await fixture.command(engine: engine).execute()

        guard case let .output(json) = result else {
            Issue.record("expected a ready output, got \(result)")
            return
        }
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        let counts = try #require(object["counts"] as? [String: Any])
        #expect(counts["suggestionsSilent"] as? Int == 2)
        #expect(counts["suggestionsNonempty"] as? Int == 0)
    }

    private static func unavailableJSON(reason: String) -> String {
        """
        {"counts":null,"exactMatchAtOne":null,"keystrokesSaved":null,"latencyMilliseconds":null,\
        "limit":500,"privacy":{"aggregateOnly":true,"containsCandidates":false,"containsPaths":false,\
        "containsPerCaseData":false,"containsRawText":false,"containsRecordIdentifiers":false,\
        "containsTargets":false,"localOnly":true},"reason":"\(reason)","registers":null,\
        "schema":"tilde.replay-eval.v1","state":"unavailable"}
        """
    }

    private final class Keys: PersonalHistoryKeyProviding, @unchecked Sendable {
        let data = Data(repeating: 0xA5, count: 32)
        func loadExistingKey() throws -> Data { data }
        func loadOrCreateKey() throws -> Data { data }
        func deleteKey() throws {}
    }

    private final class FakeEngine: CompletionSuggesting, @unchecked Sendable {
        struct Call: Equatable { let context: String; let appBundleIdentifier: String? }
        private let lock = NSLock()
        private var storedCalls: [Call] = []
        let reply: String?
        let throwing: Bool

        init(reply: String?, throwing: Bool = false) {
            self.reply = reply
            self.throwing = throwing
        }

        var calls: [Call] { lock.withLock { storedCalls } }

        func suggestion(
            textBeforeCursor: String,
            appBundleIdentifier: String?
        ) async throws -> CompletionSuggestion? {
            lock.withLock {
                storedCalls.append(Call(context: textBeforeCursor, appBundleIdentifier: appBundleIdentifier))
            }
            if throwing { throw URLError(.timedOut) }
            return reply.map { CompletionSuggestion(text: $0) }
        }
    }

    private struct Fixture {
        let root: URL
        let file: URL
        let suiteName: String
        let defaults: UserDefaults
        let settings: TildeSettings
        let keys = Keys()
        let store: EncryptedPersonalHistoryStore
        let historyID = "REPLAY-HISTORY-SENTINEL"

        init() throws {
            root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-replay-eval-tests-\(UUID().uuidString)")
            file = root.appendingPathComponent("Personal History/history.v1.enc")
            suiteName = "replay-eval-tests-\(UUID().uuidString)"
            defaults = try #require(UserDefaults(suiteName: suiteName))
            settings = TildeSettings(keyboard: defaults)
            store = EncryptedPersonalHistoryStore(location: file, keyProvider: keys)
            settings.personalHistoryEnabled = true
            settings.personalHistoryIdentifier = historyID
        }

        var privateSentinels: [String] { [historyID, "REPLAY-TEXT-SENTINEL", "REPLAY-SESSION-SENTINEL"] }

        func event(
            text: String,
            app: String = "com.example.Editor",
            source: PersonalHistoryEventSource = .typed
        ) -> PersonalHistoryEvent {
            PersonalHistoryEvent(
                id: UUID().uuidString,
                timestampMilliseconds: 1_786_556_800_000,
                historyIdentifier: historyID,
                sessionIdentifier: "REPLAY-SESSION-SENTINEL",
                appBundleIdentifier: app,
                source: source,
                text: text
            )!
        }

        func command(
            ownedServer: (@Sendable () -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure>)? = nil,
            engine: (any CompletionSuggesting)? = nil
        ) -> ReplayEvalCommand {
            ReplayEvalCommand(
                settings: settings,
                store: store,
                ownedServer: ownedServer ?? {
                    .success(ReplayEvalOwnedServer(baseURL: URL(string: "http://127.0.0.1:1")!))
                },
                engineFactory: { _ in engine ?? FakeEngine(reply: nil) }
            )
        }

        func remove() {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }
}
