import Foundation

public struct CompletionPrompt: Equatable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }

    public func formatted(using template: CompletionPromptTemplate) -> FormattedCompletionPrompt {
        template.format(self)
    }
}

public struct FormattedCompletionPrompt: Equatable, Sendable {
    public let template: CompletionPromptTemplate
    public let system: String
    public let user: String
    public let rawPrompt: String?

    public var templateIdentifier: String {
        template.rawValue
    }

    public init(
        template: CompletionPromptTemplate,
        system: String,
        user: String,
        rawPrompt: String? = nil
    ) {
        self.template = template
        self.system = system
        self.user = user
        self.rawPrompt = rawPrompt
    }
}

public enum CompletionPromptTemplate: String, Equatable, Sendable {
    case chatInstruct = "chat_instruct"
    case rawCompletion = "raw_completion"

    public static func template(for model: LocalModelID) -> CompletionPromptTemplate {
        switch model {
        case .qwen3Small, .qwen3Medium:
            return .rawCompletion
        case .gemma4E2B, .gemma4E4B, .gemma4E4BItOptiQ, .gemma4A4B, .qwen35FourB, .qwen35NineB:
            return .chatInstruct
        }
    }

    public func format(_ prompt: CompletionPrompt) -> FormattedCompletionPrompt {
        switch self {
        case .chatInstruct:
            return FormattedCompletionPrompt(
                template: self,
                system: prompt.system,
                user: prompt.user
            )
        case .rawCompletion:
            let rawPrompt = [prompt.system, prompt.user]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            return FormattedCompletionPrompt(
                template: self,
                system: "",
                user: rawPrompt,
                rawPrompt: rawPrompt
            )
        }
    }
}

