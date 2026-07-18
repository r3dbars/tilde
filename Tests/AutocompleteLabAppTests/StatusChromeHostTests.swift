import Foundation
import Testing

@Suite("Status chrome host wiring")
struct StatusChromeHostTests {
    @Test("AppDelegate delegates status output ownership")
    func appDelegateDelegatesStatusOutputOwnership() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/StatusChromeHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("StatusChromeHost("))
        #expect(appDelegate.contains("statusChromeHost.update("))
        #expect(!appDelegate.contains("private var lastStatusLine"))
        #expect(host.contains("private var lastStatusLine"))
        #expect(host.contains("DiagnosticsLog.shared.record(\"status\""))
        #expect(host.contains("settingsWindow.refresh("))
    }
}
