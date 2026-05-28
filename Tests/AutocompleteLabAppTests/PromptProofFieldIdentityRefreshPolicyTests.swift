import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Prompt proof field identity refresh policy")
struct PromptProofFieldIdentityRefreshPolicyTests {
    private let policy = PromptProofFieldIdentityRefreshPolicy()

    @Test("Allows word-only prompt proof identity churn inside proof mode")
    func allowsWordOnlyPromptProofIdentityChurnInsideProofMode() throws {
        let profile = try codexProfile()

        #expect(policy.canTrustRefresh(
            requestFieldIdentity: identity(elementIdentifier: 7),
            refreshedFieldIdentity: identity(elementIdentifier: 99),
            profile: profile,
            proofModeEnabled: true,
            allowsFullAcceptNoSubmitProofProfile: false
        ))
    }

    @Test("Allows Codex full-accept proof profile identity churn inside proof mode")
    func allowsCodexFullAcceptProofProfileIdentityChurnInsideProofMode() throws {
        let profile = try codexProfile().replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false
        )

        #expect(policy.canTrustRefresh(
            requestFieldIdentity: identity(elementIdentifier: 7),
            refreshedFieldIdentity: identity(elementIdentifier: 99),
            profile: profile,
            proofModeEnabled: true,
            allowsFullAcceptNoSubmitProofProfile: true
        ))
    }

    @Test("Blocks full-accept proof profile identity churn outside the proof scenario")
    func blocksFullAcceptProofProfileIdentityChurnOutsideProofScenario() throws {
        let profile = try codexProfile().replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false
        )

        #expect(!policy.canTrustRefresh(
            requestFieldIdentity: identity(elementIdentifier: 7),
            refreshedFieldIdentity: identity(elementIdentifier: 99),
            profile: profile,
            proofModeEnabled: true,
            allowsFullAcceptNoSubmitProofProfile: false
        ))
    }

    @Test("Blocks prompt proof identity churn across processes")
    func blocksPromptProofIdentityChurnAcrossProcesses() throws {
        let profile = try codexProfile()

        #expect(!policy.canTrustRefresh(
            requestFieldIdentity: identity(processIdentifier: 42, elementIdentifier: 7),
            refreshedFieldIdentity: identity(processIdentifier: 43, elementIdentifier: 7),
            profile: profile,
            proofModeEnabled: true,
            allowsFullAcceptNoSubmitProofProfile: false
        ))
    }

    @Test("Blocks prompt proof identity churn outside proof mode")
    func blocksPromptProofIdentityChurnOutsideProofMode() throws {
        let profile = try codexProfile()

        #expect(!policy.canTrustRefresh(
            requestFieldIdentity: identity(elementIdentifier: 7),
            refreshedFieldIdentity: identity(elementIdentifier: 99),
            profile: profile,
            proofModeEnabled: false,
            allowsFullAcceptNoSubmitProofProfile: false
        ))
    }

    private func codexProfile() throws -> CompatibilityProfile {
        try #require(CompatibilityProfileStore.mvp.profile(for: CodexProofFocusedTargetPolicy.bundleIdentifier))
    }

    private func identity(
        processIdentifier: Int32 = 42,
        elementIdentifier: Int
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: processIdentifier,
            elementIdentifier: elementIdentifier
        )
    }
}
