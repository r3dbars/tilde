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

    @Test("final phrase suggestions can still be short")
    func finalPhraseSuggestionsCanStillBeShort() {
        let gate = SuggestionPresentationGate()

        #expect(gate.shouldPresent(
            CompletionSuggestion(text: " ready."),
            mode: .phraseContinuation,
            phase: .final
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
}
