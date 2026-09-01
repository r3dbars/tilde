import Foundation

/// The part of setup that owns the repair action. Keeping this separate from
/// `ModelFailure` lets the setup window distinguish a model problem from an
/// input-method or runtime problem without teaching the model manager about UI.
enum TildeSetupRepairTarget: Equatable {
    case keyboard
    case model(ModelFailure)
    case runtime
}

enum TildeSetupState: Equatable {
    case installingKeyboard
    case needsKeyboard
    case needsScreenRecording
    case downloadingModel(receivedBytes: Int64, totalBytes: Int64)
    case verifyingModel
    case startingRuntime
    case needsInputSourceSelection
    case ready
    case recoverableError(TildeSetupRepairTarget)

    /// Conservative fallback for callers that do not yet know the selected
    /// descriptor. The app passes the exact selected-model byte count.
    static let gemma4E2BApproximateBytes: Int64 = 3_430_000_000

    static func resolve(
        keyboardInstallResult: GhostKeyboardInstallerHost.KeyboardInstallResult?,
        inputSourceStatus: GhostKeyboardInstallerHost.TildeInputSourceStatus,
        screenRecordingGranted: Bool,
        runtime: LlamaRuntimeSnapshot,
        socketAvailable: Bool,
        model: ModelState,
        requireInitialInputSourceSelection: Bool = true,
        selectedModelBytes: Int64 = gemma4E2BApproximateBytes
    ) -> Self {
        guard let keyboardInstallResult else { return .installingKeyboard }
        if keyboardInstallResult == .failed { return .recoverableError(.keyboard) }
        if keyboardInstallResult == .unavailableInDevelopment,
           inputSourceStatus == .missing { return .recoverableError(.keyboard) }
        guard inputSourceStatus != .missing else { return .needsKeyboard }
        guard screenRecordingGranted else { return .needsScreenRecording }

        switch model {
        case .checking, .missing:
            return .downloadingModel(
                receivedBytes: 0,
                totalBytes: selectedModelBytes
            )
        case let .downloading(receivedBytes, totalBytes):
            return .downloadingModel(receivedBytes: receivedBytes, totalBytes: totalBytes)
        case .verifying:
            return .verifyingModel
        case .failed(let failure):
            return .recoverableError(.model(failure))
        case .ready:
            break
        }

        guard socketAvailable else { return .recoverableError(.runtime) }

        switch runtime {
        case .starting, .retrying: return .startingRuntime
        case .ready:
            if requireInitialInputSourceSelection, inputSourceStatus != .selected {
                return .needsInputSourceSelection
            }
            return .ready
        case .failed: return .recoverableError(.runtime)
        }
    }
}
