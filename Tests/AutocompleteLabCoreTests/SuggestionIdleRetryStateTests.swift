import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion idle retry state")
struct SuggestionIdleRetryStateTests {
    @Test("Short boundary request cancelled by a trailing character retries after a pause")
    func shortBoundaryRequestRetriesAfterPause() {
        let triggerPolicy = SuggestionTriggerPolicy(
            wordBoundaryDelayMilliseconds: 80,
            pauseDelayMilliseconds: 80,
            minimumPhraseContinuationWords: 1,
            allowsPlainLineStartPhraseContinuation: true
        )
        let boundaryText = "Hi "
        let trailingCharacterText = "Hi t"

        #expect(triggerPolicy.decision(
            previousTextBeforeCursor: "Hi",
            currentTextBeforeCursor: boundaryText,
            requestMode: .phraseContinuation
        ) == .request(delayMilliseconds: 80))
        #expect(triggerPolicy.decision(
            previousTextBeforeCursor: boundaryText,
            currentTextBeforeCursor: trailingCharacterText,
            requestMode: .phraseContinuation
        ) == .skip)

        var state = SuggestionIdleRetryState()
        let snapshot = snapshot(trailingCharacterText)
        state.noteTextChange(
            snapshot: snapshot,
            cancelledPendingRequest: true,
            nowMilliseconds: 20,
            settleDelayMilliseconds: 80
        )

        #expect(state.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: 99,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(state.hasPendingRetry)
        #expect(state.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: 100,
            hasVisibleSuggestion: false
        ) == .requestCancelled)
        #expect(!state.hasPendingRetry)

        #expect(triggerPolicy.decision(
            previousTextBeforeCursor: nil,
            currentTextBeforeCursor: trailingCharacterText,
            requestMode: .phraseContinuation
        ) == .request(delayMilliseconds: 80))
    }

    @Test("Typing burst retry follows the final character and fires only once after settling")
    func typingBurstRetryFollowsFinalCharacter() {
        var state = SuggestionIdleRetryState(settleDelayMilliseconds: 200)
        let first = snapshot("Burst a")
        let second = snapshot("Burst ab")
        let final = snapshot("Burst abc")

        state.noteTextChange(
            snapshot: first,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        state.noteTextChange(
            snapshot: second,
            cancelledPendingRequest: false,
            nowMilliseconds: 50
        )
        state.noteTypingBurstSuppression(
            snapshot: final,
            nowMilliseconds: 100
        )

        #expect(state.consumeRetryIfReady(
            snapshot: final,
            nowMilliseconds: 299,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(state.consumeRetryIfReady(
            snapshot: final,
            nowMilliseconds: 300,
            hasVisibleSuggestion: false
        ) == .typingBurstSuppressed)
        #expect(state.consumeRetryIfReady(
            snapshot: final,
            nowMilliseconds: 500,
            hasVisibleSuggestion: false
        ) == nil)
    }

    @Test("New snapshot or visible suggestion cancels a stale idle retry")
    func staleRetryIsCancelled() {
        var changedState = SuggestionIdleRetryState(settleDelayMilliseconds: 100)
        let original = snapshot("One")
        changedState.noteTextChange(
            snapshot: original,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )

        #expect(changedState.consumeRetryIfReady(
            snapshot: snapshot("Two"),
            nowMilliseconds: 100,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(!changedState.hasPendingRetry)

        var fieldChangedState = SuggestionIdleRetryState(settleDelayMilliseconds: 100)
        fieldChangedState.noteTextChange(
            snapshot: original,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        #expect(fieldChangedState.consumeRetryIfReady(
            snapshot: snapshot("One", elementIdentifier: 8),
            nowMilliseconds: 100,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(!fieldChangedState.hasPendingRetry)

        var visibleState = SuggestionIdleRetryState(settleDelayMilliseconds: 100)
        visibleState.noteTextChange(
            snapshot: original,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        #expect(visibleState.consumeRetryIfReady(
            snapshot: original,
            nowMilliseconds: 100,
            hasVisibleSuggestion: true
        ) == nil)
        #expect(!visibleState.hasPendingRetry)
    }

    @Test("Quarantined AX cancellation follows the recovered final snapshot")
    func axQuarantineCancellationFollowsRecoveredSnapshot() {
        var state = SuggestionIdleRetryState(settleDelayMilliseconds: 240)
        let partial = snapshot(String(repeating: "a", count: 15))
        let recovered = snapshot(
            String(repeating: "a", count: 15) + String(repeating: "b", count: 11)
        )

        state.noteTextChange(
            snapshot: partial,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        #expect(state.hasPendingRetry)

        state.noteTextChange(
            snapshot: recovered,
            cancelledPendingRequest: false,
            nowMilliseconds: 750
        )
        #expect(state.consumeRetryIfReady(
            snapshot: recovered,
            nowMilliseconds: 989,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(state.consumeRetryIfReady(
            snapshot: recovered,
            nowMilliseconds: 990,
            hasVisibleSuggestion: false
        ) == .requestCancelled)
        #expect(state.consumeRetryIfReady(
            snapshot: recovered,
            nowMilliseconds: 1_500,
            hasVisibleSuggestion: false
        ) == nil)
    }

    @Test("Explicit cancellation clears a pending retry")
    func explicitCancellationClearsPendingRetry() {
        var state = SuggestionIdleRetryState(settleDelayMilliseconds: 100)
        let snapshot = snapshot("Pending")
        state.noteTextChange(
            snapshot: snapshot,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )

        #expect(state.hasPendingRetry)
        state.cancel()
        #expect(!state.hasPendingRetry)
        #expect(state.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: 100,
            hasVisibleSuggestion: false
        ) == nil)
    }

    private func snapshot(
        _ textBeforeCursor: String,
        elementIdentifier: Int = 7
    ) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.example.synthetic",
                processIdentifier: 42,
                elementIdentifier: elementIdentifier
            ),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: ""
        )
    }
}
