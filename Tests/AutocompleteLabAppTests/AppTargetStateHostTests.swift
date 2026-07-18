import Foundation
import Testing

@Suite("App target state host wiring")
struct AppTargetStateHostTests {
    @Test("AppDelegate delegates per-app target state")
    func appDelegateDelegatesPerAppTargetState() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppTargetStateHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("AppTargetStateHost(profileStore: profileStore)"))
        #expect(!appDelegate.contains("private var lastEligibleTargetApp"))
        #expect(!appDelegate.contains("private var lastFieldControlTarget"))
        #expect(host.contains("appForSettingsState"))
        #expect(host.contains("rememberFieldControlTarget"))
    }
}
