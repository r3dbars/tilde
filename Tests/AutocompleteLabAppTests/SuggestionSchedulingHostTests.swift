import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion scheduling host")
struct SuggestionSchedulingHostTests {
    @Test("AppDelegate delegates request scheduling and preserves fast-path gates")
    func appDelegateUsesSuggestionSchedulingHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var suggestionSchedulingHost"))
        #expect(appDelegate.contains("suggestionSchedulingHost.scheduleSuggestion("))
        #expect(host.contains("disablesWordCompletionForProof"))
        #expect(host.contains("suggestionOrchestrator.fastWordSelection("))
        #expect(host.contains("suggestionOrchestrator.fastPhraseSelection("))
        #expect(host.contains("suggestionRequestExecutionHost.schedule("))
    }
}
