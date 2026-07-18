import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion acceptance host")
struct SuggestionAcceptanceHostTests {
    @Test("AppDelegate delegates keyboard acceptance and preserves guard paths")
    func appDelegateUsesAcceptanceHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionAcceptanceHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var suggestionAcceptanceHost"))
        #expect(appDelegate.contains("suggestionAcceptanceHost.handleAutocompleteKey("))
        #expect(host.contains("KeyboardActionRouter(shortcutConfiguration:"))
        #expect(host.contains("currentSuggestionAcceptanceDecision("))
        #expect(host.contains("insertAcceptedText(acceptedText, action: action)"))
        #expect(host.contains("recordRawAcceptance("))
    }
}
