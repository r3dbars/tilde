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
    case lowConfidence = "low-confidence"
    case learnedRestraint = "learned-restraint"
    case lowAcceptedAndKeptProbability = "low-accepted-and-kept-probability"
    case belowThreshold = "below-threshold"
}

public enum DisplayScoreSuppressionBrain: String, Equatable, Sendable {
    case current
    case oneBrainPreview = "one-brain-preview"

    public static let environmentFlag = "STEADYTYPE_ONE_BRAIN_SUPPRESSION"

    public static func fromEnvironment(_ environment: [String: String]) -> DisplayScoreSuppressionBrain {
        guard let value = environment[environmentFlag] else {
            return .current
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on", oneBrainPreview.rawValue:
            return .oneBrainPreview
        default:
            return .current
        }
    }
}

public struct DisplayScoreTrace: Equatable, Sendable {
    public let score: DisplayScore
    public let mode: CompletionRequestMode
    public let behaviorProfileID: AutocompleteBehaviorProfileID?
    public let threshold: Double
    public let effectiveFinalScore: Double
    public let learningRestraintScoreScale: Double
    public let acceptedAndKeptProbabilityThreshold: Double

    public init(
        score: DisplayScore,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        threshold: Double,
        effectiveFinalScore: Double? = nil,
        learningRestraintScoreScale: Double = 1,
        acceptedAndKeptProbabilityThreshold: Double
    ) {
        self.score = score
        self.mode = mode
        self.behaviorProfileID = behaviorProfileID
        self.threshold = threshold
        self.effectiveFinalScore = DisplayScore.bounded(
            effectiveFinalScore ?? score.finalScore,
            to: DisplayScore.scoreBounds
        )
        self.learningRestraintScoreScale = max(0, learningRestraintScoreScale)
        self.acceptedAndKeptProbabilityThreshold = acceptedAndKeptProbabilityThreshold
    }

