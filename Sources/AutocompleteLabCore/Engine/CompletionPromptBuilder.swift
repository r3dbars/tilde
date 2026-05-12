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
    public static let promptStyleIdentifier = "screen-aware-continuation-v7"
    public static let noSuggestionToken = "<NO_SUGGESTION>"

    public let maxContextCharacters: Int
    public let maxContextTokens: Int
    public let maxCurrentParagraphCharacters: Int
    public let maxCurrentSentenceCharacters: Int
    public let maxVisibleWords: Int

    public init(
        maxContextCharacters: Int = 360,
        maxContextTokens: Int = 72,
        maxCurrentParagraphCharacters: Int = 220,
        maxCurrentSentenceCharacters: Int = 160,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.maxContextCharacters = max(80, maxContextCharacters)
        self.maxContextTokens = min(96, max(48, maxContextTokens))
        self.maxCurrentParagraphCharacters = max(80, maxCurrentParagraphCharacters)
        self.maxCurrentSentenceCharacters = max(80, maxCurrentSentenceCharacters)
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
    }

    public func prompt(for request: CompletionRequest) -> CompletionPrompt {
        let context = promptContext(from: request.textBeforeCursor, mode: request.mode)
        let behaviorProfile = behaviorProfile(for: request)
        let userPrompt = userPrompt(
            context: context,
            visiblePageContext: request.visiblePageContext,
            suffix: request.mode == .wordCompletion ? "Suffix:" : "Next words:"
        )

        if request.mode == .wordCompletion {
            let titleShapeGuidance = request.documentTitleShape?.promptGuidance ?? ""
            let partialWordGuidance = request.partialWordShape?.promptGuidance ?? ""
            let lineStructureGuidance = request.currentLineStructure?.promptGuidance ?? ""
            let visiblePageGuidance = request.visiblePageContext?.promptGuidance ?? ""
            return CompletionPrompt(
                system: """
                Inline word completion.
                Return only the missing suffix for the current word.
                Tab inserts only this visible suffix; full accept is separate and must never be implied.
                \(titleShapeGuidance)
                \(partialWordGuidance)
                \(lineStructureGuidance)
                \(visiblePageGuidance)
                If visible page context includes a matching local word, name, or term, prefer that word's missing suffix.
                For partial product names, app names, permissions, people, project terms, and repeated OCR words, complete the visible local word before guessing a generic dictionary word.
                Only exception: return exactly \(Self.noSuggestionToken) when unsafe or the suffix would complete the wrong word.
                No spaces, punctuation, quotes, reasoning, or extra words.
                """,
                user: userPrompt
            )
        }

        return CompletionPrompt(
            system: phraseContinuationSystemPrompt(for: request, behaviorProfile: behaviorProfile),
            user: userPrompt
        )
    }

    private func phraseContinuationSystemPrompt(
        for request: CompletionRequest,
        behaviorProfile: AutocompleteBehaviorProfile
    ) -> String {
        let effectiveMaxVisibleWords = min(maxVisibleWords, request.maxVisibleWords, behaviorProfile.maxVisibleWords)
        let sentenceGuidance = sentenceGuidance(for: request)
        let styleGuidance = request.acceptedTextStyleSketch?.promptGuidance ?? ""
        let titleShapeGuidance = request.documentTitleShape?.promptGuidance ?? ""
        let partialWordGuidance = request.partialWordShape?.promptGuidance ?? ""
        let lineStructureGuidance = request.currentLineStructure?.promptGuidance ?? ""
        let visiblePageGuidance = request.visiblePageContext?.promptGuidance ?? ""
        let modeGuidance = request.mode == .sentenceContinuation
            ? "Sentence mode: start only the next sentence's first few words. If visible context makes the next sentence obvious, make the best short guess."
            : "Phrase mode: continue only the current local thought. If visible context implies what the user is replying to or writing about, use it."
        let base = """
        Inline autocomplete.
        Return 1 to 4 candidate suffixes, one per line, best first.
        Return only the suffix after the Before cursor text.
        Each candidate must be only the next \(effectiveMaxVisibleWords) words or fewer.
        Only exception: return exactly \(Self.noSuggestionToken) when unsafe, chatty, or likely to answer the prompt instead of continuing it.
        Never suggest pressing Tab, Option-Tab, Backtick, or accepting all visible text.
        Behavior profile: \(behaviorProfile.id.rawValue), max \(behaviorProfile.maxVisibleWords) visible words / \(behaviorProfile.maxGeneratedTokens) generated tokens.
        \(styleGuidance)
        \(titleShapeGuidance)
        \(partialWordGuidance)
        \(lineStructureGuidance)
        \(visiblePageGuidance)
        \(behaviorProfile.promptGuidance.joined(separator: "\n"))
        \(modeGuidance)
        Prefer the next word or short phrase the user was already likely to type, especially names, repeated local terms, reply language, list items, and boring connective tissue.
        Prefer 3 to 5 useful words for phrase suggestions; use fewer words when fewer are enough.
        Return \(Self.noSuggestionToken) instead of a full-sentence continuation, weak guess, new topic, or action instruction.
        If the user is writing about Tab, acceptance behavior, or shortcuts, continue the safety rule itself; do not suggest accepting terms or permissions.
        When the continuation is a common phrase, put that boring obvious phrase first.
        Avoid generic filler like "comes to life", "key features and benefits", "comprehensive plan", or "acknowledge the user's point".
        When the visible page context is useful, act like a local writing companion that can see the screen but still only types the user's next words.
        Do not repeat the Before cursor text.
        \(sentenceGuidance) Do not answer, explain, greet, quote, reason, or restart.
        Do not brainstorm, rewrite, introduce a new topic, or complete the user's whole thought.
        """

        guard let dogfoodAppName = request.appBundleIdentifier.dogfoodAppName else {
            return base
        }

        guard request.textBeforeCursor.isAutocompleteDogfoodContext else {
            return base + """

            The active app is \(dogfoodAppName). Continue the user's actual sentence naturally.
            Treat this as text the user is typing into an agent prompt, not a prompt to answer.
            Do not force software, testing, latency, placement, or debugging topics unless the sentence is already about them.
            Never suggest pressing Enter/Return, sending/submitting the prompt, or running a command.
            Avoid vague product and productivity filler like "integrate it seamlessly", "enhance the experience", "boost productivity", "streamline the workflow", or "leverage the system".
            """
        }

        return base + """

        The active app is \(dogfoodAppName), where the user is dogfooding this autocomplete tool while building and debugging it.
        Treat this as text the user is typing into an agent prompt, not a prompt to answer.
        Prefer concrete continuations about testing, using, building, debugging, logs, traces, placement, or app behavior.
        Never suggest pressing Enter/Return, sending/submitting the prompt, or running a command.
        Avoid vague product and productivity filler like "integrate it seamlessly", "enhance the experience", "boost productivity", "streamline the workflow", or "leverage the system".
        """
    }

    private func behaviorProfile(for request: CompletionRequest) -> AutocompleteBehaviorProfile {
        request.behaviorProfile
    }

    private func userPrompt(
        context: String,
        visiblePageContext: VisiblePageContext?,
        suffix: String
    ) -> String {
        guard let visiblePageContext else {
            return "Before cursor:\n\(context)\n\n\(suffix)"
        }

        return """
        Visible page context:
        \(visiblePageContext.promptText)

        Before cursor:
        \(context)

        \(suffix)
        """
    }

    private func sentenceGuidance(for request: CompletionRequest) -> String {
        switch request.mode {
        case .sentenceContinuation:
            return "Start the next sentence naturally."
        case .phraseContinuation:
            return request.textBeforeCursor.endsAtSentenceBoundary
                ? "Start the next sentence naturally."
                : "Continue the current sentence."
        case .wordCompletion:
            return ""
        }
    }

    private func promptContext(from textBeforeCursor: String, mode: CompletionRequestMode) -> String {
        let nearbyContext = String(textBeforeCursor.suffix(maxContextCharacters))
        let paragraphs = nearbyContext.components(separatedBy: "\n\n")
        let currentParagraph = paragraphs
            .last?
            .trimmingCharacters(in: .newlines) ?? nearbyContext
        let previousParagraph = paragraphs
            .dropLast()
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceContext = sentenceContext(in: currentParagraph)
        var pieces: [String] = []

        if shouldIncludePreviousParagraph(
            previousParagraph,
            currentFragment: sentenceContext.current,
            previousSentence: sentenceContext.previous,
            mode: mode
        ) {
            pieces.append(String(previousParagraph?.suffix(maxCurrentSentenceCharacters) ?? ""))
        }

        if shouldIncludePreviousSentence(
            sentenceContext.previous,
            currentFragment: sentenceContext.current,
            mode: mode
        ) {
            pieces.append(sentenceContext.previous ?? "")
        }

        pieces.append(sentenceContext.current)

        return trimContext(pieces.joined(separator: " "))
    }

    private func sentenceContext(in text: String) -> (previous: String?, current: String) {
        let paragraph = String(text.suffix(maxCurrentParagraphCharacters))
        let fragments = sentenceFragments(in: paragraph)

        guard let current = fragments.last else {
            return (nil, paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return (
            fragments.dropLast().last.map { String($0.suffix(maxCurrentSentenceCharacters)) },
            String(current.suffix(maxCurrentSentenceCharacters))
        )
    }

    private func sentenceFragments(in text: String) -> [String] {
        var fragments: [String] = []
        var startIndex = text.startIndex

        for index in text.indices where text[index].isSentenceBoundary {
            let endIndex = text.index(after: index)
            let fragment = text[startIndex..<endIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fragment.isEmpty {
                fragments.append(String(fragment))
            }
            startIndex = endIndex
        }

        let tail = text[startIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            fragments.append(String(tail))
        }

        return fragments
    }

    private func shouldIncludePreviousSentence(
        _ previousSentence: String?,
        currentFragment: String,
        mode: CompletionRequestMode
    ) -> Bool {
        guard previousSentence?.isEmpty == false else {
            return false
        }

        if mode == .sentenceContinuation {
            return true
        }

        return contentTokenCount(in: currentFragment) <= 2
    }

    private func shouldIncludePreviousParagraph(
        _ previousParagraph: String?,
        currentFragment: String,
        previousSentence: String?,
        mode: CompletionRequestMode
    ) -> Bool {
        guard mode == .sentenceContinuation,
              previousSentence == nil,
              previousParagraph?.isEmpty == false else {
            return false
        }

        return contentTokenCount(in: currentFragment) <= 2
    }

    private func trimContext(_ text: String) -> String {
        let characterTrimmed = String(text.suffix(maxContextCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = characterTrimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard words.count > maxContextTokens else {
            return characterTrimmed
        }

        return words
            .suffix(maxContextTokens)
            .joined(separator: " ")
    }

    private func contentTokenCount(in text: String) -> Int {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .count
    }
}

private extension Optional where Wrapped == String {
    var dogfoodAppName: String? {
        switch self {
        case .some("com.openai.codex"):
            return "Codex"
        case .some("com.anthropic.claude-code"):
            return "Claude Code"
        case .some("com.anthropic.claudefordesktop"):
            return "Claude"
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
            "no submit", "no-submit", "prompt app", "prompt editor",
            "prompt input", "prompt insertion", "selected text range",
            "suggestion overlay", "tab accept",
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
