import Testing
@testable import AutocompleteLabCore

@Suite("Completion failure visibility policy")
struct CompletionFailureVisibilityPolicyTests {
    private let policy = CompletionFailureVisibilityPolicy()

    @Test("Current failed request can hide the visible suggestion")
    func currentFailedRequestCanHide() {
        var gate = SuggestionRequestGate()
        let request = CompletionRequest(textBeforeCursor: "Can we make")
        let ticket = gate.issue(request: request)
        let fieldIdentity = identity(1)

        #expect(policy.shouldHideVisibleSuggestion(
            requestGate: gate,
            ticket: ticket,
            currentRequest: request,
            failedRequestFieldIdentity: fieldIdentity,
            currentFieldIdentity: fieldIdentity
        ))
    }

    @Test("Stale failed request cannot hide a newer suggestion")
    func staleFailedRequestCannotHide() {
        var gate = SuggestionRequestGate()
        let staleRequest = CompletionRequest(textBeforeCursor: "Can we")
        let staleTicket = gate.issue(request: staleRequest)
        let newerRequest = CompletionRequest(textBeforeCursor: "Can we make this inst", mode: .wordCompletion)
        _ = gate.issue(request: newerRequest)
        let fieldIdentity = identity(1)

        #expect(!policy.shouldHideVisibleSuggestion(
            requestGate: gate,
            ticket: staleTicket,
            currentRequest: newerRequest,
            failedRequestFieldIdentity: fieldIdentity,
            currentFieldIdentity: fieldIdentity
        ))
    }

    @Test("Different field failed request cannot hide the visible suggestion")
    func differentFieldFailedRequestCannotHide() {
        var gate = SuggestionRequestGate()
        let request = CompletionRequest(textBeforeCursor: "Can we make")
        let ticket = gate.issue(request: request)

        #expect(!policy.shouldHideVisibleSuggestion(
            requestGate: gate,
            ticket: ticket,
            currentRequest: request,
            failedRequestFieldIdentity: identity(1),
            currentFieldIdentity: identity(2)
        ))
    }

    private func identity(_ elementIdentifier: Int) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.Notes",
            processIdentifier: 42,
            elementIdentifier: elementIdentifier
        )
    }
}
