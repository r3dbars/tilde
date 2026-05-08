import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion aggressiveness")
struct SuggestionAggressivenessTests {
    @Test("normal starts suggestions sooner without using the most eager thresholds")
    func normalStartsSuggestionsSooner() {
        let policy = SuggestionAggressiveness.normal.triggerPolicy
        let display = SuggestionAggressiveness.normal.displayScorePolicy

        #expect(policy.charactersBeforePauseRequest == 1)
        #expect(policy.wordCompletionDelayMilliseconds == 70)
        #expect(policy.wordBoundaryDelayMilliseconds == 100)
        #expect(policy.pauseDelayMilliseconds == 100)
        #expect(policy.sentenceBoundaryDelayMilliseconds == 260)
        #expect(display.threshold(for: .wordCompletion) == 0.55)
        #expect(display.threshold(for: .phraseContinuation) == 0.90)
        #expect(display.threshold(for: .sentenceContinuation) == 1.10)
    }

    @Test("quiet waits longer and requires stronger scores")
    func quietWaitsLongerAndRequiresStrongerScores() {
        let trigger = SuggestionAggressiveness.quiet.triggerPolicy
        let display = SuggestionAggressiveness.quiet.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 6)
        #expect(trigger.wordCompletionDelayMilliseconds == 140)
        #expect(trigger.wordBoundaryDelayMilliseconds == 240)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 450)
        #expect(display.threshold(for: .wordCompletion) == 0.75)
        #expect(display.threshold(for: .phraseContinuation) == 1.25)
        #expect(display.threshold(for: .sentenceContinuation) == 1.45)
    }

    @Test("proactive keeps safety gates but predicts faster")
    func proactiveKeepsSafetyGatesButPredictsFaster() {
        let trigger = SuggestionAggressiveness.eager.triggerPolicy
        let display = SuggestionAggressiveness.eager.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 1)
        #expect(trigger.wordCompletionDelayMilliseconds == 20)
        #expect(trigger.wordBoundaryDelayMilliseconds == 40)
        #expect(trigger.pauseDelayMilliseconds == 40)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 120)
        #expect(trigger.minimumWordCompletionCharacters == 2)
        #expect(trigger.allowsPlainLineStartWordCompletion)
        #expect(trigger.allowsPlainLineStartPhraseContinuation)
        #expect(trigger.allowsSentenceBoundaryRequest)
        #expect(display.threshold(for: .wordCompletion) == 0.40)
        #expect(display.threshold(for: .phraseContinuation) == 0.65)
        #expect(display.threshold(for: .sentenceContinuation) == 0.85)
        #expect(display.highRiskThreshold == DisplayScorePolicy().highRiskThreshold)
    }

    @Test("parsing and cycling are stable")
    func parsingAndCyclingAreStable() {
        #expect(SuggestionAggressiveness.parsed(nil) == .normal)
        #expect(SuggestionAggressiveness.parsed(" QUIET ") == .quiet)
        #expect(SuggestionAggressiveness.parsed("unknown") == .normal)
        #expect(SuggestionAggressiveness.quiet.next == .normal)
        #expect(SuggestionAggressiveness.normal.next == .eager)
        #expect(SuggestionAggressiveness.eager.next == .quiet)
        #expect(SuggestionAggressiveness.eager.traceMetadata["suggestionAggressiveness"] == "eager")
        #expect(SuggestionAggressiveness.eager.traceMetadata["suggestionAggressivenessDisplayName"] == "Proactive")
    }

    @Test("proactive caps phrase help to a short continuation")
    func proactiveCapsPhraseHelpToShortContinuation() {
        #expect(SuggestionPace.eager.maxVisibleWords(
            defaultMaxVisibleWords: 6,
            requestMode: .phraseContinuation
        ) == 4)
        #expect(SuggestionPace.eager.maxVisibleWords(
            defaultMaxVisibleWords: 3,
            requestMode: .phraseContinuation
        ) == 3)
        #expect(SuggestionPace.eager.maxVisibleWords(
            defaultMaxVisibleWords: 6,
            requestMode: .wordCompletion
        ) == 6)
        #expect(SuggestionPace.normal.maxVisibleWords(
            defaultMaxVisibleWords: 6,
            requestMode: .phraseContinuation
        ) == 6)
    }
}
