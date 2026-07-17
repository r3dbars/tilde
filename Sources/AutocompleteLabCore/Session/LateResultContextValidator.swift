public enum LateResultContextInvalidationReason: String, Equatable, Sendable {
    case fieldChanged
    case baselineChanged
    case suffixChanged
}

public enum LateResultContextValidation: Equatable, Sendable {
    case stillValid(typedSinceRequest: String)
    case invalid(LateResultContextInvalidationReason)
}

/// Revalidates model output against the focused text state that exists when it returns.
///
/// Latency alone does not make a completion stale. A result remains usable while focus is
/// still in the same field and the current text extends the text that issued the request.
public struct LateResultContextValidator: Equatable, Sendable {
    public init() {}

    public func validate(
        requestSnapshot: FocusedTextSnapshot,
        currentSnapshot: FocusedTextSnapshot
    ) -> LateResultContextValidation {
        guard currentSnapshot.fieldIdentity == requestSnapshot.fieldIdentity else {
            return .invalid(.fieldChanged)
        }

        guard currentSnapshot.textBeforeCursor.hasPrefix(requestSnapshot.textBeforeCursor) else {
            return .invalid(.baselineChanged)
        }

        guard currentSnapshot.textAfterCursor == requestSnapshot.textAfterCursor else {
            return .invalid(.suffixChanged)
        }

        return .stillValid(typedSinceRequest: String(
            currentSnapshot.textBeforeCursor.dropFirst(requestSnapshot.textBeforeCursor.count)
        ))
    }

    /// Removes text the user already typed while the model was working.
    ///
    /// A non-matching delta means the completion no longer follows the user's text. An empty
    /// remainder means the user already typed the whole suggestion, so there is nothing to show.
    public func trimmedSuggestion(
        _ suggestion: CompletionSuggestion,
        typedSinceRequest: String
    ) -> CompletionSuggestion? {
        guard let remaining = suggestion.remainingTextAfterTypeThroughPrefix(typedSinceRequest),
              !remaining.isEmpty else {
            return nil
        }

        return CompletionSuggestion(
            text: String(remaining),
            maxVisibleWords: suggestion.maxVisibleWords,
            maxVisibleCharacters: suggestion.maxVisibleCharacters
        )
    }
}
