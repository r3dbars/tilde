import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion trigger timing host")
struct SuggestionTriggerTimingHostTests {
    @Test("AppDelegate delegates trigger timing outcomes and scheduling")
    func appDelegateUsesTriggerTimingHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionTriggerTimingHost"))
        #expect(source.contains("suggestionTriggerTimingHost.handle(\n"))
    }
}
