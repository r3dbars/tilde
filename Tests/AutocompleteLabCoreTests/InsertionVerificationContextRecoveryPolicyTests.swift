import Testing
@testable import AutocompleteLabCore

@Suite("Insertion verification context recovery policy")
struct InsertionVerificationContextRecoveryPolicyTests {
    private let policy = InsertionVerificationContextRecoveryPolicy()
    private let obsidianProfile = CompatibilityProfileStore.mvp.profile(for: "md.obsidian")!
    private let textEditProfile = CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!
    private let expectedField = FocusedFieldIdentity(
        bundleIdentifier: "md.obsidian",
        processIdentifier: 42,
        elementIdentifier: 7
    )

    @Test("Recovers Obsidian CodeMirror AXWebArea swaps when text verification proves insertion")
    func recoversVerifiedObsidianWebAreaSwap() {
        #expect(policy.canRecover(input(
            contextRole: "AXWebArea",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
        #expect(policy.canRecover(input(
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .targetFingerprint
        )))
    }

    @Test("Does not recover non-Obsidian or unverified context swaps")
    func rejectsUnsafeRecoveryCases() {
        #expect(!policy.canRecover(input(
            profile: textEditProfile,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            contextRole: "AXWebArea",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            frontmostProcessIdentifier: 99,
            contextRole: "AXWebArea",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            contextRole: "AXWebArea",
            verificationResult: .unchanged,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            contextRole: "AXGroup",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
    }

    private func input(
        profile: CompatibilityProfile? = nil,
        frontmostBundleIdentifier: String = "md.obsidian",
        frontmostProcessIdentifier: Int32 = 42,
        contextRole: String?,
        verificationResult: InsertionVerificationResult,
        mismatch: InsertionVerificationContextMismatch
    ) -> InsertionVerificationContextRecoveryInput {
        InsertionVerificationContextRecoveryInput(
            profile: profile ?? obsidianProfile,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            frontmostProcessIdentifier: frontmostProcessIdentifier,
            expectedFieldIdentity: expectedField,
            contextRole: contextRole,
            verificationResult: verificationResult,
            mismatch: mismatch
        )
    }
}
