import Foundation

/// The raw-completion recipe for chat-tuned models served without a chat
/// template (llama.cpp `/completion`). Discovered 2026-07-22 (see
/// docs/ime-tuning-log.md): chat mode makes "thinking-first" models like
/// Gemma 4 deliberate or narrate instead of continuing; raw mode with a short
/// documents-being-continued scaffold produces natural, in-voice
/// continuations. The context is sent WITHOUT its trailing whitespace (models
/// continue cleanly from a word boundary and emit the separating space
/// themselves); callers use `contextEndedInWhitespace` to trim the duplicate
/// leading space from the model's output.
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

    /// Suggested generation budget: chat wants shorter bursts; prose/email get
    /// room to finish the clause (cut-off fragments were the top quality wart).
    public var generatedTokenBudget: Int {
        // Tuning-sweep override: STEADYTYPE_TOKEN_BUDGET forces the budget for
        // all registers (the driver sweeps this against the frozen quiz).
        if let raw = ProcessInfo.processInfo.environment["STEADYTYPE_TOKEN_BUDGET"],
           let value = Int(raw), value > 0 {
            return value
        }
        return self == .chat ? 14 : 20
    }
}

public struct RawContinuationPrompt: Equatable, Sendable {
    public let prompt: String
    public let contextEndedInWhitespace: Bool

    public static func scaffold(for register: ContinuationRegister) -> String {
        // Tuning-sweep override: STEADYTYPE_SCAFFOLD_<REGISTER>_FILE points at a
        // ready-made scaffold block (see script/mine_scaffolds.py). Lets the
        // driver A/B example sets without rebuilding. Absent/unreadable → builtin.
        let envKey = "STEADYTYPE_SCAFFOLD_\(register.rawValue.uppercased())_FILE"
        if let path = ProcessInfo.processInfo.environment[envKey],
           let contents = try? String(contentsOfFile: path, encoding: .utf8),
           !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return contents
        }
        switch register {
        case .chat:
            return """
            The following are real chat messages being written by their authors, continued naturally in the same casual voice.

            Text: yeah I think we can
            Continuation: make that work by friday.

            Text: lol ok that's fair,
            Continuation: let's just ship it and see.

            Text: running like 10 min late but
            Continuation: save me a seat, almost there.


            """
        case .email:
            return """
            The following are real emails being written by their authors, continued naturally.

            Text: I wanted to follow up on our call from
            Continuation: yesterday afternoon about the launch timeline.

            Text: Thanks for sending this over — I'll review it
            Continuation: tonight and get you notes by tomorrow.

            Text: Following up on last week's discussion, I think the
            Continuation: revised timeline is workable if we start now.


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


            """
        }
    }

    /// `screenContext` is the OCR snapshot of the writer's screen (frozen per
    /// typing burst upstream, so it stays inside the server's cacheable prompt
    /// prefix). It is framed as reference notes, never as text to continue.
    /// `register` selects the scaffold voice from the host app's identity.
    public init(
        textBeforeCursor: String,
        screenContext: String? = nil,
        register: ContinuationRegister = .prose,
        maxContextCharacters: Int = 3000,
        maxScreenContextCharacters: Int = 700
    ) {
        let tail = String(textBeforeCursor.suffix(max(80, maxContextCharacters)))
        let trimmed = String(
            tail.reversed().drop(while: { $0.isWhitespace }).reversed()
        )
        contextEndedInWhitespace = trimmed.count != tail.count

        var pieces = Self.scaffold(for: register)
        if let screenContext {
            let bounded = String(screenContext.prefix(max(120, maxScreenContextCharacters)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !bounded.isEmpty {
                // Screen framing is tunable (STEADYTYPE_SCREEN_FRAMING): the
                // vague "notes" framing barely helps the model RESPOND to what's
                // on screen; a direct "reply" framing tells it the screen is the
                // message being answered. See the screen-response experiments.
                let framing = ProcessInfo.processInfo.environment["STEADYTYPE_SCREEN_FRAMING"] ?? "notes"
                switch framing {
                case "reply":
                    pieces += """
                    The writer is replying to this message on screen. Respond to it directly — \
                    answer its questions and use its topic and names; never copy it verbatim:
                    \(bounded)


                    """
                case "minimal":
                    pieces += "On screen:\n\(bounded)\n\n\n"
                default:
                    pieces += """
                    Reference notes visible on the writer's screen (may be a message being replied to, \
                    a document being discussed, or unrelated windows — use names and topics from it \
                    when they fit; never copy or continue it):
                    \(bounded)


                    """
                }
            }
        }
        prompt = pieces + "Text: " + trimmed + "\nContinuation:"
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

    /// Cutoff repair, applied both to the raw generation AND after any display
    /// word-cap (the cap can re-create a dangler from a finished sentence):
    /// when text ends mid-word-stream (no terminal punctuation), trailing
    /// never-end-on words are trimmed back to a complete-feeling phrase.
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
