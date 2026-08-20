import Foundation

enum TildeSetupState: Equatable {
    case installingKeyboard
    case needsKeyboard
    case needsScreenRecording
    case preparing
    case ready
    case recoverableError

    static func resolve(
        keyboardInstallResult: GhostKeyboardInstallerHost.KeyboardInstallResult?,
        inputSourceStatus: GhostKeyboardInstallerHost.TildeInputSourceStatus,
        screenRecordingGranted: Bool,
        runtime: LlamaRuntimeSnapshot,
        socketAvailable: Bool
    ) -> Self {
        guard let keyboardInstallResult else { return .installingKeyboard }
        if keyboardInstallResult == .failed { return .recoverableError }
        if keyboardInstallResult == .unavailableInDevelopment,
           inputSourceStatus == .missing { return .recoverableError }
        guard inputSourceStatus != .missing else { return .needsKeyboard }
        guard screenRecordingGranted else { return .needsScreenRecording }
        guard socketAvailable else { return .recoverableError }

        switch runtime {
        case .starting, .retrying: return .preparing
        case .ready: return .ready
        case .failed: return .recoverableError
        }
    }
}
