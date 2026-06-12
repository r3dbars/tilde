import Testing
@testable import AutocompleteLabCore

@Suite("Completion confidence policy")
struct CompletionConfidencePolicyTests {
    private let policy = CompletionConfidencePolicy()

    @Test("Allows short word completions")
    func allowsShortWordCompletions() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: "tion", maxVisibleWords: 1),
            mode: .wordCompletion,
            textBeforeCursor: "transcrip",
            latencyMilliseconds: 40,
            supportLevel: .green
        )

        #expect(decision.bucket == .high)
        #expect(decision.canDisplay)
    }

    @Test("Allows short phrase continuations with enough context")
    func allowsShortPhraseContinuationsWithEnoughContext() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            latencyMilliseconds: 180,
            supportLevel: .green
        )

        #expect(decision.canDisplay)
        #expect(decision.bucket == .high)
    }

    @Test("Blocks one and two word nubs in daily-driver phrase mode")
    func blocksShortNubsInDailyDriverPhraseMode() {
        let oneWordDecision = policy.decision(
            suggestion: CompletionSuggestion(text: " ready", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "The draft is almost",
            latencyMilliseconds: 120,
            supportLevel: .green
        )
        let twoWordDecision = policy.decision(
            suggestion: CompletionSuggestion(text: " follow up", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "I just wanted to",
            latencyMilliseconds: 120,
            supportLevel: .green
        )

        #expect(!oneWordDecision.canDisplay)
        #expect(!twoWordDecision.canDisplay)
        #expect(oneWordDecision.bucket == .low)
        #expect(twoWordDecision.bucket == .low)
        #expect(oneWordDecision.reasons.contains("too-short-daily-driver-phrase"))
        #expect(twoWordDecision.reasons.contains("too-short-daily-driver-phrase"))
    }

    @Test("Allows preferred length daily-driver phrases")
    func allowsPreferredLengthDailyDriverPhrases() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " ready for review today", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "The draft is almost",
            latencyMilliseconds: 120,
            supportLevel: .green
        )

        #expect(decision.canDisplay)
        #expect(decision.bucket == .high)
        #expect(!decision.reasons.contains("too-short-daily-driver-phrase"))
    }

    @Test("Blocks thin-context phrase continuations")
    func blocksThinContextPhraseContinuations() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " the next step", maxVisibleWords: 4),
            mode: .phraseContinuation,
            textBeforeCursor: "Ok",
            latencyMilliseconds: 120,
            supportLevel: .green
        )

        #expect(!decision.canDisplay)
        #expect(decision.bucket == .low)
        #expect(decision.reasons.contains("thin-context"))
    }

    @Test("Yellow short phrase mode makes long phrase suggestions low confidence")
    func yellowShortPhraseModeMakesLongPhraseSuggestionsLowConfidence() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " make this easier today please", maxVisibleWords: 6),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you please make",
            latencyMilliseconds: 220,
            supportLevel: .yellow
        )

        #expect(!decision.canDisplay)
        #expect(decision.reasons.contains("yellow-app-profile"))
        #expect(decision.reasons.contains("long-visible-suggestion"))
    }

    @Test("Yellow profiles allow daily driver subsecond eight-word phrases")
    func yellowProfilesAllowDailyDriverSubsecondEightWordPhrases() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " instant without getting in the way today now", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "Autocomplete Lab Obsidian proof Smoke proof feels",
            latencyMilliseconds: 900,
            supportLevel: .yellow
        )

        #expect(decision.canDisplay)
        #expect(decision.bucket == .medium)
        #expect(!decision.reasons.contains("long-visible-suggestion"))
        #expect(!decision.reasons.contains("too-slow-to-display"))
    }

    @Test("Allows long phrase continuations when the slider is high")
    func allowsLongPhraseContinuationsWhenSliderIsHigh() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(
                text: " easy to finish without making the user think about permissions twice before they can keep writing",
                maxVisibleWords: 20
            ),
            mode: .phraseContinuation,
            textBeforeCursor: "The onboarding note should make the setup feel clear and",
            latencyMilliseconds: 650,
            supportLevel: .green
        )

        #expect(decision.canDisplay)
        #expect(!decision.reasons.contains("too-many-visible-words"))
        #expect(!decision.reasons.contains("long-visible-suggestion"))
    }

    @Test("Blocks low-confidence generic assistant text")
    func blocksGenericAssistantText() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " Let me know if you need anything else", maxVisibleWords: 7),
            mode: .phraseContinuation,
            textBeforeCursor: "Ok sounds",
            latencyMilliseconds: 1_400,
            supportLevel: .yellow
        )

        #expect(!decision.canDisplay)
        #expect(decision.bucket == .low)
        #expect(decision.reasons.contains("generic-or-assistant-like"))
        #expect(decision.reasons.contains("slow-over-1000ms"))
    }

    @Test("Blocks unsupported profiles")
    func blocksUnsupportedProfiles() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " later today", maxVisibleWords: 3),
            mode: .phraseContinuation,
            textBeforeCursor: "I can send this",
            latencyMilliseconds: 120,
            supportLevel: .unsupported
        )

        #expect(!decision.canDisplay)
        #expect(decision.reasons.contains("unsupported-app-profile"))
    }

    @Test("Blocks otherwise good suggestions after the display latency budget")
    func blocksSuggestionsAfterDisplayLatencyBudget() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            latencyMilliseconds: 900,
            supportLevel: .green
        )

        #expect(!decision.canDisplay)
        #expect(decision.bucket == .low)
        #expect(decision.reasons.contains("too-slow-to-display"))
    }
}
