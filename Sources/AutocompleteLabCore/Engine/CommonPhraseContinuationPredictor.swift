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
        CommonPhraseContinuationPrior(contextSuffix: "we should keep this", continuation: "small", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "the draft is almost", continuation: "ready", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "please make this", continuation: "clearer", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "this feels genuinely", continuation: "useful", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "i just wanted to", continuation: "follow up", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i think we should", continuation: "make sure", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "sounds good", continuation: "to me", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "that makes sense", continuation: "to me", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i can take", continuation: "a look", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "can you please", continuation: "take a look", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "let me know", continuation: "what you think", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "we should probably", continuation: "keep it simple", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "it would help to", continuation: "make this clearer", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "thanks for", continuation: "sending this over", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "before we move on", continuation: "capture the next step", score: 0.24),
        CommonPhraseContinuationPrior(contextSuffix: "the main thing is", continuation: "to keep this clear", score: 0.24),
        CommonPhraseContinuationPrior(contextSuffix: "what i need is", continuation: "a clearer next step", score: 0.24),
        CommonPhraseContinuationPrior(contextSuffix: "next step is", continuation: "to make this concrete", score: 0.24)
    ]

    private static func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    public let candidateSelectionSource: String
    public let matchMetadataKey: String

    public init(
        suggestion: CompletionSuggestion?,
        matchedContextSuffix: String?,
        score: Double?,
        suppressionReason: String?,
        candidateSelectionSource: String = "canned-bridge",
        matchMetadataKey: String = "cannedBridgeMatch"
    ) {
        self.suggestion = suggestion
        self.matchedContextSuffix = matchedContextSuffix
        self.score = score
        self.suppressionReason = suppressionReason
        self.candidateSelectionSource = candidateSelectionSource
        self.matchMetadataKey = matchMetadataKey
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "candidateSelectionSource": candidateSelectionSource,
            "cleanedCandidateCount": suggestion == nil ? "0" : "1",
            "candidateTopScore": score.map { String(format: "%.3f", $0) } ?? "none",
            "candidateScoreMargin": "none",
            "candidateSuppressionReason": suppressionReason ?? "none"
        ]
        metadata[matchMetadataKey] = matchedContextSuffix ?? "none"
        return metadata
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
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CompletionSuggestion? {
        selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        ).suggestion
    }

    public func selection(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(
            for: behaviorProfileID,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        ) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "unsupported-profile"
            )
        }

        let trimmed = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "empty-context"
            )
        }

        guard let last = trimmed.last, last.isLetter || last.isNumber else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "not-word-boundary"
            )
        }

        let context = normalizedPhrase(trimmed)
        guard let prior = bestPrior(for: context) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "no-match"
            )
        }

        return CommonPhraseContinuationSelection(
            suggestion: CompletionSuggestion(
                text: " \(prior.continuation)",
                maxVisibleWords: CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
            ),
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

    private func allowsPrediction(
        for behaviorProfileID: AutocompleteBehaviorProfileID?,
        allowsPromptAppPrediction: Bool
    ) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat):
            allowsPromptAppPrediction
        case .some(.coding), .some(.forms), .some(.search):
            false
        case .some, .none:
            true
        }
    }

    private func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
