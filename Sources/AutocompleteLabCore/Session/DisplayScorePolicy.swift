import Foundation

public struct DisplayScore: Equatable, Sendable {
    public static let componentBounds: ClosedRange<Double> = 0...1
    public static let scoreBounds: ClosedRange<Double> = -3...4

    public let utility: Double
    public let styleFit: Double
    public let contextFit: Double
    public let userAffinity: Double
    public let risk: Double
    public let repetition: Double
    public let instability: Double
    public let learningRestraint: Double
    public let acceptedAndKeptProbability: Double?
    public let acceptedAndKeptSampleCount: Int
    public let acceptedAndKeptUtilityAdjustment: Double

    public init(
        utility: Double,
        styleFit: Double,
        contextFit: Double,
        userAffinity: Double,
        risk: Double,
        repetition: Double,
        instability: Double,
        learningRestraint: Double = 0,
        acceptedAndKeptProbability: Double? = nil,
        acceptedAndKeptSampleCount: Int = 0,
        acceptedAndKeptUtilityAdjustment: Double = 0
    ) {
        self.utility = Self.component(utility)
        self.styleFit = Self.component(styleFit)
        self.contextFit = Self.component(contextFit)
        self.userAffinity = Self.component(userAffinity)
        self.risk = Self.component(risk)
        self.repetition = Self.component(repetition)
        self.instability = Self.component(instability)
        self.learningRestraint = Self.component(learningRestraint)
        self.acceptedAndKeptProbability = acceptedAndKeptProbability.map(Self.component)
        self.acceptedAndKeptSampleCount = max(0, acceptedAndKeptSampleCount)
        self.acceptedAndKeptUtilityAdjustment = Self.bounded(
            acceptedAndKeptUtilityAdjustment,
            to: -1...1
        )
    }

    public var rawScore: Double {
        utility
            + styleFit
            + contextFit
            + userAffinity
            - risk
            - repetition
            - instability
            - learningRestraint
    }

