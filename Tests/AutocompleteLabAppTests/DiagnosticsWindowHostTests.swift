import Foundation
import Testing

@Suite("Diagnostics window host wiring")
struct DiagnosticsWindowHostTests {
    @Test("AppDelegate delegates diagnostics window ownership")
    func appDelegateDelegatesDiagnosticsWindowOwnership() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/DiagnosticsWindowHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("DiagnosticsWindowHost(handler: self)"))
        #expect(appDelegate.contains("extension AppDelegate: DiagnosticsWindowActionHandling"))
        #expect(!appDelegate.contains("private let diagnosticsWindow = DiagnosticsWindowController()"))
        #expect(host.contains("struct DiagnosticsWindowPresentation"))
        #expect(host.contains("func show(_ presentation: DiagnosticsWindowPresentation)"))
        #expect(host.contains("toggleDiagnosticsScreenshotTracing"))
    }
}
