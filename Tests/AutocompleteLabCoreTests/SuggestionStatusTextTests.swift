import AutocompleteLabCore
import Testing

@Suite("Suggestion status text")
struct SuggestionStatusTextTests {
    @Test("Shown status de-emphasizes legacy instant phrase fallback")
    func shownStatusDeemphasizesLegacyInstantPhraseFallback() {
        let text = SuggestionStatusText.shown(
            mode: .phraseContinuation,
            triggerReason: "predictive-phrase-fallback",
            latencyMilliseconds: 0,
            metadata: ["candidateSelectionSource": "predictive-phrase-fallback"]
        )

        #expect(text == "Shown: phrase legacy instant 0ms")
    }

    @Test("Shown status names doc-local phrase prediction")
    func shownStatusNamesDocLocalPhrasePrediction() {
        let text = SuggestionStatusText.shown(
            mode: .phraseContinuation,
            triggerReason: "doc-local-ngram",
            latencyMilliseconds: 0,
            metadata: ["candidateSelectionSource": "doc-local-ngram"]
        )

        #expect(text == "Shown: phrase doc local 0ms")
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

    @Test("Not-shown status explains quiet model results")
    func notShownStatusExplainsQuietModelResults() {
        #expect(SuggestionStatusText.notShown(reason: "empty-suggestion") == "Quiet: no useful suggestion")
        #expect(SuggestionStatusText.notShown(reason: "no-fast-word-candidate") == "Quiet: no fast word match")
    }

    @Test("Not-shown status explains trust blockers")
    func notShownStatusExplainsTrustBlockers() {
        #expect(SuggestionStatusText.notShown(reason: "missing-anchor") == "Blocked: no cursor position")
        #expect(SuggestionStatusText.notShown(reason: "repeated-miss") == "Blocked: repeated miss")
        #expect(SuggestionStatusText.notShown(reason: "fast-phrase-learning-restraint") == "Quiet: recent rejects")
        #expect(SuggestionStatusText.notShown(reason: "engine-error") == "Blocked: model error")
        #expect(SuggestionStatusText.notShown(reason: "stale-after-keydown") == "Blocked: stale text")
    }

    @Test("Not-shown status normalizes unknown reasons")
    func notShownStatusNormalizesUnknownReasons() {
        #expect(SuggestionStatusText.notShown(reason: "display-score") == "Blocked: display score")
    }

    @Test("Not-shown status uses shared live-why reasons")
    func notShownStatusUsesSharedLiveWhyReasons() {
        #expect(SuggestionStatusText.notShown(reason: "too-slow-to-display") == "Blocked: too slow")
        #expect(SuggestionStatusText.notShown(reason: "low-confidence") == "Blocked: low confidence")
        #expect(SuggestionStatusText.notShown(reason: "prefix-family-cooldown") == "Waiting: recent prefix cooldown")
        #expect(SuggestionStatusText.notShown(reason: "quiet-mode-field") == "Waiting: quiet mode")
        #expect(SuggestionStatusText.notShown(reason: "secureField") == "Blocked: safety gate")
    }
}
