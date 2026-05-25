import Foundation

public enum SuggestionStatusText {
    public static func shown(
        mode: CompletionRequestMode,
        triggerReason: String,
        latencyMilliseconds: Int,
        metadata: [String: String]
    ) -> String {
        let modeLabel = label(for: mode)
        let source = metadata["candidateSelectionSource"] ?? triggerReason
        let sourceLabel = label(forSource: source)
        return "Shown: \(modeLabel) \(sourceLabel) \(latencyMilliseconds)ms"
    }

    private static func label(for mode: CompletionRequestMode) -> String {
        switch mode {
        case .wordCompletion:
            return "word"
        case .phraseContinuation:
            return "phrase"
        case .sentenceContinuation:
            return "sentence"
        }
    }

    private static func label(forSource source: String) -> String {
        switch source {
        case "fast-word-completion", "predictive-word-fallback":
            return "fast fallback"
        case "predictive-phrase-fallback":
            return "instant fallback"
        case "app-model-result", "model-candidate-ranker", "model-result":
            return "model"
        default:
            let normalized = source
                .split(separator: "-")
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "unknown" : normalized
        }
    }
}
