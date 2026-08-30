import Foundation
import Testing
@testable import InlineGhostIME

@Suite("Outcome ledger storage")
struct GhostOutcomeLedgerStorageTests {
    private func temporaryRoot() -> URL {
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-outcome-writer-\(UUID().uuidString)", isDirectory: true)
    }

    private func mode(of url: URL) throws -> Int16 {
        var info = stat()
        try #require(lstat(url.path, &info) == 0)
        return Int16(info.st_mode & 0o7777)
    }

    @Test("Outcome appends reject a symbolic-link leaf without touching its target")
    func rejectsSymlinkLeaf() throws {
        let root = temporaryRoot()
        let directory = root.appendingPathComponent("Outcome Ledger", isDirectory: true)
        let target = root.appendingPathComponent("sentinel.jsonl")
        let link = directory.appendingPathComponent("events.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("sentinel\n".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(!GhostOutcomeLedger.appendOwnerOnly(Data("event\n".utf8), to: link))
        #expect(try String(contentsOf: target, encoding: .utf8) == "sentinel\n")
    }

    @Test("Outcome appends reject a symbolic-link parent")
    func rejectsSymlinkParent() throws {
        let root = temporaryRoot()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let link = root.appendingPathComponent("Outcome Ledger", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(!GhostOutcomeLedger.appendOwnerOnly(
            Data("event\n".utf8),
            to: link.appendingPathComponent("events.jsonl")
        ))
        #expect(!FileManager.default.fileExists(
            atPath: target.appendingPathComponent("events.jsonl").path
        ))
    }

    @Test("Outcome appends tighten loose files and directories")
    func tightensExistingStorage() throws {
        let root = temporaryRoot()
        let directory = root.appendingPathComponent("Outcome Ledger", isDirectory: true)
        let file = directory.appendingPathComponent("events.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(chmod(directory.path, 0o755) == 0)
        #expect(FileManager.default.createFile(
            atPath: file.path,
            contents: Data("old\n".utf8),
            attributes: [.posixPermissions: 0o644]
        ))
        #expect(chmod(file.path, 0o644) == 0)

        #expect(GhostOutcomeLedger.appendOwnerOnly(Data("new\n".utf8), to: file))
        #expect(try mode(of: directory) == 0o700)
        #expect(try mode(of: file) == 0o600)
        #expect(try String(contentsOf: file, encoding: .utf8) == "old\nnew\n")
    }

    @Test("A revoked generation cannot write after taking the directory lock")
    func rechecksPermissionImmediatelyBeforeWrite() throws {
        let root = temporaryRoot()
        let file = root.appendingPathComponent("Outcome Ledger/events.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }
        var checks = 0

        #expect(!GhostOutcomeLedger.appendOwnerOnly(Data("stale\n".utf8), to: file) {
            checks += 1
            return checks == 1
        })
        #expect(checks == 2)
        #expect(try Data(contentsOf: file).isEmpty)
    }
}
