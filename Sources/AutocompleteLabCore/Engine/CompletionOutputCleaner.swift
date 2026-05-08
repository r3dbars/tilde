import Foundation

public struct CompletionOutputCleaner: Equatable, Sendable {
    private static let noSuggestionToken = CompletionPromptBuilder.noSuggestionToken.lowercased()

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

    public func cleanCandidates(
        _ rawOutput: String,
        after textBeforeCursor: String?,
        mode: CompletionRequestMode,
        limit: Int = 3
    ) -> [CompletionSuggestion] {
        let maxCandidateCount = max(1, limit)
        var seen: Set<String> = []
        var suggestions: [CompletionSuggestion] = []

        for candidateLine in candidateLines(from: rawOutput) {
            guard let suggestion = clean(candidateLine, after: textBeforeCursor, mode: mode) else {
                continue
            }

            let key = normalizedCandidateKey(suggestion.visibleText)
            guard seen.insert(key).inserted else {
                continue
            }

            suggestions.append(suggestion)
            if suggestions.count >= maxCandidateCount {
                break
            }
        }

        return suggestions
    }

    public func cleanBestCandidate(
        _ rawOutput: String,
        after textBeforeCursor: String?,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        limit: Int = 3,
        ranker: CompletionCandidateRanker = CompletionCandidateRanker()
    ) -> CompletionCandidateSelection {
        let candidates = cleanCandidates(
            rawOutput,
            after: textBeforeCursor,
            mode: mode,
            limit: limit
        )
        return ranker.selection(
            candidates,
            mode: mode,
            textBeforeCursor: textBeforeCursor,
            behaviorProfileID: behaviorProfileID
        )
    }

