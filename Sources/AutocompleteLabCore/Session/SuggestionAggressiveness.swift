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

    public var defaultTuningLevel: Int {
        switch self {
        case .quiet:
            1
        case .normal:
            2
        case .eager:
            4
        }
    }
}

public struct SuggestionTuning: Equatable, Sendable {
    public static let minimumAggressivenessLevel = 1
    public static let maximumAggressivenessLevel = 5
    public static let defaultAggressivenessLevel = SuggestionAggressiveness.normal.defaultTuningLevel

    public let aggressivenessLevel: Int
    public let maxVisibleWords: Int

    public init(
        aggressivenessLevel: Int = Self.defaultAggressivenessLevel,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.aggressivenessLevel = Self.clampedAggressivenessLevel(aggressivenessLevel)
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
    }

    public init(
        aggressiveness: SuggestionAggressiveness,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.init(
            aggressivenessLevel: aggressiveness.defaultTuningLevel,
            maxVisibleWords: maxVisibleWords
        )
    }

    public static func clampedAggressivenessLevel(_ value: Int) -> Int {
        min(maximumAggressivenessLevel, max(minimumAggressivenessLevel, value))
    }

    public var displayName: String {
        switch aggressivenessLevel {
        case 1:
            "Quiet"
        case 2:
            "Normal"
        case 3:
            "Proactive"
        case 4:
            "Very Proactive"
        default:
            "Max"
        }
    }

    public var detailText: String {
        switch aggressivenessLevel {
        case 1:
            "Waits longer and needs stronger scores before showing."
        case 2:
            "Shows a little sooner with balanced filtering."
        case 3:
            "Predicts partial words and starts phrase help after short pauses."
        case 4:
            "Shows quickly, allows starter phrases, and needs less confidence."
        default:
            "Shows as soon as the safety checks allow."
        }
    }

    public var pace: SuggestionPace {
        switch aggressivenessLevel {
        case 1:
            .quiet
        case 2:
            .normal
        default:
            .eager
        }
    }

    public var legacyAggressiveness: SuggestionAggressiveness {
        switch aggressivenessLevel {
        case 1:
            .quiet
        case 2:
            .normal
        default:
            .eager
        }
    }

    public var displayScorePolicy: DisplayScorePolicy {
        switch aggressivenessLevel {
        case 1:
            SuggestionAggressiveness.quiet.displayScorePolicy
        case 2:
            SuggestionAggressiveness.normal.displayScorePolicy
        case 3:
            DisplayScorePolicy(
                wordCompletionThreshold: 0.45,
                phraseContinuationThreshold: 0.75,
                sentenceContinuationThreshold: 0.95
            )
        case 4:
            SuggestionAggressiveness.eager.displayScorePolicy
        default:
            DisplayScorePolicy(
                wordCompletionThreshold: 0.35,
                phraseContinuationThreshold: 0.55,
                sentenceContinuationThreshold: 0.75
            )
        }
    }

    public func activationPolicy(supportPace: SuggestionPace) -> CompletionActivationPolicy {
        guard supportPace == .eager else {
            return CompletionActivationPolicy(pace: supportPace)
        }

        if aggressivenessLevel >= 5 {
            return CompletionActivationPolicy(
                minimumContextCharacters: 1,
                minimumContextWords: 1,
                minimumPhraseContinuationWords: 1,
                minimumWordCompletionCharacters: 1,
                maximumWordCompletionCharacters: 18,
                allowsTerminalSentenceBoundary: true,
                allowsUnfinishedWordPhraseContinuation: true
            )
        }

        if aggressivenessLevel >= 4 {
            return CompletionActivationPolicy(
                minimumContextCharacters: 1,
                minimumContextWords: 1,
                minimumPhraseContinuationWords: 1,
                minimumWordCompletionCharacters: 2,
                maximumWordCompletionCharacters: 16,
                allowsTerminalSentenceBoundary: true,
                allowsUnfinishedWordPhraseContinuation: true
            )
        }

        return CompletionActivationPolicy(pace: .eager)
    }

    public func triggerPolicy(supportPace: SuggestionPace) -> SuggestionTriggerPolicy {
        guard supportPace == .eager else {
            return SuggestionTriggerPolicy(pace: supportPace)
        }

        switch aggressivenessLevel {
        case 3:
            return SuggestionTriggerPolicy(pace: .eager)
        case 4:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 20,
                wordBoundaryDelayMilliseconds: 40,
                softPunctuationDelayMilliseconds: 90,
                structuralPunctuationDelayMilliseconds: 90,
                closingPunctuationDelayMilliseconds: 90,
                sentenceBoundaryDelayMilliseconds: 120,
                pauseDelayMilliseconds: 40,
                minimumWordCompletionCharacters: 2,
                allowsPlainLineStartWordCompletion: true,
                allowsPlainLineStartPhraseContinuation: true,
                allowsSentenceBoundaryRequest: true
            )
        case 5:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 20,
                wordBoundaryDelayMilliseconds: 20,
                softPunctuationDelayMilliseconds: 40,
                structuralPunctuationDelayMilliseconds: 40,
                closingPunctuationDelayMilliseconds: 40,
                sentenceBoundaryDelayMilliseconds: 60,
                pauseDelayMilliseconds: 20,
                minimumWordCompletionCharacters: 1,
                allowsPlainLineStartWordCompletion: true,
                allowsPlainLineStartPhraseContinuation: true,
                allowsSentenceBoundaryRequest: true
            )
        default:
            return SuggestionTriggerPolicy(pace: supportPace)
        }
    }

    public var traceMetadata: [String: String] {
        [
            "suggestionAggressiveness": legacyAggressiveness.rawValue,
            "suggestionAggressivenessDisplayName": displayName,
            "suggestionAggressivenessLevel": String(aggressivenessLevel),
            "suggestionMaxVisibleWords": String(maxVisibleWords)
        ]
    }
}
