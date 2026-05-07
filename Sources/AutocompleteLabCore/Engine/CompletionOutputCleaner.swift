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

        guard !looksLikePromptInstructionEcho(singleLine) else {
            return nil
        }

        let withoutPromptEchoLabel = strippingPromptEchoLabel(from: singleLine)

        guard !withoutPromptEchoLabel.isEmpty else {
            return nil
        }

        guard !looksLikePromptInstructionEcho(withoutPromptEchoLabel) else {
            return nil
        }

        guard !looksLikeAssistantMeta(withoutPromptEchoLabel) else {
            return nil
        }

        guard !looksLikeGenericChatFiller(withoutPromptEchoLabel) else {
            return nil
        }

        guard !looksLikeUnsafePromptAction(withoutPromptEchoLabel) else {
            return nil
        }

        if let textBeforeCursor,
           looksLikeAssistantResponseToPrompt(withoutPromptEchoLabel, after: textBeforeCursor) {
            return nil
        }

        if let textBeforeCursor,
           looksLikeGenericAgentProductivityFiller(withoutPromptEchoLabel, after: textBeforeCursor) {
            return nil
        }

        if let textBeforeCursor,
           restartsCurrentSentence(withoutPromptEchoLabel, after: textBeforeCursor) {
            return nil
        }

        let normalizedSuggestion = mode == .wordCompletion ? withoutPromptEchoLabel : ensureLeadingSpace(withoutPromptEchoLabel)
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
           !isValidWordCompletion(
                suggestion.visibleText,
                rawCandidate: withoutPromptEchoLabel,
                after: textBeforeCursor
           ) {
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

        if mode == .phraseContinuation,
           isAdviceOrToneDriftPhrase(suggestion.visibleText) {
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
            || normalized.hasPrefix("as an ai")
            || normalized.hasPrefix("happy to")
            || normalized.hasPrefix("here's")
            || normalized.hasPrefix("here is")
            || normalized.hasPrefix("i can help")
            || normalized.hasPrefix("i can't")
            || normalized.hasPrefix("i cannot")
            || normalized.hasPrefix("i can’t")
            || normalized.hasPrefix("i'm here")
            || normalized.hasPrefix("i am here")
            || normalized.hasPrefix("it sounds like")
            || normalized.hasPrefix("no problem")
            || normalized.hasPrefix("the user ")
            || normalized.hasPrefix("the user is ")
            || normalized.hasPrefix("user is ")
            || normalized.hasPrefix("would you like")
            || normalized.hasPrefix("you can ")
            || normalized.hasPrefix("you could ")
            || normalized.hasPrefix("you might ")
            || normalized.hasPrefix("assistant:")
            || normalized.hasPrefix("system:")
    }

    private func looksLikePromptInstructionEcho(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("before cursor:")
            || normalized.hasPrefix("after cursor:")
            || normalized.hasPrefix("inline autocomplete")
            || normalized.hasPrefix("inline word completion")
            || normalized.hasPrefix("return only")
            || normalized.hasPrefix("no spaces")
            || normalized.hasPrefix("continue the current sentence")
            || normalized.hasPrefix("start the next sentence")
    }

    private func strippingPromptEchoLabel(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for label in Self.promptEchoLabels {
            guard trimmed.lowercased().hasPrefix(label) else {
                continue
            }

            return String(trimmed.dropFirst(label.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
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

    private func looksLikeUnsafePromptAction(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("press enter")
            || normalized.hasPrefix("press return")
            || normalized.hasPrefix("hit enter")
            || normalized.hasPrefix("hit return")
            || normalized.hasPrefix("send the prompt")
            || normalized.hasPrefix("submit the prompt")
            || normalized.hasPrefix("click send")
            || normalized.hasPrefix("run this command")
            || normalized.hasPrefix("execute this command")
            || normalized.hasPrefix("execute the command")
    }

    private func looksLikeAssistantResponseToPrompt(_ text: String, after textBeforeCursor: String) -> Bool {
        let normalizedCandidate = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.assistantResponsePrefixes.contains(where: { normalizedCandidate.hasPrefix($0) }) else {
            return false
        }

        let nearbyContext = String(textBeforeCursor.suffix(180)).lowercased()
        return Self.promptRequestMarkers.contains(where: { nearbyContext.contains($0) })
    }

    private func looksLikeGenericAgentProductivityFiller(_ text: String, after textBeforeCursor: String) -> Bool {
        let nearbyContext = String(textBeforeCursor.suffix(180)).lowercased()
        guard Self.promptRequestMarkers.contains(where: { nearbyContext.contains($0) }) else {
            return false
        }

        let normalizedCandidate = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Self.genericAgentProductivityFillers.contains { normalizedCandidate.hasPrefix($0) }
    }

    private func ensureLeadingSpace(_ text: String) -> String {
        guard let first = text.first, !first.isWhitespace else {
            return text
        }

        return " " + text
    }

    private func isValidWordCompletion(
        _ text: String,
        rawCandidate: String,
        after textBeforeCursor: String?
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }) else {
            return false
        }

        guard trimmed.allSatisfy({ $0.isLetter }) else {
            return false
        }

        guard let textBeforeCursor,
              let fragment = trailingWordFragment(in: textBeforeCursor) else {
            return true
        }

        let normalizedFragment = fragment.lowercased()
        let normalizedRawCandidate = rawCandidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedFragment.isEmpty,
              !normalizedRawCandidate.isEmpty,
              normalizedRawCandidate.allSatisfy({ $0.isLetter }) else {
            return true
        }

        if normalizedRawCandidate.hasPrefix(normalizedFragment) {
            return normalizedRawCandidate.count > normalizedFragment.count
        }

        return !Self.commonWholeWords.contains(normalizedRawCandidate)
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

    private func isAdviceOrToneDriftPhrase(_ text: String) -> Bool {
        let words = normalizedWords(in: text)
        guard words.count >= 2 else {
            return false
        }

        return Self.adviceOrToneDriftStarters.contains { starter in
            words.starts(with: starter)
        }
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

    private func restartsCurrentSentence(_ suggestion: String, after textBeforeCursor: String) -> Bool {
        let currentSentenceWords = normalizedWords(in: currentSentence(in: textBeforeCursor))
        let suggestionWords = normalizedWords(in: suggestion)

        guard currentSentenceWords.count > 3,
              suggestionWords.count >= 3 else {
            return false
        }

        if suggestionWords.count > currentSentenceWords.count,
           Array(suggestionWords.prefix(currentSentenceWords.count)) == currentSentenceWords {
            return false
        }

        return Array(currentSentenceWords.prefix(3)) == Array(suggestionWords.prefix(3))
    }

    private func currentSentence(in text: String) -> String {
        let separators = CharacterSet(charactersIn: ".!?\n")
        let components = text.components(separatedBy: separators)
        return components.last ?? text
    }

    private func normalizedWords(in text: String) -> [String] {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .map {
                $0.trimmingCharacters(in: .punctuationCharacters).lowercased()
            }
            .filter { !$0.isEmpty }
    }

    private func trailingWordFragment(in text: String) -> String? {
        guard let last = text.last, last.isLetter else {
            return nil
        }

        return text.split(whereSeparator: { !$0.isLetter }).last.map(String.init)
    }

    private static let lowValueSingleWordPhrases: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "but", "for", "i",
        "if", "in", "is", "it", "of", "on", "or", "so", "the", "to",
        "was", "we", "were", "with", "you"
    ]

    private static let promptEchoLabels = [
        "next words:",
        "next word:",
        "continuation:",
        "completion:",
        "suggestion:",
        "suffix:"
    ]

    private static let commonWholeWords = Set(WordCompletionCandidateRanker.defaultWords)
        .union(lowValueSingleWordPhrases)

    private static let assistantResponsePrefixes: Set<String> = [
        "first,",
        "i can ",
        "i will ",
        "i'll ",
        "let me ",
        "sure,",
        "we need to "
    ]

    private static let promptRequestMarkers: Set<String> = [
        "build ",
        "can you",
        "could you",
        "debug ",
        "explain ",
        "fix ",
        "help me",
        "inspect ",
        "look at",
        "make ",
        "please ",
        "run ",
        "write "
    ]

    private static let genericAgentProductivityFillers: Set<String> = [
        "boost productivity",
        "enhance productivity",
        "increase efficiency",
        "make it more productive",
        "make this more productive",
        "optimize the workflow",
        "save time and effort",
        "streamline the process",
        "streamline the workflow",
        "work smarter"
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

    private static let adviceOrToneDriftStarters: Set<[String]> = [
        ["a", "good", "way"],
        ["absolutely"],
        ["great", "question"],
        ["happy", "to", "help"],
        ["i", "love", "this"],
        ["i", "recommend"],
        ["i", "suggest"],
        ["it", "is", "important"],
        ["it's", "important"],
        ["one", "thing", "to", "consider"],
        ["seamless", "experience"],
        ["sounds", "great"],
        ["the", "best", "way"],
        ["this", "is", "a", "great"],
        ["this", "is", "exciting"],
        ["you", "may", "want"],
        ["you", "might", "want"]
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
