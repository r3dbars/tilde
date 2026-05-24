import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned Qwen MLX model with short suggestions and reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .qwen35FourB)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 11)
        #expect(policy.maxVisibleWords == 5)
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
        #expect(!policy.allowsVisibleWordCount(6))
        #expect(!policy.allowsVisibleWordCount(7))
        #expect(!policy.allowsVisibleWordCount(8))
        #expect(!policy.allowsVisibleWordCount(9))
    }

    @Test("Request modes cap generated tokens by autocomplete role")
    func requestModesCapGeneratedTokensByAutocompleteRole() {
        #expect(CompletionRequestMode.wordCompletion.generatedTokenCeiling == 3)
        #expect(CompletionRequestMode.phraseContinuation.generatedTokenCeiling == 48)
        #expect(CompletionRequestMode.sentenceContinuation.generatedTokenCeiling == 48)
    }

    @Test("Completion length configuration reads environment overrides")
    func completionLengthConfigurationReadsEnvironmentOverrides() {
        let defaultConfiguration = CompletionLengthConfiguration.fromEnvironment([:])
        let short = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_VISIBLE_WORDS": "3"
        ])
        let long = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_VISIBLE_WORDS": "42",
            "AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS": "99"
        ])

        #expect(defaultConfiguration.maxVisibleWords == 5)
        #expect(defaultConfiguration.maxGeneratedTokens == 11)
        #expect(defaultConfiguration.displaySummary == "5 words / 11 tokens")
        #expect(short.maxVisibleWords == 3)
        #expect(short.maxGeneratedTokens == 9)
        #expect(short.displaySummary == "3 words / 9 tokens")
        #expect(long.maxVisibleWords == 20)
        #expect(long.maxGeneratedTokens == 48)
        #expect(long.displaySummary == "20 words / 48 tokens")
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
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 5) == 1)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 8) == 3)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 12) == 8)
        #expect(CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: 20) == 12)
    }

    @Test("Experiment arms set default completion lengths")
    func experimentArmsSetDefaultCompletionLengths() {
        let oneWord = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_1_word"
        ])
        let threeWord = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_3_word"
        ])
        let overridden = CompletionLengthConfiguration.fromEnvironment([
            "AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_1_word",
            "AUTOCOMPLETE_LAB_VISIBLE_WORDS": "3"
        ])

        #expect(oneWord.experimentArm == .length1Word)
        #expect(oneWord.maxVisibleWords == 1)
        #expect(oneWord.maxGeneratedTokens == 4)
        #expect(threeWord.experimentArm == .length3Word)
        #expect(threeWord.maxVisibleWords == 5)
        #expect(threeWord.maxGeneratedTokens == 11)
        #expect(overridden.experimentArm == .length1Word)
        #expect(overridden.maxVisibleWords == 3)
        #expect(overridden.maxGeneratedTokens == 9)
    }

    @Test("Experiment arm selection prefers environment then persisted then assigned")
    func experimentArmSelectionPrefersEnvironmentThenPersistedThenAssigned() {
        let environmentSelection = AutocompleteExperimentArmSelection.current(
            environment: ["AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_1_word"],
            persistedRawValue: "length_3_word",
            chooseArm: { .length3Word }
        )
        let persistedSelection = AutocompleteExperimentArmSelection.current(
            environment: [:],
            persistedRawValue: "length_3_word",
            chooseArm: { .length1Word }
        )
        let assignedSelection = AutocompleteExperimentArmSelection.current(
            environment: [:],
            persistedRawValue: nil,
            chooseArm: { .length1Word }
        )

        #expect(environmentSelection.arm == .length1Word)
        #expect(environmentSelection.source == .environment)
        #expect(environmentSelection.shouldPersist)
        #expect(persistedSelection.arm == .length3Word)
        #expect(persistedSelection.source == .persisted)
        #expect(!persistedSelection.shouldPersist)
        #expect(assignedSelection.arm == .length1Word)
        #expect(assignedSelection.source == .assigned)
        #expect(assignedSelection.shouldPersist)
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
