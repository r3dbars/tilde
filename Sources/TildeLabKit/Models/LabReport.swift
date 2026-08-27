import Foundation

public enum LabCaseOutcome: String, Codable, CaseIterable, Sendable {
    case useful
    case wrong
    case silent
    case correctSilence = "correct-silence"
    case unwanted
    case timeout
    case error
}

/// Separates predicting the user's recorded continuation from offering a
/// different continuation that still follows an explicitly reviewed,
/// human-acceptable answer path.
public enum LabAnswerMatchKind: String, Codable, CaseIterable, Sendable {
    case none
    case exactPrediction = "exact-prediction"
    case acceptableAlternative = "acceptable-alternative"
}

public struct LabCaseResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(scenarioID)#seed-\(generationSeed)#\(repetition)" }

    public let scenarioID: String
    public let category: String
    public let counterfactualPairID: String?
    public let repetition: Int
    public let generationSeed: Int
    public let outcome: LabCaseOutcome
    public let expectedSuggestion: Bool
    public let hasGoldenContinuation: Bool
    public let offered: Bool
    public let modelRequested: Bool
    public let policySuppressed: Bool
    public let exactMatchAt1: Bool
    public let exactMatchAt2: Bool
    public let exactMatchAt3: Bool
    public let exactContinuationMatched: Bool
    public let acceptablePrefixMatched: Bool
    public let acceptableContinuationMatched: Bool
    public let answerMatchKind: LabAnswerMatchKind
    public let requiredTermsSatisfied: Bool
    public let forbiddenTermViolation: Bool
    public let wordLimitViolation: Bool
    public let scenarioSource: LabScenarioSource
    public let corpusID: String?
    public let rootScenarioID: String?
    public let replayCheckpoint: LabReplayCheckpoint
    public let contextVariant: LabContextVariant
    public let temporalIntegrityPassed: Bool
    public let baselineKeystrokes: Int
    public let grossKeystrokesSaved: Int
    public let acceptanceKeystrokes: Int
    public let correctionKeystrokes: Int
    public let dismissalKeystrokes: Int
    public let netKeystrokesSaved: Int
    public let failureCategory: LabFailureCategory
    public let keystrokesSaved: Int
    public let latencyMilliseconds: Int?
    public let firstTokenMilliseconds: Int?
    public let meanTokenProbability: Double?
    public let decisionReason: LabDecisionReason
    public let visibleWordCount: Int
    public let visibleCharacterCount: Int
    public let workerIndex: Int?
    public let candidateCacheHit: Bool?

    public init(
        scenarioID: String,
        category: String,
        counterfactualPairID: String? = nil,
        repetition: Int,
        generationSeed: Int = 0,
        outcome: LabCaseOutcome,
        expectedSuggestion: Bool,
        hasGoldenContinuation: Bool,
        offered: Bool,
        modelRequested: Bool = false,
        policySuppressed: Bool = false,
        exactMatchAt1: Bool = false,
        exactMatchAt2: Bool = false,
        exactMatchAt3: Bool = false,
        exactContinuationMatched: Bool = false,
        acceptablePrefixMatched: Bool = false,
        acceptableContinuationMatched: Bool = false,
        answerMatchKind: LabAnswerMatchKind = .none,
        requiredTermsSatisfied: Bool = true,
        forbiddenTermViolation: Bool = false,
        wordLimitViolation: Bool = false,
        scenarioSource: LabScenarioSource = .synthetic,
        corpusID: String? = nil,
        rootScenarioID: String? = nil,
        replayCheckpoint: LabReplayCheckpoint = .caret,
        contextVariant: LabContextVariant = .structuredThread,
        temporalIntegrityPassed: Bool = true,
        baselineKeystrokes: Int = 0,
        grossKeystrokesSaved: Int = 0,
        acceptanceKeystrokes: Int = 0,
        correctionKeystrokes: Int = 0,
        dismissalKeystrokes: Int = 0,
        netKeystrokesSaved: Int = 0,
        failureCategory: LabFailureCategory = .none,
        keystrokesSaved: Int = 0,
        latencyMilliseconds: Int? = nil,
        firstTokenMilliseconds: Int? = nil,
        meanTokenProbability: Double? = nil,
        decisionReason: LabDecisionReason = .shown,
        visibleWordCount: Int = 0,
        visibleCharacterCount: Int = 0,
        workerIndex: Int? = nil,
        candidateCacheHit: Bool? = nil
    ) {
        self.scenarioID = scenarioID
        self.category = category
        self.counterfactualPairID = counterfactualPairID
        self.repetition = repetition
        self.generationSeed = generationSeed
        self.outcome = outcome
        self.expectedSuggestion = expectedSuggestion
        self.hasGoldenContinuation = hasGoldenContinuation
        self.offered = offered
        self.modelRequested = modelRequested
        self.policySuppressed = policySuppressed
        self.exactMatchAt1 = exactMatchAt1
        self.exactMatchAt2 = exactMatchAt2
        self.exactMatchAt3 = exactMatchAt3
        self.exactContinuationMatched = exactContinuationMatched
        self.acceptablePrefixMatched = acceptablePrefixMatched
        self.acceptableContinuationMatched = acceptableContinuationMatched
        self.answerMatchKind = answerMatchKind
        self.requiredTermsSatisfied = requiredTermsSatisfied
        self.forbiddenTermViolation = forbiddenTermViolation
        self.wordLimitViolation = wordLimitViolation
        self.scenarioSource = scenarioSource
        self.corpusID = corpusID
        self.rootScenarioID = rootScenarioID
        self.replayCheckpoint = replayCheckpoint
        self.contextVariant = contextVariant
        self.temporalIntegrityPassed = temporalIntegrityPassed
        self.baselineKeystrokes = baselineKeystrokes
        self.grossKeystrokesSaved = grossKeystrokesSaved
        self.acceptanceKeystrokes = acceptanceKeystrokes
        self.correctionKeystrokes = correctionKeystrokes
        self.dismissalKeystrokes = dismissalKeystrokes
        self.netKeystrokesSaved = netKeystrokesSaved
        self.failureCategory = failureCategory
        self.keystrokesSaved = keystrokesSaved
        self.latencyMilliseconds = latencyMilliseconds
        self.firstTokenMilliseconds = firstTokenMilliseconds
        self.meanTokenProbability = meanTokenProbability
        self.decisionReason = decisionReason
        self.visibleWordCount = visibleWordCount
        self.visibleCharacterCount = visibleCharacterCount
        self.workerIndex = workerIndex
        self.candidateCacheHit = candidateCacheHit
    }

    private enum CodingKeys: String, CodingKey {
        case scenarioID, category, counterfactualPairID, repetition, generationSeed
        case outcome, expectedSuggestion
        case hasGoldenContinuation, offered, modelRequested, policySuppressed
        case exactMatchAt1, exactMatchAt2, exactMatchAt3, exactContinuationMatched
        case acceptablePrefixMatched, acceptableContinuationMatched, answerMatchKind
        case requiredTermsSatisfied, forbiddenTermViolation, wordLimitViolation
        case scenarioSource, corpusID, rootScenarioID, replayCheckpoint, contextVariant
        case temporalIntegrityPassed
        case baselineKeystrokes, grossKeystrokesSaved, acceptanceKeystrokes
        case correctionKeystrokes, dismissalKeystrokes, netKeystrokesSaved, failureCategory
        case keystrokesSaved, latencyMilliseconds, firstTokenMilliseconds, meanTokenProbability
        case decisionReason, visibleWordCount, visibleCharacterCount, workerIndex
        case candidateCacheHit
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        scenarioID = try values.decode(String.self, forKey: .scenarioID)
        category = try values.decode(String.self, forKey: .category)
        counterfactualPairID = try values.decodeIfPresent(String.self, forKey: .counterfactualPairID)
        repetition = try values.decode(Int.self, forKey: .repetition)
        generationSeed = try values.decodeIfPresent(Int.self, forKey: .generationSeed) ?? 0
        outcome = try values.decode(LabCaseOutcome.self, forKey: .outcome)
        expectedSuggestion = try values.decode(Bool.self, forKey: .expectedSuggestion)
        hasGoldenContinuation = try values.decode(Bool.self, forKey: .hasGoldenContinuation)
        offered = try values.decode(Bool.self, forKey: .offered)
        policySuppressed = try values.decodeIfPresent(Bool.self, forKey: .policySuppressed) ?? false
        exactMatchAt1 = try values.decodeIfPresent(Bool.self, forKey: .exactMatchAt1) ?? false
        exactMatchAt2 = try values.decodeIfPresent(Bool.self, forKey: .exactMatchAt2) ?? false
        exactMatchAt3 = try values.decodeIfPresent(Bool.self, forKey: .exactMatchAt3) ?? false
        exactContinuationMatched = try values.decodeIfPresent(
            Bool.self,
            forKey: .exactContinuationMatched
        ) ?? false
        acceptablePrefixMatched = try values.decodeIfPresent(
            Bool.self,
            forKey: .acceptablePrefixMatched
        ) ?? false
        acceptableContinuationMatched = try values.decodeIfPresent(
            Bool.self,
            forKey: .acceptableContinuationMatched
        ) ?? false
        answerMatchKind = try values.decodeIfPresent(
            LabAnswerMatchKind.self,
            forKey: .answerMatchKind
        ) ?? .none
        requiredTermsSatisfied = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiredTermsSatisfied
        ) ?? true
        forbiddenTermViolation = try values.decodeIfPresent(
            Bool.self,
            forKey: .forbiddenTermViolation
        ) ?? false
        wordLimitViolation = try values.decodeIfPresent(
            Bool.self,
            forKey: .wordLimitViolation
        ) ?? false
        scenarioSource = try values.decodeIfPresent(LabScenarioSource.self, forKey: .scenarioSource)
            ?? .synthetic
        corpusID = try values.decodeIfPresent(String.self, forKey: .corpusID)
        rootScenarioID = try values.decodeIfPresent(String.self, forKey: .rootScenarioID)
        replayCheckpoint = try values.decodeIfPresent(
            LabReplayCheckpoint.self,
            forKey: .replayCheckpoint
        ) ?? .caret
        contextVariant = try values.decodeIfPresent(LabContextVariant.self, forKey: .contextVariant)
            ?? .structuredThread
        temporalIntegrityPassed = try values.decodeIfPresent(
            Bool.self,
            forKey: .temporalIntegrityPassed
        ) ?? true
        baselineKeystrokes = try values.decodeIfPresent(Int.self, forKey: .baselineKeystrokes) ?? 0
        grossKeystrokesSaved = try values.decodeIfPresent(Int.self, forKey: .grossKeystrokesSaved)
            ?? (try values.decodeIfPresent(Int.self, forKey: .keystrokesSaved) ?? 0)
        acceptanceKeystrokes = try values.decodeIfPresent(Int.self, forKey: .acceptanceKeystrokes) ?? 0
        correctionKeystrokes = try values.decodeIfPresent(Int.self, forKey: .correctionKeystrokes) ?? 0
        dismissalKeystrokes = try values.decodeIfPresent(Int.self, forKey: .dismissalKeystrokes) ?? 0
        netKeystrokesSaved = try values.decodeIfPresent(Int.self, forKey: .netKeystrokesSaved)
            ?? grossKeystrokesSaved
        failureCategory = try values.decodeIfPresent(LabFailureCategory.self, forKey: .failureCategory)
            ?? .none
        keystrokesSaved = try values.decodeIfPresent(Int.self, forKey: .keystrokesSaved) ?? 0
        latencyMilliseconds = try values.decodeIfPresent(Int.self, forKey: .latencyMilliseconds)
        firstTokenMilliseconds = try values.decodeIfPresent(Int.self, forKey: .firstTokenMilliseconds)
        meanTokenProbability = try values.decodeIfPresent(Double.self, forKey: .meanTokenProbability)
        decisionReason = try values.decodeIfPresent(LabDecisionReason.self, forKey: .decisionReason)
            ?? (offered ? .shown : .emptyOutput)
        visibleWordCount = try values.decodeIfPresent(Int.self, forKey: .visibleWordCount) ?? 0
        visibleCharacterCount = try values.decodeIfPresent(Int.self, forKey: .visibleCharacterCount) ?? 0
        workerIndex = try values.decodeIfPresent(Int.self, forKey: .workerIndex)
        candidateCacheHit = try values.decodeIfPresent(Bool.self, forKey: .candidateCacheHit)
        modelRequested = try values.decodeIfPresent(Bool.self, forKey: .modelRequested)
            ?? (latencyMilliseconds != nil || outcome == .timeout || outcome == .error)
    }
}

