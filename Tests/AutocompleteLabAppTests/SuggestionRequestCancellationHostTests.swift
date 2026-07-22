import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion request cancellation host")
struct SuggestionRequestCancellationHostTests {




    @Test("AppDelegate delegates request cancellation to the host")
    func appDelegateUsesCancellationHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionRequestCancellationHost"))
        #expect(source.contains("suggestionRequestCancellationHost.cancelPendingRequest(reason: reason)"))
        #expect(source.contains("suggestionRequestCancellationHost.invalidatePendingRequest()"))
        #expect(!source.contains("let cancelledPendingRequest = suggestionRequestScheduler.cancelPendingRequest()"))
    }
}
