import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned Qwen MLX model with calmer defaults")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .qwen35FourB)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 10)
        #expect(policy.maxVisibleWords == 4)
        #expect(policy.maxVisibleWords >= CompletionModelPolicy.minimumVisibleWords)
        #expect(policy.maxVisibleWords <= CompletionModelPolicy.maximumVisibleWords)
    }

    @Test("Model policy clamps visible completions to autocomplete size")
    func modelPolicyClampsVisibleCompletions() {
        let tiny = CompletionModelPolicy(
            model: .qwen35FourB,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 16,
            maxGeneratedTokens: 12,
            maxVisibleWords: 1,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )
        let huge = CompletionModelPolicy(
            model: .qwen35FourB,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 16,
            maxGeneratedTokens: 12,
            maxVisibleWords: 20,
            debounceMilliseconds: 240,
            targetLatencyMilliseconds: 900,
            reasoningEnabled: false
        )

        #expect(tiny.maxVisibleWords == 1)
        #expect(huge.maxVisibleWords == 7)
    }

    @Test("Model policy accepts only tiny autocomplete-sized visible output")
    func modelPolicyAcceptsOnlyTinyVisibleOutput() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.allowsVisibleWordCount(1))
        #expect(policy.allowsVisibleWordCount(2))
        #expect(policy.allowsVisibleWordCount(3))
        #expect(policy.allowsVisibleWordCount(4))
        #expect(!policy.allowsVisibleWordCount(5))
    }

    @Test("Completion length configuration reads environment overrides")
    func completionLengthConfigurationReadsEnvironmentOverrides() {
        let short = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_VISIBLE_WORDS": "3"
        ])
        let long = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_VISIBLE_WORDS": "42",
            "AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS": "99"
        ])

        #expect(short.maxVisibleWords == 3)
        #expect(short.maxGeneratedTokens == 9)
        #expect(short.displaySummary == "3 words / 9 tokens")
        #expect(long.maxVisibleWords == 7)
        #expect(long.maxGeneratedTokens == 32)
        #expect(long.displaySummary == "7 words / 32 tokens")
    }

    @Test("M5 with 128 GB is supported")
    func m5With128GBIsSupported() {
        let hardware = HardwareProfile(chipName: "M5 Max", memoryGB: 128, isAppleSilicon: true)

        #expect(CompletionModelPolicy.mvp.supports(hardware))
    }

    @Test("16 GB Apple Silicon profile supports the 4B MVP target")
    func sixteenGBSupportsTheFourBMVPTarget() {
        let hardware = HardwareProfile(chipName: "M1", memoryGB: 16, isAppleSilicon: true)

        #expect(CompletionModelPolicy.mvp.supports(hardware))
    }
}
