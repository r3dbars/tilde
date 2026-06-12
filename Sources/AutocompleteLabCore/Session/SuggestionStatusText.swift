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
        let policy = SuggestionSilenceExplanationPolicy()
        switch policy.reasonCode(forTraceReason: reason) {
        case .noUsefulSuggestion:
            if reason == "no-fast-word-candidate" {
                return "Quiet: no fast word match"
            }
            return "Quiet: no useful suggestion"
        case .placement where reason == "missing-anchor":
            return "Blocked: no cursor position"
        case .placement:
            return "Blocked: cursor placement"
        case .repetition:
            return "Blocked: repeated miss"
        case .learnedRestraint:
            return "Quiet: recent rejects"
        case .modelError:
            return "Blocked: model error"
        case .staleContext:
            return "Blocked: stale text"
        case .latency:
            return "Blocked: too slow"
        case .confidence:
            return "Blocked: low confidence"
        case .displayScore:
            return "Blocked: display score"
        case .prefixCooldown:
            return "Waiting: recent prefix cooldown"
        case .quietMode:
            return "Waiting: quiet mode"
        case .safety:
            return "Blocked: safety gate"
        case .typingCadence:
            return "Waiting: typing fast"
        case .settingsOrRuntime:
            return "Blocked: suggestions unavailable"
        case .unknown:
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
        case "predictive-phrase-fallback":
            return "instant fallback"
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
