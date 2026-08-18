import Foundation

/// A short raw-completion recipe for the app-owned llama server. The context is
/// sent without trailing whitespace; `contextEndedInWhitespace` removes the
/// model's duplicate leading space from its response.
/// Writing register inferred from the host app — the scaffold's examples teach
/// the model the room's voice (casual chat vs email vs flowing prose).
public enum ContinuationRegister: String, Sendable {
    case chat
    case email
    case prose

    private static let chatBundlePrefixes = [
        "com.tinyspeck.slackmacgap", "com.hnc.Discord", "ru.keepcoder.Telegram",
        "com.apple.MobileSMS", "net.whatsapp.WhatsApp", "com.anthropic.claudefordesktop",
        "com.openai.chat", "com.openai.atlas", "com.facebook.archon", "com.microsoft.teams2",
    ]
    private static let emailBundlePrefixes = [
        "com.apple.mail", "com.microsoft.Outlook", "com.readdle.smartemail",
        "com.superhuman.electron", "com.mimestream.Mimestream", "it.bloop.airmail",
    ]

    public static func from(bundleIdentifier: String?) -> ContinuationRegister {
        guard let bundleIdentifier else { return .prose }
        if chatBundlePrefixes.contains(where: bundleIdentifier.hasPrefix) { return .chat }
        if emailBundlePrefixes.contains(where: bundleIdentifier.hasPrefix) { return .email }
        return .prose
    }

    /// Picks the completion register the way `LlamaCompletionEngine`'s live
    /// socket path does: the classified SCENE wins whenever it says the
    /// user is replying — a chat conversation rendered in a browser or
    /// email client still wants the chat scaffold's short, casual voice,
    /// regardless of what `from(bundleIdentifier:)` would otherwise say
    /// about that host app. The host-app register is only the fallback,
    /// for every other case (`scene` absent/stale, or classified as
    /// `.composing`/`.referencing`) — exactly today's (pre-Screen-Memory)
    /// behavior.
    public static func following(
        scene: ScreenScene.Scene?,
        hostBundleIdentifier: String?
    ) -> ContinuationRegister {
        scene?.mode == .replying ? .chat : from(bundleIdentifier: hostBundleIdentifier)
    }

    /// Suggested generation budget: chat wants shorter bursts; prose/email get
    /// room to finish the clause (cut-off fragments were the top quality wart).
    public var generatedTokenBudget: Int {
        return self == .chat ? 14 : 20
    }

    /// A replying scene reads as rapid-fire when the visible turns' median
    /// length is at or under this many words ("up?", "lol", "u there").
    public static let terseReplyMedianWordThreshold = 3.0
    /// The clamped budget for rapid-fire rooms: one short burst, not a
    /// sentence. Live dogfood (build 2705) showed chat's 14 tokens producing
    /// "here, I am here."-length ghosts in rooms speaking two-word turns.
    public static let terseReplyTokenBudget = 5

    /// Scene-aware budget: same as `generatedTokenBudget` except when the
    /// classified scene says the user is replying to a conversation whose
    /// turns are terse — then the ghost should match the room's rhythm, so
    /// the budget clamps down to `terseReplyTokenBudget`. A `nil`, composing,
    /// or referencing scene (and a replying scene with no measurable turns)
    /// changes nothing.
    public func generatedTokenBudget(scene: ScreenScene.Scene?) -> Int {
        guard let scene, scene.mode == .replying,
              let median = Self.medianTurnWordCount(scene.conversationTurns),
              median <= Self.terseReplyMedianWordThreshold else {
            return generatedTokenBudget
        }
        return min(generatedTokenBudget, Self.terseReplyTokenBudget)
    }

    /// Trusts `turns` as already representing real messages, one per turn.
    /// Code review (P2, verify-then-fix): this was checked against a
    /// concern that `ScreenScene`/`ScreenTextRecognizer` might hand this
    /// function one turn per wrapped Vision OCR *line*, which would make an
    /// ordinary multi-line chat bubble look like several short "terse"
    /// turns and wrongly clamp generation. Verified NOT the case: Vision's
    /// `VNRecognizeTextRequest` does recognize text line by line (see
    /// `ScreenTextRecognizer`), but `ScreenScene.classify` re-groups
    /// adjacent same-speaker OCR lines whose vertical gap is small relative
    /// to their own height back into one `ConversationTurn` before this
    /// function ever runs (see `mergeWrappedLines` in `ScreenScene.swift`),
    /// while genuinely separate same-speaker messages (ordinary bubble
    /// spacing) stay distinct so a real rapid-fire room still clamps. See
    /// `ScreenSceneTests.wrappedBubbleLinesMergeIntoOneTurn` /
    /// `.separateSameSpeakerMessagesStayDistinct` for the upstream proof,
    /// and `terseClampSurvivesAWrappedMultiLineBubble` below for an
    /// end-to-end version through this function.
    private static func medianTurnWordCount(_ turns: [ScreenScene.ConversationTurn]) -> Double? {
        let counts = turns
            .map { $0.text.split(whereSeparator: \.isWhitespace).count }
            .filter { $0 > 0 }
            .sorted()
        guard !counts.isEmpty else { return nil }
        let middle = counts.count / 2
        return counts.count.isMultiple(of: 2)
            ? Double(counts[middle - 1] + counts[middle]) / 2
            : Double(counts[middle])
    }
}

