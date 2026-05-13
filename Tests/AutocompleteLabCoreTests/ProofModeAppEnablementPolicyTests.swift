import Testing
@testable import AutocompleteLabCore

@Suite("Proof mode app enablement policy")
struct ProofModeAppEnablementPolicyTests {
    @Test("Disabled apps stay disabled outside proof mode")
    func disabledAppsStayDisabledOutsideProofMode() {
        let policy = ProofModeAppEnablementPolicy(
            disabledBundleIdentifiers: ["md.obsidian"]
        )

        #expect(!policy.isEnabled(
            appBundleIdentifier: "md.obsidian",
            suggestionBundleIdentifier: "md.obsidian"
        ))
    }

    @Test("Active proof target overrides disabled app selection")
    func activeProofTargetOverridesDisabledAppSelection() {
        let policy = ProofModeAppEnablementPolicy(
            disabledBundleIdentifiers: ["md.obsidian"],
            activeProofBundleIdentifiers: ["md.obsidian"]
        )

        #expect(policy.isEnabled(
            appBundleIdentifier: "md.obsidian",
            suggestionBundleIdentifier: "md.obsidian"
        ))
    }

    @Test("Proof suggestion bundle can enable a host app")
    func proofSuggestionBundleCanEnableAHostApp() {
        let policy = ProofModeAppEnablementPolicy(
            disabledBundleIdentifiers: ["com.apple.Terminal"],
            activeProofBundleIdentifiers: ["com.openai.claude-code.virtual"]
        )

        #expect(policy.isEnabled(
            appBundleIdentifier: "com.apple.Terminal",
            suggestionBundleIdentifier: "com.openai.claude-code.virtual"
        ))
    }
}
