import Foundation

public enum SuggestionAggressiveness: String, Codable, Equatable, Sendable, CaseIterable {
    case quiet
    case normal
    case eager

    public var displayName: String {
        switch self {
        case .quiet:
            return "Quiet"
        case .normal:
            return "Normal"
        case .eager:
            return "Eager"
        }
    }

    public var next: SuggestionAggressiveness {
        switch self {
        case .quiet:
            return .normal
        case .normal:
            return .eager
        case .eager:
            return .quiet
        }
    }

    public static func parsed(_ rawValue: String?) -> SuggestionAggressiveness {
        guard let rawValue else {
            return .normal
        }

        return SuggestionAggressiveness(
            rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ) ?? .normal
    }

    public var triggerPolicy: SuggestionTriggerPolicy {
        switch self {
        case .quiet:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 6,
                wordCompletionDelayMilliseconds: 140,
                wordBoundaryDelayMilliseconds: 240,
                softPunctuationDelayMilliseconds: 240,
                structuralPunctuationDelayMilliseconds: 240,
                closingPunctuationDelayMilliseconds: 220,
                sentenceBoundaryDelayMilliseconds: 450,
                pauseDelayMilliseconds: 240,
                largeTextChangeDelayMilliseconds: 320
            )
        case .normal:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 70,
                wordBoundaryDelayMilliseconds: 100,
                softPunctuationDelayMilliseconds: 140,
                structuralPunctuationDelayMilliseconds: 140,
                closingPunctuationDelayMilliseconds: 140,
                sentenceBoundaryDelayMilliseconds: 260,
                pauseDelayMilliseconds: 100
            )
        case .eager:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 0,
                wordBoundaryDelayMilliseconds: 0,
                softPunctuationDelayMilliseconds: 140,
                structuralPunctuationDelayMilliseconds: 140,
                closingPunctuationDelayMilliseconds: 140,
                sentenceBoundaryDelayMilliseconds: 280,
                pauseDelayMilliseconds: 15
            )
        }
    }

    public var displayScorePolicy: DisplayScorePolicy {
        switch self {
        case .quiet:
            return DisplayScorePolicy(
                wordCompletionThreshold: 0.75,
                phraseContinuationThreshold: 1.25,
                sentenceContinuationThreshold: 1.45
            )
        case .normal:
            return DisplayScorePolicy(
                wordCompletionThreshold: 0.55,
                phraseContinuationThreshold: 0.90,
                sentenceContinuationThreshold: 1.10
            )
        case .eager:
            return DisplayScorePolicy(
                wordCompletionThreshold: 0.50,
                phraseContinuationThreshold: 0.85,
                sentenceContinuationThreshold: 1.05
            )
        }
    }

    public var traceMetadata: [String: String] {
        [
            "suggestionAggressiveness": rawValue,
            "suggestionAggressivenessDisplayName": displayName
        ]
    }
}