public struct LabLatencySummary: Codable, Equatable, Sendable {
    public let count: Int
    public let p50Milliseconds: Int?
    public let p95Milliseconds: Int?
    public let p99Milliseconds: Int?
    public let maximumMilliseconds: Int?

    public static let empty = LabLatencySummary(
        count: 0,
        p50Milliseconds: nil,
        p95Milliseconds: nil,
        p99Milliseconds: nil,
        maximumMilliseconds: nil
    )
}

public struct LabAggregateMetrics: Codable, Equatable, Sendable {
    public let totalCases: Int
    public let useful: Int
    public let wrong: Int
    public let silent: Int
    public let correctSilence: Int
    public let unwanted: Int
    public let timeouts: Int
    public let errors: Int
    public let policySuppressions: Int
    public let modelRequests: Int
    public let exactMatchAt1Rate: Double
    public let exactMatchAt2Rate: Double
    public let exactMatchAt3Rate: Double
    public let exactPredictionRate: Double
    public let acceptableAlternativeRate: Double
    public let usefulnessRate: Double
    public let restraintRate: Double
    public let ordinaryRestraintRate: Double?
    public let sensitiveRestraintRate: Double?
    public let counterfactualPairPassRate: Double?
    public let replyScore: Int?
    public let qualityScore: Int?
    public let promotionEligible: Bool?
    public let promotionGateFailures: [String]
    public let factualityRate: Double
    public let brevityRate: Double
    public let baselineKeystrokes: Int
    public let grossKeystrokesSaved: Int
    public let acceptanceKeystrokes: Int
    public let correctionKeystrokes: Int
    public let dismissalKeystrokes: Int
    public let netKeystrokesSaved: Int
    public let netKeystrokeSavingsRate: Double
    public let netKeystrokesSavedPer1000Characters: Double
    public let badSuggestionRate: Double
    public let temporalIntegrityRate: Double
    public let failureCategoryCounts: [String: Int]
    public let gates: LabGateSummary
    public let keystrokesSaved: Int
    public let keystrokesSavedPerCase: Double
    public let throughputCasesPerSecond: Double
    public let throughputModelRequestsPerSecond: Double
    public let latency: LabLatencySummary
    public let firstTokenLatency: LabLatencySummary
    public let meanTokenProbability: Double?
    public let decisionReasonCounts: [String: Int]

