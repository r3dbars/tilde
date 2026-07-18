import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation preparation host")
struct SuggestionPresentationPreparationHostTests {
    @Test("AppDelegate delegates late-result and placement preparation")
    func appDelegateUsesPreparationHost() throws {
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

        #expect(source.contains("private lazy var suggestionPresentationPreparationHost"))
        #expect(source.contains("suggestionPresentationPreparationHost.prepare(\n"))
    }
}
