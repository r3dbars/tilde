import Testing
@testable import AutocompleteLabCore

/// Regression lock for the latency contract and the default model/asset identity.
///
/// These values are load-bearing for the inline-autocomplete feel and are referenced
/// from several places that cannot all see each other at compile time:
///
///   - `SuggestionOrchestrator` (app target) caps a *cold, first-visible* model paint at
///     1200ms and a *refinement of an already-visible* suggestion at 2000ms. Those ceilings
///     are deliberately tied to the core scheduling budgets locked below; if the core
///     budgets move, the orchestrator comment and the latency proof docs must move with
///     them. This suite makes a silent drift fail loudly.
///   - `docs/research/runtime-options.md` documents the default model. The asset/policy
///     identity check below keeps that doc honest: the shipped default asset and the
///     default completion policy must name the same model.
///
/// If you intend to change a budget or the default model, update this lock *and* the
/// matching proof docs in the same change — do not weaken the assertion to make it pass.
@Suite("Latency budget + default model lock")
struct LatencyBudgetLockTests {
    @Test("Default scheduling budgets match the first-visible (1200ms) / refine (2000ms) contract")
    func defaultSchedulingBudgetsAreLocked() {
        let policy = SuggestionRequestSchedulingPolicy()

        // Cold first-visible model paint ceiling (mirrors
        // SuggestionOrchestrator.maximumFirstVisibleModelDisplayLatencyMilliseconds).
        #expect(policy.instantWordResultBudgetMilliseconds == 1_200)
        // Refinement-of-visible ceiling (mirrors
        // SuggestionOrchestrator.maximumFinalModelDisplayLatencyMilliseconds).
        #expect(policy.continuationResultBudgetMilliseconds == 2_000)
        // Floating-overlay stability floor.
        #expect(policy.floatingOverlayMinimumDelayMilliseconds == 60)
    }

    @Test("Keystroke lane carries the 1200ms budget and suppresses only when over it")
    func keystrokeLaneBudgetIsEnforcedAtTheBoundary() {
        let policy = SuggestionRequestSchedulingPolicy()
        let schedule = policy.schedule(
            policyDelayMilliseconds: 0,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            renderMode: .inlineAdjacent
        )

        #expect(schedule.resultLatencyBudgetMilliseconds == 1_200)
        // Exactly at budget still shows; one millisecond over is dropped rather than
        // painted as a stale, late ghost flash after the caret has moved on.
        #expect(policy.shouldSuppressResult(latencyMilliseconds: 1_200, schedule: schedule) == false)
        #expect(policy.shouldSuppressResult(latencyMilliseconds: 1_201, schedule: schedule) == true)
    }

    @Test("Default completion policy keeps the verified Qwen low-latency target shape")
    func defaultCompletionPolicyShapeIsLocked() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .qwen35FourB)
        #expect(policy.targetLatencyMilliseconds == 50)
        #expect(policy.maxGeneratedTokens == 20)
        #expect(policy.maxVisibleWords == 8)
        #expect(policy.minimumMemoryGB == 16)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
    }

    @Test("Shipped default asset names the same model as the default policy (anti doc-drift)")
    func defaultAssetMatchesDefaultPolicyModel() {
        // The single fact behind docs/research/runtime-options.md: the preferred MLX asset
        // and the default completion policy must agree on the model. Historically the docs
        // Drift between the runtime asset and prompt policy can silently select the wrong model.
        #expect(LocalModelAssetManifest.preferredMLX.model == CompletionModelPolicy.mvp.model)
        #expect(LocalModelAssetManifest.preferredMLX.model == .qwen35FourB)
        #expect(LocalModelAssetManifest.preferredMLX.source != nil)
    }
}
