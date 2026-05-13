import Testing
@testable import AutocompleteLabCore

struct RuntimeProofOptionsTests {
    @Test("Reads proof-only fast word completion disable flag")
    func readsProofOnlyFastWordCompletionDisableFlag() {
        let options = RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "yes"
        ])

        #expect(options.disablesFastWordCompletion)
    }

    @Test("Leaves fast word completions enabled unless the proof flag is truthy")
    func leavesFastWordCompletionsEnabledByDefault() {
        #expect(!RuntimeProofOptions(environment: [:]).disablesFastWordCompletion)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "0"
        ]).disablesFastWordCompletion)
    }
}
