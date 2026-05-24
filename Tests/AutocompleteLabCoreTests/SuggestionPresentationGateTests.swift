import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion presentation gate")
struct SuggestionPresentationGateTests {
    @Test("streamed phrase partials wait for enough visible words")
    func streamedPhrasePartialsWaitForEnoughWords() {
        let gate = SuggestionPresentationGate()

        #expect(!gate.shouldPresent(
            CompletionSuggestion(text: " ready."),
            mode: .phraseContinuation,
            phase: .streamingPartial
        ))

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: " ready to"),
            mode: .phraseContinuation,
            phase: .streamingPartial
        ))
    }

    @Test("high word slider waits for a high-word streaming partial")
    func highWordSliderWaitsForHighWordStreamingPartial() {
        let gate = SuggestionPresentationGate()

        #expect(!gate.shouldPresent(
            CompletionSuggestion(text: " permission feel clear today", maxVisibleWords: 20),
            mode: .phraseContinuation,
            phase: .streamingPartial
        ))

        #expect(gate.shouldPresent(
            CompletionSuggestion(
                text: " permission feel clear today while keeping the setup simple enough to finish without breaking focus",
                maxVisibleWords: 20
            ),
            mode: .phraseContinuation,
            phase: .streamingPartial
        ))
    }

    @Test("final phrase suggestions can still be short")
    func finalPhraseSuggestionsCanStillBeShort() {
        let gate = SuggestionPresentationGate()

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: " ready."),
            mode: .phraseContinuation,
            phase: .final
        ))
    }

    @Test("streamed sentence partials wait for a fuller thought")
    func streamedSentencePartialsWaitForFullerThought() {
        let gate = SuggestionPresentationGate()

        #expect(!gate.shouldPresent(
            CompletionSuggestion(text: " The next"),
            mode: .sentenceContinuation,
            phase: .streamingPartial
        ))

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: " The next step"),
            mode: .sentenceContinuation,
            phase: .streamingPartial
        ))
    }

    @Test("word completions do not wait for phrase streaming rules")
    func wordCompletionsBypassPhraseStreamingRules() {
        let gate = SuggestionPresentationGate()

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: "tation", maxVisibleWords: 1),
            mode: .wordCompletion,
            phase: .streamingPartial
        ))
    }

    @Test("streaming suppresses duplicate and tiny same-word changes")
    func streamingSuppressesDuplicateAndTinySameWordChanges() {
        let gate = SuggestionPresentationGate(minimumStreamingPhraseCharacterDelta: 3)

        #expect(!gate.shouldPresent(
            CompletionSuggestion(text: " make this"),
            mode: .phraseContinuation,
            phase: .streamingPartial,
            previousVisibleText: " make this"
        ))

        #expect(!gate.shouldPresent(
            CompletionSuggestion(text: " make this."),
            mode: .phraseContinuation,
            phase: .streamingPartial,
            previousVisibleText: " make this"
        ))

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: " make this work"),
            mode: .phraseContinuation,
            phase: .streamingPartial,
            previousVisibleText: " make this"
        ))
    }

    @Test("streaming partials are paced and capped")
    func streamingPartialsArePacedAndCapped() {
        let gate = SuggestionPresentationGate(
            minimumStreamingPhraseCharacterDelta: 6,
            minimumStreamingIntervalMilliseconds: 50,
            maximumStreamingPartialPresentations: 2
        )
        var state = StreamingPresentationState()

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this"),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 100
        ))

        #expect(!gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this work"),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 130
        ))

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this work now"),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 160
        ))

        #expect(!gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this work now please"),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 230
        ))
    }

    @Test("late streaming partials are suppressed before they become visible")
    func lateStreamingPartialsAreSuppressedBeforeTheyBecomeVisible() {
        let gate = SuggestionPresentationGate(
            minimumStreamingIntervalMilliseconds: 0,
            maximumStreamingPartialLatencyMilliseconds: 750
        )
        var state = StreamingPresentationState()

        #expect(!gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 100,
            latencyMilliseconds: 751
        ))
        #expect(state.presentedCount == 0)

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 110,
            latencyMilliseconds: 750
        ))
        #expect(state.presentedCount == 1)

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better", maxVisibleWords: 3),
            mode: .phraseContinuation,
            state: &state,
            nowMilliseconds: 120,
            latencyMilliseconds: 900
        ))
        #expect(state.presentedCount == 2)
    }

    @Test("sentence streaming allows one partial while phrase streaming allows two")
    func sentenceStreamingAllowsOnePartialWhilePhraseStreamingAllowsTwo() {
        let gate = SuggestionPresentationGate(
            minimumStreamingPhraseWords: 2,
            minimumStreamingSentenceWords: 3,
            minimumStreamingPhraseCharacterDelta: 4,
            minimumStreamingIntervalMilliseconds: 0,
            maximumStreamingPartialPresentations: 2,
            maximumStreamingSentencePartialPresentations: 1
        )
        var phraseState = StreamingPresentationState()
        var sentenceState = StreamingPresentationState()

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            mode: .phraseContinuation,
            state: &phraseState,
            nowMilliseconds: 100
        ))
        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this quieter", maxVisibleWords: 3),
            mode: .phraseContinuation,
            state: &phraseState,
            nowMilliseconds: 110
        ))

        #expect(gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " The next step", maxVisibleWords: 4),
            mode: .sentenceContinuation,
            state: &sentenceState,
            nowMilliseconds: 100
        ))
        #expect(!gate.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " The next step is", maxVisibleWords: 4),
            mode: .sentenceContinuation,
            state: &sentenceState,
            nowMilliseconds: 110
        ))
    }
}
