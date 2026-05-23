import Foundation

public struct CommonPhraseContinuationPrior: Equatable, Sendable {
    public let contextSuffix: String
    public let continuation: String
    public let score: Double

    public init(contextSuffix: String, continuation: String, score: Double) {
        self.contextSuffix = Self.normalizedPhrase(contextSuffix)
        self.continuation = Self.normalizedPhrase(continuation)
        self.score = score
    }

    public var continuationWords: [String] {
        Self.words(in: continuation)
    }

    public static let defaultPriors: [CommonPhraseContinuationPrior] = [
        CommonPhraseContinuationPrior(contextSuffix: "we should keep this", continuation: "small", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "the draft is almost", continuation: "ready", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "please make this", continuation: "clearer", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "this feels genuinely", continuation: "useful", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "i just wanted to", continuation: "follow up", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "i think we should", continuation: "make sure", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "when this works we can", continuation: "keep moving", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "the app should", continuation: "stay quiet", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "can you please", continuation: "take a look", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "we should probably", continuation: "keep it simple", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i want to", continuation: "move this forward", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "it would help to", continuation: "make it easier", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the most important thing is to", continuation: "keep the scope small", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "i am trying to", continuation: "figure out how to", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "this sentence should continue", continuation: "without sounding too formal", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "the safest version is to", continuation: "make this easier to", score: 0.26)
    ]

    private static func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func words(in text: String) -> [String] {
        normalizedPhrase(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

public struct CommonPhraseContinuationSelection: Equatable, Sendable {
    public let suggestion: CompletionSuggestion?
    public let matchedContextSuffix: String?
    public let score: Double?
    public let suppressionReason: String?

    public init(
        suggestion: CompletionSuggestion?,
        matchedContextSuffix: String?,
        score: Double?,
        suppressionReason: String?
    ) {
        self.suggestion = suggestion
        self.matchedContextSuffix = matchedContextSuffix
        self.score = score
        self.suppressionReason = suppressionReason
    }

    public var traceMetadata: [String: String] {
        [
            "candidateSelectionSource": "predictive-phrase-fallback",
            "cleanedCandidateCount": suggestion == nil ? "0" : "1",
            "candidateTopScore": score.map { String(format: "%.3f", $0) } ?? "none",
            "candidateScoreMargin": "none",
            "candidateSuppressionReason": suppressionReason ?? "none",
            "predictivePhraseMatch": matchedContextSuffix ?? "none"
        ]
    }
}

public struct CommonPhraseContinuationPredictor: Equatable, Sendable {
    public let priors: [CommonPhraseContinuationPrior]

    public init(priors: [CommonPhraseContinuationPrior] = CommonPhraseContinuationPrior.defaultPriors) {
        self.priors = priors
    }

    public func suggestion(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4
    ) -> CompletionSuggestion? {
        selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords
        ).suggestion
    }

    public func selection(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(for: behaviorProfileID) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "unsupported-profile"
            )
        }

        let trimmed = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, last.isLetter || last.isNumber else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "not-word-boundary"
            )
        }

        let context = normalizedPhrase(trimmed)
        guard !context.isEmpty else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "empty-context"
            )
        }

        guard let prior = bestPrior(for: context) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "no-match"
            )
        }

        let clampedMaxWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        let suggestion = CompletionSuggestion(
            text: " \(prior.continuation)",
            maxVisibleWords: clampedMaxWords
        )

        return CommonPhraseContinuationSelection(
            suggestion: suggestion,
            matchedContextSuffix: prior.contextSuffix,
            score: prior.score,
            suppressionReason: nil
        )
    }

    private func bestPrior(for context: String) -> CommonPhraseContinuationPrior? {
        priors
            .filter { context.hasSuffix($0.contextSuffix) }
            .sorted {
                let lhsWords = $0.contextSuffix.split(separator: " ").count
                let rhsWords = $1.contextSuffix.split(separator: " ").count
                if lhsWords != rhsWords {
                    return lhsWords > rhsWords
                }

                return $0.score > $1.score
            }
            .first
    }

    private func allowsPrediction(for behaviorProfileID: AutocompleteBehaviorProfileID?) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat), .some(.coding), .some(.forms), .some(.search):
            false
        case .some, .none:
            true
        }
    }

    private func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
