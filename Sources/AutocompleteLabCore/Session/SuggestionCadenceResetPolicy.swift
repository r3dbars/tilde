public struct SuggestionCadenceResetPolicy: Equatable, Sendable {
    public init() {}

    public func shouldResetLastRequestedText(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        selectedTextLength: Int
    ) -> Bool {
        if selectedTextLength > 0 {
            return true
        }

        guard let previousTextBeforeCursor else {
            return false
        }

        return currentTextBeforeCursor.count < previousTextBeforeCursor.count
    }
}
