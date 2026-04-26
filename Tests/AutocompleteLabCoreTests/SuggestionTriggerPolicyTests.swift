import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion trigger policy")
struct SuggestionTriggerPolicyTests {
    @Test("First snapshot requests a suggestion")
    func firstSnapshotRequestsSuggestion() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: nil, currentTextBeforeCursor: "I think"))
    }

    @Test("Unchanged snapshots do not request again")
    func unchangedSnapshotsDoNotRequestAgain() {
        let policy = SuggestionTriggerPolicy()

        #expect(!policy.shouldRequestSuggestion(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I think"))
    }

    @Test("Typing and deletion request refreshed suggestions")
    func typingAndDeletionRequestRefreshes() {
        let policy = SuggestionTriggerPolicy(charactersBeforePauseRequest: 4)

        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: "I thin", currentTextBeforeCursor: "I think"))
        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: "I", currentTextBeforeCursor: "I think"))
        #expect(policy.shouldRequestSuggestion(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I thin"))
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

    @Test("Short in-word typing waits for the pause threshold")
    func shortInWordTypingWaits() {
        let policy = SuggestionTriggerPolicy(charactersBeforePauseRequest: 4)

        #expect(policy.decision(previousTextBeforeCursor: "I thi", currentTextBeforeCursor: "I thin") == .request(delayMilliseconds: 60))
        #expect(policy.decision(previousTextBeforeCursor: "I ", currentTextBeforeCursor: "I think") == .request(delayMilliseconds: 60))
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
}