    public var metadata: [String: String] {
        var metadata = score.traceMetadata
        metadata["displayScoreMode"] = mode.rawValue
        if let behaviorProfileID {
            metadata["displayScoreBehaviorProfile"] = behaviorProfileID.rawValue
        }
        metadata["displayScoreThreshold"] = DisplayScore.format(threshold)
        metadata["displayScoreEffectiveFinal"] = DisplayScore.format(effectiveFinalScore)
        metadata["displayScoreLearningRestraintScale"] = DisplayScore.format(learningRestraintScoreScale)
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
    public let acceptedAndKeptProbabilityMultiplier: Double
    public let learningRestraintScoreScale: Double

    public init(
        wordCompletionThreshold: Double = 0.60,
        phraseContinuationThreshold: Double = 1.10,
        sentenceContinuationThreshold: Double = 1.25,
        highRiskThreshold: Double = 0.85,
        highRepetitionThreshold: Double = 0.85,
        highInstabilityThreshold: Double = 0.85,
        minimumAcceptedAndKeptSamples: Int = 6,
        acceptedAndKeptProbabilityMultiplier: Double = 1,
        learningRestraintScoreScale: Double = 1
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
        self.acceptedAndKeptProbabilityMultiplier = max(0, acceptedAndKeptProbabilityMultiplier)
        self.learningRestraintScoreScale = max(0, learningRestraintScoreScale)
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
        guard adjustment != 0 else {
            return self
        }

        return DisplayScorePolicy(
            wordCompletionThreshold: wordCompletionThreshold + adjustment,
            phraseContinuationThreshold: phraseContinuationThreshold + adjustment,
            sentenceContinuationThreshold: sentenceContinuationThreshold + adjustment,
            highRiskThreshold: highRiskThreshold,
            highRepetitionThreshold: highRepetitionThreshold,
            highInstabilityThreshold: highInstabilityThreshold,
            minimumAcceptedAndKeptSamples: minimumAcceptedAndKeptSamples,
            acceptedAndKeptProbabilityMultiplier: acceptedAndKeptProbabilityMultiplier,
            learningRestraintScoreScale: learningRestraintScoreScale
        )
    }

    public func withLearningRestraint(
        acceptedAndKeptProbabilityMultiplier: Double,
        learningRestraintScoreScale: Double,
        minimumAcceptedAndKeptSamples: Int
    ) -> DisplayScorePolicy {
        DisplayScorePolicy(
            wordCompletionThreshold: wordCompletionThreshold,
            phraseContinuationThreshold: phraseContinuationThreshold,
            sentenceContinuationThreshold: sentenceContinuationThreshold,
            highRiskThreshold: highRiskThreshold,
            highRepetitionThreshold: highRepetitionThreshold,
            highInstabilityThreshold: highInstabilityThreshold,
            minimumAcceptedAndKeptSamples: minimumAcceptedAndKeptSamples,
            acceptedAndKeptProbabilityMultiplier: acceptedAndKeptProbabilityMultiplier,
            learningRestraintScoreScale: learningRestraintScoreScale
        )
    }

    public func decision(
        for score: DisplayScore,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        suppressionBrain: DisplayScoreSuppressionBrain = .current
    ) -> DisplayScoreDecision {
        let effectiveFinalScore = effectiveFinalScore(for: score)
        let trace = DisplayScoreTrace(
            score: score,
            mode: mode,
            behaviorProfileID: behaviorProfileID,
            threshold: threshold(for: mode),
            effectiveFinalScore: effectiveFinalScore,
            learningRestraintScoreScale: learningRestraintScoreScale,
            acceptedAndKeptProbabilityThreshold: acceptedAndKeptProbabilityThreshold(
                for: mode,
                behaviorProfileID: behaviorProfileID
            )
        )

        switch suppressionBrain {
        case .current:
            return currentDecision(for: score, trace: trace)
        case .oneBrainPreview:
            return oneBrainPreviewDecision(for: score, trace: trace)
        }
    }

    private func currentDecision(
        for score: DisplayScore,
        trace: DisplayScoreTrace
    ) -> DisplayScoreDecision {
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

        guard trace.effectiveFinalScore >= trace.threshold else {
            return .suppress(DisplayScoreSuppression(reason: .belowThreshold, trace: trace))
        }

        return .display(trace)
    }

    private func oneBrainPreviewDecision(
        for score: DisplayScore,
        trace: DisplayScoreTrace
    ) -> DisplayScoreDecision {
        if score.risk >= highRiskThreshold {
            return .suppress(DisplayScoreSuppression(reason: .highRisk, trace: trace))
        }

        guard trace.effectiveFinalScore >= trace.threshold else {
            return .suppress(DisplayScoreSuppression(
                reason: bindingReason(for: score, trace: trace),
                trace: trace
            ))
        }

        return .display(trace)
    }

    private func bindingReason(
        for score: DisplayScore,
        trace: DisplayScoreTrace
    ) -> DisplayScoreSuppressionReason {
        let gap = trace.threshold - trace.effectiveFinalScore
        guard gap > 0 else {
            return .belowThreshold
        }

        let candidates = bindingPenaltyCandidates(for: score, trace: trace)
        if let flippingCandidate = candidates
            .filter({ trace.effectiveFinalScore + $0.penalty >= trace.threshold })
            .sorted(by: bindingCandidateSort)
            .first {
            return flippingCandidate.reason
        }

        return .belowThreshold
    }

    private func bindingPenaltyCandidates(
        for score: DisplayScore,
        trace: DisplayScoreTrace
    ) -> [(reason: DisplayScoreSuppressionReason, penalty: Double, priority: Int)] {
        var candidates: [(reason: DisplayScoreSuppressionReason, penalty: Double, priority: Int)] = []

        if score.repetition > 0 {
            candidates.append((.highRepetition, score.repetition, 0))
        }

        if score.instability > 0 {
            candidates.append((.highInstability, score.instability, 1))
        }

        let effectiveLearningPenalty = score.learningRestraint * learningRestraintScoreScale
        if effectiveLearningPenalty > 0 {
            candidates.append((.learnedRestraint, effectiveLearningPenalty, 2))
        }

        if let acceptedAndKeptProbability = score.acceptedAndKeptProbability,
           score.acceptedAndKeptSampleCount >= minimumAcceptedAndKeptSamples,
           acceptedAndKeptProbability < trace.acceptedAndKeptProbabilityThreshold,
           effectiveLearningPenalty <= 0 {
            candidates.append((.lowAcceptedAndKeptProbability, trace.threshold - trace.effectiveFinalScore, 3))
        }

        return candidates
    }

    private func bindingCandidateSort(
        _ lhs: (reason: DisplayScoreSuppressionReason, penalty: Double, priority: Int),
        _ rhs: (reason: DisplayScoreSuppressionReason, penalty: Double, priority: Int)
    ) -> Bool {
        if abs(lhs.penalty - rhs.penalty) > 0.0001 {
            return lhs.penalty < rhs.penalty
        }

        return lhs.priority < rhs.priority
    }

    public func acceptedAndKeptProbabilityThreshold(
        for mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> Double {
        let baseThreshold: Double = switch mode {
        case .wordCompletion:
            0.20
        case .phraseContinuation:
            0.30
        case .sentenceContinuation:
            0.18
        }

        let profileFloor: Double
        if let behaviorProfileID {
            profileFloor = switch behaviorProfileID {
            case .aiChat:
                switch mode {
                case .wordCompletion:
                    0.28
                case .phraseContinuation, .sentenceContinuation:
                    0.34
                }
            case .casualChat:
                switch mode {
                case .wordCompletion:
                    0.22
                case .phraseContinuation, .sentenceContinuation:
                    0.30
                }
            case .docsProse, .email, .notes:
                switch mode {
                case .wordCompletion:
                    0.20
                case .phraseContinuation:
                    0.32
                case .sentenceContinuation:
                    0.22
                }
            case .coding:
                switch mode {
                case .wordCompletion:
                    0.22
                case .phraseContinuation, .sentenceContinuation:
                    0.32
                }
            case .bullets:
                switch mode {
                case .wordCompletion:
                    0.20
                case .phraseContinuation, .sentenceContinuation:
                    0.28
                }
            case .forms, .search:
                0.30
            }
        } else {
            profileFloor = baseThreshold
        }

        return max(baseThreshold, profileFloor) * acceptedAndKeptProbabilityMultiplier
    }

    public func effectiveFinalScore(for score: DisplayScore) -> Double {
        DisplayScore.bounded(
            score.finalScore + score.learningRestraint * (1 - learningRestraintScoreScale),
            to: DisplayScore.scoreBounds
        )
    }
}
