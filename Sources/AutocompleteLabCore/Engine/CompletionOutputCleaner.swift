import Foundation

public enum CompletionCleanRejectionReason: String, Sendable {
    case unsafeHiddenOrControlCharacter
    case emptyOutput
    case noSuggestionSentinel
    case promptInstructionEcho
    case emptyAfterPrefixTrimming
    case replaysContext
}

public enum CompletionCleanResult: Sendable {
    case accepted(CompletionSuggestion)
    case rejected(CompletionCleanRejectionReason)

    public var suggestion: CompletionSuggestion? {
        guard case let .accepted(suggestion) = self else { return nil }
        return suggestion
    }

    public var rejectionReason: CompletionCleanRejectionReason? {
        guard case let .rejected(reason) = self else { return nil }
        return reason
    }
}

public struct CompletionOutputCleaner: Sendable {
    private static let noSuggestion = "<no_suggestion>"
    private static let wrappers = CharacterSet(charactersIn: "\"'`")
    private static let unsafeScalars: Set<Unicode.Scalar> = [
        "\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}", "\u{FEFF}",
    ]
    private static let instructionPrefixes = [
        "the following are real chat messages being written by their authors",
        "the following are real emails being written by their authors",
        "the following are real documents being written by their authors",
        "system:", "assistant:",
        "thinking process", "analyze the request", "okay, let's see", "okay, the user",
    ]
    private static let refusalMarkers = [
        "i cannot assist", "i can't assist", "cannot help with that",
    ]

    private let maxVisibleWords: Int

    public init(maxVisibleWords: Int = CompletionSuggestion.defaultMaxVisibleWords) {
        self.maxVisibleWords = CompletionSuggestion.clampedVisibleWords(maxVisibleWords)
    }

    public func clean(
        _ rawOutput: String,
        after textBeforeCursor: String?
    ) -> CompletionSuggestion? {
        cleanWithReason(rawOutput, after: textBeforeCursor).suggestion
    }

    public func cleanWithReason(
        _ rawOutput: String,
        after textBeforeCursor: String?
    ) -> CompletionCleanResult {
        guard !containsUnsafeCharacter(rawOutput) else {
            return .rejected(.unsafeHiddenOrControlCharacter)
        }

        var candidate = rawOutput
            .replacingOccurrences(of: #"(?is)<think>.*?</think>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</?think>"#, with: "", options: .regularExpression)
            .components(separatedBy: .newlines)[0]
        candidate = unwrapped(candidate)

        guard !candidate.isEmpty else { return .rejected(.emptyOutput) }
        guard !isNoSuggestion(candidate) else { return .rejected(.noSuggestionSentinel) }

        candidate = unwrapped(strippingAnswerLabel(from: candidate))
        guard !candidate.isEmpty else { return .rejected(.emptyOutput) }
        guard !isNoSuggestion(candidate) else { return .rejected(.noSuggestionSentinel) }
        guard !isInstructionLeak(candidate) else { return .rejected(.promptInstructionEcho) }

        var continuation = candidate.first?.isWhitespace == true ? candidate : " " + candidate
        if let textBeforeCursor {
            continuation = trimTypedPrefix(continuation, after: textBeforeCursor)
        }
        guard !continuation.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .rejected(.emptyAfterPrefixTrimming)
        }
        if let textBeforeCursor, replaysContext(continuation, context: textBeforeCursor) {
            return .rejected(.replaysContext)
        }

        return .accepted(CompletionSuggestion(text: continuation, maxVisibleWords: maxVisibleWords))
    }

