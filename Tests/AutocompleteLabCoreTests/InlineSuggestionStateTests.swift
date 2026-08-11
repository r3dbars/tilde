import Testing
@testable import AutocompleteLabCore

@Suite("Inline suggestion state")
struct InlineSuggestionStateTests {
    @Test("Stale client, bundle, context, and range tickets cannot present")
    func stalePresentationIsRejected() {
        let expected = ticket()
        let staleTickets = [
            ticket(client: "other"),
            ticket(bundle: "other.app"),
            ticket(context: "different"),
            ticket(location: 8),
            ticket(length: 2),
        ]

        for stale in staleTickets {
            var state = InlineSuggestionState()
            #expect(state.reduce(.awaitSuggestion(expected)).isEmpty)
            #expect(state.reduce(.present(" world", stale)).isEmpty)
            #expect(!state.isVisible)
        }
    }

    @Test("A newer request rejects an older result for the same field state")
    func requestOrderRejectsLateResult() {
        let older = ticket(request: 1)
        let newer = ticket(request: 2)
        var state = InlineSuggestionState()
        _ = state.reduce(.awaitSuggestion(older))
        _ = state.reduce(.awaitSuggestion(newer))

        #expect(state.reduce(.present(" old", older)).isEmpty)
        #expect(state.reduce(.present(" new", newer)) == [.show(" new")])
    }

    @Test("Matching type-through hides, inserts, and re-marks without scheduling")
    func matchingTypeThroughConsumesOneGrapheme() {
        let current = ticket(context: "caf", location: 3)
        let advanced = current.advancing(with: "é")
        var state = InlineSuggestionState()
        _ = state.reduce(.awaitSuggestion(current))
        _ = state.reduce(.present("é noir", current))

        #expect(state.reduce(.type("é", current: current, advanced: advanced)) == [
            .hide, .insert("é"), .show(" noir"),
        ])
        #expect(state.visibleTicket == advanced)
        #expect(state.pendingTicket == nil)
    }

    @Test("Divergence hides, inserts, then schedules a new request")
    func divergenceEffectOrder() {
        let current = ticket()
        var state = InlineSuggestionState()
        _ = state.reduce(.awaitSuggestion(current))
        _ = state.reduce(.present(" world", current))

        #expect(state.reduce(.type("!", current: current, advanced: current.advancing(with: "!"))) == [
            .hide, .insert("!"), .schedule,
        ])
    }

    @Test("Tab accepts the current suggestion without immediately chaining another")
    func acceptanceRequiresCurrentTicket() {
        let current = ticket()
        var stale = InlineSuggestionState()
        _ = stale.reduce(.awaitSuggestion(current))
        _ = stale.reduce(.present(" world", current))
        #expect(stale.reduce(.accept(ticket(location: 99))) == [.hide])

        var live = InlineSuggestionState()
        _ = live.reduce(.awaitSuggestion(current))
        _ = live.reduce(.present(" world", current))
        #expect(live.reduce(.accept(current)) == [.hide, .insert(" world")])
    }

    private func ticket(
        client: String = "client-1",
        bundle: String = "com.example.editor",
        context: String = "hello",
        location: Int = 5,
        length: Int = 0,
        request: Int = 0
    ) -> InlineSuggestionTicket {
        InlineSuggestionTicket(
            clientIdentifier: client,
            bundleIdentifier: bundle,
            contextFingerprint: InlineSuggestionTicket.fingerprint(context),
            selectionLocation: location,
            selectionLength: length,
            requestIdentifier: request
        )
    }
}
