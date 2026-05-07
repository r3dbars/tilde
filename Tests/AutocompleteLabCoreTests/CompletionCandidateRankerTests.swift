import Testing
@testable import AutocompleteLabCore

@Suite("Completion candidate ranker")
struct CompletionCandidateRankerTests {
    @Test("Phrase mode prefers useful short candidates")
    func phraseModePrefersUsefulShortCandidates() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " right now", maxVisibleWords: 8),
            CompletionSuggestion(text: " feel calm and fast", maxVisibleWords: 8),
            CompletionSuggestion(text: " feel calm and fast without adding another noisy surface", maxVisibleWords: 8),
            CompletionSuggestion(text: " are you sure?", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(suggestions, mode: .phraseContinuation)

        #expect(ranked.first?.suggestion.visibleText == " feel calm and fast")
        #expect(ranked.last?.suggestion.visibleText == " are you sure?")
    }

    @Test("Sentence mode prefers sentence-length continuations over questions")
    func sentenceModePrefersSentenceLengthContinuationsOverQuestions() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " and keep moving.", maxVisibleWords: 8),
            CompletionSuggestion(text: " and keep the next step clear.", maxVisibleWords: 8),
            CompletionSuggestion(text: " does that make sense?", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(suggestions, mode: .sentenceContinuation)

        #expect(ranked.first?.suggestion.visibleText == " and keep the next step clear.")
        #expect(ranked.last?.suggestion.visibleText == " does that make sense?")
    }

    @Test("Sentence mode penalizes planning drift")
    func sentenceModePenalizesPlanningDrift() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " It keeps the scope clear.", maxVisibleWords: 8),
            CompletionSuggestion(text: " We should make a roadmap.", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .sentenceContinuation,
            textBeforeCursor: "That is enough for this pass."
        )

        #expect(ranked.first?.suggestion.visibleText == " It keeps the scope clear.")
    }

    @Test("Ranking penalizes unsupported names and dates")
    func rankingPenalizesUnsupportedNamesAndDates() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " checking the notes first", maxVisibleWords: 8),
            CompletionSuggestion(text: " meeting Sarah tomorrow", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            textBeforeCursor: "I can help with the launch by"
        )

        #expect(ranked.first?.suggestion.visibleText == " checking the notes first")
    }

    @Test("Ranking gives local terms a small tie breaker")
    func rankingGivesLocalTermsSmallTieBreaker() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " a clean next step", maxVisibleWords: 8),
            CompletionSuggestion(text: " a clean migration step", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            textBeforeCursor: "The migration plan needs"
        )

        #expect(ranked.first?.suggestion.visibleText == " a clean migration step")
    }

    @Test("Word mode prefers short alphabetic suffixes")
    func wordModePrefersShortAlphabeticSuffixes() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: "tion.", maxVisibleWords: 8),
            CompletionSuggestion(text: "tionally", maxVisibleWords: 8),
            CompletionSuggestion(text: "tion", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(suggestions, mode: .wordCompletion)

        #expect(ranked.first?.suggestion.visibleText == "tion")
        #expect(ranked.last?.suggestion.visibleText == "tion.")
    }

    @Test("Best returns nil when no candidates survive")
    func bestReturnsNilWhenNoCandidatesSurvive() {
        let ranker = CompletionCandidateRanker()

        #expect(ranker.best([], mode: .phraseContinuation) == nil)
    }

    @Test("Selection suppresses ambiguous top candidates")
    func selectionSuppressesAmbiguousTopCandidates() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " feel calm today", maxVisibleWords: 8),
            CompletionSuggestion(text: " feel clear today", maxVisibleWords: 8)
        ]

        let selection = ranker.selection(suggestions, mode: .phraseContinuation)

        #expect(selection.suggestion == nil)
        #expect(selection.scoreMargin == 0)
        #expect(selection.suppressionReason == .lowScoreMargin)
    }

    @Test("Selection allows single high confidence candidates")
    func selectionAllowsSingleHighConfidenceCandidates() {
        let ranker = CompletionCandidateRanker()
        let suggestion = CompletionSuggestion(text: " feel calm today", maxVisibleWords: 8)

        let selection = ranker.selection([suggestion], mode: .phraseContinuation)

        #expect(selection.suggestion == suggestion)
        #expect(selection.scoreMargin == nil)
        #expect(selection.suppressionReason == nil)
    }

    @Test("Selection suppresses low score sentence candidates")
    func selectionSuppressesLowScoreSentenceCandidates() {
        let ranker = CompletionCandidateRanker()
        let suggestion = CompletionSuggestion(text: " and then", maxVisibleWords: 8)

        let selection = ranker.selection([suggestion], mode: .sentenceContinuation)

        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == .lowTopScore)
    }
}
