import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Open research Personal History store", .serialized)
struct OpenResearchHistoryStoreTests {
    @Test("Raw typed and accepted text is readable JSONL with owner-only permissions")
    func plaintextRoundTrip() async throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let events = [
            fixture.event(id: "typed", text: "OPEN_TYPED_SENTINEL", source: .typed),
            fixture.event(
                id: "accepted", text: " accepted output", source: .acceptedSuggestion
            ),
        ]

        try await fixture.plaintext.append(events)

        #expect(try await fixture.plaintext.loadEvents() == events)
        let raw = try String(contentsOf: fixture.plaintextURL, encoding: .utf8)
        #expect(raw.hasPrefix("TILDE-OPEN-RESEARCH-HISTORY\t1\n"))
        #expect(raw.contains("OPEN_TYPED_SENTINEL"))
        #expect(raw.contains("accepted_suggestion"))
        #expect(raw.contains("com.example.Editor"))

        var fileInfo = stat()
        var directoryInfo = stat()
        #expect(lstat(fixture.plaintextURL.path, &fileInfo) == 0)
        #expect(fileInfo.st_mode & 0o7777 == 0o600)
        #expect(lstat(fixture.plaintextURL.deletingLastPathComponent().path, &directoryInfo) == 0)
        #expect(directoryInfo.st_mode & 0o7777 == 0o700)
    }

    @Test("Existing encrypted history migrates completely and loses its old key")
    func encryptedMigration() async throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let old = [
            fixture.event(id: "old-a", text: "OLD_OPEN_SENTINEL"),
            fixture.event(id: "old-b", text: " second historical event"),
        ]
        try await fixture.encrypted.append(old)

        let replay = try await fixture.open.loadReplay(maximumBytes: .max)

        #expect(replay.events == old)
        #expect(!FileManager.default.fileExists(atPath: fixture.encryptedURL.path))
        #expect(fixture.keys.deleted)
        let raw = try String(contentsOf: fixture.plaintextURL, encoding: .utf8)
        #expect(raw.contains("OLD_OPEN_SENTINEL"))
        #expect((try await fixture.open.summary()).location == fixture.plaintextURL)
    }

    @Test("A partial prior migration deduplicates event identities before removing legacy data")
    func migrationDeduplicates() async throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let shared = fixture.event(id: "shared", text: "shared event")
        let missing = fixture.event(id: "missing", text: "missing event")
        try await fixture.plaintext.append([shared])
        try await fixture.encrypted.append([shared, missing])

        let replay = try await fixture.open.loadReplay(maximumBytes: .max)

        #expect(replay.events == [shared, missing])
        #expect(replay.events.filter { $0.id == "shared" }.count == 1)
        #expect(!FileManager.default.fileExists(atPath: fixture.encryptedURL.path))
    }

    @Test("Paired aggregates remain beside raw events and status never emits the text")
    func checkpointAndStatus() async throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let event = fixture.event(id: "score", text: "STATUS_RAW_SENTINEL")
        let stored = PersonalNextWordStoredCheckpoint(
            historyIdentifier: "history",
            experimentIdentifier: "experiment",
            excludedApps: [],
            checkpoint: PersonalNextWordShadow().checkpoint
        )
        try await fixture.plaintext.append([event], checkpoint: stored)

        let suite = "open-research-status-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = TildeSettings(keyboard: defaults)
        settings.personalHistoryEnabled = true
        settings.personalHistoryIdentifier = "history"
        settings.personalHistoryConsentIdentifier = "consent"
        settings.personalNextWordExperimentIdentifier = "experiment"
        let result = PersonalBrainStatusCommand(settings: settings, store: fixture.plaintext)
            .execute()
        guard case let .output(json) = result else {
            Issue.record("Expected ready aggregate status")
            return
        }
        #expect(json.contains("\"state\":\"ready\""))
        #expect(!json.contains("STATUS_RAW_SENTINEL"))
        #expect(try fixture.plaintext.loadLatestCheckpoint() == stored)
    }

    @Test("Deleting open research history also removes any legacy encrypted copy and key")
    func deletion() async throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        try await fixture.encrypted.append([fixture.event(id: "old", text: "legacy")])
        _ = try await fixture.open.loadReplay(maximumBytes: .max)
        try await fixture.open.append([fixture.event(id: "new", text: "open")])

        try await fixture.open.deleteAll()

        #expect(!FileManager.default.fileExists(atPath: fixture.plaintextURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.encryptedURL.path))
        #expect(fixture.keys.deleted)
    }

    private final class Keys: PersonalHistoryKeyProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var key: Data? = Data(repeating: 0x7A, count: 32)
        private var wasDeleted = false

        var deleted: Bool { lock.withLock { wasDeleted } }

        func loadExistingKey() throws -> Data {
            try lock.withLock {
                guard let key else { throw PersonalHistoryStorageError.missingKey }
                return key
            }
        }

        func loadOrCreateKey() throws -> Data {
            lock.withLock {
                if let key { return key }
                let created = Data(repeating: 0x7A, count: 32)
                key = created
                return created
            }
        }

        func deleteKey() throws {
            lock.withLock {
                key = nil
                wasDeleted = true
            }
        }
    }

    private struct Fixture {
        let root: URL
        let plaintextURL: URL
        let encryptedURL: URL
        let keys = Keys()
        let plaintext: PlaintextPersonalHistoryStore
        let encrypted: EncryptedPersonalHistoryStore
        let open: OpenResearchHistoryStore

        init() {
            root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-open-research-tests-\(UUID().uuidString)")
            plaintextURL = root.appendingPathComponent("Open Research History/history.v1.jsonl")
            encryptedURL = root.appendingPathComponent("Personal History/history.v1.enc")
            plaintext = PlaintextPersonalHistoryStore(location: plaintextURL)
            encrypted = EncryptedPersonalHistoryStore(location: encryptedURL, keyProvider: keys)
            open = OpenResearchHistoryStore(plaintext: plaintext, encryptedLegacy: encrypted)
        }

        func event(
            id: String,
            text: String,
            source: PersonalHistoryEventSource = .typed
        ) -> PersonalHistoryEvent {
            PersonalHistoryEvent(
                id: id,
                timestampMilliseconds: 1_786_485_600_000,
                historyIdentifier: "history",
                consentIdentifier: "consent",
                sessionIdentifier: "session",
                appBundleIdentifier: "com.example.Editor",
                source: source,
                text: text
            )!
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}
