import Foundation

public enum CompletionPrefixTrimmer {
    public static func trim(_ suggestion: String, after textBeforeCursor: String) -> String {
        guard !suggestion.isEmpty else {
            return suggestion
        }

        if let overlapTrimmed = trimOverlappingLeadingWords(suggestion, after: textBeforeCursor) {
            return overlapTrimmed
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

    private static func trimOverlappingLeadingWords(_ suggestion: String, after textBeforeCursor: String) -> String? {
        let typedWords = normalizedWords(in: textBeforeCursor)
        let suggestionWords = wordRanges(in: suggestion)

        guard !typedWords.isEmpty, !suggestionWords.isEmpty else {
            return nil
        }

        let normalizedSuggestionWords = suggestionWords.map { normalized(String(suggestion[$0])) }
        let maximumOverlap = min(typedWords.count, normalizedSuggestionWords.count)

        for overlap in stride(from: maximumOverlap, through: 1, by: -1) {
            let typedSuffix = Array(typedWords.suffix(overlap))
            let suggestionPrefix = Array(normalizedSuggestionWords.prefix(overlap))

            guard typedSuffix == suggestionPrefix else {
                continue
            }

            if overlap >= suggestionWords.count {
                return ""
            }

            let nextStart = suggestionWords[overlap].lowerBound
            return formattedRemainingSuggestion(String(suggestion[nextStart...]), after: textBeforeCursor)
        }

        return nil
    }

    private static func formattedRemainingSuggestion(_ suggestion: String, after textBeforeCursor: String) -> String {
        guard textBeforeCursor.last?.isWhitespace != true,
              suggestion.first?.isWhitespace != true else {
            return suggestion
        }

        return " " + suggestion
    }

    private static func trailingWordFragment(in text: String) -> String? {
        text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    private static func normalizedWords(in text: String) -> [String] {
        wordRanges(in: text)
            .map { normalized(String(text[$0])) }
            .filter { !$0.isEmpty }
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var wordStart: String.Index?

        for index in text.indices {
            if text[index].isWhitespace {
                if let start = wordStart {
                    ranges.append(start..<index)
                    wordStart = nil
                }
            } else if wordStart == nil {
                wordStart = index
            }
        }

        if let start = wordStart {
            ranges.append(start..<text.endIndex)
        }

        return ranges
    }

    private static func normalized(_ word: String) -> String {
        word
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }
}
