@testable import AutocompleteLabApp
import Testing

@Suite("Suggestion request scheduler")
@MainActor
struct SuggestionRequestSchedulerTests {
    @Test("cancels a pending request before it runs")
    func cancelsPendingRequestBeforeItRuns() async throws {
        let scheduler = SuggestionRequestScheduler()
        var didRun = false

        scheduler.schedule(suggestionID: "first", delayMilliseconds: 80) {
            didRun = true
        }

        #expect(scheduler.hasPendingRequest)
        #expect(scheduler.cancelPendingRequest())
        #expect(!scheduler.hasPendingRequest)

        try await Task.sleep(for: .milliseconds(120))
        #expect(!didRun)
    }

    @Test("clears completed request state")
    func clearsCompletedRequestState() async throws {
        let scheduler = SuggestionRequestScheduler()
        var didRun = false

        scheduler.schedule(suggestionID: "second", delayMilliseconds: 10) {
            didRun = true
        }

        try await Task.sleep(for: .milliseconds(60))
        #expect(didRun)
        #expect(!scheduler.hasPendingRequest)
    }
}