public struct CompletionPromptBuilder: Equatable, Sendable {
    public static let promptStyleIdentifier = "screen-aware-continuation-v9"
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
        let effectiveMaxVisibleWords = effectiveMaxVisibleWords(
            for: request,
            behaviorProfile: behaviorProfile
        )
        let userPrompt = userPrompt(
            context: context,
            visiblePageContext: request.visiblePageContext,
            suffix: suffixLabel(for: request.mode, visibleWords: effectiveMaxVisibleWords)
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
                Critical suffix example: "The privacy note should stay redac" -> ted. Do not return tion for redac in a privacy-note context.
                Suffix examples: transi -> tion; configu -> rable; visi -> ble; qui -> etly; redac -> ted. For "The setting should be configu", return rable, not ration. For "privacy note should stay redac", return ted, not tion. Never return tion unless it completes the visible word.
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
        let effectiveMaxVisibleWords = effectiveMaxVisibleWords(
            for: request,
            behaviorProfile: behaviorProfile
        )
        let candidateCountGuidance = candidateCountGuidance(forVisibleWords: effectiveMaxVisibleWords)
        let sentenceGuidance = sentenceGuidance(for: request)
        let lengthGuidance = lengthGuidance(forVisibleWords: effectiveMaxVisibleWords)
        let styleLengthGuidance = styleLengthGuidance(forVisibleWords: effectiveMaxVisibleWords)
        let styleGuidance = request.acceptedTextStyleSketch?.promptGuidance ?? ""
        let titleShapeGuidance = request.documentTitleShape?.promptGuidance ?? ""
        let partialWordGuidance = request.partialWordShape?.promptGuidance ?? ""
        let lineStructureGuidance = request.currentLineStructure?.promptGuidance ?? ""
        let visiblePageGuidance = request.visiblePageContext?.promptGuidance ?? ""
        let exampleGuidance = exampleGuidance(forVisibleWords: effectiveMaxVisibleWords)
        let modeGuidance = request.mode == .sentenceContinuation
            ? "Sentence mode: continue naturally up to the visible word limit. If the limit is high and the next sentence is obvious, a longer sentence chunk is allowed."
            : "Phrase mode: continue only the current local thought. If visible context implies what the user is replying to or writing about, use it."
        let base = """
        Inline autocomplete.
        \(candidateCountGuidance)
        Return only the suffix after the Before cursor text.
        Each candidate must be only the next \(effectiveMaxVisibleWords) words or fewer.
        \(lengthGuidance)
        Return exactly \(Self.noSuggestionToken) when the continuation is not obvious from the local text.
        Only exception: return exactly \(Self.noSuggestionToken) when unsafe, chatty, or likely to answer the prompt instead of continuing it.
        Never suggest pressing Tab, Shift-Tab, Option-Tab, Backtick, or accepting all visible text.
        Behavior profile: \(behaviorProfile.id.rawValue), max \(behaviorProfile.maxVisibleWords) visible words / \(behaviorProfile.maxGeneratedTokens) generated tokens.
        \(styleGuidance)
        \(styleLengthGuidance)
        \(titleShapeGuidance)
        \(partialWordGuidance)
        \(lineStructureGuidance)
        \(visiblePageGuidance)
        \(behaviorProfile.promptGuidance.joined(separator: "\n"))
        \(modeGuidance)
        Prefer the next word or short phrase at low settings; at high settings, prefer the next words the user was already likely to type, especially names, repeated local terms, reply language, list items, and boring connective tissue.
        Prefer enough high-confidence words to match the visible word limit; use fewer words when fewer are enough.
        Return \(Self.noSuggestionToken) instead of a weak guess, new topic, or action instruction.
        If the user is writing about Tab, acceptance behavior, or shortcuts, continue the safety rule itself; do not suggest accepting terms or permissions.
        When the continuation is a common phrase, put that boring obvious phrase first.
        If the best continuation would answer the user, issue an instruction to the app, or start a new topic, return \(Self.noSuggestionToken).
        Ordinary drafting with should or need is allowed when it is not telling the app to act; continue it with concrete next words.
        Avoid generic filler like "comes to life", "key features and benefits", "comprehensive plan", or "acknowledge the user's point".
        \(exampleGuidance)
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

    private func effectiveMaxVisibleWords(
        for request: CompletionRequest,
        behaviorProfile: AutocompleteBehaviorProfile
    ) -> Int {
        min(maxVisibleWords, request.maxVisibleWords, behaviorProfile.maxVisibleWords)
    }

    private func suffixLabel(for mode: CompletionRequestMode, visibleWords: Int) -> String {
        guard mode != .wordCompletion else {
            return "Suffix:"
        }

        let preferredMinimum = CompletionModelPolicy.preferredMinimumVisibleWords(
            forVisibleWords: visibleWords
        )
        guard visibleWords >= 6 else {
            return "Next words:"
        }

        return "Next \(preferredMinimum)-\(visibleWords) words, or \(Self.noSuggestionToken):"
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

    private func lengthGuidance(forVisibleWords visibleWords: Int) -> String {
        let preferredMinimum = CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: visibleWords)
        switch visibleWords {
        case 16...:
            return """
            Length setting: high. The candidate must be 12-\(visibleWords) words when the current sentence can keep going naturally.
            Do not stop at a 2-4 word phrase just because it is grammatical; continue the same sentence into a useful longer chunk.
            If you cannot produce at least 12 strong next words, return \(Self.noSuggestionToken) instead of a short fallback.
            """
        case 12...:
            return """
            Length setting: high. The candidate must be \(preferredMinimum)-\(visibleWords) words when the current sentence can keep going naturally.
            Do not stop at a 2-4 word phrase just because it is grammatical.
            If you cannot produce at least \(preferredMinimum) strong next words, return \(Self.noSuggestionToken) instead of a short fallback.
            """
        case 9...:
            return "Length setting: medium-long. Prefer \(preferredMinimum)-\(visibleWords) words when the next words are clear."
        case 6...:
            return "Length setting: medium. Prefer at least \(preferredMinimum) words when the next words are clear."
        default:
            return "Length setting: short. A short phrase is fine."
        }
    }

    private func candidateCountGuidance(forVisibleWords visibleWords: Int) -> String {
        guard visibleWords >= 12 else {
            return "Return 1 or 2 candidate suffixes, one per line, best first."
        }

        return "Return exactly one longer candidate suffix. Do not return multiple lines or a short alternate candidate."
    }

    private func exampleGuidance(forVisibleWords visibleWords: Int) -> String {
        guard visibleWords >= 12 else {
            return """
            Shape examples: "The draft feels calmer when it" -> "stays short and specific"; "The review should focus on" -> "real user risk"; "A good reply here would be" -> "short, kind, and specific".
            Correction examples: "Correct this spelling: recieve ->" -> "receive"; "adress ->" -> "address"; "seperate ->" -> "separate"; "calender ->" -> "calendar"; "occured ->" -> "occurred". Return only the corrected word.
            Natural examples: "Before we ship, we should" -> "run one small check"; "The meeting notes need a" -> "clear next step"; "The onboarding screen should make" -> "permission feel clear"; "The local test should fail only when" -> "proof is missing"; "The draft says simple simple, so the next words should" -> "move forward".
            List examples: "Project notes / Keep the app small / Make the copy" -> "short and clear"; "Decision log / Hold the risky path until" -> "proof exists". Return \(Self.noSuggestionToken) only for empty bullets or empty numbered list items.
            More examples: "quiet mode should stay quiet mode should stay" -> "calm in the background"; "Hold the risky path until" -> "proof exists"; "the next step is to" -> "write a small repro"; "autocomplete should" -> "stay silent".
            More examples: "This bug is easiest to test with" -> "small fixture case"; "After the demo, capture the" -> "open questions quickly"; "tested the button, tested the button, and now need" -> "one fresh check"; "should not echo" -> "new detail"; "next words should" -> "move forward"; "starts repeating the model starts repeating, prefer" -> "noisy output blocked"; "product update should mention" -> "one clear change"; "press Tab and confirm" -> "next word only".
            """
        }

        return """
        Long natural examples: "Before we ship, we should" -> "run one small check against the live app before changing anything else"; "The meeting notes need a" -> "clear next step that someone can finish without reading the whole thread again"; "The onboarding note should make the setup feel clear and" -> "easy to finish without making the user think about permissions twice before they can keep writing"; "The local test should fail only when" -> "proof is missing from the exact app path we are trying to trust"; "The draft says simple simple, so the next words should" -> "keep moving in plain language without adding a new topic or pitch".
        More long examples: "The draft feels calmer when it" -> "stays short and specific while still giving the reader enough context to decide what happens next"; "The review should focus on" -> "real user risk in the exact flow people are trying to use today"; "After the demo, capture the" -> "open questions quickly so the next pass starts from what people actually noticed"; "Product update should mention" -> "one clear change and the proof that it works in the real app"; "Press Tab and confirm" -> "the next word stays visible so the second accept still feels natural".
        Correction exception: "Correct this spelling: recieve ->" -> "receive"; "adress ->" -> "address"; "seperate ->" -> "separate"; "calender ->" -> "calendar"; "occured ->" -> "occurred". Return one corrected word only for explicit spelling correction prompts.
        Do not copy the example topics. For ordinary drafting at this high setting, do not return a 1-4 word answer.
        """
    }

    private func styleLengthGuidance(forVisibleWords visibleWords: Int) -> String {
        guard visibleWords >= 12 else {
            return ""
        }

        return "Length setting overrides recent short-kept history. Use the style sketch for tone and casing, not to shrink the suggestion below the high word-count target."
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
