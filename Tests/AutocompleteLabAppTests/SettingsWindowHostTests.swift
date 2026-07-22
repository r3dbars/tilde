import Foundation
import Testing

@Suite("Settings window host wiring")
struct SettingsWindowHostTests {
    @Test("AppDelegate delegates SettingsWindowController construction")
    func appDelegateDelegatesSettingsConstruction() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("SettingsWindowHost(appDelegate: self)"))
        #expect(appDelegate.contains("func handleSettingsWindowAction(_ action: SettingsWindowAction)"))
        #expect(!appDelegate.contains("private lazy var settingsWindow = SettingsWindowController("))
    }
}
