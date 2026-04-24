import Foundation

public enum CompletionPrefixTrimmer {
    public static func trim(_ suggestion: String, after textBeforeCursor: String) -> String {
        guard !suggestion.isEmpty else {
            return suggestion
        }

        if let trimmedFullPrefix = trimFullPrefix(suggestion, after: textBeforeCursor) {
            return trimmedFullPrefix
        }

        if textBeforeCursor.last?.isWhitespace == true {
            return String(suggestion.drop(while: { $0.isWhitespace }))
        }

        guard let typedFragment = trailingWordFragment(in: textBeforeCursor),
              !typedFragment.isEmpty else {
            return suggestion
        }

        let suggestionBody = suggestion.drop(while: { $0.isWhitespace })
        if repeatsBeginningOfContext(suggestionBody, textBeforeCursor: textBeforeCursor) {
            return ""
        }

        let suggestedWords = wordRanges(in: suggestionBody)
        guard let firstSuggestedWord = suggestedWords.first else {
            return suggestion
        }
        let normalizedTypedFragment = normalized(typedFragment)

        if normalized(String(firstSuggestedWord.word)).hasPrefix(normalizedTypedFragment) {
            return completionSuffix(
                in: suggestionBody,
                wordRange: firstSuggestedWord.range,
                typedFragment: typedFragment
            )
        }

        if looksLikeUnfinishedFragment(typedFragment),
           let laterMatchingWord = suggestedWords.prefix(4).first(where: {
               normalized(String($0.word)).hasPrefix(normalizedTypedFragment)
           }) {
            return completionSuffix(
                in: suggestionBody,
                wordRange: laterMatchingWord.range,
                typedFragment: typedFragment
            )
        }

        if looksLikeUnfinishedFragment(typedFragment) {
            return ""
        }

        return suggestion
    }

    private static func trimFullPrefix(_ suggestion: String, after textBeforeCursor: String) -> String? {
        let typedContext = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typedContext.isEmpty else {
            return nil
        }

        let suggestionBody = suggestion.drop(while: { $0.isWhitespace })
        guard suggestionBody.lowercased().hasPrefix(typedContext.lowercased()) else {
            return nil
        }

        let remainderStart = suggestionBody.index(suggestionBody.startIndex, offsetBy: typedContext.count)
        let remainder = suggestionBody[remainderStart...]

        if textBeforeCursor.last?.isWhitespace == true {
            return String(remainder.drop(while: { $0.isWhitespace }))
        }

        return String(remainder)
    }

    private static func trailingWordFragment(in text: String) -> String? {
        text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    private static func looksLikeUnfinishedFragment(_ fragment: String) -> Bool {
        let normalizedFragment = normalized(fragment)
        guard normalizedFragment.count >= 2, normalizedFragment.count <= 4 else {
            return false
        }

        let commonCompleteShortWords: Set<String> = [
            "a", "all", "an", "and", "any", "are", "as", "at", "be", "but",
            "by", "can", "did", "do", "for", "get", "go", "had", "has", "he",
            "her", "hey", "hi", "his", "how", "i", "if", "in", "is", "it",
            "like", "make", "me", "my", "need", "new", "no", "not", "now",
            "of", "on", "one", "or", "our", "out", "plan", "see", "she",
            "so", "that", "the", "then", "this", "to", "too", "up", "us",
            "want", "was", "we", "what", "when", "who", "why", "will",
            "with", "work", "yes", "yet", "you"
        ]

        return !commonCompleteShortWords.contains(normalizedFragment)
    }

    private static func repeatsBeginningOfContext(
        _ suggestionBody: Substring,
        textBeforeCursor: String
    ) -> Bool {
        let normalizedSuggestion = normalizedPhrase(String(suggestionBody))
        let normalizedContext = normalizedPhrase(textBeforeCursor)

        guard normalizedSuggestion.count >= 6,
              normalizedContext.count > normalizedSuggestion.count,
              normalizedContext.hasPrefix(normalizedSuggestion) else {
            return false
        }

        return !normalizedContext.hasSuffix(normalizedSuggestion)
    }

    private static func wordRanges(in text: Substring) -> [(word: Substring, range: Range<String.Index>)] {
        var ranges: [(word: Substring, range: Range<String.Index>)] = []
        var index = text.startIndex

        while index < text.endIndex {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }

            guard index < text.endIndex else {
                break
            }

            let wordStart = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }

            let range = wordStart..<index
            ranges.append((word: text[range], range: range))
        }

        return ranges
    }

    private static func completionSuffix(
        in text: Substring,
        wordRange: Range<String.Index>,
        typedFragment: String
    ) -> String {
        let overlapCount = typedFragment.count
        if overlapCount >= text[wordRange].count {
            return String(text[wordRange.upperBound...])
        }

        let suffixStart = text.index(wordRange.lowerBound, offsetBy: overlapCount, limitedBy: wordRange.upperBound)
            ?? wordRange.upperBound
        return String(text[suffixStart...])
    }

    private static func normalized(_ word: String) -> String {
        word
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }

    private static func normalizedPhrase(_ text: String) -> String {
        var normalized = ""
        for character in text.lowercased() {
            normalized.append(character.isLetter || character.isNumber ? character : " ")
        }

        return normalized
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .joined(separator: " ")
    }
}