    public func clean(_ rawOutput: String, after textBeforeCursor: String?, mode: CompletionRequestMode) -> CompletionSuggestion? {
        guard !containsUnsafePromptHiddenOrControlCharacter(rawOutput) else {
            return nil
        }

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

        guard !isNoSuggestionSentinel(withoutThinking) else {
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

        guard !isNoSuggestionSentinel(withoutPromptEchoLabel) else {
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

        guard !looksLikeVisibleUIChromeCandidate(withoutPromptEchoLabel, mode: mode) else {
            return nil
        }

        if let textBeforeCursor,
           looksLikeAssistantResponseToPrompt(withoutPromptEchoLabel, after: textBeforeCursor) {
            return nil
        }

        if let textBeforeCursor,
           restartsCurrentSentence(withoutPromptEchoLabel, after: textBeforeCursor) {
            return nil
        }

        guard !isAdviceOrToneDriftPhrase(withoutPromptEchoLabel) else {
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

        if mode.isContinuation,
           let textBeforeCursor,
           duplicatesVisibleTypedWords(trimmedSuggestion, after: textBeforeCursor) {
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

        if mode.isContinuation,
           isLowValueSingleWordPhrase(suggestion.visibleText) {
            return nil
        }

        if mode.isContinuation,
           isLowSignalPhrase(suggestion.visibleText) {
            return nil
        }

        if mode.isContinuation,
           isAdviceOrToneDriftPhrase(suggestion.visibleText) {
            return nil
        }

        if looksLikeVisibleUIChromeCandidate(suggestion.visibleText, mode: mode) {
            return nil
        }

        return suggestion
    }

    private func candidateLines(from rawOutput: String) -> [String] {
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

        let lines = withoutThinking
            .components(separatedBy: .newlines)
            .map(strippingCandidatePrefix)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return lines.isEmpty ? [withoutThinking] : lines
    }

    private func strippingCandidatePrefix(from text: String) -> String {
        text
            .replacingOccurrences(
                of: #"^\s*candidate\s+\d+\s*[\).:-]?\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"^\s*(?:[-*•]|\d+[\).:]|[A-Za-z][\).:])\s+"#,
                with: "",
                options: .regularExpression
            )
    }

    private func normalizedCandidateKey(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func isNoSuggestionSentinel(_ text: String) -> Bool {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: Self.noSuggestionWrapperCharacters)

        return trimmed.lowercased() == Self.noSuggestionToken
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
            || normalized == "before cursor"
            || normalized.hasPrefix("before cursor ")
            || normalized.hasPrefix("after cursor:")
            || normalized == "after cursor"
            || normalized.hasPrefix("after cursor ")
            || normalized.hasPrefix("action:")
            || normalized.range(of: #"^candidate\s+\d+\s*[\).:-]?\s*$"#, options: .regularExpression) != nil
            || normalized.hasPrefix("inline autocomplete")
            || normalized.hasPrefix("inline word completion")
            || normalized.hasPrefix("next action:")
            || normalized.hasPrefix("recommendation:")
            || normalized.hasPrefix("return only")
            || normalized.hasPrefix("return exactly")
            || normalized.hasPrefix("rewrite:")
            || normalized.hasPrefix("no spaces")
            || normalized.hasPrefix("continue the current sentence")
            || normalized.hasPrefix("start the next sentence")
    }

    private func strippingPromptEchoLabel(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutCandidateLabel = trimmed.replacingOccurrences(
            of: #"^\s*candidate\s+\d+\s*[\).:-]\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        if withoutCandidateLabel != trimmed {
            return withoutCandidateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        }

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

        return Self.genericFillerPrefixes.contains { normalized.hasPrefix($0) }
    }

    private func looksLikeUnsafePromptAction(_ text: String) -> Bool {
        if containsUnsafePromptHiddenOrControlCharacter(text) {
            return true
        }

        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.unsafePromptCommandPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }

        if normalized.hasPrefix("```") || normalized.hasPrefix("$ ") || normalized.hasPrefix("> ") {
            return true
        }

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
            || Self.unsafePromptActionWords.contains(normalized)
    }

    private func containsUnsafePromptHiddenOrControlCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            if Self.unsafePromptHiddenScalars.contains(scalar) {
                return true
            }
            if scalar == "\n" || scalar == "\r" {
                return false
            }
            return CharacterSet.controlCharacters.contains(scalar)
        }
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

    private func looksLikeVisibleUIChromeCandidate(_ text: String, mode: CompletionRequestMode) -> Bool {
        guard mode.isContinuation else {
            return false
        }

        let words = normalizedWords(in: text)
        guard !words.isEmpty else {
            return false
        }

        if isWrappedInMarkdownEmphasis(text), words.count <= 4 {
            return true
        }

        if words[0] == "untitled" {
            return words.count == 1
                || words.dropFirst().allSatisfy { $0.allSatisfy(\.isNumber) || Self.visibleUIChromeTokens.contains($0) }
        }

        if words[0] == "ep", words.count <= 3 {
            return true
        }

        guard words.count >= 2, words.count <= 5 else {
            return false
        }

        return words.allSatisfy { Self.visibleUIChromeTokens.contains($0) || $0.allSatisfy(\.isNumber) }
    }

    private func isWrappedInMarkdownEmphasis(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("**") && trimmed.hasSuffix("**"))
            || (trimmed.hasPrefix("__") && trimmed.hasSuffix("__"))
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

    private func duplicatesVisibleTypedWords(_ suggestion: String, after textBeforeCursor: String) -> Bool {
        let suggestionWords = normalizedWords(in: suggestion)
        guard !suggestionWords.isEmpty else {
            return false
        }

        let currentSentenceWords = normalizedWords(in: currentSentence(in: textBeforeCursor))
        guard !currentSentenceWords.isEmpty else {
            return false
        }

        if suggestionWords.count == 1,
           let onlyWord = suggestionWords.first,
           onlyWord.count > 3,
           !Self.lowValueSingleWordPhrases.contains(onlyWord),
           currentSentenceWords.contains(onlyWord) {
            return true
        }

        let maximumLead = min(3, suggestionWords.count, currentSentenceWords.count)
        guard maximumLead >= 2 else {
            return false
        }

        for leadCount in stride(from: maximumLead, through: 2, by: -1) {
            let leadPhrase = Array(suggestionWords.prefix(leadCount))
            if currentSentenceWords.windows(ofCount: leadCount).contains(leadPhrase) {
                return true
            }
        }

        return false
    }

    private func restartsCurrentSentence(_ suggestion: String, after textBeforeCursor: String) -> Bool {
        let currentSentenceWords = normalizedWords(in: currentSentence(in: textBeforeCursor))
        let suggestionWords = normalizedWords(in: suggestion)

        guard currentSentenceWords.count > 3,
              suggestionWords.count >= 3 else {
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

    private static let noSuggestionWrapperCharacters = CharacterSet(charactersIn: "\"'`")

    private static let commonWholeWords = Set(WordCompletionCandidateRanker.defaultWords)
        .union(lowValueSingleWordPhrases)

    private static let visibleUIChromeTokens: Set<String> = [
        "automations",
        "chat",
        "chats",
        "edited",
        "font",
        "format",
        "helvetica",
        "new",
        "plugins",
        "projects",
        "regular",
        "search",
        "settings",
        "untitled"
    ]

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

    private static let unsafePromptCommandPrefixes = [
        "/", "!", "@", "--", "sudo ", "curl ", "bash ", "sh ", "rm "
    ]

    private static let unsafePromptActionWords: Set<String> = [
        "allow",
        "approve",
        "click",
        "delete",
        "deploy",
        "enter",
        "execute",
        "merge",
        "return",
        "run",
        "send",
        "ship",
        "submit"
    ]

    private static let unsafePromptHiddenScalars: Set<Unicode.Scalar> = [
        "\u{200B}",
        "\u{200C}",
        "\u{200D}",
        "\u{2060}",
        "\u{FEFF}"
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

    private static let genericFillerPrefixes: Set<String> = [
        "boost productivity",
        "absolutely,",
        "certainly,",
        "drive better outcomes",
        "enhance the experience",
        "enhance user experience",
        "improve productivity",
        "improve the user experience",
        "increase productivity",
        "integrate it seamlessly",
        "i would like to",
        "i will do that",
        "i'll do that",
        "let me know",
        "leverage the system",
        "make users more productive",
        "maximize efficiency",
        "of course,",
        "okay, i would",
        "okay, would",
        "one option is",
        "optimize the workflow",
        "save time and effort",
        "streamline the workflow",
        "streamline workflows",
        "sure,",
        "that makes a lot of sense",
        "unlock efficiency"
    ]

    private static let adviceOrToneDriftStarters: Set<[String]> = [
        ["a", "good", "way"],
        ["a", "better", "approach"],
        ["absolutely"],
        ["boost", "productivity"],
        ["drive", "better", "outcomes"],
        ["great", "question"],
        ["happy", "to", "help"],
        ["i'd", "recommend"],
        ["i'd", "suggest"],
        ["i’d", "recommend"],
        ["i’d", "suggest"],
        ["i", "love", "this"],
        ["i", "recommend"],
        ["i", "suggest"],
        ["i", "would", "recommend"],
        ["i", "would", "suggest"],
        ["i", "think", "we", "should"],
        ["it", "is", "important"],
        ["it's", "important"],
        ["let's"],
        ["lets"],
        ["make", "sure", "to"],
        ["make", "users", "more", "productive"],
        ["maximize", "efficiency"],
        ["one", "thing", "to", "consider"],
        ["one", "option", "is"],
        ["next", "action"],
        ["next", "step"],
        ["optimize", "the", "workflow"],
        ["rewrite", "this"],
        ["save", "time", "and", "effort"],
        ["seamless", "experience"],
        ["sounds", "great"],
        ["streamline", "the", "workflow"],
        ["streamline", "workflows"],
        ["the", "best", "way"],
        ["the", "next", "step"],
        ["the", "best", "approach"],
        ["this", "is", "a", "great"],
        ["this", "is", "exciting"],
        ["try", "saying"],
        ["unlock", "efficiency"],
        ["you", "may", "want"],
        ["you", "might", "want"],
        ["you", "need", "to"],
        ["you", "should"],
        ["we", "need", "to"],
        ["we", "should"],
        ["what", "i", "would", "do"]
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
