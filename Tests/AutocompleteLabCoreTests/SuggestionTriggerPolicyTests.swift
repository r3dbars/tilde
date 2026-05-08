import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion trigger policy")
struct SuggestionTriggerPolicyTests {
    @Test("First snapshot requests a suggestion")
    func firstSnapshotRequestsSuggestion() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(previousTextBeforeCursor: nil, currentTextBeforeCursor: "I think") == .request(delayMilliseconds: 180))
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

    @Test("Natural word boundaries use phrase delay")
    func naturalWordBoundariesUsePhraseDelay() {
        let policy = SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 4,
            wordBoundaryDelayMilliseconds: 80,
            pauseDelayMilliseconds: 180
        )

        #expect(policy.decision(previousTextBeforeCursor: "Can we", currentTextBeforeCursor: "Can we ") == .request(delayMilliseconds: 80))
    }

    @Test("Punctuation boundaries use separate researched delays")
    func punctuationBoundariesUseSeparateResearchedDelays() {
        let policy = SuggestionTriggerPolicy(
            wordBoundaryDelayMilliseconds: 160,
            softPunctuationDelayMilliseconds: 220,
            structuralPunctuationDelayMilliseconds: 240,
            closingPunctuationDelayMilliseconds: 180
        )

        #expect(policy.decision(
            previousTextBeforeCursor: "Can we",
            currentTextBeforeCursor: "Can we,"
        ) == .request(delayMilliseconds: 220))

        #expect(policy.decision(
            previousTextBeforeCursor: "Can we",
            currentTextBeforeCursor: "Can we;"
        ) == .request(delayMilliseconds: 220))

        #expect(policy.decision(
            previousTextBeforeCursor: "Can we",
            currentTextBeforeCursor: "Can we:"
        ) == .request(delayMilliseconds: 240))

        #expect(policy.decision(
            previousTextBeforeCursor: "Can we",
            currentTextBeforeCursor: "Can we)"
        ) == .request(delayMilliseconds: 180))

        #expect(policy.decision(
            previousTextBeforeCursor: "Can we",
            currentTextBeforeCursor: "Can we "
        ) == .request(delayMilliseconds: 160))
    }

    @Test("Profile punctuation waits at fragile boundaries")
    func profilePunctuationWaitsAtFragileBoundaries() {
        let policy = SuggestionTriggerPolicy(sentenceBoundaryDelayMilliseconds: 360)

        #expect(policy.decision(
            previousTextBeforeCursor: "Hi Justin",
            currentTextBeforeCursor: "Hi Justin,",
            lineStartBehavior: .email,
            behaviorProfileID: .email
        ) == .request(delayMilliseconds: 360))

        #expect(policy.decision(
            previousTextBeforeCursor: "- Follow up",
            currentTextBeforeCursor: "- Follow up:",
            lineStartBehavior: .listItem,
            behaviorProfileID: .bullets
        ) == .request(delayMilliseconds: 360))

        #expect(policy.decision(
            previousTextBeforeCursor: "let value = makeCall(arg",
            currentTextBeforeCursor: "let value = makeCall(arg)",
            behaviorProfileID: .coding
        ) == .skip)
    }

    @Test("Within-word typing uses researched word delay")
    func withinWordTypingUsesResearchedWordDelay() {
        let policy = SuggestionTriggerPolicy(charactersBeforePauseRequest: 4)

        #expect(policy.decision(previousTextBeforeCursor: "I thi", currentTextBeforeCursor: "I thin") == .request(delayMilliseconds: 120))
        #expect(policy.decision(previousTextBeforeCursor: "I ", currentTextBeforeCursor: "I think") == .request(delayMilliseconds: 120))
    }

    @Test("Eager app-style delays are clamped to responsive ranges")
    func eagerAppStyleDelaysAreClampedToResponsiveRanges() {
        let policy = SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 1,
            wordCompletionDelayMilliseconds: 0,
            wordBoundaryDelayMilliseconds: 0,
            pauseDelayMilliseconds: 15
        )

        #expect(policy.wordCompletionDelayMilliseconds == 20)
        #expect(policy.wordBoundaryDelayMilliseconds == 40)
        #expect(policy.pauseDelayMilliseconds == 40)
        #expect(policy.decision(previousTextBeforeCursor: "I think", currentTextBeforeCursor: "I think ") == .request(delayMilliseconds: 40))
        #expect(policy.decision(previousTextBeforeCursor: "I think this wor", currentTextBeforeCursor: "I think this work") == .request(delayMilliseconds: 20))
        #expect(policy.decision(previousTextBeforeCursor: "I think ", currentTextBeforeCursor: "I think x") == .request(delayMilliseconds: 40))
    }

    @Test("Word fragments need three alphabetic characters")
    func wordFragmentsNeedThreeAlphabeticCharacters() {
        let policy = SuggestionTriggerPolicy(wordCompletionDelayMilliseconds: 50)

        #expect(policy.decision(previousTextBeforeCursor: "I need d", currentTextBeforeCursor: "I need di") == .skip)
        #expect(policy.decision(previousTextBeforeCursor: "I need di", currentTextBeforeCursor: "I need dic") == .request(delayMilliseconds: 50))
    }

    @Test("Word fragments after a space use researched word delay")
    func wordFragmentsAfterSpaceUseResearchedWordDelay() {
        let policy = SuggestionTriggerPolicy(wordCompletionDelayMilliseconds: 50)

        #expect(policy.decision(
            previousTextBeforeCursor: "I need ",
            currentTextBeforeCursor: "I need dic"
        ) == .request(delayMilliseconds: 50))
    }

    @Test("Proactive pace predicts short line-start word fragments")
    func proactivePacePredictsShortLineStartWordFragments() {
        let policy = SuggestionTriggerPolicy(pace: .eager)

        #expect(policy.decision(
            previousTextBeforeCursor: "U",
            currentTextBeforeCursor: "Um"
        ) == .request(delayMilliseconds: 20))
    }

    @Test("Proactive pace asks for phrase help after a short word-boundary pause")
    func proactivePaceAsksForPhraseHelpAfterShortWordBoundaryPause() {
        let policy = SuggestionTriggerPolicy(pace: .eager)

        #expect(policy.decision(
            previousTextBeforeCursor: "I feel",
            currentTextBeforeCursor: "I feel "
        ) == .request(delayMilliseconds: 40))
    }

    @Test("Proactive pace asks after a single starter word")
    func proactivePaceAsksAfterSingleStarterWord() {
        let policy = SuggestionTriggerPolicy(pace: .eager)

        #expect(policy.decision(
            previousTextBeforeCursor: "Um",
            currentTextBeforeCursor: "Um "
        ) == .request(delayMilliseconds: 40))
    }

    @Test("Proactive pace asks after sentence boundaries")
    func proactivePaceAsksAfterSentenceBoundaries() {
        let policy = SuggestionTriggerPolicy(pace: .eager)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works",
            currentTextBeforeCursor: "I think this works."
        ) == .request(delayMilliseconds: 120))
    }

    @Test("Sentence boundaries stay quiet by default")
    func sentenceBoundariesStayQuietByDefault() {
        let policy = SuggestionTriggerPolicy(sentenceBoundaryDelayMilliseconds: 500)

        #expect(policy.sentenceBoundaryDelayMilliseconds == 450)
        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works",
            currentTextBeforeCursor: "I think this works."
        ) == .skip)
        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works",
            currentTextBeforeCursor: "I think this works?"
        ) == .skip)
        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works",
            currentTextBeforeCursor: "I think this works!"
        ) == .skip)
    }

    @Test("Line and paragraph starts wait for two content words")
    func lineAndParagraphStartsWaitForTwoContentWords() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.",
            currentTextBeforeCursor: "I think this works.\n"
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\nN",
            currentTextBeforeCursor: "I think this works.\nNe"
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\nNew pla",
            currentTextBeforeCursor: "I think this works.\nNew plan"
        ) == .request(delayMilliseconds: 120))

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- ",
            currentTextBeforeCursor: "I think this works.\n- N"
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- New pla",
            currentTextBeforeCursor: "I think this works.\n- New plan"
        ) == .request(delayMilliseconds: 120))

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- [ ] ",
            currentTextBeforeCursor: "I think this works.\n- [ ] N"
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- [ ] Follow upd",
            currentTextBeforeCursor: "I think this works.\n- [ ] Follow upda"
        ) == .request(delayMilliseconds: 120))
    }

    @Test("Plain line starts stay quiet for single word fragments")
    func plainLineStartsStayQuietForSingleWordFragments() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\nPla",
            currentTextBeforeCursor: "I think this works.\nPlan"
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\nPlan",
            currentTextBeforeCursor: "I think this works.\nPlan "
        ) == .skip)
    }

    @Test("List line starts allow constrained word completion only")
    func listLineStartsAllowConstrainedWordCompletionOnly() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- Pr",
            currentTextBeforeCursor: "I think this works.\n- Pri",
            lineStartBehavior: .listItem
        ) == .request(delayMilliseconds: 120))

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- ",
            currentTextBeforeCursor: "I think this works.\n- P",
            lineStartBehavior: .listItem
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "I think this works.\n- Plan",
            currentTextBeforeCursor: "I think this works.\n- Plan ",
            lineStartBehavior: .listItem
        ) == .skip)
    }

    @Test("Email line starts allow constrained word completion only")
    func emailLineStartsAllowConstrainedWordCompletionOnly() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(
            previousTextBeforeCursor: "Hi Justin,\nTh",
            currentTextBeforeCursor: "Hi Justin,\nTha",
            lineStartBehavior: .email
        ) == .request(delayMilliseconds: 120))

        #expect(policy.decision(
            previousTextBeforeCursor: "Hi Justin,\nThanks",
            currentTextBeforeCursor: "Hi Justin,\nThanks ",
            lineStartBehavior: .email
        ) == .skip)
    }

    @Test("Profiles with fresh paragraph suppression wait for stronger local context")
    func profileFreshParagraphStartsNeedStrongerLocalContext() {
        let policy = SuggestionTriggerPolicy()

        #expect(policy.decision(
            previousTextBeforeCursor: "The intro is enough.\n\nNew pla",
            currentTextBeforeCursor: "The intro is enough.\n\nNew plan",
            behaviorProfileID: .docsProse
        ) == .skip)

        #expect(policy.decision(
            previousTextBeforeCursor: "The intro is enough.\n\nNew plan nee",
            currentTextBeforeCursor: "The intro is enough.\n\nNew plan need",
            behaviorProfileID: .docsProse
        ) == .request(delayMilliseconds: 120))

        #expect(policy.decision(
            previousTextBeforeCursor: "The intro is enough.\n\nNew pla",
            currentTextBeforeCursor: "The intro is enough.\n\nNew plan",
            behaviorProfileID: .notes
        ) == .request(delayMilliseconds: 120))
    }

    @Test("Line start behavior follows profile and list shape")
    func lineStartBehaviorFollowsProfileAndListShape() {
        #expect(SuggestionLineStartBehavior.behavior(
            for: .email,
            currentLineStructure: nil
        ) == .email)

        #expect(SuggestionLineStartBehavior.behavior(
            for: .notes,
            currentLineStructure: CurrentLineStructure.from(textBeforeCursor: "- Pri")
        ) == .listItem)

        #expect(SuggestionLineStartBehavior.behavior(
            for: .notes,
            currentLineStructure: nil
        ) == .plain)
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
