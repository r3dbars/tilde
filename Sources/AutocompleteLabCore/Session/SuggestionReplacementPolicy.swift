import Foundation

public enum SuggestionReplacementSuppressionReason: String, Equatable, Sendable {
    case freshVisibleSuggestion = "fresh-visible-suggestion"
    case changedFirstWord = "changed-first-word"
    case lowScoreMargin = "low-score-margin"
}

public struct SuggestionReplacementDecision: Equatable, Sendable {
    public let shouldPresent: Bool
    public let reason: SuggestionReplacementSuppressionReason?
    public let currentAgeMilliseconds: Int?
    public let scoreMargin: Double?

    public init(
        shouldPresent: Bool,
        reason: SuggestionReplacementSuppressionReason? = nil,
        currentAgeMilliseconds: Int? = nil,
        scoreMargin: Double? = nil
    ) {
        self.shouldPresent = shouldPresent
        self.reason = reason
        self.currentAgeMilliseconds = currentAgeMilliseconds
        self.scoreMargin = scoreMargin
    }

    public var metadata: [String: String] {
        var metadata = [
            "replacementDecision": shouldPresent ? "present" : "suppress"
        ]
        if let reason {
            metadata["replacementSuppressionReason"] = reason.rawValue
        }
        if let currentAgeMilliseconds {
            metadata["replacementCurrentAgeMs"] = String(currentAgeMilliseconds)
        }
        if let scoreMargin {
            metadata["replacementScoreMargin"] = String(format: "%.2f", scoreMargin)
        }
        return metadata
    }
}

public struct SuggestionReplacementPolicy: Equatable, Sendable {
    public let minimumFreshLifetimeMilliseconds: Int
    public let staleLifetimeMilliseconds: Int
    public let minimumScoreMargin: Double

    public init(
        minimumFreshLifetimeMilliseconds: Int = 1_200,
        staleLifetimeMilliseconds: Int = 2_000,
        minimumScoreMargin: Double = 0.35
    ) {
        self.minimumFreshLifetimeMilliseconds = max(0, minimumFreshLifetimeMilliseconds)
        self.staleLifetimeMilliseconds = max(
            self.minimumFreshLifetimeMilliseconds,
            staleLifetimeMilliseconds
        )
        self.minimumScoreMargin = max(0, minimumScoreMargin)
    }

    public func decision(
        currentVisibleText: String?,
        proposedVisibleText: String,
        currentSuggestionID: String?,
        proposedSuggestionID: String,
        currentAgeMilliseconds: Int?,
        currentScore: Double?,
        proposedScore: Double
    ) -> SuggestionReplacementDecision {
        guard let currentVisibleText,
              !currentVisibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SuggestionReplacementDecision(shouldPresent: true)
        }

        let currentText = normalizedVisibleText(currentVisibleText)
        let proposedText = normalizedVisibleText(proposedVisibleText)
        if currentText.isEmpty || currentText == proposedText {
            return SuggestionReplacementDecision(shouldPresent: true)
        }

        guard let currentAgeMilliseconds else {
            return SuggestionReplacementDecision(shouldPresent: true)
        }

        let scoreMargin = currentScore.map { proposedScore - $0 }
        if firstWord(in: currentText) != firstWord(in: proposedText) {
            return SuggestionReplacementDecision(
                shouldPresent: false,
                reason: .changedFirstWord,
                currentAgeMilliseconds: currentAgeMilliseconds,
                scoreMargin: scoreMargin
            )
        }

        if currentSuggestionID == proposedSuggestionID {
            return SuggestionReplacementDecision(
                shouldPresent: true,
                currentAgeMilliseconds: currentAgeMilliseconds,
                scoreMargin: scoreMargin
            )
        }

        if currentAgeMilliseconds < minimumFreshLifetimeMilliseconds {
            if let scoreMargin, scoreMargin >= minimumScoreMargin {
                return SuggestionReplacementDecision(
                    shouldPresent: true,
                    currentAgeMilliseconds: currentAgeMilliseconds,
                    scoreMargin: scoreMargin
                )
            }
            return SuggestionReplacementDecision(
                shouldPresent: false,
                reason: .freshVisibleSuggestion,
                currentAgeMilliseconds: currentAgeMilliseconds,
                scoreMargin: scoreMargin
            )
        }

        if currentAgeMilliseconds < staleLifetimeMilliseconds,
           let scoreMargin,
           scoreMargin < minimumScoreMargin {
            return SuggestionReplacementDecision(
                shouldPresent: false,
                reason: .lowScoreMargin,
                currentAgeMilliseconds: currentAgeMilliseconds,
                scoreMargin: scoreMargin
            )
        }

        return SuggestionReplacementDecision(
            shouldPresent: true,
            currentAgeMilliseconds: currentAgeMilliseconds,
            scoreMargin: scoreMargin
        )
    }

    private func normalizedVisibleText(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstWord(in text: String) -> String? {
        text.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    }
}
