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

    @Test("Email profile penalizes invented commitments")
    func emailProfilePenalizesInventedCommitments() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " checking the draft first", maxVisibleWords: 8),
            CompletionSuggestion(text: " scheduling a meeting tomorrow", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            textBeforeCursor: "Thanks for sending this over. I will start by",
            behaviorProfileID: .email
        )

        #expect(ranked.first?.suggestion.visibleText == " checking the draft first")
    }

    @Test("Coding profile penalizes invented blocks and imports")
    func codingProfilePenalizesInventedBlocksAndImports() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " appending the value", maxVisibleWords: 8),
            CompletionSuggestion(text: " import Foundation", maxVisibleWords: 8),
            CompletionSuggestion(text: " func rebuildEverything()", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            textBeforeCursor: "items.",
            behaviorProfileID: .coding
        )

        #expect(ranked.first?.suggestion.visibleText == " appending the value")
        #expect(ranked.dropFirst().map(\.suggestion.visibleText).contains(" import Foundation"))
        #expect(ranked.dropFirst().map(\.suggestion.visibleText).contains(" func rebuildEverything()"))
    }

    @Test("Prompt app profile suppresses submit-like actions")
    func promptAppProfileSuppressesSubmitLikeActions() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " keep it local", maxVisibleWords: 8),
            CompletionSuggestion(text: " press Enter to send", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            textBeforeCursor: "Can you make the proof",
            behaviorProfileID: .aiChat
        )
        let submitSelection = ranker.selection(
            [CompletionSuggestion(text: " press Enter to send", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            behaviorProfileID: .aiChat
        )

        #expect(ranked.first?.suggestion.visibleText == " keep it local")
        #expect(submitSelection.suggestion == nil)
        #expect(submitSelection.suppressionReason == .lowTopScore)
    }

    @Test("Suppressed field profiles keep generated text below the display threshold")
    func suppressedFieldProfilesKeepGeneratedTextBelowDisplayThreshold() {
        let ranker = CompletionCandidateRanker()

        let formSelection = ranker.selection(
            [CompletionSuggestion(text: " Justin", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            behaviorProfileID: .forms
        )
        let searchSelection = ranker.selection(
            [CompletionSuggestion(text: " autocomplete", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            behaviorProfileID: .search
        )

        #expect(formSelection.suggestion == nil)
        #expect(searchSelection.suggestion == nil)
        #expect(formSelection.suppressionReason == .lowTopScore)
        #expect(searchSelection.suppressionReason == .lowTopScore)
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
