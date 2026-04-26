import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion request gate")
struct SuggestionRequestGateTests {
    @Test("Issued ticket is allowed for the matching current request")
    func issuedTicketIsAllowed() {
        var gate = SuggestionRequestGate()
        let request = CompletionRequest(textBeforeCursor: "Can we")

        let ticket = gate.issue(request: request)

        #expect(gate.allows(ticket, currentRequest: request))
    }

    @Test("Invalidating blocks stale returned suggestions")
    func invalidatingBlocksStaleTickets() {
        var gate = SuggestionRequestGate()
        let firstRequest = CompletionRequest(textBeforeCursor: "Can we")
        let firstTicket = gate.issue(request: firstRequest)

        gate.invalidate()

        #expect(!gate.allows(firstTicket, currentRequest: firstRequest))
    }

    @Test("Newer request blocks older request even when text still exists")
    func newerRequestBlocksOlderTicket() {
        var gate = SuggestionRequestGate()
        let firstRequest = CompletionRequest(textBeforeCursor: "Can we")
        let firstTicket = gate.issue(request: firstRequest)
        let newerRequest = CompletionRequest(textBeforeCursor: "Can we make")

        let newerTicket = gate.issue(request: newerRequest)

        #expect(!gate.allows(firstTicket, currentRequest: firstRequest))
        #expect(!gate.allows(firstTicket, currentRequest: newerRequest))
        #expect(gate.allows(newerTicket, currentRequest: newerRequest))
    }
}
