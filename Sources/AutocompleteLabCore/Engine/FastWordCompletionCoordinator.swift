import Foundation

public enum FastWordCompletionSuppressionReason: String, Equatable, Sendable {
    case repeatedMiss = "repeated-miss"
    case noFastWordCandidate = "no-fast-word-candidate"
}

public struct FastWordCompletionSuppression: Equatable, Sendable {
    public let reason: FastWordCompletionSuppressionReason
    public let suggestion: CompletionSuggestion?

    public init(
        reason: FastWordCompletionSuppressionReason,
        suggestion: CompletionSuggestion? = nil
    ) {
        self.reason = reason
        self.suggestion = suggestion
    }
}

public enum FastWordCompletionPlan: Equatable, Sendable {
    case notWordCompletion
    case present(CompletionSuggestion)
    case suppress(FastWordCompletionSuppression)
}

public struct FastWordCompletionCoordinator: Equatable, Sendable {
    public var ranker: WordCompletionCandidateRanker

    public init(ranker: WordCompletionCandidateRanker = WordCompletionCandidateRanker()) {
        self.ranker = ranker
    }

    public func plan(
        request: CompletionRequest,
        recentWords: [String],
        repetitionSuppressor: SuggestionRepetitionSuppressor,
        scope: String
    ) -> FastWordCompletionPlan {
        guard request.mode == .wordCompletion else {
            return .notWordCompletion
        }

        guard let suggestion = ranker.suggestion(
            for: request.textBeforeCursor,
            recentWords: recentWords
        ) else {
            return .suppress(FastWordCompletionSuppression(reason: .noFastWordCandidate))
        }

        guard !repetitionSuppressor.shouldSuppress(
            suggestion.visibleText,
            mode: request.mode,
            scope: scope
        ) else {
            return .suppress(FastWordCompletionSuppression(
                reason: .repeatedMiss,
                suggestion: suggestion
            ))
        }

        return .present(suggestion)
    }
}
