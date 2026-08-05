/// Keeps Tilde quiet until the writer has supplied enough intent in the
/// current editing session to ground a useful suggestion.
public enum SuggestionActivationPolicy {
    public static let minimumTypedCharacters = 3

    public static func allowsSuggestions(afterUserTyped text: String) -> Bool {
        var meaningfulCharacters = 0
        for character in text where character.isLetter || character.isNumber {
            meaningfulCharacters += 1
            if meaningfulCharacters >= minimumTypedCharacters {
                return true
            }
        }
        return false
    }
}

/// Fail closed at the start of a field. When a client cannot expose even its
/// first character, treating a location-zero field as blank is calmer and safer
/// than carrying context over from the previously focused field.
public enum BlankFieldSuggestionPolicy {
    public static func shouldSuppress(
        selectionLocation: Int,
        firstCharacterAtCursor: String?
    ) -> Bool {
        selectionLocation == 0 && (firstCharacterAtCursor?.isEmpty ?? true)
    }
}