    public init(
        totalCases: Int,
        useful: Int,
        wrong: Int,
        silent: Int,
        correctSilence: Int,
        unwanted: Int,
        timeouts: Int,
        errors: Int,
        policySuppressions: Int,
        modelRequests: Int,
        exactMatchAt1Rate: Double,
        exactMatchAt2Rate: Double,
        exactMatchAt3Rate: Double,
        exactPredictionRate: Double = 0,
        acceptableAlternativeRate: Double = 0,
        usefulnessRate: Double,
        restraintRate: Double,
        ordinaryRestraintRate: Double? = nil,
        sensitiveRestraintRate: Double? = nil,
        counterfactualPairPassRate: Double? = nil,
        replyScore: Int?,
        qualityScore: Int? = nil,
        promotionEligible: Bool? = nil,
        promotionGateFailures: [String] = [],
        factualityRate: Double = 0,
        brevityRate: Double = 0,
        baselineKeystrokes: Int = 0,
        grossKeystrokesSaved: Int = 0,
        acceptanceKeystrokes: Int = 0,
        correctionKeystrokes: Int = 0,
        dismissalKeystrokes: Int = 0,
        netKeystrokesSaved: Int = 0,
        netKeystrokeSavingsRate: Double = 0,
        netKeystrokesSavedPer1000Characters: Double = 0,
        badSuggestionRate: Double = 0,
        temporalIntegrityRate: Double = 1,
        failureCategoryCounts: [String: Int] = [:],
        gates: LabGateSummary = .init(
            badSuggestions: .notRun,
            sensitiveSituations: .notRun,
            temporalIntegrity: .notRun,
            latency: .notRun
        ),
        keystrokesSaved: Int,
        keystrokesSavedPerCase: Double,
        throughputCasesPerSecond: Double,
        throughputModelRequestsPerSecond: Double,
        latency: LabLatencySummary,
        firstTokenLatency: LabLatencySummary = .empty,
        meanTokenProbability: Double? = nil,
        decisionReasonCounts: [String: Int] = [:]
    ) {
        self.totalCases = totalCases
        self.useful = useful
        self.wrong = wrong
        self.silent = silent
        self.correctSilence = correctSilence
        self.unwanted = unwanted
        self.timeouts = timeouts
        self.errors = errors
        self.policySuppressions = policySuppressions
        self.modelRequests = modelRequests
        self.exactMatchAt1Rate = exactMatchAt1Rate
        self.exactMatchAt2Rate = exactMatchAt2Rate
        self.exactMatchAt3Rate = exactMatchAt3Rate
        self.exactPredictionRate = exactPredictionRate
        self.acceptableAlternativeRate = acceptableAlternativeRate
        self.usefulnessRate = usefulnessRate
        self.restraintRate = restraintRate
        self.ordinaryRestraintRate = ordinaryRestraintRate
        self.sensitiveRestraintRate = sensitiveRestraintRate
        self.counterfactualPairPassRate = counterfactualPairPassRate
        self.replyScore = replyScore
        self.qualityScore = qualityScore ?? replyScore
        self.promotionEligible = promotionEligible
        self.promotionGateFailures = promotionGateFailures
        self.factualityRate = factualityRate
        self.brevityRate = brevityRate
        self.baselineKeystrokes = baselineKeystrokes
        self.grossKeystrokesSaved = grossKeystrokesSaved
        self.acceptanceKeystrokes = acceptanceKeystrokes
        self.correctionKeystrokes = correctionKeystrokes
        self.dismissalKeystrokes = dismissalKeystrokes
        self.netKeystrokesSaved = netKeystrokesSaved
        self.netKeystrokeSavingsRate = netKeystrokeSavingsRate
        self.netKeystrokesSavedPer1000Characters = netKeystrokesSavedPer1000Characters
        self.badSuggestionRate = badSuggestionRate
        self.temporalIntegrityRate = temporalIntegrityRate
        self.failureCategoryCounts = failureCategoryCounts
        self.gates = gates
        self.keystrokesSaved = keystrokesSaved
        self.keystrokesSavedPerCase = keystrokesSavedPerCase
        self.throughputCasesPerSecond = throughputCasesPerSecond
        self.throughputModelRequestsPerSecond = throughputModelRequestsPerSecond
        self.latency = latency
        self.firstTokenLatency = firstTokenLatency
        self.meanTokenProbability = meanTokenProbability
        self.decisionReasonCounts = decisionReasonCounts
    }

