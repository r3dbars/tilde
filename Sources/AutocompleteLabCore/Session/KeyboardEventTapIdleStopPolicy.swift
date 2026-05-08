import Foundation

public struct KeyboardEventTapIdleStopPolicy: Equatable, Sendable {
    public init() {}

    public func shouldStopKeyboardCapture(
        hasVisibleSuggestion: Bool,
        isSuggestionPanelVisible: Bool,
        hasPendingAcceptedInsertionUndo: Bool
    ) -> Bool {
        !hasVisibleSuggestion
            && !isSuggestionPanelVisible
            && !hasPendingAcceptedInsertionUndo
    }
}
