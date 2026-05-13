import Testing
@testable import AutocompleteLabCore

@Suite("Proof mode scope policy")
struct ProofModeScopePolicyTests {
    @Test("Inactive proof mode allows normal enabled apps")
    func inactiveProofModeAllowsNormalEnabledApps() {
        let policy = ProofModeScopePolicy()

        #expect(policy.allows(
            appBundleIdentifier: "com.google.Chrome",
            suggestionBundleIdentifier: "com.google.Chrome"
        ))
    }

    @Test("Active proof mode blocks apps outside the requested proof target")
    func activeProofModeBlocksOutsideApps() {
        let policy = ProofModeScopePolicy(scopedBundleIdentifiers: ["com.apple.TextEdit"])

        #expect(policy.allows(
            appBundleIdentifier: "com.apple.TextEdit",
            suggestionBundleIdentifier: "com.apple.TextEdit"
        ))
        #expect(!policy.allows(
            appBundleIdentifier: "com.google.Chrome",
            suggestionBundleIdentifier: "com.google.Chrome"
        ))
    }

    @Test("Active proof mode can allow a virtual proof profile through its suggestion bundle")
    func activeProofModeAllowsVirtualProofProfile() {
        let policy = ProofModeScopePolicy(scopedBundleIdentifiers: ["com.openai.claude-code.virtual"])

        #expect(policy.allows(
            appBundleIdentifier: "com.apple.Terminal",
            suggestionBundleIdentifier: "com.openai.claude-code.virtual"
        ))
    }
}
