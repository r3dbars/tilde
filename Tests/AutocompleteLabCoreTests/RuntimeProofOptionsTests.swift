import Testing
@testable import AutocompleteLabCore

struct RuntimeProofOptionsTests {
    @Test("Reads proof-only fast word completion disable flag")
    func readsProofOnlyFastWordCompletionDisableFlag() {
        let options = RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "yes",
            RuntimeProofOptions.disableWordCompletionEnvironmentKey: "1",
            RuntimeProofOptions.disablePhraseContinuationEnvironmentKey: "on",
            RuntimeProofOptions.disableFastPhraseFallbackEnvironmentKey: "true",
            RuntimeProofOptions.proofScenarioEnvironmentKey: " textedit-model-latency "
        ])

        #expect(options.disablesFastWordCompletion)
        #expect(options.disablesWordCompletion)
        #expect(options.disablesPhraseContinuation)
        #expect(options.disablesFastPhraseFallback)
        #expect(options.proofScenario == "textedit-model-latency")
    }

    @Test("Leaves fast word completions enabled unless the proof flag is truthy")
    func leavesFastWordCompletionsEnabledByDefault() {
        #expect(!RuntimeProofOptions(environment: [:]).disablesFastWordCompletion)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastWordCompletionEnvironmentKey: "0"
        ]).disablesFastWordCompletion)
        #expect(!RuntimeProofOptions(environment: [:]).disablesWordCompletion)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableWordCompletionEnvironmentKey: "false"
        ]).disablesWordCompletion)
        #expect(!RuntimeProofOptions(environment: [:]).disablesPhraseContinuation)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disablePhraseContinuationEnvironmentKey: "off"
        ]).disablesPhraseContinuation)
        #expect(!RuntimeProofOptions(environment: [:]).disablesFastPhraseFallback)
        #expect(!RuntimeProofOptions(environment: [
            RuntimeProofOptions.disableFastPhraseFallbackEnvironmentKey: "no"
        ]).disablesFastPhraseFallback)
    }

    @Test("Ignores blank proof scenario")
    func ignoresBlankProofScenario() {
        #expect(RuntimeProofOptions(environment: [
            RuntimeProofOptions.proofScenarioEnvironmentKey: "   "
        ]).proofScenario == nil)
    }

    @Test("Recognizes Codex full accept no-submit proof scenario")
    func recognizesCodexFullAcceptNoSubmitProofScenario() {
        let options = RuntimeProofOptions(environment: [
            RuntimeProofOptions.proofScenarioEnvironmentKey:
                " \(RuntimeProofOptions.codexPromptFullAcceptNoSubmitScenario) "
        ])

        #expect(options.allowsCodexPromptFullAcceptNoSubmitProof)
        #expect(!RuntimeProofOptions(proofScenario: "codex-model-latency")
            .allowsCodexPromptFullAcceptNoSubmitProof)
        #expect(!RuntimeProofOptions().allowsCodexPromptFullAcceptNoSubmitProof)
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

    @Test("Disables word completion only inside active proof scope")
    func disablesWordCompletionOnlyInsideActiveProofScope() {
        let options = RuntimeProofOptions(disablesWordCompletion: true)

        #expect(options.disablesWordCompletion(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!options.disablesWordCompletion(
            appBundleIdentifier: "com.apple.Notes",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!RuntimeProofOptions(disablesWordCompletion: false).disablesWordCompletion(
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

    @Test("Disables fast phrase fallback only inside active proof scope")
    func disablesFastPhraseFallbackOnlyInsideActiveProofScope() {
        let options = RuntimeProofOptions(disablesFastPhraseFallback: true)

        #expect(options.disablesFastPhraseFallback(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!options.disablesFastPhraseFallback(
            appBundleIdentifier: "com.apple.Notes",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
        #expect(!RuntimeProofOptions(disablesFastPhraseFallback: false).disablesFastPhraseFallback(
            appBundleIdentifier: "com.apple.TextEdit",
            activeProofBundleIdentifiers: ["com.apple.TextEdit"]
        ))
    }
}
