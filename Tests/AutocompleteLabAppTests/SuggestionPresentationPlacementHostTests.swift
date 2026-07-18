import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation placement host")
struct SuggestionPresentationPlacementHostTests {
    @Test("AppDelegate delegates placement suppression side effects")
    func appDelegateUsesPlacementHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionPresentationPlacementHost"))
        #expect(source.contains("suggestionPresentationPlacementHost.suppress(\n"))
    }
}
