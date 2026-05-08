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

    @Test("eager keeps safety gates but lowers display thresholds")
    func eagerKeepsSafetyGatesButLowersDisplayThresholds() {
        let trigger = SuggestionAggressiveness.eager.triggerPolicy
        let display = SuggestionAggressiveness.eager.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 1)
        #expect(trigger.wordCompletionDelayMilliseconds == 50)
        #expect(trigger.wordBoundaryDelayMilliseconds == 80)
        #expect(trigger.pauseDelayMilliseconds == 80)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 280)
        #expect(display.threshold(for: .wordCompletion) == 0.50)
        #expect(display.threshold(for: .phraseContinuation) == 0.85)
        #expect(display.threshold(for: .sentenceContinuation) == 1.05)
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
    }
}
