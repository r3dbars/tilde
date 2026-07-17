import Testing
@testable import AutocompleteLabCore

@Suite("Insertion verification context recovery policy")
struct InsertionVerificationContextRecoveryPolicyTests {
    private let policy = InsertionVerificationContextRecoveryPolicy()
    private let obsidianProfile = CompatibilityProfileStore.mvp.profile(for: "md.obsidian")!
    private let chromeProfile = CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome")!
    private let codexProfile = CompatibilityProfileStore.mvp.profile(for: "com.openai.codex")!
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

    @Test("Recovers Chromium target fingerprint churn only after verified insertion")
    func recoversVerifiedChromiumTargetFingerprintChurn() {
        #expect(policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .targetFingerprint
        )))
        #expect(policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextField",
            verificationResult: .verified,
            mismatch: .targetFingerprint
        )))
    }

    @Test("Recovers verified Codex text-area identity churn")
    func recoversVerifiedCodexTextAreaIdentityChurn() {
        let codexField = FocusedFieldIdentity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(policy.canRecover(input(
            profile: codexProfile,
            frontmostBundleIdentifier: "com.openai.codex",
            expectedField: codexField,
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            profile: codexProfile,
            frontmostBundleIdentifier: "com.openai.codex",
            expectedField: codexField,
            contextRole: "AXTextArea",
            verificationResult: .unchanged,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            profile: codexProfile,
            frontmostBundleIdentifier: "com.openai.codex",
            expectedField: codexField,
            contextRole: "AXGroup",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
    }

    @Test("Does not recover one-character Chrome text-area verification")
    func rejectsOneCharacterChromeTextAreaVerification() {
        #expect(!policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .targetFingerprint,
            previousTextBeforeCursorUTF16Length: 0,
            acceptedTextUTF16Length: 1,
            currentTextBeforeCursorUTF16Length: 1
        )))

        #expect(policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .targetFingerprint,
            previousTextBeforeCursorUTF16Length: 12,
            acceptedTextUTF16Length: 4,
            currentTextBeforeCursorUTF16Length: 16
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
        #expect(!policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextArea",
            verificationResult: .verified,
            mismatch: .fieldIdentity
        )))
        #expect(!policy.canRecover(input(
            profile: chromeProfile,
            frontmostBundleIdentifier: "com.google.Chrome",
            expectedField: FocusedFieldIdentity(
                bundleIdentifier: "com.google.Chrome",
                processIdentifier: 42,
                elementIdentifier: 99
            ),
            contextRole: "AXTextArea",
            verificationResult: .unchanged,
            mismatch: .targetFingerprint
        )))
    }

    private func input(
        profile: CompatibilityProfile? = nil,
        frontmostBundleIdentifier: String = "md.obsidian",
        frontmostProcessIdentifier: Int32 = 42,
        expectedField: FocusedFieldIdentity? = nil,
        contextRole: String?,
        verificationResult: InsertionVerificationResult,
        mismatch: InsertionVerificationContextMismatch,
        previousTextBeforeCursorUTF16Length: Int? = nil,
        acceptedTextUTF16Length: Int? = nil,
        currentTextBeforeCursorUTF16Length: Int? = nil
    ) -> InsertionVerificationContextRecoveryInput {
        InsertionVerificationContextRecoveryInput(
            profile: profile ?? obsidianProfile,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            frontmostProcessIdentifier: frontmostProcessIdentifier,
            expectedFieldIdentity: expectedField ?? self.expectedField,
            contextRole: contextRole,
            verificationResult: verificationResult,
            mismatch: mismatch,
            previousTextBeforeCursorUTF16Length: previousTextBeforeCursorUTF16Length,
            acceptedTextUTF16Length: acceptedTextUTF16Length,
            currentTextBeforeCursorUTF16Length: currentTextBeforeCursorUTF16Length
        )
    }
}
