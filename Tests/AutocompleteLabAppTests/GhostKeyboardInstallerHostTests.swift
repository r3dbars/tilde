import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Keyboard installer")
struct GhostKeyboardInstallerHostTests {
    private let fileManager = FileManager.default

    private func makeBundle(
        at url: URL,
        identifier: String = "bar.r3d.inputmethod.InlineGhost",
        contents: String,
        date: Date
    ) throws {
        let executable = url.appendingPathComponent("Contents/MacOS/InlineGhostIME")
        try fileManager.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let info: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleExecutable": "InlineGhostIME"
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: url.appendingPathComponent("Contents/Info.plist"))
        try Data(contents.utf8).write(to: executable)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755, .modificationDate: date],
            ofItemAtPath: executable.path
        )
    }

    @Test("A ready replacement swaps in without leaving staging files")
    func replacesInstalledBundle() throws {
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundled = root.appendingPathComponent("Bundled.app")
        let installed = root.appendingPathComponent("Input Methods/InlineGhostIME.app")
        defer { try? fileManager.removeItem(at: root) }

        try makeBundle(at: bundled, contents: "new", date: Date())
        try makeBundle(at: installed, contents: "old", date: .distantPast)

        #expect(try GhostKeyboardInstallerHost.installIfNeeded(
            bundled: bundled,
            installed: installed,
            fileManager: fileManager
        ))
        let binary = installed.appendingPathComponent("Contents/MacOS/InlineGhostIME")
        #expect(try String(contentsOf: binary, encoding: .utf8) == "new")
        let siblings = try fileManager.contentsOfDirectory(
            at: installed.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        #expect(siblings.map(\.lastPathComponent) == ["InlineGhostIME.app"])
    }

    @Test("An invalid packaged keyboard cannot disturb the installed keyboard")
    func rejectsInvalidSourceBeforeMutation() throws {
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundled = root.appendingPathComponent("Bundled.app")
        let installed = root.appendingPathComponent("Input Methods/InlineGhostIME.app")
        defer { try? fileManager.removeItem(at: root) }

        try makeBundle(at: bundled, identifier: "example.invalid", contents: "bad", date: Date())
        try makeBundle(at: installed, contents: "working", date: .distantPast)

        #expect(throws: (any Error).self) {
            try GhostKeyboardInstallerHost.installIfNeeded(
                bundled: bundled,
                installed: installed,
                fileManager: fileManager
            )
        }
        let binary = installed.appendingPathComponent("Contents/MacOS/InlineGhostIME")
        #expect(try String(contentsOf: binary, encoding: .utf8) == "working")
    }
}
