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
                You are an inline word-completion engine, not a chat assistant.
                Finish only the current unfinished word before the cursor.
                Return only the missing suffix or the finished current word.
                Do not add a space, a new word, punctuation, explanation, quotes, or reasoning.
                """,
                user: "Text before cursor:\n\(context)\n\nWord completion:"
            )
        }

        return CompletionPrompt(
            system: phraseContinuationSystemPrompt(for: request),
            user: "Text before cursor:\n\(context)\n\nAutocomplete continuation:"
        )
    }

    private func phraseContinuationSystemPrompt(for request: CompletionRequest) -> String {
        let base = """
        You are an inline autocomplete engine, not a chat assistant.
        Continue only the current sentence or phrase before the cursor.
        Return only the next \(maxVisibleWords) words or fewer.
        Do not reuse old lines, answer, explain, summarize, greet, restart the sentence, or mention the user.
        No explanation.
        No quotes. No reasoning.
        """

        guard request.appBundleIdentifier == "com.openai.codex" else {
            return base
        }

        guard request.textBeforeCursor.isAutocompleteDogfoodContext else {
            return base + """

            The active app is Codex. Continue the user's actual sentence naturally.
            Do not force software, testing, latency, placement, or debugging topics unless the current sentence is already about them.
            Avoid vague product phrases like "integrate it seamlessly", "enhance the experience", or "leverage the system".
            """
        }

        return base + """

        The active app is Codex, where the user is dogfooding this autocomplete tool while building and debugging it.
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

private extension String {
    var isAutocompleteDogfoodContext: Bool {
        let lowercasedText = lowercased()
        let dogfoodTerms = [
            "autocomplete", "completion", "codex app", "engine", "latency",
            "placement", "trace", "traces", "debug", "debugging", "test",
            "testing", "suggestion", "suggestions", "tab", "caret", "model"
        ]

        return dogfoodTerms.contains { lowercasedText.contains($0) }
    }
}

private extension Character {
    var isSentenceBoundary: Bool {
        [".", "!", "?", "\n"].contains(self)
    }
}
