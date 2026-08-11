import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Secure local storage")
struct SecureLocalStorageTests {
    private func makeTempDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-secure-storage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func posixMode(of url: URL) throws -> Int16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = try #require(attributes[.posixPermissions] as? NSNumber)
        return number.int16Value & 0o777
    }

    @Test("Created directories are owner-only (0700)")
    func createsOwnerOnlyDirectory() throws {
        let root = makeTempDirectoryURL()
        let directory = root.appendingPathComponent("nested/logs", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(SecureLocalStorage.createDirectory(at: directory))
        #expect(try posixMode(of: directory) == 0o700)
    }

    @Test("Created files are owner-only (0600)")
    func createsOwnerOnlyFile() throws {
        let root = makeTempDirectoryURL()
        let file = root.appendingPathComponent("traces.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(SecureLocalStorage.createDirectory(at: root))
        #expect(SecureLocalStorage.ensureFile(at: file))
        #expect(try posixMode(of: file) == 0o600)
    }

    @Test("Existing world-readable files are tightened on next ensure (migration)")
    func tightensExistingLooseFile() throws {
        let root = makeTempDirectoryURL()
        let file = root.appendingPathComponent("legacy.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Simulate a file created by an earlier build at the default umask (world-readable).
        #expect(FileManager.default.createFile(
            atPath: file.path,
            contents: Data("old\n".utf8),
            attributes: [.posixPermissions: NSNumber(value: Int16(0o644))]
        ))
        #expect(try posixMode(of: file) == 0o644)

        #expect(SecureLocalStorage.ensureFile(at: file))
        #expect(try posixMode(of: file) == 0o600)
        // Contents are preserved — tightening must not truncate an existing log.
        #expect(try String(contentsOf: file, encoding: .utf8) == "old\n")
    }

    @Test("Existing world-readable directories are tightened on next create (migration)")
    func tightensExistingLooseDirectory() throws {
        let root = makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o755))]
        )
        #expect(try posixMode(of: root) == 0o755)

        #expect(SecureLocalStorage.createDirectory(at: root))
        #expect(try posixMode(of: root) == 0o700)
    }

}
