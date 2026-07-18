import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("App enablement host")
@MainActor
struct AppEnablementHostTests {
    @Test("Persists disabled app state and setup completion without AppDelegate")
    func persistsEnablementState() {
        let suiteName = "SteadyType.AppEnablementHostTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let host = AppEnablementHost(profileStore: .mvp)
        host.load(defaults: defaults)
        #expect(host.disabledBundleIdentifiers.isEmpty)
        #expect(!host.setupCompleted)

        host.disabledBundleIdentifiers = ["com.example.test"]
        host.persist(defaults: defaults)
        host.markSetupCompleted(defaults: defaults)

        let reloaded = AppEnablementHost(profileStore: .mvp)
        reloaded.load(defaults: defaults)
        #expect(reloaded.disabledBundleIdentifiers == ["com.example.test"])
        #expect(reloaded.setupCompleted)
    }

    @Test("AppDelegate delegates enablement storage and persistence")
    func appDelegateDelegatesEnablementStorage() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("AppEnablementHost(profileStore: profileStore)"))
        #expect(appDelegate.contains("appEnablementHost.load()"))
        #expect(appDelegate.contains("appEnablementHost.persist()"))
        #expect(appDelegate.contains("appEnablementHost.markSetupCompleted()"))
        #expect(!appDelegate.contains("DisabledAppSelection(defaultOffProfileStore:"))
    }
}
