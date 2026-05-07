import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion trigger policy")
struct SuggestionTriggerPolicyTests {
    @Test("First snapshot requests a suggestion")
    func firstSnapshotRequestsSuggestion() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(previousTextBeforeCursor: nil, currentTextBeforeCursor: "I think") == .request(delayMilliseconds: 70))
    }

    @Test("Unchanged snapshots do not request again")
    func unchangedSnapshotsDoNotRequestAgain() {
        let policy = SuggestionTriggerPolicy()

        #expect(!policy.shouldRequestSuggestion(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I think"))
    }

    @Test("Typing requests refreshed suggestions but deletion stays quiet")
    func typingRequestsRefreshesButDeletionStaysQuiet() {
        let policy = SuggestionTriggerPolicy(charactersBeforePauseRequest: 4)

        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: "I thin", currentTextBeforeCursor: "I think"))
        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: "I", currentTextBeforeCursor: "I think"))
        #expect(!policy.shouldRequestSuggestion(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I thin"))
    }

    @Test("Natural boundaries trigger quickly")
    func naturalBoundariesTriggerQuickly() {
        let policy = SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 4,
            wordBoundaryDelayMilliseconds: 80,
            pauseDelayMilliseconds: 180
        )

        #expect(policy.decision(previousTextBeforeCursor: "Can", currentTextBeforeCursor: "Can ") == .request(delayMilliseconds: 80))
        #expect(policy.decision(previousTextBeforeCursor: "Can we", currentTextBeforeCursor: "Can we,") == .request(delayMilliseconds: 80))
    }

    @Test("Short in-word typing requests instant word completion")
    func shortInWordTypingWaits() {
        let policy = SuggestionTriggerPolicy(charactersBeforePauseRequest: 4)

        #expect(policy.decision(previousTextBeforeCursor: "I thi", currentTextBeforeCursor: "I thin") == .request(delayMilliseconds: 0))
        #expect(policy.decision(previousTextBeforeCursor: "I ", currentTextBeforeCursor: "I think") == .request(delayMilliseconds: 0))
    }

    @Test("Snappy mode requests a phrase on every changed character")
    func snappyModeRequestsEveryChangedCharacter() {
        let policy = SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 1,
            wordBoundaryDelayMilliseconds: 0,
            pauseDelayMilliseconds: 15
        )

        #expect(policy.decision(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I think ") == .request(delayMilliseconds: 0))
        #expect(policy.decision(previousTextBeforeCursor: "I think this wor", currentTextBeforeCursor: "I think this work") == .request(delayMilliseconds: 0))
        #expect(policy.decision(previousTextBeforeCursor: "I think ", currentTextBeforeCursor: "I think x") == .request(delayMilliseconds: 15))
    }

    @Test("Word fragments trigger quickly for completion")
    func wordFragmentsTriggerQuickly() {
        let policy = SuggestionTriggerPolicy(wordCompletionDelayMilliseconds: 50)

        #expect(policy.decision(previousTextBeforeCursor: "d", currentTextBeforeCursor: "di") == .request(delayMilliseconds: 50))
        #expect(policy.decision(previousTextBeforeCursor: "di", currentTextBeforeCursor: "dic") == .request(delayMilliseconds: 50))
    }

    @Test("Word fragments after a space trigger quickly for completion")
    func wordFragmentsAfterSpaceTriggerQuickly() {
        let policy = SuggestionTriggerPolicy(wordCompletionDelayMilliseconds: 50)

        #expect(policy.decision(
            previousTextBeforeCursor: "I need the ",
            currentTextBeforeCursor: "I need the tr"
        ) == .request(delayMilliseconds: 50))
    }

    @Test("Large pasted text waits before requesting")
    func largePastedTextWaitsBeforeRequesting() {
        let policy = SuggestionTriggerPolicy(
            pauseDelayMilliseconds: 70,
            largeTextChangeCharacterThreshold: 10,
            largeTextChangeDelayMilliseconds: 300
        )

        #expect(policy.decision(
            previousTextBeforeCursor: "I think ",
            currentTextBeforeCursor: "I think this whole pasted sentence should not fire instantly"
        ) == .request(delayMilliseconds: 300))
    }
}
