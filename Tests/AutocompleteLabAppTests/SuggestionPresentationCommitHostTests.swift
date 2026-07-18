import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation commit host")
struct SuggestionPresentationCommitHostTests {
    @Test("AppDelegate delegates post-delivery state and trace commit to the host")
    func appDelegateUsesCommitHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let orchestrationHost = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionPresentationOrchestrationHost.swift"),
            encoding: .utf8
        )
        let source = appDelegate + orchestrationHost

        #expect(source.contains("private lazy var suggestionPresentationCommitHost"))
        #expect(source.contains("suggestionPresentationCommitHost.commit(input: presentationCommitInput)"))
        #expect(!source.contains("RawAutocompleteTraceLog.shared.record(\n            type: .suggestionPresented"))
    }
}
