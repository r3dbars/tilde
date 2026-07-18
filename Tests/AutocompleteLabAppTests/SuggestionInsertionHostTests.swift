import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion insertion host")
struct SuggestionInsertionHostTests {
    @Test("AppDelegate delegates accepted-text routing and keeps safety gates in the host")
    func appDelegateUsesInsertionHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionInsertionHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private(set) lazy var suggestionInsertionHost"))
        #expect(appDelegate.contains("suggestionInsertionHost.insertAcceptedText("))
        #expect(host.contains("acceptedTextSafetyPolicy.decision("))
        #expect(host.contains("insertCodexProofText"))
        #expect(host.contains("insertObsidianSystemEventsPasteText"))
        #expect(host.contains("expectedFieldIdentity: currentSuggestionState.fieldIdentity"))
    }
}
