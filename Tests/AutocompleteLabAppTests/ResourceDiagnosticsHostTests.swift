import Foundation
import Testing

@Suite("Resource diagnostics host")
struct ResourceDiagnosticsHostTests {
    @Test("AppDelegate delegates resource timer ownership")
    func appDelegateDelegatesResourceDiagnostics() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/ResourceDiagnosticsHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("let resourceDiagnosticsHost = ResourceDiagnosticsHost()"))
        #expect(appDelegate.contains("resourceDiagnosticsHost.start()"))
        #expect(appDelegate.contains("resourceDiagnosticsHost.stop()"))
        #expect(!appDelegate.contains("ProcessResourceDiagnosticsSampler"))
        #expect(!appDelegate.contains("private func startResourceDiagnostics()"))
        #expect(!appDelegate.contains("private func recordResourceDiagnostics(reason:"))
        #expect(host.contains("runtime-resource-sample"))
        #expect(host.contains("func start()"))
        #expect(host.contains("func stop()"))
    }
}