    public var finalScore: Double {
        Self.bounded(rawScore, to: Self.scoreBounds)
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "displayScoreUtility": Self.format(utility),
            "displayScoreStyleFit": Self.format(styleFit),
            "displayScoreContextFit": Self.format(contextFit),
            "displayScoreUserAffinity": Self.format(userAffinity),
            "displayScoreRisk": Self.format(risk),
            "displayScoreRepetition": Self.format(repetition),
            "displayScoreInstability": Self.format(instability),
            "displayScoreLearningRestraint": Self.format(learningRestraint),
            "displayScoreRaw": Self.format(rawScore),
            "displayScoreFinal": Self.format(finalScore)
        ]
        if let acceptedAndKeptProbability {
            metadata["displayScoreAcceptedAndKeptProbability"] = Self.format(acceptedAndKeptProbability)
            metadata["displayScoreAcceptedAndKeptSamples"] = String(acceptedAndKeptSampleCount)
            metadata["displayScoreAcceptedAndKeptUtilityAdjustment"] =
                Self.format(acceptedAndKeptUtilityAdjustment)
        }
        return metadata
    }

    private static func component(_ value: Double) -> Double {
        bounded(value, to: componentBounds)
    }

    static func bounded(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public enum DisplayScoreSuppressionReason: String, Equatable, Sendable {
    case highRisk = "high-risk"
    case highRepetition = "high-repetition"
    case highInstability = "high-instability"
    case tooSlowToDisplay = "too-slow-to-display"
    case lowAcceptedAndKeptProbability = "low-accepted-and-kept-probability"
    case belowThreshold = "below-threshold"
}

public struct DisplayScoreTrace: Equatable, Sendable {
    public let score: DisplayScore
    public let mode: CompletionRequestMode
    public let behaviorProfileID: AutocompleteBehaviorProfileID?
    public let threshold: Double
    public let acceptedAndKeptProbabilityThreshold: Double

    public init(
        score: DisplayScore,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        threshold: Double,
        acceptedAndKeptProbabilityThreshold: Double
    ) {
        self.score = score
        self.mode = mode
        self.behaviorProfileID = behaviorProfileID
        self.threshold = threshold
        self.acceptedAndKeptProbabilityThreshold = acceptedAndKeptProbabilityThreshold
    }

    public var metadata: [String: String] {
        var metadata = score.traceMetadata
        metadata["displayScoreMode"] = mode.rawValue
        if let behaviorProfileID {
            metadata["displayScoreBehaviorProfile"] = behaviorProfileID.rawValue
        }
        metadata["displayScoreThreshold"] = DisplayScore.format(threshold)
        if score.acceptedAndKeptProbability != nil {
            metadata["displayScoreAcceptedAndKeptThreshold"] =
                DisplayScore.format(acceptedAndKeptProbabilityThreshold)
        }
        return metadata
    }
}

public struct DisplayScoreSuppression: Equatable, Sendable {
    public let reason: DisplayScoreSuppressionReason
    public let trace: DisplayScoreTrace

    public init(
        reason: DisplayScoreSuppressionReason,
        trace: DisplayScoreTrace
    ) {
        self.reason = reason
        self.trace = trace
    }

    public var metadata: [String: String] {
        var metadata = trace.metadata
        metadata["displayScoreDecision"] = "suppress"
        metadata["displayScoreSuppressionReason"] = reason.rawValue
        return metadata
    }
}

public enum DisplayScoreDecision: Equatable, Sendable {
    case display(DisplayScoreTrace)
    case suppress(DisplayScoreSuppression)

    public var shouldDisplay: Bool {
        switch self {
        case .display:
            true
        case .suppress:
            false
        }
    }

    public var trace: DisplayScoreTrace {
        switch self {
        case let .display(trace):
            trace
        case let .suppress(suppression):
            suppression.trace
        }
    }

    public var metadata: [String: String] {
        switch self {
        case let .display(trace):
            var metadata = trace.metadata
            metadata["displayScoreDecision"] = "display"
            return metadata
        case let .suppress(suppression):
            return suppression.metadata
        }
    }
}

public struct DisplayScorePolicy: Equatable, Sendable {
    public let wordCompletionThreshold: Double
    public let phraseContinuationThreshold: Double
    public let sentenceContinuationThreshold: Double
    public let highRiskThreshold: Double
    public let highRepetitionThreshold: Double
    public let highInstabilityThreshold: Double
    public let minimumAcceptedAndKeptSamples: Int

    public init(
        wordCompletionThreshold: Double = 0.60,
        phraseContinuationThreshold: Double = 1.00,
        sentenceContinuationThreshold: Double = 1.20,
        highRiskThreshold: Double = 0.85,
        highRepetitionThreshold: Double = 0.85,
        highInstabilityThreshold: Double = 0.85,
        minimumAcceptedAndKeptSamples: Int = 6
    ) {
        self.wordCompletionThreshold = DisplayScore.bounded(
            wordCompletionThreshold,
            to: DisplayScore.scoreBounds
        )
        self.phraseContinuationThreshold = DisplayScore.bounded(
            phraseContinuationThreshold,
            to: DisplayScore.scoreBounds
        )
        self.sentenceContinuationThreshold = DisplayScore.bounded(
            sentenceContinuationThreshold,
            to: DisplayScore.scoreBounds
        )
        self.highRiskThreshold = DisplayScore.bounded(highRiskThreshold, to: DisplayScore.componentBounds)
        self.highRepetitionThreshold = DisplayScore.bounded(highRepetitionThreshold, to: DisplayScore.componentBounds)
        self.highInstabilityThreshold = DisplayScore.bounded(highInstabilityThreshold, to: DisplayScore.componentBounds)
        self.minimumAcceptedAndKeptSamples = max(1, minimumAcceptedAndKeptSamples)
    }

    public func threshold(for mode: CompletionRequestMode) -> Double {
        switch mode {
        case .wordCompletion:
            wordCompletionThreshold
        case .sentenceContinuation:
            sentenceContinuationThreshold
        case .phraseContinuation:
            phraseContinuationThreshold
        }
    }

    public func adjustingThresholds(by adjustment: Double) -> DisplayScorePolicy {
        let safeAdjustment = max(0, adjustment)
        guard safeAdjustment > 0 else {
            return self
        }

        return DisplayScorePolicy(
            wordCompletionThreshold: wordCompletionThreshold + safeAdjustment,
            phraseContinuationThreshold: phraseContinuationThreshold + safeAdjustment,
            sentenceContinuationThreshold: sentenceContinuationThreshold + safeAdjustment,
            highRiskThreshold: highRiskThreshold,
            highRepetitionThreshold: highRepetitionThreshold,
            highInstabilityThreshold: highInstabilityThreshold,
            minimumAcceptedAndKeptSamples: minimumAcceptedAndKeptSamples
        )
    }

    public func decision(
        for score: DisplayScore,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> DisplayScoreDecision {
        let trace = DisplayScoreTrace(
            score: score,
            mode: mode,
            behaviorProfileID: behaviorProfileID,
            threshold: threshold(for: mode),
            acceptedAndKeptProbabilityThreshold: acceptedAndKeptProbabilityThreshold(
                for: mode,
                behaviorProfileID: behaviorProfileID
            )
        )

        if score.risk >= highRiskThreshold {
            return .suppress(DisplayScoreSuppression(reason: .highRisk, trace: trace))
        }

        if score.repetition >= highRepetitionThreshold {
            return .suppress(DisplayScoreSuppression(reason: .highRepetition, trace: trace))
        }

        if score.instability >= highInstabilityThreshold {
            return .suppress(DisplayScoreSuppression(reason: .highInstability, trace: trace))
        }

        if let acceptedAndKeptProbability = score.acceptedAndKeptProbability,
           score.acceptedAndKeptSampleCount >= minimumAcceptedAndKeptSamples,
           acceptedAndKeptProbability < trace.acceptedAndKeptProbabilityThreshold {
            return .suppress(DisplayScoreSuppression(reason: .lowAcceptedAndKeptProbability, trace: trace))
        }

        guard score.finalScore >= trace.threshold else {
            return .suppress(DisplayScoreSuppression(reason: .belowThreshold, trace: trace))
        }

        return .display(trace)
    }

    public func acceptedAndKeptProbabilityThreshold(
        for mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> Double {
        let baseThreshold: Double = switch mode {
        case .wordCompletion:
            0.20
        case .phraseContinuation:
            0.12
        case .sentenceContinuation:
            0.18
        }

        guard let behaviorProfileID else {
            return baseThreshold
        }

        let profileFloor: Double = switch behaviorProfileID {
        case .aiChat:
            switch mode {
            case .wordCompletion:
                0.28
            case .phraseContinuation, .sentenceContinuation:
                0.24
            }
        case .casualChat:
            switch mode {
            case .wordCompletion:
                0.22
            case .phraseContinuation, .sentenceContinuation:
                0.20
            }
        case .docsProse, .email, .notes:
            switch mode {
            case .wordCompletion:
                0.20
            case .phraseContinuation:
                0.16
            case .sentenceContinuation:
                0.22
            }
        case .coding:
            switch mode {
            case .wordCompletion:
                0.22
            case .phraseContinuation, .sentenceContinuation:
                0.18
            }
        case .bullets:
            switch mode {
            case .wordCompletion:
                0.20
            case .phraseContinuation, .sentenceContinuation:
                0.14
            }
        case .forms, .search:
            0.30
        }

        return max(baseThreshold, profileFloor)
    }
}