public struct RawContinuationPrompt: Equatable, Sendable {
    public let prompt: String
    public let contextEndedInWhitespace: Bool

    /// Whether `text` ends at a word boundary — the same predicate that
    /// produces `contextEndedInWhitespace` above, exposed statically so
    /// callers that never build a full prompt (e.g. the socket host's
    /// personal-suggestion gate) can still ask "is the last word actually
    /// finished?" before treating the tail as complete words.
    public static func endsAtWordBoundary(_ text: String) -> Bool {
        text.last?.isWhitespace ?? false
    }

    public static func scaffold(for register: ContinuationRegister) -> String {
        switch register {
        case .chat:
            return """
            Real chat messages, continued naturally in the same casual voice.

            Text: yeah I think we can
            Continuation: make that work by friday.

            Text: running like 10 min late but
            Continuation: save me a seat, almost there.


            """
        case .email:
            return """
            Real emails, continued naturally.

            Text: I wanted to follow up on our call from
            Continuation: yesterday afternoon about the launch timeline.

            Text: Thanks for sending this over — I'll review it
            Continuation: tonight and get you notes by tomorrow.


            """
        case .prose:
            return """
            The following are real documents being written by their authors, continued naturally.

            Text: I wanted to follow up on our call from
            Continuation: yesterday afternoon about the launch timeline.

            Text: honestly the new setup is working better
            Continuation: than I expected, we should keep it.

            Text: The results suggest two things. First, the approach
            Continuation: scales well beyond the original design load.

            Text: It rained most of the weekend, so we ended up
            Continuation: staying in and finally organizing the garage.

            Text: What surprised me most about the whole trip was
            Continuation: how quickly the days started to blur together.

            Text: I keep coming back to the same conclusion:
            Continuation: the simplest version of the plan is the right one.


            """
        }
    }

    /// Screen Memory plan Phase 2 PR 2b: the most a screen-context block may
    /// spend of the shared budget, regardless of how much the field text
    /// left over. Keeps a near-empty field from handing the whole 3,000-char
    /// budget to OCR'd screen text.
    public static let maxSceneContextCharacters = 1_000

    /// `register` selects the scaffold voice from the host app's identity.
    /// `scene` is Screen Memory's classified on-screen context (Phase 2 PR
    /// 2a) — `nil` (no capture, capture disabled/no-permission, or stale)
    /// reproduces today's prompt exactly, byte for byte; this is the
    /// fallback behavior degraded mode (Screen Recording permission denied,
    /// or the user's own toggle off) relies on.
    ///
    /// Budgeting: field text is computed first, from the full
    /// `maxContextCharacters` budget, same as before Screen Memory existed —
    /// it always gets everything it needs (up to that budget) and is never
    /// shrunk to make room for screen context. The scene context block only
    /// spends what's left of that same budget afterward, capped at
    /// `maxSceneContextCharacters` — "field text always wins ties."
    public init(
        textBeforeCursor: String,
        register: ContinuationRegister = .prose,
        scene: ScreenScene.Scene? = nil,
        maxContextCharacters: Int = 3000
    ) {
        let totalBudget = max(80, maxContextCharacters)
        let tail = String(textBeforeCursor.suffix(totalBudget))
        let trimmed = String(
            tail.reversed().drop(while: { $0.isWhitespace }).reversed()
        )
        contextEndedInWhitespace = trimmed.count != tail.count

        if trimmed.isEmpty {
            prompt = ""
            return
        }

        let remainingForScene = max(0, totalBudget - trimmed.count)
        let sceneBudget = min(Self.maxSceneContextCharacters, remainingForScene)
        let sceneBlock = Self.sceneContextBlock(for: scene, budget: sceneBudget)

        prompt = Self.scaffold(for: register) + sceneBlock + "Text: " + trimmed + "\nContinuation:"
    }

