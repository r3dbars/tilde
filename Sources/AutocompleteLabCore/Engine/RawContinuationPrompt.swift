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
public struct RawContinuationPrompt: Equatable, Sendable {
    public let prompt: String
    public let contextEndedInWhitespace: Bool

    public static let scaffold = """
    The following are real documents being written by their authors, continued naturally.

    Text: I wanted to follow up on our call from
    Continuation: yesterday afternoon about the launch timeline.

    Text: honestly the new setup is working better
    Continuation: than I expected, we should keep it.


    """

    /// `screenContext` is the OCR snapshot of the writer's screen (frozen per
    /// typing burst upstream, so it stays inside the server's cacheable prompt
    /// prefix). It is framed as reference notes, never as text to continue.
    public init(
        textBeforeCursor: String,
        screenContext: String? = nil,
        maxContextCharacters: Int = 1200,
        maxScreenContextCharacters: Int = 700
    ) {
        let tail = String(textBeforeCursor.suffix(max(80, maxContextCharacters)))
        let trimmed = String(
            tail.reversed().drop(while: { $0.isWhitespace }).reversed()
        )
        contextEndedInWhitespace = trimmed.count != tail.count

        var pieces = Self.scaffold
        if let screenContext {
            let bounded = String(screenContext.prefix(max(120, maxScreenContextCharacters)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !bounded.isEmpty {
                pieces += """
                Reference notes visible on the writer's screen (may be a message being replied to, \
                a document being discussed, or unrelated windows — use names and topics from it \
                when they fit; never copy or continue it):
                \(bounded)


                """
            }
        }
        prompt = pieces + "Text: " + trimmed + "\nContinuation:"
    }

    /// Normalizes a raw model continuation against the original context: strips
    /// the model's separating space when the user already typed one, and cuts at
    /// the first newline (raw mode can run on).
    public func normalizedContinuation(_ rawOutput: String) -> String {
        var text = rawOutput
        if let newline = text.firstIndex(where: \.isNewline) {
            text = String(text[..<newline])
        }
        if contextEndedInWhitespace {
            text = String(text.drop(while: { $0 == " " }))
        }
        return text
    }
}
