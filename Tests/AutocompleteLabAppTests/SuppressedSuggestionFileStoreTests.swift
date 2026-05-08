import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Suppressed suggestion file store")
struct SuppressedSuggestionFileStoreTests {
    @Test("Persists suppression fingerprints without raw suggestion text")
    func persistsFingerprintsWithoutRawText() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuppressedSuggestionFileStoreTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let fileURL = temporaryFolder.appendingPathComponent("suppressed-suggestions.json")
        let store = SuppressedSuggestionFileStore(
            fileURL: fileURL,
            secret: Data("unit-test-secret".utf8)
        )

        let entry = try #require(store.suppressExact(
            "Never show this private phrase",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        ))

        #expect(store.match(
            "never show this private phrase",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        ) == entry)

        let reloaded = SuppressedSuggestionFileStore(
            fileURL: fileURL,
            secret: Data("unit-test-secret".utf8)
        )
        #expect(reloaded.match(
            "Never show this private phrase",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        ) == entry)

        let json = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("Never show"))
        #expect(!json.localizedCaseInsensitiveContains("private phrase"))
        #expect(json.contains(entry.hmacToken))
    }

    @Test("Delete all removes the persisted blocklist")
    func deleteAllRemovesPersistedBlocklist() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuppressedSuggestionFileStoreDeleteTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let fileURL = temporaryFolder.appendingPathComponent("suppressed-suggestions.json")
        let store = SuppressedSuggestionFileStore(
            fileURL: fileURL,
            secret: Data("unit-test-secret".utf8)
        )

        store.suppressExact(
            "Never show this private phrase",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        )
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        store.deleteAll()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(store.match(
            "Never show this private phrase",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        ) == nil)
    }
}
