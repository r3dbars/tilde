import Foundation

/// Rejects a suggestion that merely reads the screen back. The output
/// cleaner already refuses to replay the user's typed text; this is the
/// same idea for the injected scene context. Found 2026-08-23 while
/// evaluating prompt formats: a model reply can be a verbatim line from
/// the conversation block ("Them: are you still coming"), which reads as
/// nonsense ghost text.
public enum SceneEchoPolicy {
    /// True when the suggestion is substantially a fragment of a scene
    /// turn or reference snippet. Short overlaps ("ok", "see you") are
    /// normal language reuse, not echoes; an echo needs at least three
    /// words and ten characters of contiguous overlap.
    public static func isEcho(_ suggestionText: String, scene: ScreenScene.Scene?) -> Bool {
        guard let scene else { return false }
        let candidate = normalized(suggestionText)
        guard candidate.count >= 10, candidate.split(separator: " ").count >= 3 else { return false }
        let sources = scene.conversationTurns.map(\.text) + scene.referenceSnippets
        for source in sources {
            let text = normalized(source)
            if text.contains(candidate) { return true }
        }
        return false
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}
