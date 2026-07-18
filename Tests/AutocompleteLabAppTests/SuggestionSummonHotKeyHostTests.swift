import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion summon hotkey host")
@MainActor
struct SuggestionSummonHotKeyHostTests {
    @Test("Keeps the Control-Backtick descriptor and forwards lifecycle")
    func ownsNativeHotKeyLifecycle() {
        let host = SuggestionSummonHotKeyHost {
        }

        #expect(host.descriptor == .controlBacktick)
        host.stop()
    }

    @Test("AppDelegate delegates summon hotkey ownership")
    func appDelegateDelegatesHotKeyOwnership() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("SuggestionSummonHotKeyHost"))
        #expect(appDelegate.contains("suggestionSummonHotKeyHost.start()"))
        #expect(appDelegate.contains("suggestionSummonHotKeyHost.stop()"))
        #expect(!appDelegate.contains("SuggestionSummonHotKey {"))
    }
}
