import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned large MLX model with reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .gemma4A4B)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 12)
        #expect(policy.maxVisibleWords == 6)
        #expect(policy.maxVisibleWords >= CompletionModelPolicy.minimumVisibleWords)
        #expect(policy.maxVisibleWords <= CompletionModelPolicy.maximumVisibleWords)
    }

    @Test("Model policy clamps visible completions to autocomplete size")
    func modelPolicyClampsVisibleCompletions() {
        let tiny = CompletionModelPolicy(
            model: .gemma4A4B,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 64,
            maxGeneratedTokens: 12,
            maxVisibleWords: 1,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )
        let huge = CompletionModelPolicy(
            model: .gemma4A4B,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 64,
            maxGeneratedTokens: 12,
            maxVisibleWords: 20,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )

        #expect(tiny.maxVisibleWords == 2)
        #expect(huge.maxVisibleWords == 8)
    }

    @Test("M5 with 128 GB is supported")
    func m5With128GBIsSupported() {
        let hardware = HardwareProfile(chipName: "M5 Max", memoryGB: 128, isAppleSilicon: true)

        #expect(CompletionModelPolicy.mvp.supports(hardware))
    }

    @Test("16 GB profile is not the large-model MVP target")
    func sixteenGBIsNotTheLargeModelMVPTarget() {
        let hardware = HardwareProfile(chipName: "M1", memoryGB: 16, isAppleSilicon: true)

        #expect(!CompletionModelPolicy.mvp.supports(hardware))
    }
}
