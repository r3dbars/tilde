import Foundation

/// Deterministic silence gates for scene shapes where a small completion
/// model should not be asked to decide what to say. Screen text is untrusted
/// data: quoting it in the prompt prevents structural prompt splicing, but it
/// does not guarantee that the model will ignore an instruction written inside
/// that data. These checks run before inference and therefore cannot be
/// bypassed by sampling configuration or model behavior.
public enum SceneSuggestionPolicy {
    public enum SuppressionReason: String, CaseIterable, Equatable, Sendable {
        case promptInjection = "prompt-injection-scene"
        case noIncomingTurn = "no-incoming-turn"
        case resolvedConversation = "resolved-conversation"
        case ambiguousChoice = "ambiguous-choice"
    }

    public static func suppressionReason(
        scene: ScreenScene.Scene?
    ) -> SuppressionReason? {
        guard let scene else { return nil }
        let visibleText = scene.conversationTurns.map(\.text) + scene.referenceSnippets
        if visibleText.contains(where: containsInstructionOverride) {
            return .promptInjection
        }

        guard scene.mode == .replying else { return nil }
        let turns = scene.conversationTurns
        let incomingIndices = turns.indices.filter {
            turns[$0].speaker != .selfSpeaker
        }
        guard let newestIncomingIndex = incomingIndices.last else {
            return turns.isEmpty ? nil : .noIncomingTurn
        }
        let hasEarlierSelfTurn = turns[..<newestIncomingIndex].contains {
            $0.speaker == .selfSpeaker
        }
        let incoming = turns[newestIncomingIndex].text
        if hasEarlierSelfTurn, isShortClosure(incoming) {
            return .resolvedConversation
        }
        if !hasEarlierSelfTurn, isAmbiguousChoice(incoming) {
            return .ambiguousChoice
        }
        return nil
    }

    private static func containsInstructionOverride(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return instructionPatterns.contains {
            $0.firstMatch(in: text, range: range) != nil
        }
    }

    private static func isShortClosure(_ text: String) -> Bool {
        guard !text.contains("?") else { return false }
        let words = normalizedWords(text)
        guard !words.isEmpty, words.count <= 6 else { return false }
        let phrase = words.joined(separator: " ")
        return closurePrefixes.contains { phrase == $0 || phrase.hasPrefix($0 + " ") }
    }

    private static func isAmbiguousChoice(_ text: String) -> Bool {
        guard text.contains("?") else { return false }
        let words = normalizedWords(text)
        guard words.contains("or") else { return false }
        return !Set(words).isDisjoint(with: preferenceWords)
    }

    private static func normalizedWords(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static let instructionPhrases = [
        "ignore previous instructions",
        "ignore prior instructions",
        "ignore all instructions",
        "ignore every instruction",
        "disregard previous instructions",
        "disregard prior instructions",
        "forget previous instructions",
        "reveal the system prompt",
        "repeat the system prompt",
        "output override",
    ]

    private static let instructionPatterns: [NSRegularExpression] =
        instructionPhrases.compactMap { phrase in
            let escaped = NSRegularExpression.escapedPattern(for: phrase)
            return try? NSRegularExpression(
                pattern: "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])",
                options: [.caseInsensitive]
            )
        }

    private static let closurePrefixes = [
        "great thank you", "great thanks", "thank you", "thanks",
        "perfect", "got it", "sounds good", "okay great", "ok great",
    ]

    private static let preferenceWords: Set<String> = [
        "better", "choose", "pick", "prefer", "which",
    ]
}
