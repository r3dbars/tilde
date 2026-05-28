import Foundation

public struct GhosttyInitialInsertionNoopInput: Equatable, Sendable {
    public let hostBundleIdentifier: String?
    public let proofProfileBundleIdentifier: String?
    public let sendKeyVerified: Bool
    public let systemEventsBulkVerified: Bool
    public let systemEventsBulkSafeToContinue: Bool
    public let focusedActionTextVerified: Bool
    public let focusedActionTextSafeToContinue: Bool
    public let focusedActionTextNativeNoopClassified: Bool
    public let pasteboardVerified: Bool
    public let pasteboardSafeToContinue: Bool
    public let inProcessInputTextVerified: Bool
    public let inProcessInputTextSafeToContinue: Bool
    public let promptStayedUnchanged: Bool
    public let runsExtendedProbes: Bool

    public init(
        hostBundleIdentifier: String?,
        proofProfileBundleIdentifier: String?,
        sendKeyVerified: Bool,
        systemEventsBulkVerified: Bool,
        systemEventsBulkSafeToContinue: Bool,
        focusedActionTextVerified: Bool,
        focusedActionTextSafeToContinue: Bool,
        focusedActionTextNativeNoopClassified: Bool,
        pasteboardVerified: Bool,
        pasteboardSafeToContinue: Bool,
        inProcessInputTextVerified: Bool,
        inProcessInputTextSafeToContinue: Bool,
        promptStayedUnchanged: Bool,
        runsExtendedProbes: Bool
    ) {
        self.hostBundleIdentifier = hostBundleIdentifier
        self.proofProfileBundleIdentifier = proofProfileBundleIdentifier
        self.sendKeyVerified = sendKeyVerified
        self.systemEventsBulkVerified = systemEventsBulkVerified
        self.systemEventsBulkSafeToContinue = systemEventsBulkSafeToContinue
        self.focusedActionTextVerified = focusedActionTextVerified
        self.focusedActionTextSafeToContinue = focusedActionTextSafeToContinue
        self.focusedActionTextNativeNoopClassified = focusedActionTextNativeNoopClassified
        self.pasteboardVerified = pasteboardVerified
        self.pasteboardSafeToContinue = pasteboardSafeToContinue
        self.inProcessInputTextVerified = inProcessInputTextVerified
        self.inProcessInputTextSafeToContinue = inProcessInputTextSafeToContinue
        self.promptStayedUnchanged = promptStayedUnchanged
        self.runsExtendedProbes = runsExtendedProbes
    }
}

public struct GhosttyInsertionNoopPolicy: Equatable, Sendable {
    public static let initialNoopClusterReason = "ghostty-initial-insertion-noop-cluster"

    public init() {}

    public func shouldFailFastAfterInitialNoopCluster(
        _ input: GhosttyInitialInsertionNoopInput
    ) -> Bool {
        input.hostBundleIdentifier == "com.mitchellh.ghostty"
            && input.proofProfileBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && !input.runsExtendedProbes
            && !input.sendKeyVerified
            && !input.systemEventsBulkVerified
            && input.systemEventsBulkSafeToContinue
            && !input.focusedActionTextVerified
            && input.focusedActionTextSafeToContinue
            && input.focusedActionTextNativeNoopClassified
            && !input.pasteboardVerified
            && input.pasteboardSafeToContinue
            && !input.inProcessInputTextVerified
            && input.inProcessInputTextSafeToContinue
            && input.promptStayedUnchanged
    }
}
