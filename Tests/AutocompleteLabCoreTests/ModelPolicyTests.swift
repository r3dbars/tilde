import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned Qwen MLX model with reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .qwen35NineB)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 8)
        #expect(policy.maxVisibleWords == 4)
        #expect(policy.maxVisibleWords >= CompletionModelPolicy.minimumVisibleWords)
        #expect(policy.maxVisibleWords <= CompletionModelPolicy.maximumVisibleWords)
    }

    @Test("Model policy clamps visible completions to autocomplete size")
    func modelPolicyClampsVisibleCompletions() {
        let tiny = CompletionModelPolicy(
            model: .qwen35NineB,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 32,
            maxGeneratedTokens: 12,
            maxVisibleWords: 1,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )
        let huge = CompletionModelPolicy(
            model: .qwen35NineB,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 32,
            maxGeneratedTokens: 12,
            maxVisibleWords: 20,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )

        #expect(tiny.maxVisibleWords == 2)
        #expect(huge.maxVisibleWords == 8)
    }

    @Test("Model policy accepts only tiny autocomplete-sized visible output")
    func modelPolicyAcceptsOnlyTinyVisibleOutput() {
        let policy = CompletionModelPolicy.mvp

        #expect(!policy.allowsVisibleWordCount(1))
        #expect(policy.allowsVisibleWordCount(2))
        #expect(policy.allowsVisibleWordCount(4))
        #expect(!policy.allowsVisibleWordCount(5))
    }

    @Test("M5 with 128 GB is supported")
    func m5With128GBIsSupported() {
        let hardware = HardwareProfile(chipName: "M5 Max", memoryGB: 128, isAppleSilicon: true)

        #expect(CompletionModelPolicy.mvp.supports(hardware))
    }

    @Test("16 GB profile is not the 9B MVP target")
    func sixteenGBIsNotTheNineBMVPTarget() {
        let hardware = HardwareProfile(chipName: "M1", memoryGB: 16, isAppleSilicon: true)

        #expect(!CompletionModelPolicy.mvp.supports(hardware))
    }
}