    public var complete: Bool { timeouts == 0 && errors == 0 && totalCases > 0 }

    private enum CodingKeys: String, CodingKey {
        case totalCases, useful, wrong, silent, correctSilence, unwanted
        case timeouts, errors, policySuppressions, modelRequests
        case exactMatchAt1Rate, exactMatchAt2Rate, exactMatchAt3Rate
        case exactPredictionRate, acceptableAlternativeRate
        case usefulnessRate, restraintRate, ordinaryRestraintRate, sensitiveRestraintRate
        case counterfactualPairPassRate, replyScore, qualityScore
        case promotionEligible, promotionGateFailures, factualityRate, brevityRate
        case baselineKeystrokes, grossKeystrokesSaved, acceptanceKeystrokes
        case correctionKeystrokes, dismissalKeystrokes, netKeystrokesSaved
        case netKeystrokeSavingsRate, netKeystrokesSavedPer1000Characters
        case badSuggestionRate, temporalIntegrityRate, failureCategoryCounts, gates
        case keystrokesSaved
        case keystrokesSavedPerCase, throughputCasesPerSecond
        case throughputModelRequestsPerSecond, latency, firstTokenLatency
        case meanTokenProbability, decisionReasonCounts
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalCases = try values.decode(Int.self, forKey: .totalCases)
        useful = try values.decode(Int.self, forKey: .useful)
        wrong = try values.decode(Int.self, forKey: .wrong)
        silent = try values.decode(Int.self, forKey: .silent)
        correctSilence = try values.decode(Int.self, forKey: .correctSilence)
        unwanted = try values.decode(Int.self, forKey: .unwanted)
        timeouts = try values.decode(Int.self, forKey: .timeouts)
        errors = try values.decode(Int.self, forKey: .errors)
        policySuppressions = try values.decode(Int.self, forKey: .policySuppressions)
        exactMatchAt1Rate = try values.decode(Double.self, forKey: .exactMatchAt1Rate)
        exactMatchAt2Rate = try values.decode(Double.self, forKey: .exactMatchAt2Rate)
        exactMatchAt3Rate = try values.decode(Double.self, forKey: .exactMatchAt3Rate)
        exactPredictionRate = try values.decodeIfPresent(
            Double.self,
            forKey: .exactPredictionRate
        ) ?? 0
        acceptableAlternativeRate = try values.decodeIfPresent(
            Double.self,
            forKey: .acceptableAlternativeRate
        ) ?? 0
        usefulnessRate = try values.decode(Double.self, forKey: .usefulnessRate)
        restraintRate = try values.decode(Double.self, forKey: .restraintRate)
        ordinaryRestraintRate = try values.decodeIfPresent(Double.self, forKey: .ordinaryRestraintRate)
        sensitiveRestraintRate = try values.decodeIfPresent(Double.self, forKey: .sensitiveRestraintRate)
        counterfactualPairPassRate = try values.decodeIfPresent(
            Double.self,
            forKey: .counterfactualPairPassRate
        )
        replyScore = try values.decodeIfPresent(Int.self, forKey: .replyScore)
        qualityScore = try values.decodeIfPresent(Int.self, forKey: .qualityScore) ?? replyScore
        promotionEligible = try values.decodeIfPresent(Bool.self, forKey: .promotionEligible)
        promotionGateFailures = try values.decodeIfPresent(
            [String].self,
            forKey: .promotionGateFailures
        ) ?? []
        factualityRate = try values.decodeIfPresent(Double.self, forKey: .factualityRate) ?? 0
        brevityRate = try values.decodeIfPresent(Double.self, forKey: .brevityRate) ?? 0
        keystrokesSaved = try values.decode(Int.self, forKey: .keystrokesSaved)
        baselineKeystrokes = try values.decodeIfPresent(Int.self, forKey: .baselineKeystrokes) ?? 0
        grossKeystrokesSaved = try values.decodeIfPresent(Int.self, forKey: .grossKeystrokesSaved)
            ?? keystrokesSaved
        acceptanceKeystrokes = try values.decodeIfPresent(Int.self, forKey: .acceptanceKeystrokes) ?? 0
        correctionKeystrokes = try values.decodeIfPresent(Int.self, forKey: .correctionKeystrokes) ?? 0
        dismissalKeystrokes = try values.decodeIfPresent(Int.self, forKey: .dismissalKeystrokes) ?? 0
        netKeystrokesSaved = try values.decodeIfPresent(Int.self, forKey: .netKeystrokesSaved)
            ?? grossKeystrokesSaved
        netKeystrokeSavingsRate = try values.decodeIfPresent(
            Double.self,
            forKey: .netKeystrokeSavingsRate
        ) ?? (baselineKeystrokes > 0 ? Double(netKeystrokesSaved) / Double(baselineKeystrokes) : 0)
        netKeystrokesSavedPer1000Characters = try values.decodeIfPresent(
            Double.self,
            forKey: .netKeystrokesSavedPer1000Characters
        ) ?? (baselineKeystrokes > 0 ? netKeystrokeSavingsRate * 1_000 : 0)
        badSuggestionRate = try values.decodeIfPresent(Double.self, forKey: .badSuggestionRate) ?? 0
        temporalIntegrityRate = try values.decodeIfPresent(
            Double.self,
            forKey: .temporalIntegrityRate
        ) ?? 1
        failureCategoryCounts = try values.decodeIfPresent(
            [String: Int].self,
            forKey: .failureCategoryCounts
        ) ?? [:]
        gates = try values.decodeIfPresent(LabGateSummary.self, forKey: .gates) ?? .init(
            badSuggestions: .notRun,
            sensitiveSituations: .notRun,
            temporalIntegrity: .notRun,
            latency: .notRun
        )
        keystrokesSavedPerCase = try values.decode(Double.self, forKey: .keystrokesSavedPerCase)
        throughputCasesPerSecond = try values.decode(Double.self, forKey: .throughputCasesPerSecond)
        latency = try values.decode(LabLatencySummary.self, forKey: .latency)
        firstTokenLatency = try values.decodeIfPresent(
            LabLatencySummary.self,
            forKey: .firstTokenLatency
        ) ?? .empty
        meanTokenProbability = try values.decodeIfPresent(Double.self, forKey: .meanTokenProbability)
        decisionReasonCounts = try values.decodeIfPresent(
            [String: Int].self,
            forKey: .decisionReasonCounts
        ) ?? [:]

