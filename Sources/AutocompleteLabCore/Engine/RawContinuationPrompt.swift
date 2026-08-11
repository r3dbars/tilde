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

    /// Suggested generation budget: chat wants shorter bursts; prose/email get
    /// room to finish the clause (cut-off fragments were the top quality wart).
    public var generatedTokenBudget: Int {
        return self == .chat ? 14 : 20
    }
}

public struct RawContinuationPrompt: Equatable, Sendable {
    public let prompt: String
    public let contextEndedInWhitespace: Bool

    public static func scaffold(for register: ContinuationRegister) -> String {
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

    /// `register` selects the scaffold voice from the host app's identity.
    public init(
        textBeforeCursor: String,
        register: ContinuationRegister = .prose,
        maxContextCharacters: Int = 3000
    ) {
        let tail = String(textBeforeCursor.suffix(max(80, maxContextCharacters)))
        let trimmed = String(
            tail.reversed().drop(while: { $0.isWhitespace }).reversed()
        )
        contextEndedInWhitespace = trimmed.count != tail.count

        if trimmed.isEmpty {
            prompt = ""
            return
        }

        prompt = Self.scaffold(for: register) + "Text: " + trimmed + "\nContinuation:"
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
