import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Ghostty insertion no-op policy")
struct GhosttyInsertionNoopPolicyTests {
    private let policy = GhosttyInsertionNoopPolicy()

    @Test("Fails fast after the initial app-owned Ghostty insertion cluster no-ops")
    func failsFastAfterInitialNoopCluster() {
        #expect(policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster()))
    }

    @Test("Keeps extended probes available for focused transport research")
    func extendedProbesContinue() {
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            runsExtendedProbes: true
        )))
    }

    @Test("Does not fail fast when a transport verifies or the prompt mutates")
    func verifiedOrMutatedPromptDoesNotFailFast() {
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            systemEventsBulkVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            focusedActionTextVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            pasteActionVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            bundledGhosttyInputTextHelperVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            inProcessInputTextVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            frontWindowInputTextVerified: true
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            promptStayedUnchanged: false
        )))
    }

    @Test("Does not fail fast when an in-process input miss is unsafe")
    func unsafeInProcessInputMissDoesNotFailFast() {
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            focusedActionTextSafeToContinue: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            pasteActionSafeToContinue: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            bundledGhosttyInputTextHelperSafeToContinue: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            inProcessInputTextSafeToContinue: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            frontWindowInputTextSafeToContinue: false
        )))
    }

    @Test("Requires native screen-copy no-op classification before initial fail-fast")
    func nativeScreenCopyNoopClassificationRequired() {
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            focusedActionTextNativeNoopClassified: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            pasteActionNativeNoopClassified: false
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            frontWindowInputTextNativeNoopClassified: false
        )))
    }

    @Test("Only applies to the proof-scoped Ghostty terminal host")
    func onlyAppliesToGhosttyProofProfile() {
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            hostBundleIdentifier: "com.apple.Terminal"
        )))
        #expect(!policy.shouldFailFastAfterInitialNoopCluster(.ghosttyNoopCluster(
            proofProfileBundleIdentifier: "com.apple.TextEdit"
        )))
    }
}

private extension GhosttyInitialInsertionNoopInput {
    static func ghosttyNoopCluster(
        hostBundleIdentifier: String? = "com.mitchellh.ghostty",
        proofProfileBundleIdentifier: String? = ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
        sendKeyVerified: Bool = false,
        systemEventsBulkVerified: Bool = false,
        systemEventsBulkSafeToContinue: Bool = true,
        focusedActionTextVerified: Bool = false,
        focusedActionTextSafeToContinue: Bool = true,
        focusedActionTextNativeNoopClassified: Bool = true,
        pasteActionVerified: Bool = false,
        pasteActionSafeToContinue: Bool = true,
        pasteActionNativeNoopClassified: Bool = true,
        pasteboardVerified: Bool = false,
        pasteboardSafeToContinue: Bool = true,
        bundledGhosttyInputTextHelperVerified: Bool = false,
        bundledGhosttyInputTextHelperSafeToContinue: Bool = true,
        inProcessInputTextVerified: Bool = false,
        inProcessInputTextSafeToContinue: Bool = true,
        frontWindowInputTextVerified: Bool = false,
        frontWindowInputTextSafeToContinue: Bool = true,
        frontWindowInputTextNativeNoopClassified: Bool = true,
        promptStayedUnchanged: Bool = true,
        runsExtendedProbes: Bool = false
    ) -> GhosttyInitialInsertionNoopInput {
        GhosttyInitialInsertionNoopInput(
            hostBundleIdentifier: hostBundleIdentifier,
            proofProfileBundleIdentifier: proofProfileBundleIdentifier,
            sendKeyVerified: sendKeyVerified,
            systemEventsBulkVerified: systemEventsBulkVerified,
            systemEventsBulkSafeToContinue: systemEventsBulkSafeToContinue,
            focusedActionTextVerified: focusedActionTextVerified,
            focusedActionTextSafeToContinue: focusedActionTextSafeToContinue,
            focusedActionTextNativeNoopClassified: focusedActionTextNativeNoopClassified,
            pasteActionVerified: pasteActionVerified,
            pasteActionSafeToContinue: pasteActionSafeToContinue,
            pasteActionNativeNoopClassified: pasteActionNativeNoopClassified,
            pasteboardVerified: pasteboardVerified,
            pasteboardSafeToContinue: pasteboardSafeToContinue,
            bundledGhosttyInputTextHelperVerified: bundledGhosttyInputTextHelperVerified,
            bundledGhosttyInputTextHelperSafeToContinue: bundledGhosttyInputTextHelperSafeToContinue,
            inProcessInputTextVerified: inProcessInputTextVerified,
            inProcessInputTextSafeToContinue: inProcessInputTextSafeToContinue,
            frontWindowInputTextVerified: frontWindowInputTextVerified,
            frontWindowInputTextSafeToContinue: frontWindowInputTextSafeToContinue,
            frontWindowInputTextNativeNoopClassified: frontWindowInputTextNativeNoopClassified,
            promptStayedUnchanged: promptStayedUnchanged,
            runsExtendedProbes: runsExtendedProbes
        )
    }
}
