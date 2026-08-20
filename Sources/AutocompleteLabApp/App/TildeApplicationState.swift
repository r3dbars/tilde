import Foundation

enum TildeApplicationState: Equatable {
    case needsKeyboard
    case needsPermission
    case preparingModel
    case ready
    case paused(until: Date)
    case disabled
    case recoverableError

    static func resolve(
        suggestionsEnabled: Bool,
        pausedUntil: Date?,
        keyboardAvailable: Bool,
        screenMemoryEnabled: Bool,
        screenRecordingGranted: Bool,
        runtime: LlamaRuntimeSnapshot,
        socketAvailable: Bool,
        now: Date = Date()
    ) -> Self {
        guard suggestionsEnabled, screenMemoryEnabled else { return .disabled }
        if let pausedUntil, pausedUntil > now { return .paused(until: pausedUntil) }
        guard keyboardAvailable else { return .needsKeyboard }
        guard screenRecordingGranted else { return .needsPermission }
        guard socketAvailable else { return .recoverableError }

        switch runtime {
        case .starting, .retrying:
            return .preparingModel
        case .ready:
            return .ready
        case .failed:
            return .recoverableError
        }
    }

    var statusText: String {
        switch self {
        case .needsKeyboard: "Finish Setup"
        case .needsPermission: "Permission Required"
        case .preparingModel: "Model is Loading"
        case .ready: "Tilde is Ready"
        case .paused, .disabled: "Tilde is Paused"
        case .recoverableError: "Tilde Needs Attention"
        }
    }

    var iconAppearance: TildeMenuIconAppearance {
        switch self {
        case .ready: .normal
        case .paused, .disabled: .dimmed
        case .needsKeyboard, .needsPermission, .preparingModel, .recoverableError: .warning
        }
    }
}

enum TildeMenuIconAppearance: Equatable {
    case normal
    case dimmed
    case warning
}
