import Foundation

public struct RankedCompletionCandidate: Equatable, Sendable {
    public let suggestion: CompletionSuggestion
    public let score: Double

    public init(suggestion: CompletionSuggestion, score: Double) {
        self.suggestion = suggestion
        self.score = score
    }
}

public struct CompletionCandidateRanker: Equatable, Sendable {
    public init() {}

    public func ranked(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode
    ) -> [RankedCompletionCandidate] {
        suggestions
            .map { suggestion in
                RankedCompletionCandidate(
                    suggestion: suggestion,
                    score: score(suggestion, mode: mode)
                )
            }
            .sorted {
                if abs($0.score - $1.score) > 0.0001 {
                    return $0.score > $1.score
                }

                return $0.suggestion.visibleText.count < $1.suggestion.visibleText.count
            }
    }

    public func best(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode
    ) -> CompletionSuggestion? {
        ranked(suggestions, mode: mode).first?.suggestion
    }

    private func score(_ suggestion: CompletionSuggestion, mode: CompletionRequestMode) -> Double {
        let visibleText = suggestion.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = suggestion.visibleWordCount
        var score = 0.5

        switch mode {
        case .wordCompletion:
            score += visibleText.count <= 12 ? 0.35 : 0.15
            score -= visibleText.contains(where: { !$0.isLetter }) ? 0.45 : 0
        case .phraseContinuation:
            score += phraseLengthScore(wordCount)
            score -= visibleText.hasSuffix("?") ? 0.35 : 0
        case .sentenceContinuation:
            score += sentenceLengthScore(wordCount)
            score -= visibleText.hasSuffix("?") ? 0.35 : 0
        }

        if visibleText.count <= CompletionSuggestion.defaultMaxVisibleCharacters {
            score += 0.10
        }

        return score
    }

    private func phraseLengthScore(_ wordCount: Int) -> Double {
        switch wordCount {
        case 3...4:
            return 0.35
        case 2:
            return 0.26
        case 5:
            return 0.18
        default:
            return 0.08
        }
    }

    private func sentenceLengthScore(_ wordCount: Int) -> Double {
        switch wordCount {
        case 4...6:
            return 0.35
        case 3:
            return 0.26
        case 2:
            return 0.14
        default:
            return 0.08
        }
    }
}
