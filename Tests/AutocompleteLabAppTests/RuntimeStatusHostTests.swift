import Foundation
import Testing

@Suite("Runtime status host wiring")
struct RuntimeStatusHostTests {
    @Test("AppDelegate delegates runtime status transitions")
    func appDelegateDelegatesRuntimeStatusTransitions() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/RuntimeStatusHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("RuntimeStatusHost(handler: self)"))
        #expect(appDelegate.contains("extension AppDelegate: RuntimeStatusHandling"))
        #expect(!appDelegate.contains("private var currentRuntimeState: LocalRuntimeState"))
        #expect(host.contains("hasSurfacedModelSetupUI"))
        #expect(host.contains("Model install: ready"))
        #expect(host.contains("downloadNeeded"))
    }
}
