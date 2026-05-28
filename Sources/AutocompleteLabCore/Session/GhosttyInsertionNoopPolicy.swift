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
    public let pasteActionVerified: Bool
    public let pasteActionSafeToContinue: Bool
    public let pasteActionNativeNoopClassified: Bool
    public let pasteboardVerified: Bool
    public let pasteboardSafeToContinue: Bool
    public let bundledGhosttyInputTextHelperVerified: Bool
    public let bundledGhosttyInputTextHelperSafeToContinue: Bool
    public let inProcessInputTextVerified: Bool
    public let inProcessInputTextSafeToContinue: Bool
    public let frontWindowInputTextVerified: Bool
    public let frontWindowInputTextSafeToContinue: Bool
    public let frontWindowInputTextNativeNoopClassified: Bool
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
        pasteActionVerified: Bool,
        pasteActionSafeToContinue: Bool,
        pasteActionNativeNoopClassified: Bool,
        pasteboardVerified: Bool,
        pasteboardSafeToContinue: Bool,
        bundledGhosttyInputTextHelperVerified: Bool,
        bundledGhosttyInputTextHelperSafeToContinue: Bool,
        inProcessInputTextVerified: Bool,
        inProcessInputTextSafeToContinue: Bool,
        frontWindowInputTextVerified: Bool,
        frontWindowInputTextSafeToContinue: Bool,
        frontWindowInputTextNativeNoopClassified: Bool,
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
        self.pasteActionVerified = pasteActionVerified
        self.pasteActionSafeToContinue = pasteActionSafeToContinue
        self.pasteActionNativeNoopClassified = pasteActionNativeNoopClassified
        self.pasteboardVerified = pasteboardVerified
        self.pasteboardSafeToContinue = pasteboardSafeToContinue
        self.bundledGhosttyInputTextHelperVerified = bundledGhosttyInputTextHelperVerified
        self.bundledGhosttyInputTextHelperSafeToContinue = bundledGhosttyInputTextHelperSafeToContinue
        self.inProcessInputTextVerified = inProcessInputTextVerified
        self.inProcessInputTextSafeToContinue = inProcessInputTextSafeToContinue
        self.frontWindowInputTextVerified = frontWindowInputTextVerified
        self.frontWindowInputTextSafeToContinue = frontWindowInputTextSafeToContinue
        self.frontWindowInputTextNativeNoopClassified = frontWindowInputTextNativeNoopClassified
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
            && !input.pasteActionVerified
            && input.pasteActionSafeToContinue
            && input.pasteActionNativeNoopClassified
            && !input.pasteboardVerified
            && input.pasteboardSafeToContinue
            && !input.bundledGhosttyInputTextHelperVerified
            && input.bundledGhosttyInputTextHelperSafeToContinue
            && !input.inProcessInputTextVerified
            && input.inProcessInputTextSafeToContinue
            && !input.frontWindowInputTextVerified
            && input.frontWindowInputTextSafeToContinue
            && input.frontWindowInputTextNativeNoopClassified
            && input.promptStayedUnchanged
    }
}
