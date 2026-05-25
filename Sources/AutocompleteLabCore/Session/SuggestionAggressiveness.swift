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
                phraseContinuationThreshold: 1.40,
                sentenceContinuationThreshold: 1.50
            )
        case .normal:
            return DisplayScorePolicy(
                wordCompletionThreshold: 0.55,
                phraseContinuationThreshold: 1.15,
                sentenceContinuationThreshold: 1.25
            )
        case .eager:
            return DisplayScorePolicy(
                wordCompletionThreshold: 0.40,
                phraseContinuationThreshold: 1.00,
                sentenceContinuationThreshold: 1.10
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
    public static let defaultAggressivenessLevel = 4
    public static let defaultMaxVisibleWords = 8
    public static let minimumWordStartCharacters = 1
    public static let maximumWordStartCharacters = 5
    public static let defaultWordStartCharacters = 2
    public static let minimumPhraseStartWords = 1
    public static let maximumPhraseStartWords = 6
    public static let defaultPhraseStartWords = 2
    public static let minimumResponseSpeedLevel = 1
    public static let maximumResponseSpeedLevel = 5
    public static let defaultResponseSpeedLevel = 5
    public static let minimumConfidenceLevel = 1
    public static let maximumConfidenceLevel = 5
    public static let defaultConfidenceLevel = 4
    public static let minimumLearningRestraintLevel = 0
    public static let maximumLearningRestraintLevel = 3
    public static let defaultLearningRestraintLevel = 1
    public static let predictiveFallbackWritingApps: Set<String> = [
        "com.apple.TextEdit",
        "com.apple.Notes",
        "md.obsidian"
    ]

    public let aggressivenessLevel: Int
    public let maxVisibleWords: Int
    public let wordStartCharacters: Int
    public let phraseStartWords: Int
    public let responseSpeedLevel: Int
    public let confidenceLevel: Int
    public let learningRestraintLevel: Int

    public init(
        aggressivenessLevel: Int = Self.defaultAggressivenessLevel,
        maxVisibleWords: Int = Self.defaultMaxVisibleWords,
        wordStartCharacters: Int = Self.defaultWordStartCharacters,
        phraseStartWords: Int = Self.defaultPhraseStartWords,
        responseSpeedLevel: Int = Self.defaultResponseSpeedLevel,
        confidenceLevel: Int = Self.defaultConfidenceLevel,
        learningRestraintLevel: Int = Self.defaultLearningRestraintLevel
    ) {
        self.aggressivenessLevel = Self.clampedAggressivenessLevel(aggressivenessLevel)
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        self.wordStartCharacters = Self.clampedWordStartCharacters(wordStartCharacters)
        self.phraseStartWords = Self.clampedPhraseStartWords(phraseStartWords)
        self.responseSpeedLevel = Self.clampedResponseSpeedLevel(responseSpeedLevel)
        self.confidenceLevel = Self.clampedConfidenceLevel(confidenceLevel)
        self.learningRestraintLevel = Self.clampedLearningRestraintLevel(learningRestraintLevel)
    }

    public init(
        aggressiveness: SuggestionAggressiveness,
        maxVisibleWords: Int = Self.defaultMaxVisibleWords
    ) {
        self.init(
            aggressivenessLevel: aggressiveness.defaultTuningLevel,
            maxVisibleWords: maxVisibleWords
        )
    }

    public static func clampedAggressivenessLevel(_ value: Int) -> Int {
        min(maximumAggressivenessLevel, max(minimumAggressivenessLevel, value))
    }

    public static func clampedWordStartCharacters(_ value: Int) -> Int {
        min(maximumWordStartCharacters, max(minimumWordStartCharacters, value))
    }

    public static func clampedPhraseStartWords(_ value: Int) -> Int {
        min(maximumPhraseStartWords, max(minimumPhraseStartWords, value))
    }

    public static func clampedResponseSpeedLevel(_ value: Int) -> Int {
        min(maximumResponseSpeedLevel, max(minimumResponseSpeedLevel, value))
    }

    public static func clampedConfidenceLevel(_ value: Int) -> Int {
        min(maximumConfidenceLevel, max(minimumConfidenceLevel, value))
    }

    public static func clampedLearningRestraintLevel(_ value: Int) -> Int {
        min(maximumLearningRestraintLevel, max(minimumLearningRestraintLevel, value))
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
            "Fewer suggestions. Waits longer."
        case 2:
            "Balanced suggestions."
        case 3:
            "More suggestions after short pauses."
        case 4:
            "Fast and willing to guess."
        default:
            "Most active. Shows whenever checks allow."
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
        let basePolicy = switch aggressivenessLevel {
        case 1:
            SuggestionAggressiveness.quiet.displayScorePolicy
        case 2:
            SuggestionAggressiveness.normal.displayScorePolicy
        case 3:
            DisplayScorePolicy(
                wordCompletionThreshold: 0.45,
                phraseContinuationThreshold: 1.10,
                sentenceContinuationThreshold: 1.20
            )
        case 4:
            DisplayScorePolicy(
                wordCompletionThreshold: 0.40,
                phraseContinuationThreshold: 1.00,
                sentenceContinuationThreshold: 1.10
            )
        default:
            DisplayScorePolicy(
                wordCompletionThreshold: 0.35,
                phraseContinuationThreshold: 0.90,
                sentenceContinuationThreshold: 1.00
            )
        }
        return basePolicy
            .adjustingThresholds(by: confidenceThresholdAdjustment)
            .withLearningRestraint(
                acceptedAndKeptProbabilityMultiplier: acceptedAndKeptProbabilityMultiplier,
                learningRestraintScoreScale: learningRestraintScoreScale,
                minimumAcceptedAndKeptSamples: minimumAcceptedAndKeptSamples
            )
    }

    public func activationPolicy(
        supportPace: SuggestionPace,
        allowsSentenceBoundaryContinuation: Bool = true,
        minimumPhraseContinuationWords: Int? = nil
    ) -> CompletionActivationPolicy {
        guard supportPace == .eager else {
            return CompletionActivationPolicy(pace: supportPace)
        }

        let allowsTerminalSentenceBoundary = allowsSentenceBoundaryContinuation
            && aggressivenessLevel >= 4
        let phraseContinuationWords = minimumPhraseContinuationWords
            .map(Self.clampedPhraseStartWords) ?? phraseStartWords

        if aggressivenessLevel >= 5 {
            return CompletionActivationPolicy(
                minimumContextCharacters: 1,
                minimumContextWords: 1,
                minimumPhraseContinuationWords: phraseContinuationWords,
                minimumWordCompletionCharacters: wordStartCharacters,
                maximumWordCompletionCharacters: 18,
                allowsTerminalSentenceBoundary: allowsTerminalSentenceBoundary,
                allowsUnfinishedWordPhraseContinuation: true,
                prefersPhraseContinuationForWordFragments: true
            )
        }

        if aggressivenessLevel >= 4 {
            return CompletionActivationPolicy(
                minimumContextCharacters: 1,
                minimumContextWords: 1,
                minimumPhraseContinuationWords: phraseContinuationWords,
                minimumWordCompletionCharacters: wordStartCharacters,
                maximumWordCompletionCharacters: 16,
                allowsTerminalSentenceBoundary: allowsTerminalSentenceBoundary,
                allowsUnfinishedWordPhraseContinuation: true,
                prefersPhraseContinuationForWordFragments: true
            )
        }

        return CompletionActivationPolicy(
            minimumContextCharacters: 1,
            minimumContextWords: 1,
            minimumPhraseContinuationWords: phraseContinuationWords,
            minimumWordCompletionCharacters: wordStartCharacters,
            maximumWordCompletionCharacters: 16,
            allowsTerminalSentenceBoundary: false,
            allowsUnfinishedWordPhraseContinuation: false
        )
    }

    public func triggerPolicy(
        supportPace: SuggestionPace,
        allowsSentenceBoundaryContinuation: Bool = true,
        minimumPhraseContinuationWords: Int? = nil,
        allowsPlainLineStartPhraseContinuation: Bool = false
    ) -> SuggestionTriggerPolicy {
        guard supportPace == .eager else {
            return SuggestionTriggerPolicy(pace: supportPace)
        }

        let allowsSentenceBoundaryRequest = allowsSentenceBoundaryContinuation
            && aggressivenessLevel >= 4
        let phraseContinuationWords = minimumPhraseContinuationWords
            .map(Self.clampedPhraseStartWords) ?? phraseStartWords

        switch aggressivenessLevel {
        case 3:
            return responseSpeedTriggerPolicy
        case 4:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: responseSpeedDelays.wordCompletion,
                wordBoundaryDelayMilliseconds: min(responseSpeedDelays.wordBoundary, 100),
                softPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 140),
                structuralPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 140),
                closingPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 140),
                sentenceBoundaryDelayMilliseconds: min(responseSpeedDelays.sentenceBoundary, 240),
                pauseDelayMilliseconds: min(responseSpeedDelays.pause, 100),
                minimumWordCompletionCharacters: wordStartCharacters,
                minimumPhraseContinuationWords: phraseContinuationWords,
                allowsPlainLineStartWordCompletion: true,
                allowsPlainLineStartPhraseContinuation: allowsPlainLineStartPhraseContinuation,
                allowsSentenceBoundaryRequest: allowsSentenceBoundaryRequest
            )
        case 5:
            return SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: responseSpeedDelays.wordCompletion,
                wordBoundaryDelayMilliseconds: min(responseSpeedDelays.wordBoundary, 80),
                softPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 120),
                structuralPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 120),
                closingPunctuationDelayMilliseconds: min(responseSpeedDelays.punctuation, 120),
                sentenceBoundaryDelayMilliseconds: min(responseSpeedDelays.sentenceBoundary, 200),
                pauseDelayMilliseconds: min(responseSpeedDelays.pause, 80),
                minimumWordCompletionCharacters: wordStartCharacters,
                minimumPhraseContinuationWords: phraseContinuationWords,
                allowsPlainLineStartWordCompletion: true,
                allowsPlainLineStartPhraseContinuation: allowsPlainLineStartPhraseContinuation,
                allowsSentenceBoundaryRequest: allowsSentenceBoundaryRequest
            )
        default:
            return responseSpeedTriggerPolicy
        }
    }

    public func allowsModelWordCompletionFallback(
        visiblePageContextAvailable: Bool
    ) -> Bool {
        aggressivenessLevel >= 4 || visiblePageContextAvailable
    }

    public func allowsPredictiveWordFallback(
        appBundleIdentifier: String,
        visiblePageContextAvailable: Bool
    ) -> Bool {
        if allowsModelWordCompletionFallback(visiblePageContextAvailable: visiblePageContextAvailable) {
            return true
        }

        return Self.predictiveFallbackWritingApps.contains(appBundleIdentifier)
    }

    public func allowsPredictivePhraseFallback(
        appBundleIdentifier: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        visiblePageContextAvailable: Bool
    ) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat), .some(.coding), .some(.forms), .some(.search):
            return false
        case .some, .none:
            break
        }

        if visiblePageContextAvailable || aggressivenessLevel >= 3 {
            return true
        }

        return Self.predictiveFallbackWritingApps.contains(appBundleIdentifier)
            || appBundleIdentifier == "com.google.Chrome"
    }

    public var traceMetadata: [String: String] {
        [
            "suggestionAggressiveness": legacyAggressiveness.rawValue,
            "suggestionAggressivenessDisplayName": displayName,
            "suggestionAggressivenessLevel": String(aggressivenessLevel),
            "suggestionMaxVisibleWords": String(maxVisibleWords),
            "suggestionWordStartCharacters": String(wordStartCharacters),
            "suggestionPhraseStartWords": String(phraseStartWords),
            "suggestionResponseSpeedLevel": String(responseSpeedLevel),
            "suggestionConfidenceLevel": String(confidenceLevel),
            "suggestionLearningRestraintLevel": String(learningRestraintLevel)
        ]
    }

    private var confidenceThresholdAdjustment: Double {
        switch confidenceLevel {
        case 1:
            0.20
        case 2:
            0.10
        case 4:
            -0.10
        case 5:
            -0.20
        default:
            0
        }
    }

    private var acceptedAndKeptProbabilityMultiplier: Double {
        switch learningRestraintLevel {
        case 0:
            0
        case 1:
            0.50
        case 3:
            1.25
        default:
            1
        }
    }

    private var learningRestraintScoreScale: Double {
        switch learningRestraintLevel {
        case 0:
            0
        case 1:
            0.35
        case 3:
            1.25
        default:
            1
        }
    }

    private var minimumAcceptedAndKeptSamples: Int {
        switch learningRestraintLevel {
        case 0:
            Int.max / 4
        case 1:
            12
        case 3:
            3
        default:
            6
        }
    }

    private var responseSpeedTriggerPolicy: SuggestionTriggerPolicy {
        SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 1,
            wordCompletionDelayMilliseconds: responseSpeedDelays.wordCompletion,
            wordBoundaryDelayMilliseconds: responseSpeedDelays.wordBoundary,
            softPunctuationDelayMilliseconds: responseSpeedDelays.punctuation,
            structuralPunctuationDelayMilliseconds: responseSpeedDelays.punctuation,
            closingPunctuationDelayMilliseconds: responseSpeedDelays.punctuation,
            sentenceBoundaryDelayMilliseconds: responseSpeedDelays.sentenceBoundary,
            pauseDelayMilliseconds: responseSpeedDelays.pause,
            minimumWordCompletionCharacters: wordStartCharacters,
            minimumPhraseContinuationWords: phraseStartWords,
            allowsPlainLineStartWordCompletion: true,
            allowsPlainLineStartPhraseContinuation: false,
            allowsSentenceBoundaryRequest: false
        )
    }

    private var responseSpeedDelays: (
        wordCompletion: Int,
        wordBoundary: Int,
        punctuation: Int,
        sentenceBoundary: Int,
        pause: Int
    ) {
        switch responseSpeedLevel {
        case 1:
            (120, 220, 220, 380, 220)
        case 2:
            (80, 180, 200, 300, 180)
        case 4:
            (20, 100, 140, 200, 100)
        case 5:
            (20, 80, 120, 180, 80)
        default:
            (40, 140, 180, 240, 140)
        }
    }
}
