import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation commit host")
struct SuggestionPresentationCommitHostTests {
    @Test("AppDelegate delegates post-delivery state and trace commit to the host")
    func appDelegateUsesCommitHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionPresentationCommitHost"))
        #expect(source.contains("suggestionPresentationCommitHost.commit(input: presentationCommitInput)"))
        #expect(!source.contains("RawAutocompleteTraceLog.shared.record(\n            type: .suggestionPresented"))
    }
}
