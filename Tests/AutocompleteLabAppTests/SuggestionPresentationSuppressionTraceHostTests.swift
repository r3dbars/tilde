import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation suppression trace host")
struct SuggestionPresentationSuppressionTraceHostTests {
    @Test("AppDelegate delegates presentation suppression trace handoff")
    func appDelegateUsesSuppressionTraceHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/AutocompleteLabApp/App/SuggestionPresentationSuppressionTraceHost.swift"
            ),
            encoding: .utf8
        )
        let orchestrationHost = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/AutocompleteLabApp/App/SuggestionPresentationOrchestrationHost.swift"
            ),
            encoding: .utf8
        )
        let presentationWiring = appDelegate + orchestrationHost

        #expect(appDelegate.contains("private lazy var suggestionPresentationSuppressionTraceHost"))
        #expect(presentationWiring.contains("suggestionPresentationSuppressionTraceHost.record(\n"))
        #expect(host.contains("type: .suggestionSuppressed"))
        #expect(host.contains("suggestion-blocked"))
    }
}
