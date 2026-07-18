import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion request cancellation host")
struct SuggestionRequestCancellationHostTests {
    @Test("Cancels retry before the pending request and clears streaming state")
    func cancelsInOrder() {
        var events: [String] = []
        let host = SuggestionRequestCancellationHost(
            dependencies: SuggestionRequestCancellationHostDependencies(
                clearCooldownPreservation: { events.append("clear-cooldown") },
                hasScheduledPresentationRetry: { true },
                cancelPresentationRetry: { events.append("cancel-retry") },
                cancelPendingRequest: {
                    events.append("cancel-request")
                    return true
                },
                clearStreamingPresentations: { events.append("clear-streaming") },
                invalidateRequest: { events.append("invalidate-request") }
            )
        )

        #expect(host.cancelPendingRequest(reason: "test"))
        #expect(events == [
            "clear-cooldown",
            "cancel-retry",
            "cancel-request",
            "clear-streaming"
        ])
    }

    @Test("Reports retry cancellation when no model request is pending")
    func reportsRetryOnlyCancellation() {
        var clearStreamingCalled = false
        let host = SuggestionRequestCancellationHost(
            dependencies: SuggestionRequestCancellationHostDependencies(
                clearCooldownPreservation: {},
                hasScheduledPresentationRetry: { true },
                cancelPresentationRetry: {},
                cancelPendingRequest: { false },
                clearStreamingPresentations: { clearStreamingCalled = true },
                invalidateRequest: {}
            )
        )

        #expect(host.cancelPendingRequest(reason: "retry-only"))
        #expect(!clearStreamingCalled)
    }

    @Test("Does not report cancellation when neither request nor retry is pending")
    func reportsNoCancellation() {
        let host = SuggestionRequestCancellationHost(
            dependencies: SuggestionRequestCancellationHostDependencies(
                clearCooldownPreservation: {},
                hasScheduledPresentationRetry: { false },
                cancelPresentationRetry: {},
                cancelPendingRequest: { false },
                clearStreamingPresentations: {},
                invalidateRequest: {}
            )
        )

        #expect(!host.cancelPendingRequest(reason: "idle"))
    }

    @Test("Invalidation always clears streaming state before invalidating the request")
    func invalidatesInOrder() {
        var events: [String] = []
        let host = SuggestionRequestCancellationHost(
            dependencies: SuggestionRequestCancellationHostDependencies(
                clearCooldownPreservation: { events.append("clear-cooldown") },
                hasScheduledPresentationRetry: { false },
                cancelPresentationRetry: {},
                cancelPendingRequest: { events.append("cancel-request"); return false },
                clearStreamingPresentations: { events.append("clear-streaming") },
                invalidateRequest: { events.append("invalidate-request") }
            )
        )

        #expect(!host.invalidatePendingRequest())
        #expect(events == [
            "clear-cooldown",
            "cancel-request",
            "clear-streaming",
            "invalidate-request"
        ])
    }

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
