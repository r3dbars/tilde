import Testing
@testable import AutocompleteLabCore

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
            promptStayedUnchanged: false
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
        pasteboardVerified: Bool = false,
        pasteboardSafeToContinue: Bool = true,
        promptStayedUnchanged: Bool = true,
        runsExtendedProbes: Bool = false
    ) -> GhosttyInitialInsertionNoopInput {
        GhosttyInitialInsertionNoopInput(
            hostBundleIdentifier: hostBundleIdentifier,
            proofProfileBundleIdentifier: proofProfileBundleIdentifier,
            sendKeyVerified: sendKeyVerified,
            systemEventsBulkVerified: systemEventsBulkVerified,
            systemEventsBulkSafeToContinue: systemEventsBulkSafeToContinue,
            pasteboardVerified: pasteboardVerified,
            pasteboardSafeToContinue: pasteboardSafeToContinue,
            promptStayedUnchanged: promptStayedUnchanged,
            runsExtendedProbes: runsExtendedProbes
        )
    }
}
