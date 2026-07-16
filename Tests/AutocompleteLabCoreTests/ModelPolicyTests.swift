import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned Gemma MLX model with short suggestions and reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .gemma4E4BItOptiQ)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 20)
        #expect(policy.maxVisibleWords == 8)
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
        #expect(huge.maxVisibleWords == 20)
    }

    @Test("Model policy accepts autocomplete-sized visible output")
    func modelPolicyAcceptsVisibleOutput() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.allowsVisibleWordCount(1))
        #expect(policy.allowsVisibleWordCount(2))
        #expect(policy.allowsVisibleWordCount(3))
        #expect(policy.allowsVisibleWordCount(5))
        #expect(policy.allowsVisibleWordCount(6))
        #expect(policy.allowsVisibleWordCount(7))
        #expect(policy.allowsVisibleWordCount(8))
        #expect(!policy.allowsVisibleWordCount(9))
    }

    @Test("Request modes cap generated tokens by autocomplete role")
    func requestModesCapGeneratedTokensByAutocompleteRole() {
        #expect(CompletionRequestMode.wordCompletion.generatedTokenCeiling == 3)
        #expect(CompletionRequestMode.phraseContinuation.generatedTokenCeiling == 48)
        #expect(CompletionRequestMode.sentenceContinuation.generatedTokenCeiling == 48)
    }

    @Test("Shipping completion length configuration is the MVP default")
    func shippingCompletionLengthConfigurationIsMVPDefault() {
        let defaultConfiguration = CompletionLengthConfiguration.default

        #expect(defaultConfiguration.maxVisibleWords == 8)
        #expect(defaultConfiguration.maxGeneratedTokens == 20)
        #expect(defaultConfiguration.displaySummary == "8 words / 20 tokens")
    }

    @Test("Generated token budget grows for longer visible suggestions")
    func generatedTokenBudgetGrowsForLongerVisibleSuggestions() {
        #expect(CompletionModelPolicy.generatedTokenBudget(forVisibleWords: 3) == 9)
        #expect(CompletionModelPolicy.generatedTokenBudget(forVisibleWords: 5) == 11)
        #expect(CompletionModelPolicy.generatedTokenBudget(forVisibleWords: 12) == 28)
        #expect(CompletionModelPolicy.generatedTokenBudget(forVisibleWords: 20) == 44)
    }

    @Test("Preferred minimum grows when the word slider is high")
    func preferredMinimumGrowsWhenWordSliderIsHigh() {
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 3) == 1)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 5) == 3)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 8) == 3)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 12) == 8)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 20) == 12)
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
