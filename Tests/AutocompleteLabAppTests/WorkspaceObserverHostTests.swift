import Foundation
import Testing

@Suite("Workspace observer host wiring")
struct WorkspaceObserverHostTests {
    @Test("AppDelegate delegates workspace and screen notification ownership")
    func appDelegateDelegatesWorkspaceObserverOwnership() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/WorkspaceObserverHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("WorkspaceObserverHost(handler: self)"))
        #expect(appDelegate.contains("extension AppDelegate: WorkspaceObserverEventHandling"))
        #expect(appDelegate.contains("handleWorkspaceObserverEvent(_ event: WorkspaceObserverEvent)"))
        #expect(!appDelegate.contains("private func startWorkspaceFocusObservers()"))
        #expect(!appDelegate.contains("private func startScreenGeometryObserver()"))
        #expect(!appDelegate.contains("private var workspaceFocusObservers"))
        #expect(host.contains("NSWorkspace.didActivateApplicationNotification"))
        #expect(host.contains("NSApplication.didChangeScreenParametersNotification"))
        #expect(host.contains("func stop()"))
    }
}
