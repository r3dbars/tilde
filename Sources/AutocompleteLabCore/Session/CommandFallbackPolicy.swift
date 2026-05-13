import Foundation

public enum CommandFallbackAvailability: String, Equatable, Sendable {
    case inlineAvailable = "inline-available"
    case copyOnly = "copy-only"
    case unavailable
}

public enum CommandFallbackReason: String, Equatable, Sendable {
    case noCurrentApp = "no-current-app"
    case inlineAvailable = "inline-available"
    case appDisabled = "app-disabled"
    case sensitiveApp = "sensitive-app"
    case sensitiveField = "sensitive-field"
    case unsupportedApp = "unsupported-app"
    case denylistedApp = "denylisted-app"
    case diagnosticsOnlyProfile = "diagnostics-only-profile"
    case untrustedPlacement = "untrusted-placement"
    case unsupportedProfile = "unsupported-profile"
}

public struct CommandFallbackDecision: Equatable, Sendable {
    public let availability: CommandFallbackAvailability
    public let reason: CommandFallbackReason

    public init(
        availability: CommandFallbackAvailability,
        reason: CommandFallbackReason
    ) {
        self.availability = availability
        self.reason = reason
    }

    public var canCopyOnly: Bool {
        availability == .copyOnly
    }

    public var statusText: String {
        switch availability {
        case .inlineAvailable:
            return "Fallback: not needed; cursor placement is available."
        case .copyOnly:
            return "Fallback: copy-only; cursor placement and auto-insert stay off until testing passes."
        case .unavailable:
            switch reason {
            case .noCurrentApp:
                return "Fallback: choose a writing app first."
            case .appDisabled:
                return "Fallback: off while this app is paused."
            case .sensitiveApp, .sensitiveField, .denylistedApp:
                return "Fallback: unavailable in sensitive apps or fields."
            case .unsupportedApp:
                return "Fallback: unavailable until this app has a profile."
            case .diagnosticsOnlyProfile, .untrustedPlacement, .unsupportedProfile:
                return "Fallback: unavailable here."
            case .inlineAvailable:
                return "Fallback: not needed; cursor placement is available."
            }
        }
    }

    public var detailText: String {
        switch reason {
        case .noCurrentApp:
            return "No text is read until a current writing app is selected."
        case .inlineAvailable:
            return "Use the normal cursor-placement path; the fallback stays out of the typing loop."
        case .appDisabled:
            return "The user's app pause wins over fallback helpers."
        case .sensitiveApp:
            return "Autocomplete stays quiet and does not offer copy helpers in sensitive app profiles."
        case .sensitiveField:
            return "Autocomplete stays quiet and does not offer copy helpers in secure, form, URL, or search fields."
        case .unsupportedApp:
            return "Unsupported apps should feel intentionally off, not broken."
        case .denylistedApp:
            return "Denylisted apps stay fully unavailable."
        case .diagnosticsOnlyProfile:
            return "A non-sensitive diagnostics-only profile can use explicit copy-only fallback, but never automatic insert."
        case .untrustedPlacement:
            return "When placement is untrusted, the app can fall back to copy-only instead of showing detached ghost text."
        case .unsupportedProfile:
            return "This profile has no safe cursor-placement or copy-only fallback."
        }
    }
}

public struct CommandFallbackPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        supportStatus: CompatibilitySupportStatus,
        isEnabled: Bool,
        fieldKind: AXFieldKind? = nil,
        allowsLowConfidencePlacement: Bool? = nil,
        hasCurrentApp: Bool = true
    ) -> CommandFallbackDecision {
        guard hasCurrentApp else {
            return CommandFallbackDecision(availability: .unavailable, reason: .noCurrentApp)
        }

        if fieldKind?.suppressesSuggestionsByDefault == true {
            return CommandFallbackDecision(availability: .unavailable, reason: .sensitiveField)
        }

        switch supportStatus {
        case .denylisted:
            return CommandFallbackDecision(availability: .unavailable, reason: .denylistedApp)
        case .unsupported:
            return CommandFallbackDecision(availability: .unavailable, reason: .unsupportedApp)
        case let .supported(profile):
            if profile.isSensitive {
                return CommandFallbackDecision(availability: .unavailable, reason: .sensitiveApp)
            }

            guard isEnabled else {
                return CommandFallbackDecision(availability: .unavailable, reason: .appDisabled)
            }

            if profile.canPresentSuggestions {
                if allowsLowConfidencePlacement == false,
                   profile.allowsCopyOnlyCommandFallback {
                    return CommandFallbackDecision(availability: .copyOnly, reason: .untrustedPlacement)
                }

                return CommandFallbackDecision(availability: .inlineAvailable, reason: .inlineAvailable)
            }

            if profile.allowsCopyOnlyCommandFallback {
                return CommandFallbackDecision(availability: .copyOnly, reason: .diagnosticsOnlyProfile)
            }

            return CommandFallbackDecision(availability: .unavailable, reason: .unsupportedProfile)
        }
    }
}
