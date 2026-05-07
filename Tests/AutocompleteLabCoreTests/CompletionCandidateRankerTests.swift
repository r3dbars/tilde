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
}
