import Foundation

public struct KeyboardCapturePolicy: Equatable, Sendable {
    public init() {}

    public func shouldCaptureKeys(
        isTrustedForAccessibility: Bool,
        hasVisibleSuggestion: Bool,
        controlState: SuggestionControlState = .running
    ) -> Bool {
        isTrustedForAccessibility
            && hasVisibleSuggestion
            && controlState == .running
    }
}
