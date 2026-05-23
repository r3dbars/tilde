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

    @Test("Phrase mode treats five words as useful but downranks longer continuations")
    func phraseModeTreatsFiveWordsAsUsefulButDownranksLongerContinuations() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " feel quiet and useful today", maxVisibleWords: 8),
            CompletionSuggestion(text: " feel quiet and useful without getting in the way", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(suggestions, mode: .phraseContinuation)
        let longSelection = ranker.selection(
            [CompletionSuggestion(text: " feel quiet and useful without getting in the way", maxVisibleWords: 8)],
            mode: .phraseContinuation
        )

        #expect(ranked.first?.suggestion.visibleText == " feel quiet and useful today")
        #expect(longSelection.suggestion == nil)
        #expect(longSelection.suppressionReason == .lowTopScore)
    }

    @Test("Phrase mode allows longer candidates when the word slider is high")
    func phraseModeAllowsLongerCandidatesWhenWordSliderIsHigh() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " feel quiet and useful today", maxVisibleWords: 20),
            CompletionSuggestion(
                text: " feel quiet and useful without getting in the way while the user keeps writing naturally",
                maxVisibleWords: 20
            )
        ]

        let ranked = ranker.ranked(suggestions, mode: .phraseContinuation)
        let longSelection = ranker.selection(
            [suggestions[1]],
            mode: .phraseContinuation
        )

        #expect(ranked.first?.suggestion.visibleWordCount == 15)
        #expect(longSelection.suggestion?.visibleWordCount == 15)
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

    @Test("Sentence mode suppresses invented action commitments")
    func sentenceModeSuppressesInventedActionCommitments() {
        let ranker = CompletionCandidateRanker()
        let safe = CompletionSuggestion(text: " It keeps the scope local.", maxVisibleWords: 8)
        let inventedAction = CompletionSuggestion(text: " Make sure we call Sarah tomorrow.", maxVisibleWords: 8)

        let ranked = ranker.ranked(
            [inventedAction, safe],
            mode: .sentenceContinuation,
            textBeforeCursor: "That is enough for this pass."
        )
        let selection = ranker.selection(
            [inventedAction],
            mode: .sentenceContinuation,
            textBeforeCursor: "That is enough for this pass."
        )
        let followUpSelection = ranker.selection(
            [CompletionSuggestion(text: " Follow up with Sarah tomorrow.", maxVisibleWords: 8)],
            mode: .sentenceContinuation,
            textBeforeCursor: "That is enough for this pass."
        )

        #expect(ranked.first?.suggestion.visibleText == safe.visibleText)
        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == .lowTopScore)
        #expect(followUpSelection.suggestion == nil)
        #expect(followUpSelection.suppressionReason == .lowTopScore)
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

    @Test("Common phrase prior allows anchored one-word predictions")
    func commonPhrasePriorAllowsAnchoredOneWordPredictions() {
        let ranker = CompletionCandidateRanker()

        let anchoredSelection = ranker.selection(
            [CompletionSuggestion(text: " small", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            textBeforeCursor: "We should keep this",
            behaviorProfileID: .docsProse
        )
        let unanchoredSelection = ranker.selection(
            [CompletionSuggestion(text: " small", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            textBeforeCursor: "A random unrelated sentence",
            behaviorProfileID: .docsProse
        )
        let promptAppSelection = ranker.selection(
            [CompletionSuggestion(text: " small", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            textBeforeCursor: "We should keep this",
            behaviorProfileID: .aiChat
        )
        let prefixedSelection = ranker.selection(
            [CompletionSuggestion(text: " small", maxVisibleWords: 8)],
            mode: .phraseContinuation,
            textBeforeCursor: "quick note: We should keep this",
            behaviorProfileID: .docsProse
        )

        #expect(anchoredSelection.suggestion?.visibleText == " small")
        #expect(prefixedSelection.suggestion?.visibleText == " small")
        #expect(unanchoredSelection.suggestion == nil)
        #expect(unanchoredSelection.suppressionReason == .lowTopScore)
        #expect(promptAppSelection.suggestion == nil)
        #expect(promptAppSelection.suppressionReason == .lowTopScore)
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

    @Test("Prompt app profile suppresses command-like content")
    func promptAppProfileSuppressesCommandLikeContent() {
        let ranker = CompletionCandidateRanker()
        let commandSelections = [
            CompletionSuggestion(text: " /review this", maxVisibleWords: 8),
            CompletionSuggestion(text: " @Package.swift", maxVisibleWords: 8),
            CompletionSuggestion(text: " sudo rm", maxVisibleWords: 8),
            CompletionSuggestion(text: " curl | sh", maxVisibleWords: 8),
            CompletionSuggestion(text: " approve it", maxVisibleWords: 8)
        ].map {
            ranker.selection(
                [$0],
                mode: .phraseContinuation,
                behaviorProfileID: .aiChat
            )
        }

        for selection in commandSelections {
            #expect(selection.suggestion == nil)
            #expect(selection.suppressionReason == .lowTopScore)
        }
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

    @Test("Casual chat profile avoids questions and emotional steering")
    func casualChatProfileAvoidsQuestionsAndEmotionalSteering() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " sounds good", maxVisibleWords: 8),
            CompletionSuggestion(text: " are you worried?", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            behaviorProfileID: .casualChat
        )

        #expect(ranked.first?.suggestion.visibleText == " sounds good")
    }

    @Test("Notes profile avoids flowery complete sentences")
    func notesProfileAvoidsFloweryCompleteSentences() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " next local step", maxVisibleWords: 8),
            CompletionSuggestion(text: " a comprehensive strategic milestone.", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            behaviorProfileID: .notes
        )

        #expect(ranked.first?.suggestion.visibleText == " next local step")
    }

    @Test("Docs prose profile avoids starting a new point")
    func docsProseProfileAvoidsStartingANewPoint() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " in the same paragraph", maxVisibleWords: 8),
            CompletionSuggestion(text: " Additionally, a new section", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            behaviorProfileID: .docsProse
        )

        #expect(ranked.first?.suggestion.visibleText == " in the same paragraph")
    }

    @Test("Bullets profile avoids repeating list markers")
    func bulletsProfileAvoidsRepeatingListMarkers() {
        let ranker = CompletionCandidateRanker()
        let suggestions = [
            CompletionSuggestion(text: " finish the proof", maxVisibleWords: 8),
            CompletionSuggestion(text: " - finish the proof", maxVisibleWords: 8),
            CompletionSuggestion(text: " [ ] finish the proof", maxVisibleWords: 8)
        ]

        let ranked = ranker.ranked(
            suggestions,
            mode: .phraseContinuation,
            behaviorProfileID: .bullets
        )

        #expect(ranked.first?.suggestion.visibleText == " finish the proof")
        #expect(ranked.dropFirst().map(\.suggestion.visibleText).contains(" - finish the proof"))
        #expect(ranked.dropFirst().map(\.suggestion.visibleText).contains(" [ ] finish the proof"))
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