        let inferredRequests = max(0, totalCases - policySuppressions)
        modelRequests = try values.decodeIfPresent(Int.self, forKey: .modelRequests)
            ?? inferredRequests
        throughputModelRequestsPerSecond = try values.decodeIfPresent(
            Double.self,
            forKey: .throughputModelRequestsPerSecond
        ) ?? (totalCases > 0
            ? throughputCasesPerSecond * Double(modelRequests) / Double(totalCases)
            : 0)
    }
}

public struct LabAssetSnapshot: Codable, Equatable, Sendable {
    public enum InferenceBackend: String, Codable, Sendable {
        case localLlama = "local-llama"
        case codexSubscription = "codex-subscription"

        public var title: String {
            switch self {
            case .localLlama: "Local llama-server"
            case .codexSubscription: "Codex subscription ceiling"
            }
        }
    }

    public let inferenceBackend: InferenceBackend
    public let verificationMode: LabModelVerificationMode
    public let modelIdentifier: String
    public let modelRevision: String
    public let modelSHA256: String
    public let helperSHA256: String

    public init(
        inferenceBackend: InferenceBackend = .localLlama,
        verificationMode: LabModelVerificationMode = .productionPinned,
        modelIdentifier: String,
        modelRevision: String,
        modelSHA256: String,
        helperSHA256: String
    ) {
        self.inferenceBackend = inferenceBackend
        self.verificationMode = verificationMode
        self.modelIdentifier = modelIdentifier
        self.modelRevision = modelRevision
        self.modelSHA256 = modelSHA256
        self.helperSHA256 = helperSHA256
    }