    /// Renders the classified scene into the prompt shape the plan
    /// specifies per mode, then truncates to whatever budget is left —
    /// truncation only ever bites when the field text has already claimed
    /// most of `maxContextCharacters`, since `ScreenScene` itself already
    /// caps turns/snippets well under `maxSceneContextCharacters`.
    ///
    /// OCR'd screen text is untrusted the same way pasted or typed text is:
    /// it can contain a card number, an API key, a JWT sitting in a log
    /// pane, etc. `SecretRules.scrub(..., config: .forPromptContext)` runs
    /// on every turn and snippet before it is interpolated into the prompt
    /// — structured secrets are replaced with a `⟨redacted:type⟩` token
    /// (never persisted, never sent to the model) while ordinary
    /// conversational text passes through unchanged.
    private static func sceneContextBlock(for scene: ScreenScene.Scene?, budget: Int) -> String {
        guard let scene, budget > 0 else { return "" }
        switch scene.mode {
        case .replying:
            guard !scene.conversationTurns.isEmpty else { return "" }
            let lines = scene.conversationTurns.map {
                "\($0.speaker == .selfSpeaker ? "You" : "Them"): \(scrubbedForPrompt($0.text))"
            }
            return truncatedBlock(header: "Conversation:\n", body: lines.joined(separator: "\n"), budget: budget)
        case .referencing:
            guard let snippet = scene.referenceSnippets.first else { return "" }
            return truncatedBlock(header: "Reference:\n", body: scrubbedForPrompt(snippet), budget: budget)
        case .composing:
            return ""
        }
    }

    private static func scrubbedForPrompt(_ text: String) -> String {
        SecretRules.scrub(text, config: .forPromptContext).clean
    }

    /// The blank line that always separates a scene block from the `Text:`
    /// line that follows it in the assembled prompt.
    private static let sceneBlockTrailer = "\n\n"

    /// Renders `header + body + sceneBlockTrailer`, truncating only `body`
    /// when the combination doesn't fit `budget` — the header and trailing
    /// blank line are never chopped. A truncated header, or a block missing
    /// its trailing separator, can silently fuse into whatever text follows
    /// it in the prompt (a chopped `Conversation:` header, or a dangling
    /// scene fragment running straight into the `Text:` line) — both worse
    /// than simply omitting screen context for this one request. If there
    /// isn't even room for the header plus the trailer, the whole block is
    /// dropped.
    private static func truncatedBlock(header: String, body: String, budget: Int) -> String {
        let full = header + body + sceneBlockTrailer
        guard full.count > budget else { return full }
        let reserved = header.count + sceneBlockTrailer.count
        guard reserved < budget else { return "" }
        let truncatedBody = String(body.prefix(budget - reserved))
        guard !truncatedBody.isEmpty else { return "" }
        return header + truncatedBody + sceneBlockTrailer
    }

    /// Words a suggestion should never END on — a trailing article/preposition/
    /// conjunction is the signature of a token-limit cutoff mid-clause
    /// ("…thoughts on the"). Trimming them back yields a complete-feeling
    /// phrase ("…thoughts").
    private static let neverEndOn: Set<String> = [
        "a", "an", "the", "of", "on", "in", "to", "at", "by", "as", "if",
        "and", "or", "but", "with", "for", "from", "that", "than", "so",
        "my", "your", "our", "their", "his", "her", "its", "is", "are",
        "was", "be", "been", "will", "would", "can", "could", "should",
        "very", "more", "most", "quite", "really",
    ]

    /// Normalizes a raw model continuation against the original context: strips
    /// the model's separating space when the user already typed one, cuts at
    /// the first newline (raw mode can run on), and trims token-limit cutoffs
    /// so the ghost never dangles mid-clause.
    public func normalizedContinuation(_ rawOutput: String) -> String {
        var text = rawOutput
        if let newline = text.firstIndex(where: \.isNewline) {
            text = String(text[..<newline])
        }
        if contextEndedInWhitespace {
            text = String(text.drop(while: { $0 == " " }))
        }
        return Self.repairDanglingTail(text)
    }

    /// Apply this to raw output and to the display-capped suggestion: a cap can
    /// expose a trailing function word from an otherwise complete sentence.
    public static func repairDanglingTail(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last, last.isLetter || last.isNumber else {
            return text
        }
        var words = trimmed.split(separator: " ").map(String.init)
        while let tail = words.last,
              neverEndOn.contains(tail.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            words.removeLast()
        }
        guard !words.isEmpty else { return text }
        let leadingSpace = text.hasPrefix(" ") ? " " : ""
        return leadingSpace + words.joined(separator: " ")
    }
}
