import Testing
@testable import AutocompleteLabCore

@Suite("Model policy")
struct ModelPolicyTests {
    @Test("MVP uses app-owned Gemma 4 E2B with reasoning off")
    func mvpPolicy() {
        let policy = CompletionModelPolicy.mvp

        #expect(policy.model == .gemma4E2B)
        #expect(policy.runtimeOwnership == .appOwnedEmbedded)
        #expect(policy.reasoningEnabled == false)
        #expect(policy.maxGeneratedTokens == 16)
        #expect(policy.maxVisibleWords == 3)
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
