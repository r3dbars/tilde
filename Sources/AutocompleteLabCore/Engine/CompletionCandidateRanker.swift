import Foundation

public struct RankedCompletionCandidate: Equatable, Sendable {
    public let suggestion: CompletionSuggestion
    public let score: Double

    public init(suggestion: CompletionSuggestion, score: Double) {
        self.suggestion = suggestion
        self.score = score
    }
}

public enum CompletionCandidateSuppressionReason: String, Equatable, Sendable {
    case noCandidates = "no-candidates"
    case lowTopScore = "low-top-score"
    case lowScoreMargin = "low-score-margin"
}

public struct CompletionCandidateSelection: Equatable, Sendable {
    public let rankedCandidates: [RankedCompletionCandidate]
    public let selectedCandidate: RankedCompletionCandidate?
    public let scoreMargin: Double?
    public let suppressionReason: CompletionCandidateSuppressionReason?

    public init(
        rankedCandidates: [RankedCompletionCandidate],
        selectedCandidate: RankedCompletionCandidate?,
        scoreMargin: Double?,
        suppressionReason: CompletionCandidateSuppressionReason?
    ) {
        self.rankedCandidates = rankedCandidates
        self.selectedCandidate = selectedCandidate
        self.scoreMargin = scoreMargin
        self.suppressionReason = suppressionReason
    }

    public var suggestion: CompletionSuggestion? {
        selectedCandidate?.suggestion
    }
}

public struct CompletionCandidateRanker: Equatable, Sendable {
    public let minimumScoreMargin: Double

    public init(minimumScoreMargin: Double = 0.05) {
        self.minimumScoreMargin = max(0, minimumScoreMargin)
    }

    public func ranked(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil
    ) -> [RankedCompletionCandidate] {
        suggestions
            .map { suggestion in
                RankedCompletionCandidate(
                    suggestion: suggestion,
                    score: score(suggestion, mode: mode, textBeforeCursor: textBeforeCursor)
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
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil
    ) -> CompletionSuggestion? {
        selection(suggestions, mode: mode, textBeforeCursor: textBeforeCursor).suggestion
    }

    public func selection(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil
    ) -> CompletionCandidateSelection {
        let rankedCandidates = ranked(suggestions, mode: mode, textBeforeCursor: textBeforeCursor)

        guard let topCandidate = rankedCandidates.first else {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: nil,
                suppressionReason: .noCandidates
            )
        }

        guard topCandidate.score >= minimumTopScore(for: mode) else {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: nil,
                suppressionReason: .lowTopScore
            )
        }

        let scoreMargin = rankedCandidates.dropFirst().first.map { topCandidate.score - $0.score }
        if let scoreMargin, scoreMargin < minimumScoreMargin {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: scoreMargin,
                suppressionReason: .lowScoreMargin
            )
        }

        return CompletionCandidateSelection(
            rankedCandidates: rankedCandidates,
            selectedCandidate: topCandidate,
            scoreMargin: scoreMargin,
            suppressionReason: nil
        )
    }

    private func score(
        _ suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        textBeforeCursor: String?
    ) -> Double {
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
            score -= sentencePlanningDriftPenalty(visibleText)
        }

        if mode.isContinuation {
            score += localContextAlignmentScore(visibleText, textBeforeCursor: textBeforeCursor)
            score -= unsupportedCommitmentPenalty(visibleText, textBeforeCursor: textBeforeCursor)
            score -= genericFillerPenalty(visibleText)
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

    private func minimumTopScore(for mode: CompletionRequestMode) -> Double {
        switch mode {
        case .wordCompletion:
            return 0.80
        case .phraseContinuation:
            return 0.78
        case .sentenceContinuation:
            return 0.82
        }
    }

    private func localContextAlignmentScore(_ text: String, textBeforeCursor: String?) -> Double {
        guard let textBeforeCursor else {
            return 0
        }

        let localWords = Set(contentWords(in: textBeforeCursor.suffix(240)))
        guard !localWords.isEmpty else {
            return 0
        }

        let candidateWords = Set(contentWords(in: text))
        guard !candidateWords.isEmpty else {
            return 0
        }

        return localWords.isDisjoint(with: candidateWords) ? 0 : 0.06
    }

    private func unsupportedCommitmentPenalty(_ text: String, textBeforeCursor: String?) -> Double {
        guard let textBeforeCursor,
              !textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let contextWords = Set(contentWords(in: textBeforeCursor))
        let unsupportedProperNouns = properNounTokens(in: text)
            .filter { !contextWords.contains($0.lowercased()) }
        let unsupportedDates = dateOrDeadlineWords(in: text)
            .filter { !contextWords.contains($0) }

        var penalty = min(0.30, Double(unsupportedProperNouns.count) * 0.15)
        if !unsupportedDates.isEmpty {
            penalty += 0.18
        }
        return penalty
    }

    private func genericFillerPenalty(_ text: String) -> Double {
        let words = Set(contentWords(in: text))
        let fillerWords: Set<String> = [
            "enhance", "enhanced", "enhancing",
            "leverage", "leveraging",
            "optimize", "optimized", "optimizing",
            "robust", "seamless", "seamlessly",
            "streamline", "streamlined", "unlock"
        ]

        return words.isDisjoint(with: fillerWords) ? 0 : 0.22
    }

    private func sentencePlanningDriftPenalty(_ text: String) -> Double {
        let normalized = normalizedPhrase(text)
        let planningPrefixes = [
            "action item", "let's", "lets", "make sure to", "next step",
            "the next step", "then we can", "we can", "we should",
            "you can", "you should"
        ]
        if planningPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return 0.30
        }

        let planningWords: Set<String> = [
            "roadmap", "schedule", "sprint", "task", "timeline"
        ]
        return Set(contentWords(in: text)).isDisjoint(with: planningWords) ? 0 : 0.18
    }

    private func properNounTokens(in text: String) -> [String] {
        let rawTokens = text
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        return rawTokens.enumerated().compactMap { index, token in
            guard index > 0,
                  token.count > 1,
                  token.first?.isUppercase == true,
                  token.dropFirst().allSatisfy(\.isLowercase) else {
                return nil
            }
            return token
        }
    }

    private func dateOrDeadlineWords(in text: String) -> [String] {
        let words = contentWords(in: text)
        let deadlineWords: Set<String> = [
            "today", "tomorrow", "tonight",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        return words.filter { deadlineWords.contains($0) }
    }

    private func contentWords<S: StringProtocol>(in text: S) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !Self.stopWords.contains($0) && $0.count > 2 }
    }

    private func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static let stopWords: Set<String> = [
        "and", "are", "but", "can", "for", "from", "had", "has", "have",
        "her", "his", "its", "not", "our", "out", "she", "that", "the",
        "their", "then", "this", "was", "with", "you", "your"
    ]
}
