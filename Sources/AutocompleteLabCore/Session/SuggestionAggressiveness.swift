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
            return "Proactive"
        }
    }

    public var pace: SuggestionPace {
        switch self {
        case .quiet:
            return .quiet
        case .normal:
            return .normal
        case .eager:
            return .eager
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
        SuggestionTriggerPolicy(pace: pace)
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
                wordCompletionThreshold: 0.40,
                phraseContinuationThreshold: 0.65,
                sentenceContinuationThreshold: 0.85
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
