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

    @Test("legacy proactive keeps safety gates but predicts faster")
    func proactiveKeepsSafetyGatesButPredictsFaster() {
        let trigger = SuggestionAggressiveness.eager.triggerPolicy
        let display = SuggestionAggressiveness.eager.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 1)
        #expect(trigger.wordCompletionDelayMilliseconds == 40)
        #expect(trigger.wordBoundaryDelayMilliseconds == 70)
        #expect(trigger.pauseDelayMilliseconds == 70)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 200)
        #expect(trigger.minimumWordCompletionCharacters == 2)
        #expect(trigger.allowsPlainLineStartWordCompletion)
        #expect(!trigger.allowsPlainLineStartPhraseContinuation)
        #expect(!trigger.allowsSentenceBoundaryRequest)
        #expect(display.threshold(for: .wordCompletion) == 0.40)
        #expect(display.threshold(for: .phraseContinuation) == 0.65)
        #expect(display.threshold(for: .sentenceContinuation) == 0.85)
        #expect(display.highRiskThreshold == DisplayScorePolicy().highRiskThreshold)
    }

    @Test("tuning levels expose more aggressive controls")
    func tuningLevelsExposeMoreAggressiveControls() {
        let proactive = SuggestionTuning(aggressivenessLevel: 3, maxVisibleWords: 8)
        let veryProactive = SuggestionTuning(aggressivenessLevel: 4, maxVisibleWords: 8)
        let max = SuggestionTuning(aggressivenessLevel: 5, maxVisibleWords: 99)

        #expect(proactive.displayScorePolicy.threshold(for: .phraseContinuation) == 0.75)
        #expect(veryProactive.displayScorePolicy.threshold(for: .phraseContinuation) == 0.65)
        #expect(max.displayScorePolicy.threshold(for: .phraseContinuation) == 0.55)
        #expect(max.maxVisibleWords == 8)

        let veryProactiveTrigger = veryProactive.triggerPolicy(supportPace: .eager)
        #expect(veryProactiveTrigger.wordCompletionDelayMilliseconds == 20)
        #expect(veryProactiveTrigger.wordBoundaryDelayMilliseconds == 40)
        #expect(veryProactiveTrigger.sentenceBoundaryDelayMilliseconds == 120)
        #expect(veryProactiveTrigger.allowsPlainLineStartPhraseContinuation)
        #expect(veryProactiveTrigger.allowsSentenceBoundaryRequest)

        let maxTrigger = max.triggerPolicy(supportPace: .eager)
        #expect(maxTrigger.wordBoundaryDelayMilliseconds == 20)
        #expect(maxTrigger.softPunctuationDelayMilliseconds == 40)
        #expect(maxTrigger.sentenceBoundaryDelayMilliseconds == 60)
        #expect(maxTrigger.pauseDelayMilliseconds == 20)
        #expect(maxTrigger.minimumWordCompletionCharacters == 1)
        #expect(max.traceMetadata["suggestionAggressivenessLevel"] == "5")
        #expect(max.traceMetadata["suggestionMaxVisibleWords"] == "8")
    }

    @Test("max activation starts from the first strong screen-aware hint")
    func maxActivationStartsFromFirstHint() {
        let activation = SuggestionTuning(aggressivenessLevel: 5)
            .activationPolicy(supportPace: .eager)

        #expect(activation.decision(
            textBeforeCursor: "R",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.wordCompletion))

        #expect(activation.decision(
            textBeforeCursor: "Yes ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("predictive fallback stays on for writing surfaces before OCR arrives")
    func predictiveFallbackStaysOnForWritingSurfaces() {
        let normal = SuggestionTuning(aggressivenessLevel: 2)

        #expect(normal.allowsPredictiveWordFallback(
            appBundleIdentifier: "com.apple.Notes",
            visiblePageContextAvailable: false
        ))
        #expect(normal.allowsPredictiveWordFallback(
            appBundleIdentifier: "com.apple.TextEdit",
            visiblePageContextAvailable: false
        ))
        #expect(normal.allowsPredictiveWordFallback(
            appBundleIdentifier: "md.obsidian",
            visiblePageContextAvailable: false
        ))
        #expect(!normal.allowsModelWordCompletionFallback(visiblePageContextAvailable: false))
        #expect(!normal.allowsPredictiveWordFallback(
            appBundleIdentifier: "com.apple.mail",
            visiblePageContextAvailable: false
        ))
        #expect(normal.allowsPredictiveWordFallback(
            appBundleIdentifier: "com.apple.mail",
            visiblePageContextAvailable: true
        ))
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

    @Test("pace leaves visible word count to tuning")
    func paceLeavesVisibleWordCountToTuning() {
        #expect(SuggestionPace.eager.maxVisibleWords(
            defaultMaxVisibleWords: 6,
            requestMode: .phraseContinuation
        ) == 6)
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
