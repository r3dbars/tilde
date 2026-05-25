import AutocompleteLabCore
import Testing

@Suite("Suggestion status text")
struct SuggestionStatusTextTests {
    @Test("Shown status names instant phrase fallback")
    func shownStatusNamesInstantPhraseFallback() {
        let text = SuggestionStatusText.shown(
            mode: .phraseContinuation,
            triggerReason: "predictive-phrase-fallback",
            latencyMilliseconds: 0,
            metadata: ["candidateSelectionSource": "predictive-phrase-fallback"]
        )

        #expect(text == "Shown: phrase instant fallback 0ms")
    }

    @Test("Shown status names model backed phrase")
    func shownStatusNamesModelBackedPhrase() {
        let text = SuggestionStatusText.shown(
            mode: .phraseContinuation,
            triggerReason: "model-result",
            latencyMilliseconds: 245,
            metadata: ["candidateSelectionSource": "app-model-result"]
        )

        #expect(text == "Shown: phrase model 245ms")
    }

    @Test("Shown status names fast word fallback")
    func shownStatusNamesFastWordFallback() {
        let text = SuggestionStatusText.shown(
            mode: .wordCompletion,
            triggerReason: "fast-word-completion",
            latencyMilliseconds: 0,
            metadata: ["candidateSelectionSource": "fast-word-completion"]
        )

        #expect(text == "Shown: word fast fallback 0ms")
    }
}
