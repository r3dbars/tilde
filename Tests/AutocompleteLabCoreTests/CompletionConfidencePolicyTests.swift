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

    @Test("Yellow profiles make long phrase suggestions low confidence")
    func yellowProfilesMakeLongPhraseSuggestionsLowConfidence() {
        let decision = policy.decision(
            suggestion: CompletionSuggestion(text: " make this easier today please", maxVisibleWords: 6),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you please",
            latencyMilliseconds: 220,
            supportLevel: .yellow
        )

        #expect(!decision.canDisplay)
        #expect(decision.reasons.contains("yellow-app-profile"))
        #expect(decision.reasons.contains("long-visible-suggestion"))
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
