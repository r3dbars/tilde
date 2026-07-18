import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation orchestration host")
struct SuggestionPresentationOrchestrationHostTests {
    @Test("AppDelegate delegates display and replacement orchestration")
    func appDelegateUsesPresentationOrchestrationHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionPresentationOrchestrationHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var suggestionPresentationOrchestrationHost"))
        #expect(appDelegate.contains("suggestionPresentationOrchestrationHost.presentSuggestion("))
        #expect(host.contains("suggestionOrchestrator.displayScoreDecision("))
        #expect(host.contains("suggestionOrchestrator.replacementDecision("))
        #expect(host.contains("suggestionPresentationCommitHost.commit("))
    }
}
