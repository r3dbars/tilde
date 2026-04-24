import Foundation

public enum CompletionPrefixTrimmer {
    public static func trim(_ suggestion: String, after textBeforeCursor: String) -> String {
        guard !suggestion.isEmpty else {
            return suggestion
        }

        if textBeforeCursor.last?.isWhitespace == true {
            return String(suggestion.drop(while: { $0.isWhitespace }))
        }

        guard let typedFragment = trailingWordFragment(in: textBeforeCursor),
              !typedFragment.isEmpty else {
            return suggestion
        }

        let suggestionBody = suggestion.drop(while: { $0.isWhitespace })
        let firstSuggestedWord = suggestionBody.prefix(while: { !$0.isWhitespace })

        guard !firstSuggestedWord.isEmpty,
              normalized(String(firstSuggestedWord)).hasPrefix(normalized(typedFragment)) else {
            return suggestion
        }

        let overlapCount = typedFragment.count
        if overlapCount >= firstSuggestedWord.count {
            return String(suggestionBody.dropFirst(firstSuggestedWord.count))
        }

        return String(suggestionBody.dropFirst(overlapCount))
    }

    private static func trailingWordFragment(in text: String) -> String? {
        text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    private static func normalized(_ word: String) -> String {
        word
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }
}
