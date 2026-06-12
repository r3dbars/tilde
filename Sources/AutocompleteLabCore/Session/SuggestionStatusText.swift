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

    public static func notShown(reason: String) -> String {
        switch reason {
        case "empty-suggestion", "no-suggestion", "no-candidates", "low-top-score":
            return "Quiet: no useful suggestion"
        case "no-fast-word-candidate":
            return "Quiet: no fast word match"
        case "missing-anchor":
            return "Blocked: no cursor position"
        case "repeated-miss":
            return "Blocked: repeated miss"
        case "fast-phrase-learning-restraint":
            return "Quiet: recent rejects"
        case "engine-error":
            return "Blocked: model error"
        case "stale-request", "stale-field", "stale-after-keydown", "stale-text", "stale-focused-context":
            return "Blocked: stale text"
        case "too-slow-to-display":
            return "Blocked: too slow"
        default:
            let normalized = normalizedLabel(reason)
            return "Blocked: \(normalized.isEmpty ? "unknown reason" : normalized)"
        }
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
        case "doc-local-ngram":
            return "doc local"
        case "model-cache", "model-session-cache":
            return "model cache"
        case "predictive-phrase-fallback":
            return "legacy instant"
        case "app-model-result", "model-candidate-ranker", "model-result":
            return "model"
        default:
            let normalized = normalizedLabel(source)
            return normalized.isEmpty ? "unknown" : normalized
        }
    }

    private static func normalizedLabel(_ value: String) -> String {
        value
            .split(separator: "-")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
