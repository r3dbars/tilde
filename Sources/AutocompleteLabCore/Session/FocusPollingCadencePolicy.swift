import Foundation

public struct FocusPollingCadencePolicy: Equatable, Sendable {
    public let activeSuggestionIntervalSeconds: TimeInterval
    public let supportedTypingWatchIntervalSeconds: TimeInterval
    public let recentTextChangeIntervalSeconds: TimeInterval
    public let recentTextChangeWindowSeconds: TimeInterval
    public let idleIntervalSeconds: TimeInterval
    public let untrustedIntervalSeconds: TimeInterval

    public init(
        activeSuggestionIntervalSeconds: TimeInterval = 0.05,
        supportedTypingWatchIntervalSeconds: TimeInterval = 0.12,
        recentTextChangeIntervalSeconds: TimeInterval = 0.20,
        recentTextChangeWindowSeconds: TimeInterval = 0.75,
        idleIntervalSeconds: TimeInterval = 0.25,
        untrustedIntervalSeconds: TimeInterval = 0.5
    ) {
        self.activeSuggestionIntervalSeconds = max(0.016, activeSuggestionIntervalSeconds)
        let supportedTypingWatchIntervalSeconds = max(0.05, supportedTypingWatchIntervalSeconds)
        self.supportedTypingWatchIntervalSeconds = supportedTypingWatchIntervalSeconds
        self.recentTextChangeIntervalSeconds = max(
            supportedTypingWatchIntervalSeconds,
            recentTextChangeIntervalSeconds
        )
        self.recentTextChangeWindowSeconds = max(0, recentTextChangeWindowSeconds)
        self.idleIntervalSeconds = max(0.1, idleIntervalSeconds)
        self.untrustedIntervalSeconds = max(0.25, untrustedIntervalSeconds)
    }

    public func interval(
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        hasVisibleSuggestion: Bool,
        hasRecentTextChange: Bool = false
    ) -> TimeInterval {
        guard isTrustedForAccessibility else {
            return untrustedIntervalSeconds
        }

        if hasVisibleSuggestion {
            return activeSuggestionIntervalSeconds
        }

        if hasSupportedProfile {
            return hasRecentTextChange
                ? recentTextChangeIntervalSeconds
                : supportedTypingWatchIntervalSeconds
        }

        return idleIntervalSeconds
    }

    public func hasRecentTextChange(lastTextChangeAt: Date?, now: Date) -> Bool {
        guard let lastTextChangeAt else {
            return false
        }

        let age = now.timeIntervalSince(lastTextChangeAt)
        return age >= 0 && age <= recentTextChangeWindowSeconds
    }

    public func shouldPoll(
        now: Date,
        lastPollAt: Date?,
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        hasVisibleSuggestion: Bool,
        hasRecentTextChange: Bool = false
    ) -> Bool {
        if let lastPollAt, now.timeIntervalSince(lastPollAt) < 0 {
            return true
        }

        guard let nextPollDate = nextPollDate(
            lastPollAt: lastPollAt,
            isTrustedForAccessibility: isTrustedForAccessibility,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: hasVisibleSuggestion,
            hasRecentTextChange: hasRecentTextChange
        ) else {
            return true
        }

        return now >= nextPollDate
    }

    public func nextPollDate(
        lastPollAt: Date?,
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        hasVisibleSuggestion: Bool,
        hasRecentTextChange: Bool = false
    ) -> Date? {
        guard let lastPollAt else {
            return nil
        }

        return lastPollAt.addingTimeInterval(interval(
            isTrustedForAccessibility: isTrustedForAccessibility,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: hasVisibleSuggestion,
            hasRecentTextChange: hasRecentTextChange
        ))
    }
}
