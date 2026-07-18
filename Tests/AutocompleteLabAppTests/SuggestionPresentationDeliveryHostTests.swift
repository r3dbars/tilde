import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation delivery host")
struct SuggestionPresentationDeliveryHostTests {
    @Test("AppDelegate delegates panel delivery and failure handoff")
    func appDelegateUsesDeliveryHost() throws {
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

        #expect(source.contains("private lazy var suggestionPresentationDeliveryHost"))
        #expect(source.contains("suggestionPresentationDeliveryHost.deliver(\n"))
    }
}
