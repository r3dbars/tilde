import Foundation

public struct CompletionPrompt: Equatable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

public struct CompletionPromptBuilder: Equatable, Sendable {
    public let maxContextCharacters: Int
    public let maxCurrentParagraphCharacters: Int
    public let maxCurrentSentenceCharacters: Int
    public let maxVisibleWords: Int

    public init(
        maxContextCharacters: Int = 360,
        maxCurrentParagraphCharacters: Int = 220,
        maxCurrentSentenceCharacters: Int = 160,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.maxContextCharacters = max(80, maxContextCharacters)
        self.maxCurrentParagraphCharacters = max(80, maxCurrentParagraphCharacters)
        self.maxCurrentSentenceCharacters = max(80, maxCurrentSentenceCharacters)
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public func prompt(for request: CompletionRequest) -> CompletionPrompt {
        let context = promptContext(from: request.textBeforeCursor)

        if request.mode == .wordCompletion {
            return CompletionPrompt(
                system: """
                Inline word completion.
                Return only the missing suffix for the current word.
                No spaces, punctuation, quotes, reasoning, or extra words.
                """,
                user: "Before cursor:\n\(context)\n\nSuffix:"
            )
        }

        return CompletionPrompt(
            system: phraseContinuationSystemPrompt(for: request),
            user: "Before cursor:\n\(context)\n\nNext words:"
        )
    }

    private func phraseContinuationSystemPrompt(for request: CompletionRequest) -> String {
        let sentenceGuidance = request.textBeforeCursor.endsAtSentenceBoundary
            ? "Start the next sentence naturally."
            : "Continue the current sentence."
        let base = """
        Inline autocomplete.
        Return only the next \(maxVisibleWords) words or fewer.
        \(sentenceGuidance) Do not answer, explain, greet, quote, reason, or restart.
        """

        guard let dogfoodAppName = request.appBundleIdentifier.dogfoodAppName else {
            return base
        }

        guard request.textBeforeCursor.isAutocompleteDogfoodContext else {
            return base + """

            The active app is \(dogfoodAppName). Continue the user's actual sentence naturally.
            Do not force software, testing, latency, placement, or debugging topics unless the sentence is already about them.
            Avoid vague product phrases like "integrate it seamlessly", "enhance the experience", or "leverage the system".
            """
        }

        return base + """

        The active app is \(dogfoodAppName), where the user is dogfooding this autocomplete tool while building and debugging it.
        Prefer concrete continuations about testing, using, building, debugging, logs, traces, placement, or app behavior.
        Avoid vague product phrases like "integrate it seamlessly", "enhance the experience", or "leverage the system".
        """
    }

    private func promptContext(from textBeforeCursor: String) -> String {
        let nearbyContext = String(textBeforeCursor.suffix(maxContextCharacters))
        let currentParagraph = nearbyContext
            .components(separatedBy: "\n\n")
            .last?
            .trimmingCharacters(in: .newlines) ?? nearbyContext
        let currentSentence = currentSentenceFragment(in: currentParagraph)

        return String(currentSentence.suffix(maxCurrentSentenceCharacters))
    }

    private func currentSentenceFragment(in text: String) -> String {
        guard let boundary = text.lastIndex(where: { $0.isSentenceBoundary }) else {
            return String(text.suffix(maxCurrentParagraphCharacters))
        }

        let fragment = text[text.index(after: boundary)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fragment.isEmpty else {
            return String(text.suffix(maxCurrentParagraphCharacters))
        }

        return fragment
    }
}

private extension Optional where Wrapped == String {
    var dogfoodAppName: String? {
        switch self {
        case .some("com.openai.codex"):
            return "Codex"
        case .some("com.anthropic.claude-code"):
            return "Claude Code"
        default:
            return nil
        }
    }
}

private extension String {
    var endsAtSentenceBoundary: Bool {
        guard let last = trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }

        return [".", "!", "?"].contains(last)
    }

    var isAutocompleteDogfoodContext: Bool {
        let lowercasedText = lowercased()
        let dogfoodPhrases = [
            "autocomplete", "codex app", "claude code", "ghost text",
            "inline suggestion", "keyboard event tap", "phrase continuation",
            "selected text range", "suggestion overlay", "tab accept",
            "visual placement", "word completion"
        ]
        if dogfoodPhrases.contains(where: { lowercasedText.contains($0) }) {
            return true
        }

        let tokens = Set(lowercasedWords(in: lowercasedText))

        guard tokens.contains("tab") else {
            return false
        }

        let tabContextTerms: Set<String> = [
            "accept", "accepts", "accepted", "hit", "key", "press", "pressed"
        ]
        return !tokens.isDisjoint(with: tabContextTerms)
    }

    private func lowercasedWords(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

private extension Character {
    var isSentenceBoundary: Bool {
        [".", "!", "?", "\n"].contains(self)
    }
}
