import Foundation

public struct CompletionOutputCleaner: Equatable, Sendable {
    public let minimumVisibleWords: Int
    public let maxVisibleWords: Int

    public init(
        minimumVisibleWords: Int = CompletionModelPolicy.minimumVisibleWords,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.minimumVisibleWords = max(1, minimumVisibleWords)
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
    }

    public func clean(_ rawOutput: String) -> CompletionSuggestion? {
        clean(rawOutput, after: nil)
    }

    public func clean(_ rawOutput: String, after textBeforeCursor: String?) -> CompletionSuggestion? {
        clean(rawOutput, after: textBeforeCursor, mode: .phraseContinuation)
    }

    public func clean(_ rawOutput: String, after textBeforeCursor: String?, mode: CompletionRequestMode) -> CompletionSuggestion? {
        let withoutThinking = rawOutput
            .replacingOccurrences(
                of: #"<think>[\s\S]*?</think>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"</?think>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))

        guard !withoutThinking.isEmpty else {
            return nil
        }

        let singleLine = withoutThinking
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !singleLine.isEmpty else {
            return nil
        }

        guard !looksLikeAssistantMeta(singleLine) else {
            return nil
        }

        guard !looksLikeGenericChatFiller(singleLine) else {
            return nil
        }

        let normalizedSuggestion = mode == .wordCompletion ? singleLine : ensureLeadingSpace(singleLine)
        let trimmedSuggestion: String
        if let textBeforeCursor {
            trimmedSuggestion = CompletionPrefixTrimmer.trim(normalizedSuggestion, after: textBeforeCursor)
        } else {
            trimmedSuggestion = normalizedSuggestion
        }

        guard !trimmedSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let textBeforeCursor,
           repeatsEarlierContext(trimmedSuggestion, after: textBeforeCursor) {
            return nil
        }

        let suggestion = CompletionSuggestion(text: trimmedSuggestion, maxVisibleWords: maxVisibleWords)
        guard mode == .wordCompletion || suggestion.visibleWordCount >= minimumVisibleWords else {
            return nil
        }

        if mode == .wordCompletion,
           !isValidWordCompletion(suggestion.visibleText) {
            return nil
        }

        if mode == .phraseContinuation,
           isLowValueSingleWordPhrase(suggestion.visibleText) {
            return nil
        }

        if mode == .phraseContinuation,
           isLowSignalPhrase(suggestion.visibleText) {
            return nil
        }

        return suggestion
    }

    private func looksLikeAssistantMeta(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("okay, let's see")
            || normalized.hasPrefix("let's see")
            || normalized.hasPrefix("the user ")
            || normalized.hasPrefix("the user is ")
            || normalized.hasPrefix("user is ")
            || normalized.hasPrefix("assistant:")
            || normalized.hasPrefix("system:")
    }

    private func looksLikeGenericChatFiller(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("that makes a lot of sense")
            || normalized.hasPrefix("i would like to")
            || normalized.hasPrefix("i will do that")
            || normalized.hasPrefix("i'll do that")
            || normalized.hasPrefix("let me know")
            || normalized.hasPrefix("okay, i would")
            || normalized.hasPrefix("okay, would")
            || normalized.hasPrefix("integrate it seamlessly")
            || normalized.hasPrefix("enhance the experience")
            || normalized.hasPrefix("leverage the system")
            || normalized.hasPrefix("sure,")
            || normalized.hasPrefix("certainly,")
    }

    private func ensureLeadingSpace(_ text: String) -> String {
        guard let first = text.first, !first.isWhitespace else {
            return text
        }

        return " " + text
    }

    private func isValidWordCompletion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }) else {
            return false
        }

        return trimmed.contains(where: { $0.isLetter })
    }

    private func isLowValueSingleWordPhrase(_ text: String) -> Bool {
        let words = normalizedWords(in: text)
        guard words.count == 1,
              let word = words.first else {
            return false
        }

        return Self.lowValueSingleWordPhrases.contains(word)
    }

    private func isLowSignalPhrase(_ text: String) -> Bool {
        let words = normalizedWords(in: text)
        guard words.count >= 2 else {
            return false
        }

        if Self.lowSignalPhraseStarters.contains(Array(words.prefix(2)).joined(separator: " ")) {
            return true
        }

        return words.allSatisfy { Self.lowSignalWords.contains($0) }
    }

    private func repeatsEarlierContext(_ suggestion: String, after textBeforeCursor: String) -> Bool {
        let suggestionWords = normalizedWords(in: suggestion)
        guard suggestionWords.count >= 3 else {
            return false
        }

        let contextWords = normalizedWords(in: textBeforeCursor)
        guard contextWords.count >= 4 else {
            return false
        }

        let leadPhrase = Array(suggestionWords.prefix(3))
        if Array(contextWords.suffix(min(leadPhrase.count, contextWords.count))) == leadPhrase {
            return false
        }

        return contextWords.windows(ofCount: leadPhrase.count).contains(leadPhrase)
    }

    private func normalizedWords(in text: String) -> [String] {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .map {
                $0.trimmingCharacters(in: .punctuationCharacters).lowercased()
            }
            .filter { !$0.isEmpty }
    }

    private static let lowValueSingleWordPhrases: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "but", "for", "if",
        "in", "is", "it", "of", "on", "or", "so", "the", "to", "was",
        "were", "with"
    ]

    private static let lowSignalWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "being", "but",
        "by", "can", "could", "do", "does", "for", "from", "had", "has",
        "have", "he", "her", "here", "him", "his", "i", "if", "in", "is",
        "it", "its", "just", "may", "maybe", "might", "of", "on", "or",
        "our", "probably", "really", "she", "should", "so", "some", "that",
        "the", "their", "there", "they", "this", "to", "very", "was", "we",
        "were", "will", "with", "would", "you", "your"
    ]

    private static let lowSignalPhraseStarters: Set<String> = [
        "i guess",
        "i think",
        "it would",
        "kind of",
        "sort of",
        "there are",
        "there is"
    ]
}

private extension Array where Element: Equatable {
    func windows(ofCount count: Int) -> [[Element]] {
        guard count > 0, self.count >= count else {
            return []
        }

        return indices.dropLast(count - 1).map { index in
            Array(self[index..<self.index(index, offsetBy: count)])
        }
    }
}