    private enum CodingKeys: String, CodingKey {
        case inferenceBackend, verificationMode, modelIdentifier, modelRevision, modelSHA256, helperSHA256
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        inferenceBackend = try values.decodeIfPresent(
            InferenceBackend.self,
            forKey: .inferenceBackend
        ) ?? .localLlama
        verificationMode = try values.decodeIfPresent(
            LabModelVerificationMode.self,
            forKey: .verificationMode
        ) ?? .productionPinned
        modelIdentifier = try values.decode(String.self, forKey: .modelIdentifier)
        modelRevision = try values.decode(String.self, forKey: .modelRevision)
        modelSHA256 = try values.decode(String.self, forKey: .modelSHA256)
        helperSHA256 = try values.decode(String.self, forKey: .helperSHA256)
    }
}

public struct LabPrivacyContract: Codable, Equatable, Sendable {
    public let aggregateOnly: Bool
    public let rawScenarioText: Bool
    public let rawModelOutput: Bool
    public let filePaths: Bool
    public let networkInference: Bool

    public init(
        aggregateOnly: Bool = true,
        rawScenarioText: Bool = false,
        rawModelOutput: Bool = false,
        filePaths: Bool = false,
        networkInference: Bool = false
    ) {
        self.aggregateOnly = aggregateOnly
        self.rawScenarioText = rawScenarioText
        self.rawModelOutput = rawModelOutput
        self.filePaths = filePaths
        self.networkInference = networkInference
    }

