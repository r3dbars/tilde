import Foundation

public enum ClipboardFallbackBlockReason: String, Equatable, Sendable {
    case runtimeDisabled
    case sensitiveProfile
    case profileNotOptedIn
}

public enum ClipboardFallbackDecision: Equatable, Sendable {
    case allowed
    case blocked(ClipboardFallbackBlockReason)

    public var message: String {
        switch self {
        case .allowed:
            return "Clipboard fallback is explicitly enabled for this profile."
        case let .blocked(reason):
            switch reason {
            case .runtimeDisabled:
                return "AX insertion failed and clipboard fallback is disabled."
            case .sensitiveProfile:
                return "Clipboard fallback is blocked for sensitive profiles."
            case .profileNotOptedIn:
                return "Clipboard fallback is blocked because this profile did not opt in."
            }
        }
    }
}

public struct ClipboardFallbackPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        profile: CompatibilityProfile,
        runtimeEnabled: Bool
    ) -> ClipboardFallbackDecision {
        guard runtimeEnabled else {
            return .blocked(.runtimeDisabled)
        }

        guard !profile.isSensitive else {
            return .blocked(.sensitiveProfile)
        }

        guard profile.insertionMode == .clipboardFallbackOptIn
            || profile.fallbackInsertionMode == .clipboardFallbackOptIn else {
            return .blocked(.profileNotOptedIn)
        }

        return .allowed
    }
}
