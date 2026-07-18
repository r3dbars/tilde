import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation preparation host")
struct SuggestionPresentationPreparationHostTests {
    @Test("AppDelegate delegates late-result and placement preparation")
    func appDelegateUsesPreparationHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionPresentationPreparationHost"))
        #expect(source.contains("suggestionPresentationPreparationHost.prepare(\n"))
    }
}