    private enum CodingKeys: String, CodingKey {
        case aggregateOnly, rawScenarioText, rawModelOutput, filePaths, networkInference
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        aggregateOnly = try values.decodeIfPresent(Bool.self, forKey: .aggregateOnly) ?? true
        rawScenarioText = try values.decodeIfPresent(Bool.self, forKey: .rawScenarioText) ?? false
        rawModelOutput = try values.decodeIfPresent(Bool.self, forKey: .rawModelOutput) ?? false
        filePaths = try values.decodeIfPresent(Bool.self, forKey: .filePaths) ?? false
        networkInference = try values.decodeIfPresent(Bool.self, forKey: .networkInference) ?? false
    }
}

public struct LabRuntimeStartupSummary: Codable, Equatable, Sendable {
    public let samples: Int
    public let p50Milliseconds: Int?
    public let p95Milliseconds: Int?
    public let p99Milliseconds: Int?

    public init(milliseconds: [Int]) {
        let sorted = milliseconds.sorted()
        samples = sorted.count
        p50Milliseconds = Self.percentile(sorted, fraction: 0.50)
        p95Milliseconds = Self.percentile(sorted, fraction: 0.95)
        p99Milliseconds = Self.percentile(sorted, fraction: 0.99)
    }

    private static func percentile(_ sorted: [Int], fraction: Double) -> Int? {
        guard !sorted.isEmpty else { return nil }
        let index = min(
            sorted.count - 1,
            Int((Double(sorted.count - 1) * fraction).rounded())
        )
        return sorted[index]
    }
}

