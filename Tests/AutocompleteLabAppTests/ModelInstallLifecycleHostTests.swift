import Foundation
import Testing

@Suite("Model install lifecycle host wiring")
struct ModelInstallLifecycleHostTests {
    @Test("AppDelegate delegates model install lifecycle")
    func appDelegateDelegatesModelInstallLifecycle() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/ModelInstallLifecycleHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("ModelInstallLifecycleHost(handler: self)"))
        #expect(appDelegate.contains("extension AppDelegate: ModelInstallLifecycleHandling"))
        #expect(!appDelegate.contains("private let modelInstallHost = ModelInstallHost()"))
        #expect(host.contains("model-install-succeeded"))
        #expect(host.contains("model-install-cancel-requested"))
        #expect(host.contains("reloadModelRuntimeAfterInstall"))
    }
}