    private func unwrapped(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: Self.wrappers)
    }

    private func isNoSuggestion(_ text: String) -> Bool {
        unwrapped(text).lowercased() == Self.noSuggestion
    }

    private func strippingAnswerLabel(from text: String) -> String {
        text.replacingOccurrences(
            of: #"^(?:candidate\s+\d+\s*[\).:-]\s*|(?:next words?|continuation|completion|suggestion|suffix)\s*:\s*)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func isInstructionLeak(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.range(
            of: #"^(?:(?:i(?:['’]m| am) sorry,\s*(?:but\s+)?)as (?:an ai(?: assistant| chatbot| language model)?|a language model)\b|as (?:an ai(?: assistant| chatbot| language model)?|a language model)\b[,\s]+(?:i|my)\b|i(?:['’]m| am) (?:an ai(?: assistant| chatbot| language model)?|a language model)\b)"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"^(?:candidate\s+\d+|next(?:\s+\d+-\d+)? words?|continuation|completion|suggestion|suffix)\s*:?(?:,\s*or\s*<no_suggestion>)?$"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return Self.instructionPrefixes.contains(where: normalized.hasPrefix)
            || Self.refusalMarkers.contains(where: normalized.contains)
    }

    private func containsUnsafeCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            Self.unsafeScalars.contains(scalar)
                || (scalar != "\n" && scalar != "\r" && CharacterSet.controlCharacters.contains(scalar))
        }
    }

    private func trimTypedPrefix(_ suggestion: String, after context: String) -> String {
        if context.last?.isWhitespace == true {
            return String(suggestion.drop(while: \.isWhitespace))
        }
        // A punctuation-only trailing token has no fragment. Treating its
        // normalized empty string as a prefix used to drop the first character.
        guard context.last?.isLetter == true else { return suggestion }

        let contextWords = normalizedWords(in: context)
        let suggestionRanges = wordRanges(in: suggestion)
        let suggestionWords = suggestionRanges.map { normalized(String(suggestion[$0])) }
        guard !contextWords.isEmpty, !suggestionWords.isEmpty else { return suggestion }

        for count in stride(from: min(contextWords.count, suggestionWords.count), through: 1, by: -1) {
            let typed = Array(contextWords.suffix(count))
            let offered = Array(suggestionWords.prefix(count))
            if typed == offered {
                guard count < suggestionRanges.count else { return "" }
                return " " + suggestion[suggestionRanges[count].lowerBound...]
            }

            guard typed.dropLast() == offered.dropLast(),
                  let typedLast = typed.last,
                  let offeredLast = offered.last,
                  !typedLast.isEmpty,
                  offeredLast.hasPrefix(typedLast),
                  typedLast.count < offeredLast.count else { continue }
            let range = suggestionRanges[count - 1]
            guard let start = suggestion.index(
                range.lowerBound,
                offsetBy: typedLast.count,
                limitedBy: range.upperBound
            ) else { continue }
            return String(suggestion[start...])
        }
        return suggestion
    }

    private func replaysContext(_ suggestion: String, context: String) -> Bool {
        let offered = normalizedWords(in: suggestion)
        let typed = normalizedWords(in: context)
        guard offered.count >= 3, typed.count >= 3 else { return false }

        for size in stride(from: min(4, offered.count), through: 3, by: -1) {
            if contains(Array(offered.prefix(size)), in: typed) { return true }
        }
        guard offered.count >= 4 else { return false }
        return offered.indices.dropLast(3).contains { index in
            contains(Array(offered[index..<offered.index(index, offsetBy: 4)]), in: typed)
        }
    }

    private func contains(_ needle: [String], in words: [String]) -> Bool {
        guard words.count >= needle.count else { return false }
        return words.indices.dropLast(needle.count - 1).contains { index in
            Array(words[index..<words.index(index, offsetBy: needle.count)]) == needle
        }
    }

    private func normalizedWords(in text: String) -> [String] {
        wordRanges(in: text).map { normalized(String(text[$0])) }.filter { !$0.isEmpty }
    }

    private func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        for index in text.indices {
            if text[index].isWhitespace {
                if let start { ranges.append(start..<index) }
                start = nil
            } else if start == nil {
                start = index
            }
        }
        if let start { ranges.append(start..<text.endIndex) }
        return ranges
    }

    private func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }
}