public struct LabRunReport: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.reply-bench-report.v6"
    public static let supportedSchemas = [
        "tilde-lab.reply-bench-report.v1",
        "tilde-lab.reply-bench-report.v2",
        "tilde-lab.reply-bench-report.v3",
        "tilde-lab.reply-bench-report.v4",
        "tilde-lab.reply-bench-report.v5",
        currentSchema,
    ]

    public let schema: String
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let suiteName: String
    public let suiteDigestSHA256: String
    public let scenarioCount: Int
    public let arm: LabArmConfiguration
    public let execution: LabExecutionSnapshot
    public let runtimeStartup: LabRuntimeStartupSummary?
    public let assets: LabAssetSnapshot
    public let provenance: LabReportProvenance?
    public let review: LabReportReview?
    public let evidenceEligibility: LabEvidenceEligibility?
    public let privacy: LabPrivacyContract
    public let metrics: LabAggregateMetrics
    public let cases: [LabCaseResult]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        suiteName: String,
        suiteDigestSHA256: String,
        scenarioCount: Int,
        arm: LabArmConfiguration,
        execution: LabExecutionSnapshot,
        runtimeStartup: LabRuntimeStartupSummary? = nil,
        assets: LabAssetSnapshot,
        provenance: LabReportProvenance? = nil,
        review: LabReportReview? = .unreviewed,
        privacy: LabPrivacyContract = LabPrivacyContract(),
        metrics: LabAggregateMetrics,
        cases: [LabCaseResult]
    ) {
        schema = Self.currentSchema
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.suiteName = suiteName
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.scenarioCount = scenarioCount
        self.arm = arm
        self.execution = execution
        self.runtimeStartup = runtimeStartup
        self.assets = assets
        let resolvedProvenance = provenance ?? .unavailable(capturedAt: startedAt)
        self.provenance = resolvedProvenance
        self.review = review
        self.privacy = privacy
        self.metrics = metrics
        self.cases = cases
        evidenceEligibility = Self.evaluateEvidenceEligibility(
            schema: Self.currentSchema,
            provenance: resolvedProvenance,
            review: review,
            privacy: privacy,
            metrics: metrics,
            evidenceDecisionPresent: true
        )
    }

    public var displayScore: String {
        guard metrics.complete else { return "Incomplete" }
        if arm.scoring.usesModelOutputQuality {
            return "\(metrics.qualityScore ?? 0)/100 quality"
        }
        return "\(Int((metrics.netKeystrokeSavingsRate * 100).rounded()))% NKS"
    }

    public func reviewed(
        conclusion: String,
        status: LabReportReviewStatus,
        at reviewedAt: Date = Date()
    ) throws -> LabRunReport {
        guard schema == Self.currentSchema, provenance != nil, status != .unreviewed else {
            throw LabReportProvenanceError.invalidReview
        }
        let review = try LabReportReview(
            status: status,
            conclusion: conclusion,
            reviewedAt: reviewedAt
        ).validated()
        return LabRunReport(
            id: id,
            startedAt: startedAt,
            finishedAt: finishedAt,
            suiteName: suiteName,
            suiteDigestSHA256: suiteDigestSHA256,
            scenarioCount: scenarioCount,
            arm: arm,
            execution: execution,
            runtimeStartup: runtimeStartup,
            assets: assets,
            provenance: provenance,
            review: review,
            privacy: privacy,
            metrics: metrics,
            cases: cases
        )
    }
}

public struct LabRunComparison: Equatable, Sendable {
    public let netKeystrokeSavingsRateDelta: Double
    public let scoreDelta: Int?
    public let usefulnessRateDelta: Double
    public let restraintRateDelta: Double
    public let exactMatchAt1Delta: Double
    public let p95LatencyDeltaMilliseconds: Int?
    public let throughputDelta: Double

    public init(current: LabRunReport, baseline: LabRunReport) {
        netKeystrokeSavingsRateDelta = current.metrics.netKeystrokeSavingsRate
            - baseline.metrics.netKeystrokeSavingsRate
        if let currentScore = current.metrics.qualityScore,
           let baselineScore = baseline.metrics.qualityScore {
            scoreDelta = currentScore - baselineScore
        } else {
            scoreDelta = nil
        }
        usefulnessRateDelta = current.metrics.usefulnessRate - baseline.metrics.usefulnessRate
        restraintRateDelta = current.metrics.restraintRate - baseline.metrics.restraintRate
        exactMatchAt1Delta = current.metrics.exactMatchAt1Rate - baseline.metrics.exactMatchAt1Rate
        if let currentP95 = current.metrics.latency.p95Milliseconds,
           let baselineP95 = baseline.metrics.latency.p95Milliseconds {
            p95LatencyDeltaMilliseconds = currentP95 - baselineP95
        } else {
            p95LatencyDeltaMilliseconds = nil
        }
        throughputDelta = current.metrics.throughputModelRequestsPerSecond
            - baseline.metrics.throughputModelRequestsPerSecond
    }
}
