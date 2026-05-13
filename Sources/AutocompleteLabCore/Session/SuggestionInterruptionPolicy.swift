import Foundation

public enum SuggestionInterruptionKind: String, CaseIterable, Equatable, Sendable {
    case accessibilityPermissionLost = "accessibility-permission-lost"
    case systemWillSleep = "system-will-sleep"
    case systemDidWake = "system-did-wake"
    case displaysDidSleep = "displays-did-sleep"
    case displaysDidWake = "displays-did-wake"
    case screenGeometryChanged = "screen-geometry-changed"
}

public struct SuggestionInterruptionDecision: Equatable, Sendable {
    public let shouldInvalidatePendingRequest: Bool
    public let shouldClearFocusedField: Bool
    public let shouldStopKeyboardCapture: Bool
    public let shouldHideFieldStatus: Bool
    public let hideReason: String
    public let keyboardCaptureStopReason: String
    public let decisionText: String
    public let diagnosticEvent: String
    public let diagnosticMetadata: [String: String]

    public init(
        shouldInvalidatePendingRequest: Bool,
        shouldClearFocusedField: Bool,
        shouldStopKeyboardCapture: Bool,
        shouldHideFieldStatus: Bool,
        hideReason: String,
        keyboardCaptureStopReason: String,
        decisionText: String,
        diagnosticEvent: String,
        diagnosticMetadata: [String: String]
    ) {
        self.shouldInvalidatePendingRequest = shouldInvalidatePendingRequest
        self.shouldClearFocusedField = shouldClearFocusedField
        self.shouldStopKeyboardCapture = shouldStopKeyboardCapture
        self.shouldHideFieldStatus = shouldHideFieldStatus
        self.hideReason = hideReason
        self.keyboardCaptureStopReason = keyboardCaptureStopReason
        self.decisionText = decisionText
        self.diagnosticEvent = diagnosticEvent
        self.diagnosticMetadata = diagnosticMetadata
    }
}

public struct SuggestionInterruptionPolicy: Equatable, Sendable {
    public init() {}

    public func decision(for kind: SuggestionInterruptionKind) -> SuggestionInterruptionDecision {
        let shouldClearFocusedField = kind != .screenGeometryChanged
        let event = diagnosticEvent(for: kind)
        let reason = kind.rawValue

        return SuggestionInterruptionDecision(
            shouldInvalidatePendingRequest: true,
            shouldClearFocusedField: shouldClearFocusedField,
            shouldStopKeyboardCapture: true,
            shouldHideFieldStatus: true,
            hideReason: reason,
            keyboardCaptureStopReason: reason,
            decisionText: decisionText(for: kind),
            diagnosticEvent: event,
            diagnosticMetadata: [
                "reason": reason,
                "diagnosticLayer": "suggestionInterruption",
                "safetyFailure": "true"
            ]
        )
    }

    private func diagnosticEvent(for kind: SuggestionInterruptionKind) -> String {
        switch kind {
        case .accessibilityPermissionLost:
            return "accessibility-permission-lost"
        case .systemWillSleep, .systemDidWake, .displaysDidSleep, .displaysDidWake:
            return "workspace-lifecycle-interrupted"
        case .screenGeometryChanged:
            return "screen-geometry-changed"
        }
    }

    private func decisionText(for kind: SuggestionInterruptionKind) -> String {
        switch kind {
        case .accessibilityPermissionLost:
            return "Blocked: Accessibility permission missing"
        case .systemWillSleep:
            return "Blocked: Mac is going to sleep"
        case .systemDidWake:
            return "Blocked: wake refresh required"
        case .displaysDidSleep:
            return "Blocked: display sleep"
        case .displaysDidWake:
            return "Blocked: display wake refresh required"
        case .screenGeometryChanged:
            return "Blocked: screen layout changed"
        }
    }
}
