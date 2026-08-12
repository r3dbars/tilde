import Foundation
import Security
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Encrypted Personal History store", .serialized)
struct PersonalHistoryStoreTests {
    @Test("Key query stays in the non-synchronizing login Keychain")
    func keychainQueryShape() {
        let query = KeychainPersonalHistoryKeyProvider.baseQuery()

        #expect(query[kSecClass] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService] as? String == KeychainPersonalHistoryKeyProvider.service)
        #expect(query[kSecAttrAccount] as? String == KeychainPersonalHistoryKeyProvider.account)
        #expect(query[kSecAttrSynchronizable] as? Bool == false)
        #expect(query[kSecUseDataProtectionKeychain] == nil)
        #expect(query[kSecAttrAccessible] == nil)
    }

    @Test("Encrypted events round-trip without plaintext on disk")
    func encryptedRoundTrip() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let events = [
            fixture.event(id: "one", text: "PRIVATE_TYPED_SENTINEL", source: .typed),
            fixture.event(id: "two", text: " accepted words", source: .acceptedSuggestion),
        ]

        try await fixture.store.append(events)
        #expect(try await fixture.store.loadEvents() == events)
        let raw = try Data(contentsOf: fixture.file)
        #expect(!String(decoding: raw, as: UTF8.self).contains("PRIVATE_TYPED_SENTINEL"))
        #expect(!String(decoding: raw, as: UTF8.self).contains("com.example.Editor"))
        let summary = try await fixture.store.summary()
        #expect(summary.approximateBytes == raw.count)

