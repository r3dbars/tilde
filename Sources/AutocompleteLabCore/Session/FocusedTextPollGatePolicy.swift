import Foundation

public enum FocusedTextPollGateDecision: Equatable, Sendable {
    case startPoll
    case waitForCadence
    case skipInFlight
}

public struct FocusedTextPollGatePolicy: Equatable, Sendable {
    public var cadencePolicy: FocusPollingCadencePolicy

    public init(cadencePolicy: FocusPollingCadencePolicy = FocusPollingCadencePolicy()) {
        self.cadencePolicy = cadencePolicy
    }

    public func decision(
        now: Date,
        lastPollAt: Date?,
        isPollInFlight: Bool,
        isTrustedForAccessibility: Bool,
        hasSupportedProfile: Bool,
        hasVisibleSuggestion: Bool
    ) -> FocusedTextPollGateDecision {
        guard cadencePolicy.shouldPoll(
            now: now,
            lastPollAt: lastPollAt,
            isTrustedForAccessibility: isTrustedForAccessibility,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: hasVisibleSuggestion
        ) else {
            return .waitForCadence
        }

        return isPollInFlight ? .skipInFlight : .startPoll
    }
}
