import Foundation

public struct FocusPollingCadencePolicy: Equatable, Sendable {
    public let activeSuggestionIntervalSeconds: TimeInterval
    public let supportedTypingWatchIntervalSeconds: TimeInterval
    public let idleIntervalSeconds: TimeInterval
    public let untrustedIntervalSeconds: TimeInterval

    public init(
        activeSuggestionIntervalSeconds: TimeInterval = 0.033,
        supportedTypingWatchIntervalSeconds: TimeInterval = 0.12,
        idleIntervalSeconds: TimeInterval = 0.25,
        untrustedIntervalSeconds: TimeInterval = 0.5
    ) {
        self.activeSuggestionIntervalSeconds = max(0.016, activeSuggestionIntervalSeconds)
        self.supportedTypingWatchIntervalSeconds = max(0.05, supportedTypingWatchIntervalSeconds)
        self.idleIntervalSeconds = max(0.1, idleIntervalSeconds)
        self.untrustedIntervalSeconds = max(0.25, untrustedIntervalSeconds)
    }

    public func interval(
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        hasVisibleSuggestion: Bool
    ) -> TimeInterval {
        guard isTrustedForAccessibility else {
            return untrustedIntervalSeconds
        }

        if hasVisibleSuggestion {
            return activeSuggestionIntervalSeconds
        }

        if hasSupportedProfile {
            return supportedTypingWatchIntervalSeconds
        }

        return idleIntervalSeconds
    }
}
