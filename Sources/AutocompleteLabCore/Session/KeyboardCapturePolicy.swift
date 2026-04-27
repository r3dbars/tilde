import Foundation

public struct KeyboardCapturePolicy: Equatable, Sendable {
    public init() {}

    public func shouldCaptureKeys(
        isTrustedForAccessibility: Bool,
        hasVisibleSuggestion: Bool
    ) -> Bool {
        isTrustedForAccessibility && hasVisibleSuggestion
    }
}
