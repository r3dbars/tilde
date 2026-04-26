import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses an app-owned small MLX model with reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .qwen3Medium)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 12)
        #expect(policy.maxVisibleWords == 6)
    }

    @Test("M1 with 16 GB is supported")
    func m1With16GBIsSupported() {
        let hardware = HardwareProfile(chipName: "M1", memoryGB: 16, isAppleSilicon: true)

        #expect(CompletionModelPolicy.mvp.supports(hardware))
    }

    @Test("8 GB profile is not the MVP target")
    func eightGBIsNotTheMVPTarget() {
        let hardware = HardwareProfile(chipName: "M1", memoryGB: 8, isAppleSilicon: true)

        #expect(!CompletionModelPolicy.mvp.supports(hardware))
    }
}
