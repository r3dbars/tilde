import Testing
@testable import AutocompleteLabCore

struct RuntimeProofOptionsTests {
    @Test("Reads proof-only fast word completion disable flag")
    func readsProofOnlyFastWordCompletionDisableFlag() {
        let options = RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "yes",
            RuntimeProofOptions.disablePhraseContinuationEnvironmentKey: "on",
            RuntimeProofOptions.proofScenarioEnvironmentKey: " textedit-model-latency "
        ])

        #expect(options.disablesFastWordCompletion)
        #expect(options.disablesPhraseContinuation)
        #expect(options.proofScenario == "textedit-model-latency")
    }

    @Test("Leaves fast word completions enabled unless the proof flag is truthy")
    func leavesFastWordCompletionsEnabledByDefault() {
        #expect(!RuntimeProofOptions(environment: [:]).disablesFastWordCompletion)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "0"
        ]).disablesFastWordCompletion)
        #expect(!RuntimeProofOptions(environment: [:]).disablesPhraseContinuation)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disablePhraseContinuationEnvironmentKey: "off"
        ]).disablesPhraseContinuation)
    }

    @Test("Ignores blank proof scenario")
    func ignoresBlankProofScenario() {
        #expect(RuntimeProofOptions(environment: [
            RuntimeProofOptions.proofScenarioEnvironmentKey: "   "
        ]).proofScenario == nil)
    }

    @Test("Disables fast word completion only inside active proof scope")
    func disablesFastWordCompletionOnlyInsideActiveProofScope() {
        let options = RuntimeProofOptions(disablesFastWordCompletion: true)

        #expect(options.disablesFastWordCompletion(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!options.disablesFastWordCompletion(
            appBundleIdentifier: "com.apple.Notes",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!RuntimeProofOptions(disablesFastWordCompletion: false).disablesFastWordCompletion(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
    }

    @Test("Disables phrase continuation only inside active proof scope")
    func disablesPhraseContinuationOnlyInsideActiveProofScope() {
        let options = RuntimeProofOptions(disablesPhraseContinuation: true)

        #expect(options.disablesPhraseContinuation(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!options.disablesPhraseContinuation(
            appBundleIdentifier: "com.apple.Notes",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!RuntimeProofOptions(disablesPhraseContinuation: false).disablesPhraseContinuation(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
    }
}
