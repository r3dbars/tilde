import Foundation
import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("MLX runtime warm gate")
struct MLXModelRuntimeWarmGateTests {
    @Test("Warm gate resumes every waiter when warm completes")
    func warmGateResumesEveryWaiterWhenWarmCompletes() async throws {
        let gate = MLXRuntimeWarmGate()

        async let first: Void = gate.wait()
        async let second: Void = gate.wait()
        await Task.yield()

        gate.finish(with: .success(()))

        try await first
        try await second
        try await gate.wait()
    }

    @Test("Canceling one waiter does not finish the warm gate")
    func cancelingOneWaiterDoesNotFinishWarmGate() async throws {
        let gate = MLXRuntimeWarmGate()
        let canceledWaiter = Task {
            try await gate.wait()
        }

        await Task.yield()
        canceledWaiter.cancel()

        await #expect(throws: CancellationError.self) {
            try await canceledWaiter.value
        }

        async let remainingWaiter: Void = gate.wait()
        await Task.yield()

        gate.finish(with: .success(()))

        try await remainingWaiter
        try await gate.wait()
    }

    @Test("Warm gate replays warm failures to current and future waiters")
    func warmGateReplaysWarmFailures() async {
        let gate = MLXRuntimeWarmGate()

        let first = Task {
            try await gate.wait()
        }
        await Task.yield()

        gate.finish(with: .failure(MLXModelRuntimeError.warmCompletedWithoutContainer))

        await #expect(throws: MLXModelRuntimeError.warmCompletedWithoutContainer) {
            try await first.value
        }
        await #expect(throws: MLXModelRuntimeError.warmCompletedWithoutContainer) {
            try await gate.wait()
        }
    }

    @Test("High word slider does not stop streaming after a short punctuated phrase")
    func highWordSliderDoesNotStopStreamingAfterShortPunctuatedPhrase() {
        let shortSuggestion = CompletionSuggestion(
            text: " permission feel clear today.",
            maxVisibleWords: 20
        )
        let longSuggestion = CompletionSuggestion(
            text: " permission feel clear today while keeping the setup simple enough to finish without breaking focus.",
            maxVisibleWords: 20
        )

        #expect(!MLXModelRuntime.shouldStopEarly(
            shortSuggestion,
            rawOutput: shortSuggestion.visibleText,
            mode: .phraseContinuation,
            effectiveMaxVisibleWords: 20
        ))
        #expect(MLXModelRuntime.shouldStopEarly(
            longSuggestion,
            rawOutput: longSuggestion.visibleText,
            mode: .phraseContinuation,
            effectiveMaxVisibleWords: 20
        ))
    }

    @Test("High word retry prompt repairs short first pass candidates")
    func highWordRetryPromptRepairsShortFirstPassCandidates() throws {
        let request = CompletionRequest(
            textBeforeCursor: "The onboarding note should make the setup feel clear and ",
            maxVisibleWords: 20,
            mode: .phraseContinuation
        )
        let shortCandidate = CompletionSuggestion(
            text: " permission feel clear",
            maxVisibleWords: 20
        )
        let selection = CompletionCandidateRanker().selection(
            [shortCandidate],
            mode: .phraseContinuation,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )

        #expect(selection.suppressionReason == CompletionCandidateSuppressionReason.lowTopScore)

        let prompt = try #require(MLXModelRuntime.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: [shortCandidate],
            candidateSelection: selection,
            effectiveMaxVisibleWords: 20
        ))

        #expect(prompt.system.contains("previous answer was too short"))
        #expect(prompt.system.contains("12-20 words"))
        #expect(prompt.system.contains("permission feel clear"))
        #expect(prompt.user.contains("The onboarding note should make the setup feel clear and"))
        #expect(prompt.user.hasSuffix("Next 12-20 words, or <NO_SUGGESTION>:"))
    }

    @Test("Daily driver retry prompt repairs too-short phrase candidates")
    func dailyDriverRetryPromptRepairsTooShortPhraseCandidates() throws {
        let request = CompletionRequest(
            textBeforeCursor: "Smoke proof feels ",
            maxVisibleWords: 8,
            mode: .phraseContinuation
        )
        let shortCandidate = CompletionSuggestion(
            text: " instant",
            maxVisibleWords: 8
        )
        let selection = CompletionCandidateRanker().selection(
            [shortCandidate],
            mode: .phraseContinuation,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )

        #expect(selection.suppressionReason == CompletionCandidateSuppressionReason.lowTopScore)

        let prompt = try #require(MLXModelRuntime.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: [shortCandidate],
            candidateSelection: selection,
            effectiveMaxVisibleWords: 8
        ))

        #expect(prompt.system.contains("previous answer was too short"))
        #expect(prompt.system.contains("3-8 words"))
        #expect(prompt.system.contains("instant"))
        #expect(prompt.user.contains("Smoke proof feels"))
        #expect(prompt.user.hasSuffix("Next 3-8 words, or <NO_SUGGESTION>:"))
    }

    @Test("Daily driver retry prompt repairs weak phrase candidates")
    func dailyDriverRetryPromptRepairsWeakPhraseCandidates() throws {
        let request = CompletionRequest(
            textBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof feels ",
            maxVisibleWords: 8,
            mode: .phraseContinuation
        )
        let weakCandidate = CompletionSuggestion(
            text: " smoke proof feels noisy",
            maxVisibleWords: 8
        )
        let selection = CompletionCandidateRanker().selection(
            [weakCandidate],
            mode: .phraseContinuation,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )

        #expect(selection.suppressionReason == CompletionCandidateSuppressionReason.lowTopScore)
        #expect(weakCandidate.visibleWordCount >= CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 8))

        let prompt = try #require(MLXModelRuntime.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: [weakCandidate],
            candidateSelection: selection,
            effectiveMaxVisibleWords: 8
        ))

        #expect(prompt.system.contains("not useful enough for inline autocomplete"))
        #expect(prompt.system.contains("Do not restart or repeat the Before cursor text."))
        #expect(prompt.system.contains("smoke proof feels noisy"))
        #expect(prompt.user.hasSuffix("Next 3-8 words, or <NO_SUGGESTION>:"))
    }

    @Test("Daily driver retry prompt repairs missing phrase candidates")
    func dailyDriverRetryPromptRepairsMissingPhraseCandidates() throws {
        let request = CompletionRequest(
            textBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof feels ",
            maxVisibleWords: 8,
            mode: .phraseContinuation
        )
        let selection = CompletionCandidateRanker().selection(
            [],
            mode: .phraseContinuation,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )

        #expect(selection.suppressionReason == CompletionCandidateSuppressionReason.noCandidates)

        let prompt = try #require(MLXModelRuntime.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: [],
            candidateSelection: selection,
            effectiveMaxVisibleWords: 8
        ))

        #expect(prompt.system.contains("did not produce a usable suffix"))
        #expect(prompt.system.contains("Choose a fresh continuation"))
        #expect(prompt.system.contains("3-8 words"))
        #expect(prompt.user.contains("Smoke proof feels"))
    }

    @Test("High word retry prompt stays off when the first pass is good")
    func highWordRetryPromptStaysOffWhenFirstPassIsGood() {
        let request = CompletionRequest(
            textBeforeCursor: "The onboarding note should make the setup feel clear and ",
            maxVisibleWords: 20,
            mode: .phraseContinuation
        )
        let longCandidate = CompletionSuggestion(
            text: " easy to finish without making the user think about permissions twice before they can keep writing",
            maxVisibleWords: 20
        )
        let selection = CompletionCandidateRanker().selection(
            [longCandidate],
            mode: .phraseContinuation,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )

        #expect(selection.suggestion != nil)
        #expect(MLXModelRuntime.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: [longCandidate],
            candidateSelection: selection,
            effectiveMaxVisibleWords: 20
        ) == nil)
    }
}