        var info = stat()
        #expect(lstat(fixture.file.path, &info) == 0)
        #expect(info.st_mode & 0o7777 == 0o600)
    }

    @Test("Delete removes the corpus and its encryption key")
    func deletion() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(id: "one", text: "history")])

        try await fixture.store.deleteAll()

        #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
        #expect(fixture.keys.wasDeleted)
        #expect(try await fixture.store.loadEvents().isEmpty)
    }

    @Test("Unknown or corrupt formats fail without overwriting existing bytes")
    func corruptStoreFailsClosed() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        chmod(fixture.file.deletingLastPathComponent().path, 0o700)
        let original = Data("UNKNOWN-FORMAT\n".utf8)
        try original.write(to: fixture.file)
        chmod(fixture.file.path, 0o600)

        await #expect(throws: PersonalHistoryStorageError.self) {
            try await fixture.store.loadEvents()
        }
        await #expect(throws: PersonalHistoryStorageError.self) {
            try await fixture.store.append([fixture.event(id: "one", text: "new text")])
        }
        await #expect(throws: PersonalHistoryStorageError.self) {
            try await fixture.store.summary()
        }
        #expect(try Data(contentsOf: fixture.file) == original)
    }

    @Test("Delete remains available when the corpus is corrupt")
    func corruptStoreCanBeDeleted() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        chmod(fixture.file.deletingLastPathComponent().path, 0o700)
        try Data("UNKNOWN-FORMAT\n".utf8).write(to: fixture.file)
        chmod(fixture.file.path, 0o600)

        try await fixture.store.deleteAll()

        #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
        #expect(fixture.keys.wasDeleted)
    }

    @Test("Deletion refuses a history directory redirected by a symlink")
    func deletionRejectsRedirectedDirectory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let outside = fixture.root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(
            at: outside,
            withIntermediateDirectories: true
        )
        chmod(fixture.root.path, 0o700)
        chmod(outside.path, 0o700)
        let outsideFile = outside.appendingPathComponent("history.v1.enc")
        let sentinel = Data("DO-NOT-DELETE".utf8)
        try sentinel.write(to: outsideFile)
        chmod(outsideFile.path, 0o600)
        try FileManager.default.createSymbolicLink(
            at: fixture.file.deletingLastPathComponent(),
            withDestinationURL: outside
        )

        await #expect(throws: Error.self) {
            try await fixture.store.deleteAll()
        }
        #expect(try Data(contentsOf: outsideFile) == sentinel)
        #expect(!fixture.keys.wasDeleted)
    }

    @Test("Replay reads only the most recent complete encrypted events")
    func boundedReplay() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = fixture.event(id: "one", text: "older history")
        let second = fixture.event(id: "two", text: "recent history")
        try await fixture.store.append([first, second])
        let raw = try Data(contentsOf: fixture.file)
        let finalLineBytes = raw.split(separator: 0x0A).last!.count + 1

        let replay = try await fixture.store.loadReplay(
            maximumBytes: Int64(finalLineBytes)
        )
        #expect(replay.events == [second])
    }

    @Test("A missing key never replaces or mixes an existing corpus")
    func missingExistingKeyFailsClosed() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(id: "one", text: "history")])
        let original = try Data(contentsOf: fixture.file)
        let missingKeys = MutableKeys(keyData: nil)
        let reopened = EncryptedPersonalHistoryStore(
            location: fixture.file,
            keyProvider: missingKeys
        )

        await #expect(throws: PersonalHistoryStorageError.missingKey) {
            try await reopened.loadEvents()
        }
        await #expect(throws: PersonalHistoryStorageError.missingKey) {
            try await reopened.append([fixture.event(id: "two", text: "new history")])
        }
        #expect(missingKeys.creationCount == 0)
        #expect(try Data(contentsOf: fixture.file) == original)
    }

    @Test("A wrong existing key cannot mix new records into the corpus")
    func wrongExistingKeyFailsClosed() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.append([fixture.event(id: "one", text: "history")])
        let original = try Data(contentsOf: fixture.file)
        let reopened = EncryptedPersonalHistoryStore(
            location: fixture.file,
            keyProvider: MutableKeys(keyData: Data(repeating: 0x5A, count: 32))
        )

        await #expect(throws: PersonalHistoryStorageError.corruptStore) {
            try await reopened.append([fixture.event(id: "two", text: "new history")])
        }
        #expect(try Data(contentsOf: fixture.file) == original)
    }

    @Test("An invalid encryption key fails before creating the store")
    func invalidKeyFailsClosed() async throws {
        let fixture = try Fixture(keyData: Data(repeating: 0xA5, count: 31))
        defer { fixture.remove() }

        await #expect(throws: PersonalHistoryStorageError.invalidKey) {
            try await fixture.store.append([fixture.event(id: "one", text: "history")])
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
    }

    private final class MutableKeys: PersonalHistoryKeyProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var keyData: Data?
        private var deleted = false
        private var creations = 0

        init(keyData: Data?) {
            self.keyData = keyData
        }

        var wasDeleted: Bool {
            lock.withLock { deleted }
        }

        var creationCount: Int {
            lock.withLock { creations }
        }

        func loadExistingKey() throws -> Data {
            try lock.withLock {
                guard let keyData else { throw PersonalHistoryStorageError.missingKey }
                return keyData
            }
        }

        func loadOrCreateKey() throws -> Data {
            lock.withLock {
                if let keyData { return keyData }
                creations += 1
                let created = Data(repeating: 0x5A, count: 32)
                keyData = created
                return created
            }
        }

        func deleteKey() throws {
            lock.withLock { deleted = true }
        }
    }

    private struct Fixture {
        let root: URL
        let file: URL
        let keys: MutableKeys
        let store: EncryptedPersonalHistoryStore

        init(keyData: Data = Data(repeating: 0xA5, count: 32)) throws {
            root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-history-tests-\(UUID().uuidString)")
            file = root.appendingPathComponent("Personal History/history.v1.enc")
            keys = MutableKeys(keyData: keyData)
            store = EncryptedPersonalHistoryStore(location: file, keyProvider: keys)
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
                sessionIdentifier: "session",
                appBundleIdentifier: "com.example.Editor",
                source: source,
                text: text
            )!
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
