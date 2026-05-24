import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion aggressiveness")
struct SuggestionAggressivenessTests {
    @Test("default tuning starts proactive enough for first run")
    func defaultTuningStartsProactiveEnoughForFirstRun() {
        let tuning = SuggestionTuning()

        #expect(tuning.aggressivenessLevel == 3)
        #expect(tuning.maxVisibleWords == 8)
        #expect(tuning.wordStartCharacters == 2)
        #expect(tuning.phraseStartWords == 3)
        #expect(tuning.responseSpeedLevel == 3)
        #expect(tuning.confidenceLevel == 3)
        #expect(tuning.learningRestraintLevel == 2)
        #expect(tuning.displayName == "Proactive")
        #expect(tuning.pace == .eager)

        let activation = tuning.activationPolicy(supportPace: tuning.pace)
        #expect(activation.decision(
            textBeforeCursor: "I feel ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
        #expect(activation.decision(
            textBeforeCursor: "I feel ready now ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))

        let trigger = tuning.triggerPolicy(supportPace: tuning.pace)
        #expect(trigger.decision(
            previousTextBeforeCursor: "I feel",
            currentTextBeforeCursor: "I feel ",
            requestMode: .phraseContinuation
        ) == .skip)
        #expect(trigger.decision(
            previousTextBeforeCursor: "I feel ready now",
            currentTextBeforeCursor: "I feel ready now ",
            requestMode: .phraseContinuation
        ) == .request(delayMilliseconds: 280))
    }

    @Test("normal starts suggestions sooner without using the most eager thresholds")
    func normalStartsSuggestionsSooner() {
        let policy = SuggestionAggressiveness.normal.triggerPolicy
        let display = SuggestionAggressiveness.normal.displayScorePolicy

        #expect(policy.charactersBeforePauseRequest == 1)
        #expect(policy.wordCompletionDelayMilliseconds == 70)
        #expect(policy.wordBoundaryDelayMilliseconds == 160)
        #expect(policy.pauseDelayMilliseconds == 160)
        #expect(policy.minimumPhrasePauseDelayMilliseconds == 280)
        #expect(policy.sentenceBoundaryDelayMilliseconds == 260)
        #expect(display.threshold(for: .wordCompletion) == 0.55)
        #expect(display.threshold(for: .phraseContinuation) == 1.15)
        #expect(display.threshold(for: .sentenceContinuation) == 1.25)
    }

    @Test("quiet waits longer and requires stronger scores")
    func quietWaitsLongerAndRequiresStrongerScores() {
        let trigger = SuggestionAggressiveness.quiet.triggerPolicy
        let display = SuggestionAggressiveness.quiet.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 6)
        #expect(trigger.wordCompletionDelayMilliseconds == 140)
        #expect(trigger.wordBoundaryDelayMilliseconds == 240)
        #expect(trigger.minimumPhrasePauseDelayMilliseconds == 360)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 450)
        #expect(display.threshold(for: .wordCompletion) == 0.75)
        #expect(display.threshold(for: .phraseContinuation) == 1.40)
        #expect(display.threshold(for: .sentenceContinuation) == 1.50)
    }

    @Test("legacy proactive keeps safety gates but predicts faster")
    func proactiveKeepsSafetyGatesButPredictsFaster() {
        let trigger = SuggestionAggressiveness.eager.triggerPolicy
        let display = SuggestionAggressiveness.eager.displayScorePolicy

        #expect(trigger.charactersBeforePauseRequest == 1)
        #expect(trigger.wordCompletionDelayMilliseconds == 40)
        #expect(trigger.wordBoundaryDelayMilliseconds == 140)
        #expect(trigger.pauseDelayMilliseconds == 140)
        #expect(trigger.minimumPhrasePauseDelayMilliseconds == 260)
        #expect(trigger.sentenceBoundaryDelayMilliseconds == 200)
        #expect(trigger.minimumWordCompletionCharacters == 2)
        #expect(trigger.allowsPlainLineStartWordCompletion)
        #expect(!trigger.allowsPlainLineStartPhraseContinuation)
        #expect(!trigger.allowsSentenceBoundaryRequest)
        #expect(display.threshold(for: .wordCompletion) == 0.40)
        #expect(display.threshold(for: .phraseContinuation) == 1.00)
        #expect(display.threshold(for: .sentenceContinuation) == 1.10)
        #expect(display.highRiskThreshold == DisplayScorePolicy().highRiskThreshold)
    }

    @Test("tuning levels expose more aggressive controls")
    func tuningLevelsExposeMoreAggressiveControls() {
        let proactive = SuggestionTuning(aggressivenessLevel: 3, maxVisibleWords: 8)
        let veryProactive = SuggestionTuning(aggressivenessLevel: 4, maxVisibleWords: 8)
        let max = SuggestionTuning(aggressivenessLevel: 5, maxVisibleWords: 99)

        #expect(proactive.displayScorePolicy.threshold(for: .phraseContinuation) == 1.10)
        #expect(veryProactive.displayScorePolicy.threshold(for: .phraseContinuation) == 1.00)
        #expect(max.displayScorePolicy.threshold(for: .phraseContinuation) == 0.90)
        #expect(max.maxVisibleWords == 20)

        let veryProactiveTrigger = veryProactive.triggerPolicy(supportPace: .eager)
        #expect(veryProactiveTrigger.wordCompletionDelayMilliseconds == 40)
        #expect(veryProactiveTrigger.wordBoundaryDelayMilliseconds == 100)
        #expect(veryProactiveTrigger.minimumPhrasePauseDelayMilliseconds == 240)
        #expect(veryProactiveTrigger.sentenceBoundaryDelayMilliseconds == 240)
        #expect(veryProactiveTrigger.minimumWordCompletionCharacters == 2)
        #expect(veryProactiveTrigger.minimumPhraseContinuationWords == 3)
        #expect(!veryProactiveTrigger.allowsPlainLineStartPhraseContinuation)
        #expect(!veryProactiveTrigger.allowsSentenceBoundaryRequest)

        let maxTrigger = max.triggerPolicy(supportPace: .eager)
        #expect(maxTrigger.wordBoundaryDelayMilliseconds == 80)
        #expect(maxTrigger.minimumPhrasePauseDelayMilliseconds == 220)
        #expect(maxTrigger.softPunctuationDelayMilliseconds == 120)
        #expect(maxTrigger.sentenceBoundaryDelayMilliseconds == 200)
        #expect(maxTrigger.pauseDelayMilliseconds == 80)
        #expect(maxTrigger.minimumWordCompletionCharacters == 2)
        #expect(max.traceMetadata["suggestionAggressivenessLevel"] == "5")
        #expect(max.traceMetadata["suggestionMaxVisibleWords"] == "20")
    }

    @Test("extra tuning knobs independently control timing confidence and learning")
    func extraTuningKnobsIndependentlyControlTimingConfidenceAndLearning() {
        let loose = SuggestionTuning(
            aggressivenessLevel: 3,
            maxVisibleWords: 99,
            wordStartCharacters: 1,
            phraseStartWords: 2,
            responseSpeedLevel: 5,
            confidenceLevel: 5,
            learningRestraintLevel: 0
        )

        #expect(loose.maxVisibleWords == 20)
        #expect(abs(loose.displayScorePolicy.threshold(for: .phraseContinuation) - 0.90) < 0.0001)
        #expect(loose.displayScorePolicy.acceptedAndKeptProbabilityMultiplier == 0)
        #expect(loose.displayScorePolicy.learningRestraintScoreScale == 0)

        let looseTrigger = loose.triggerPolicy(supportPace: .eager)
        #expect(looseTrigger.wordCompletionDelayMilliseconds == 20)
        #expect(looseTrigger.wordBoundaryDelayMilliseconds == 80)
        #expect(looseTrigger.minimumWordCompletionCharacters == 1)
        #expect(looseTrigger.minimumPhraseContinuationWords == 2)

        let strict = SuggestionTuning(
            aggressivenessLevel: 3,
            responseSpeedLevel: 1,
            confidenceLevel: 1,
            learningRestraintLevel: 3
        )
        #expect(abs(strict.displayScorePolicy.threshold(for: .phraseContinuation) - 1.30) < 0.0001)
        #expect(strict.displayScorePolicy.minimumAcceptedAndKeptSamples == 3)
        #expect(strict.displayScorePolicy.learningRestraintScoreScale == 1.25)
        #expect(strict.triggerPolicy(supportPace: .eager).wordBoundaryDelayMilliseconds == 220)
    }

    @Test("max activation starts from the first strong screen-aware hint")
    func maxActivationStartsFromFirstHint() {
        let activation = SuggestionTuning(
            aggressivenessLevel: 5,
            wordStartCharacters: 1,
            phraseStartWords: 3
        )
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
        ) == .block(.tooLittleContext))
        #expect(activation.decision(
            textBeforeCursor: "Yes that works ",
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
        #expect(normal.allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.apple.Notes",
            behaviorProfileID: .notes,
            visiblePageContextAvailable: false
        ))
        #expect(!normal.allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.apple.mail",
            behaviorProfileID: .email,
            visiblePageContextAvailable: false
        ))
        #expect(normal.allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.apple.mail",
            behaviorProfileID: .email,
            visiblePageContextAvailable: true
        ))
        #expect(normal.allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.google.Chrome",
            behaviorProfileID: .docsProse,
            visiblePageContextAvailable: false
        ))
        #expect(!normal.allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.google.Chrome",
            behaviorProfileID: .forms,
            visiblePageContextAvailable: false
        ))
        #expect(SuggestionTuning(aggressivenessLevel: 3).allowsPredictivePhraseFallback(
            appBundleIdentifier: "com.apple.mail",
            behaviorProfileID: .email,
            visiblePageContextAvailable: false
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
