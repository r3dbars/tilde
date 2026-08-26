import Foundation

public enum LabRunVerdict: String, Codable, Sendable {
    case eligible
    case candidate
    case degenerateSilence = "degenerate-silence"
    case incomplete

    public init(metrics: LabAggregateMetrics) {
        if !metrics.complete {
            self = .incomplete
        } else if metrics.usefulnessRate == 0 {
            self = .degenerateSilence
        } else if metrics.promotionEligible == true {
            self = .eligible
        } else {
            self = .candidate
        }
    }

    public var title: String {
        switch self {
        case .eligible: "Eligible winner"
        case .candidate: "Candidate"
        case .degenerateSilence: "Rejected: silent"
        case .incomplete: "Incomplete"
        }
    }
}

public struct LabResearchRank: Equatable, Sendable {
    public let eligible: Bool
    public let usable: Bool
    public let behavioralFloor: Double
    public let netKeystrokeSavingsRate: Double
    public let qualityScore: Int
    public let normalizedP95Milliseconds: Double
    public let complexity: Int

    public init(
        report: LabRunReport,
        controlP95Milliseconds: Int? = nil,
        complexity: Int = 0
    ) {
        let metrics = report.metrics
        let ordinary = metrics.ordinaryRestraintRate ?? metrics.restraintRate
        eligible = metrics.complete && metrics.gates.researchEligible
        usable = metrics.complete
            && metrics.usefulnessRate > 0
            && metrics.gates.badSuggestions != .fail
            && metrics.gates.sensitiveSituations != .fail
            && metrics.gates.temporalIntegrity != .fail
        behavioralFloor = min(metrics.usefulnessRate, ordinary)
        netKeystrokeSavingsRate = metrics.netKeystrokeSavingsRate
        qualityScore = metrics.qualityScore ?? 0
        let p95 = Double(metrics.latency.p95Milliseconds ?? Int.max)
        if let controlP95Milliseconds, controlP95Milliseconds > 0, p95.isFinite {
            normalizedP95Milliseconds = p95 / Double(controlP95Milliseconds)
        } else {
            normalizedP95Milliseconds = p95
        }
        self.complexity = complexity
    }

    /// Gate-first ordering. A silent or unsafe arm cannot beat a usable arm
    /// just because a weighted average happened to be larger.
    public func isBetter(than other: LabResearchRank, minimumImprovement: Double = 0) -> Bool {
        if eligible != other.eligible { return eligible }
        if usable != other.usable { return usable }
        if netKeystrokeSavingsRate > other.netKeystrokeSavingsRate + minimumImprovement { return true }
        if other.netKeystrokeSavingsRate > netKeystrokeSavingsRate + minimumImprovement { return false }
        if behavioralFloor != other.behavioralFloor { return behavioralFloor > other.behavioralFloor }
        if qualityScore != other.qualityScore { return qualityScore > other.qualityScore }
        if normalizedP95Milliseconds != other.normalizedP95Milliseconds {
            return normalizedP95Milliseconds < other.normalizedP95Milliseconds
        }
        return complexity < other.complexity
    }
}

public enum LabResearchMutation: String, Codable, CaseIterable, Identifiable, Sendable {
    case typicalP025 = "typical-p-0.25"
    case typicalP050 = "typical-p-0.50"
    case typicalP075 = "typical-p-0.75"
    case typicalP090 = "typical-p-0.90"
    case frequencyPenalty010 = "frequency-penalty-0.10"
    case frequencyPenalty025 = "frequency-penalty-0.25"
    case frequencyPenalty050 = "frequency-penalty-0.50"
    case frequencyPenalty075 = "frequency-penalty-0.75"
    case temperature010 = "temperature-0.10"
    case temperature020 = "temperature-0.20"
    case temperature030 = "temperature-0.30"
    case temperature040 = "temperature-0.40"
    case predictionTokens8 = "prediction-tokens-8"
    case predictionTokens12 = "prediction-tokens-12"
    case predictionTokens16 = "prediction-tokens-16"
    case predictionTokens24 = "prediction-tokens-24"
    case predictionTokens32 = "prediction-tokens-32"
    case predictionTokens48 = "prediction-tokens-48"
    case visibleWords3 = "visible-words-3"
    case visibleWords5 = "visible-words-5"
    case visibleWords6 = "visible-words-6"
    case visibleWords10 = "visible-words-10"
    case visibleWords12 = "visible-words-12"
    case topK20 = "top-k-20"
    case topK80 = "top-k-80"
    case topP080 = "top-p-0.80"
    case topP090 = "top-p-0.90"
    case topP099 = "top-p-0.99"
    case minP000 = "min-p-0.00"
    case minP010 = "min-p-0.10"
    case repeatPenalty105 = "repeat-penalty-1.05"
    case repeatPenalty110 = "repeat-penalty-1.10"
    case stopCharacters64 = "stop-characters-64"
    case stopCharacters128 = "stop-characters-128"
    case confidence010 = "confidence-0.10"
    case confidence020 = "confidence-0.20"
    case confidence025 = "confidence-0.25"
    case confidence030 = "confidence-0.30"
    case confidence035 = "confidence-0.35"
    case confidence040 = "confidence-0.40"
    case confidence050 = "confidence-0.50"
    case confidence060 = "confidence-0.60"
    case visibleWords2 = "visible-words-2"
    case visibleWords4 = "visible-words-4"
    case predictionTokens6 = "prediction-tokens-6"
    case predictionTokens10 = "prediction-tokens-10"
    case factualGroundingNamesNumbers = "grounding-names-numbers"
    case factualGroundingAllAnchors = "grounding-all-anchors"
    case sceneEchoAggressive = "scene-echo-aggressive"
    case sceneEchoConservative = "scene-echo-conservative"
    case intentPrior015 = "intent-prior-0.15"
    case intentPrior050 = "intent-prior-0.50"
    case intentPrior075 = "intent-prior-0.75"
    case intentFutures1 = "intent-futures-1"
    case intentFutures2 = "intent-futures-2"
    case intentFutures6 = "intent-futures-6"
    case conversationTurns2 = "conversation-turns-2"
    case conversationTurns4 = "conversation-turns-4"
    case conversationTurns12 = "conversation-turns-12"
    case minimalPrompt = "prompt-minimal"
    case noExamples = "prompt-no-examples"
    case dynamicLengthConservative = "dynamic-length-conservative"
    case dynamicLengthBalanced = "dynamic-length-balanced"
    case dynamicLengthExpansive = "dynamic-length-expansive"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .typicalP025: "Typical P 0.25"
        case .typicalP050: "Typical P 0.50"
        case .typicalP075: "Typical P 0.75"
        case .typicalP090: "Typical P 0.90"
        case .frequencyPenalty010: "Frequency penalty 0.10"
        case .frequencyPenalty025: "Frequency penalty 0.25"
        case .frequencyPenalty050: "Frequency penalty 0.50"
        case .frequencyPenalty075: "Frequency penalty 0.75"
        case .temperature010: "Temperature 0.10"
        case .temperature020: "Temperature 0.20"
        case .temperature030: "Temperature 0.30"
        case .temperature040: "Temperature 0.40"
        case .predictionTokens8: "Prediction budget 8"
        case .predictionTokens12: "Prediction budget 12"
        case .predictionTokens16: "Prediction budget 16"
        case .predictionTokens24: "Prediction budget 24"
        case .predictionTokens32: "Prediction budget 32"
        case .predictionTokens48: "Prediction budget 48"
        case .visibleWords3: "Visible cap 3 words"
        case .visibleWords5: "Visible cap 5 words"
        case .visibleWords6: "Visible cap 6 words"
        case .visibleWords10: "Visible cap 10 words"
        case .visibleWords12: "Visible cap 12 words"
        case .topK20: "Top K 20"
        case .topK80: "Top K 80"
        case .topP080: "Top P 0.80"
        case .topP090: "Top P 0.90"
        case .topP099: "Top P 0.99"
        case .minP000: "Min P 0.00"
        case .minP010: "Min P 0.10"
        case .repeatPenalty105: "Repeat penalty 1.05"
        case .repeatPenalty110: "Repeat penalty 1.10"
        case .stopCharacters64: "Stop character limit 64"
        case .stopCharacters128: "Stop character limit 128"
        case .confidence010: "Confidence floor 10%"
        case .confidence020: "Confidence floor 20%"
        case .confidence025: "Confidence floor 25%"
        case .confidence030: "Confidence floor 30%"
        case .confidence035: "Confidence floor 35%"
        case .confidence040: "Confidence floor 40%"
        case .confidence050: "Confidence floor 50%"
        case .confidence060: "Confidence floor 60%"
        case .visibleWords2: "Visible cap 2 words"
        case .visibleWords4: "Visible cap 4 words"
        case .predictionTokens6: "Prediction budget 6"
        case .predictionTokens10: "Prediction budget 10"
        case .factualGroundingNamesNumbers: "Ground names and numbers"
        case .factualGroundingAllAnchors: "Ground every factual anchor"
        case .sceneEchoAggressive: "Aggressive scene-echo rejection"
        case .sceneEchoConservative: "Conservative scene-echo rejection"
        case .intentPrior015: "Intent prior 0.15"
        case .intentPrior050: "Intent prior 0.50"
        case .intentPrior075: "Intent prior 0.75"
        case .intentFutures1: "One intent future"
        case .intentFutures2: "Two intent futures"
        case .intentFutures6: "Six intent futures"
        case .conversationTurns2: "Two conversation turns"
        case .conversationTurns4: "Four conversation turns"
        case .conversationTurns12: "Twelve conversation turns"
        case .minimalPrompt: "Minimal prompt"
        case .noExamples: "No prompt examples"
        case .dynamicLengthConservative: "Dynamic length · conservative"
        case .dynamicLengthBalanced: "Dynamic length · balanced"
        case .dynamicLengthExpansive: "Dynamic length · expansive"
        }
    }

    public var subsystem: LabResearchSubsystem {
        switch self {
        case .typicalP025, .typicalP050, .typicalP075, .typicalP090,
             .frequencyPenalty010, .frequencyPenalty025, .frequencyPenalty050,
             .frequencyPenalty075, .temperature010, .temperature020, .temperature030,
             .temperature040, .predictionTokens6, .predictionTokens8, .predictionTokens10,
             .predictionTokens12, .predictionTokens16, .predictionTokens24,
             .predictionTokens32, .predictionTokens48, .topK20, .topK80, .topP080,
             .topP090, .topP099, .minP000, .minP010, .repeatPenalty105,
             .repeatPenalty110, .stopCharacters64, .stopCharacters128:
            .generation
        case .intentPrior015, .intentPrior050, .intentPrior075, .intentFutures1,
             .intentFutures2, .intentFutures6, .conversationTurns2, .conversationTurns4,
             .conversationTurns12, .minimalPrompt, .noExamples:
            .context
        case .factualGroundingNamesNumbers, .factualGroundingAllAnchors,
             .sceneEchoAggressive, .sceneEchoConservative:
            .safety
        default:
            .display
        }
    }

    public func applying(to base: LabArmConfiguration, trial: Int) -> LabArmConfiguration {
        var arm = base
        arm.id = "research-\(trial)-\(rawValue)"
        switch self {
        case .typicalP025:
            arm.generation.typicalP = 0.25
        case .typicalP050:
            arm.generation.typicalP = 0.50
        case .typicalP075:
            arm.generation.typicalP = 0.75
        case .typicalP090:
            arm.generation.typicalP = 0.90
        case .frequencyPenalty010:
            arm.generation.frequencyPenalty = 0.10
        case .frequencyPenalty025:
            arm.generation.frequencyPenalty = 0.25
        case .frequencyPenalty050:
            arm.generation.frequencyPenalty = 0.50
        case .frequencyPenalty075:
            arm.generation.frequencyPenalty = 0.75
        case .temperature010:
            arm.generation.temperature = 0.10
            arm.generation.preset = .custom
        case .temperature020:
            arm.generation.temperature = 0.20
            arm.generation.preset = .custom
        case .temperature030:
            arm.generation.temperature = 0.30
            arm.generation.preset = .custom
        case .temperature040:
            arm.generation.temperature = 0.40
            arm.generation.preset = .custom
        case .predictionTokens8:
            arm.generation.predictionTokens = 8
        case .predictionTokens12:
            arm.generation.predictionTokens = 12
        case .predictionTokens16:
            arm.generation.predictionTokens = 16
        case .predictionTokens24:
            arm.generation.predictionTokens = 24
        case .predictionTokens32:
            arm.generation.predictionTokens = 32
        case .predictionTokens48:
            arm.generation.predictionTokens = 48
        case .visibleWords3:
            arm.judgment.maximumVisibleWords = 3
        case .visibleWords5:
            arm.judgment.maximumVisibleWords = 5
        case .visibleWords6:
            arm.judgment.maximumVisibleWords = 6
        case .visibleWords10:
            arm.judgment.maximumVisibleWords = 10
        case .visibleWords12:
            arm.judgment.maximumVisibleWords = 12
        case .topK20:
            arm.generation.topK = 20
        case .topK80:
            arm.generation.topK = 80
        case .topP080:
            arm.generation.topP = 0.80
        case .topP090:
            arm.generation.topP = 0.90
        case .topP099:
            arm.generation.topP = 0.99
        case .minP000:
            arm.generation.minP = 0
        case .minP010:
            arm.generation.minP = 0.10
        case .repeatPenalty105:
            arm.generation.repeatPenalty = 1.05
        case .repeatPenalty110:
            arm.generation.repeatPenalty = 1.10
        case .stopCharacters64:
            arm.generation.stopCharacterLimit = 64
        case .stopCharacters128:
            arm.generation.stopCharacterLimit = 128
        case .confidence010:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.10
        case .confidence020:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.20
        case .confidence025:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.25
        case .confidence030:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.30
        case .confidence035:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.35
        case .confidence040:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.40
        case .confidence050:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.50
        case .confidence060:
            arm.generation.probabilityCount = 5
            arm.generation.minimumMeanTokenProbability = 0.60
        case .visibleWords2:
            arm.judgment.maximumVisibleWords = 2
        case .visibleWords4:
            arm.judgment.maximumVisibleWords = 4
        case .predictionTokens6:
            arm.generation.predictionTokens = 6
        case .predictionTokens10:
            arm.generation.predictionTokens = 10
        case .factualGroundingNamesNumbers:
            arm.judgment.factualGrounding = .numbersAndNames
        case .factualGroundingAllAnchors:
            arm.judgment.factualGrounding = .allAnchors
        case .sceneEchoAggressive:
            arm.judgment.sceneEchoMinimumWords = 2
            arm.judgment.sceneEchoMinimumCharacters = 6
        case .sceneEchoConservative:
            arm.judgment.sceneEchoMinimumWords = 4
            arm.judgment.sceneEchoMinimumCharacters = 16
        case .intentPrior015:
            arm.prompt.intentPriorWeight = 0.15
        case .intentPrior050:
            arm.prompt.intentPriorWeight = 0.50
        case .intentPrior075:
            arm.prompt.intentPriorWeight = 0.75
        case .intentFutures1:
            arm.prompt.maximumIntentFutures = 1
        case .intentFutures2:
            arm.prompt.maximumIntentFutures = 2
        case .intentFutures6:
            arm.prompt.maximumIntentFutures = 6
        case .conversationTurns2:
            arm.prompt.conversationTurnLimit = 2
        case .conversationTurns4:
            arm.prompt.conversationTurnLimit = 4
        case .conversationTurns12:
            arm.prompt.conversationTurnLimit = 12
        case .minimalPrompt:
            arm.prompt.recipe = .minimal
        case .noExamples:
            arm.prompt.recipe = .noExamples
        case .dynamicLengthConservative:
            arm.generation.probabilityCount = 5
            arm.judgment.lengthPolicy = .confidenceBased
            arm.judgment.dynamicLength = LabDynamicLengthConfiguration(
                silenceBelowConfidence: 0.35,
                highConfidence: 0.60,
                veryHighConfidence: 0.82,
                shortMaximumWords: 2,
                clauseMaximumWords: 6,
                sentenceMaximumWords: 12
            )
        case .dynamicLengthBalanced:
            arm.generation.probabilityCount = 5
            arm.judgment.lengthPolicy = .confidenceBased
            arm.judgment.maximumVisibleWords = 20
            arm.judgment.maximumVisibleCharacters = 240
        case .dynamicLengthExpansive:
            arm.generation.probabilityCount = 5
            arm.judgment.lengthPolicy = .confidenceBased
            arm.judgment.maximumVisibleWords = 20
            arm.judgment.maximumVisibleCharacters = 240
            arm.judgment.dynamicLength = LabDynamicLengthConfiguration(
                silenceBelowConfidence: 0.15,
                highConfidence: 0.40,
                veryHighConfidence: 0.65,
                shortMaximumWords: 4,
                clauseMaximumWords: 10,
                sentenceMaximumWords: 20
            )
        }
        return arm
    }

    /// Content-policy mutations that can change whether a model completion is
    /// shown without weakening sensitive-scene suppression or other hard gates.
    public static let speakPolicyCases: [LabResearchMutation] = [
        .confidence025,
        .confidence030,
        .confidence035,
        .confidence040,
        .confidence050,
        .confidence060,
        .factualGroundingNamesNumbers,
        .factualGroundingAllAnchors,
        .sceneEchoAggressive,
        .sceneEchoConservative,
        .intentPrior015,
        .intentPrior050,
        .intentPrior075,
        .intentFutures2,
        .intentFutures1,
        .intentFutures6,
        .conversationTurns4,
        .conversationTurns2,
        .conversationTurns12,
        .visibleWords2,
        .visibleWords4,
        .predictionTokens6,
        .predictionTokens10,
        .dynamicLengthConservative,
        .dynamicLengthBalanced,
        .dynamicLengthExpansive,
    ]
}

public enum LabResearchSubsystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case generation
    case context
    case display
    case safety
    case all

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct LabAutoresearchConfiguration: Codable, Equatable, Sendable {
    public var screeningRepetitions: Int
    public var confirmationRepetitions: Int
    public var maximumTrials: Int
    public var survivorCount: Int
    public var controlInterval: Int
    public var protocolRetryCount: Int
    public var minimumBehavioralImprovement: Double
    public var randomizesTrialOrder: Bool
    public var restartsWorkersBetweenRounds: Bool
    public var timeBudgetMinutes: Int
    /// New campaigns intentionally isolate one subsystem. `nil` decodes old
    /// campaigns as their historical all-subsystem search.
    public var subsystem: LabResearchSubsystem?

    public init(
        screeningRepetitions: Int = 2,
        confirmationRepetitions: Int = 10,
        maximumTrials: Int = 12,
        survivorCount: Int = 3,
        controlInterval: Int = 4,
        protocolRetryCount: Int = 2,
        minimumBehavioralImprovement: Double = 0.005,
        randomizesTrialOrder: Bool = true,
        restartsWorkersBetweenRounds: Bool = true,
        timeBudgetMinutes: Int = 120,
        subsystem: LabResearchSubsystem? = .all
    ) {
        self.screeningRepetitions = screeningRepetitions
        self.confirmationRepetitions = confirmationRepetitions
        self.maximumTrials = maximumTrials
        self.survivorCount = survivorCount
        self.controlInterval = controlInterval
        self.protocolRetryCount = protocolRetryCount
        self.minimumBehavioralImprovement = minimumBehavioralImprovement
        self.randomizesTrialOrder = randomizesTrialOrder
        self.restartsWorkersBetweenRounds = restartsWorkersBetweenRounds
        self.timeBudgetMinutes = timeBudgetMinutes
        self.subsystem = subsystem
    }
}

public enum LabResearchDecision: String, Codable, Sendable {
    case baseline
    case control
    case confirmation
    case keep
    case discard
    case retry
    case failed
}

public struct LabResearchLedgerEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let trial: Int
    public let parentArmID: String?
    public let armID: String
    public let mutation: LabResearchMutation?
    public let reportID: UUID
    public let decision: LabResearchDecision
    public let verdict: LabRunVerdict
    public let normalizedP95Milliseconds: Double?
    public let recordedAt: Date

    public init(
        id: UUID = UUID(),
        trial: Int,
        parentArmID: String?,
        armID: String,
        mutation: LabResearchMutation?,
        reportID: UUID,
        decision: LabResearchDecision,
        verdict: LabRunVerdict,
        normalizedP95Milliseconds: Double? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.trial = trial
        self.parentArmID = parentArmID
        self.armID = armID
        self.mutation = mutation
        self.reportID = reportID
        self.decision = decision
        self.verdict = verdict
        self.normalizedP95Milliseconds = normalizedP95Milliseconds
        self.recordedAt = recordedAt
    }
}

public enum LabResearchCampaignState: String, Codable, Sendable {
    case ready
    case running
    case paused
    case completed
}

public struct LabResearchCampaign: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.autoresearch-campaign.v1"

    public let schema: String
    public let id: UUID
    public var name: String
    public let suiteDigestSHA256: String
    public let baselineArm: LabArmConfiguration
    public var championArm: LabArmConfiguration
    public var configuration: LabAutoresearchConfiguration
    public var state: LabResearchCampaignState
    public var ledger: [LabResearchLedgerEntry]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Autoresearch campaign",
        suiteDigestSHA256: String,
        baselineArm: LabArmConfiguration,
        configuration: LabAutoresearchConfiguration = .init(),
        state: LabResearchCampaignState = .ready,
        ledger: [LabResearchLedgerEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        schema = Self.currentSchema
        self.id = id
        self.name = name
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.baselineArm = baselineArm
        championArm = baselineArm
        self.configuration = configuration
        self.state = state
        self.ledger = ledger
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var completedMutationIDs: Set<String> {
        Set(ledger.compactMap(\.mutation?.rawValue))
    }

    public var championReportID: UUID? {
        ledger.last(where: {
            $0.decision == .keep || $0.decision == .baseline || $0.decision == .confirmation
        })?.reportID
    }
}

public enum LabAutoresearchPlanner {
    public static func pendingMutations(
        for campaign: LabResearchCampaign,
        seed: UInt64,
        candidates: [LabResearchMutation] = LabResearchMutation.allCases
    ) -> [LabResearchMutation] {
        var values = candidates.filter {
            !campaign.completedMutationIDs.contains($0.rawValue)
        }
        let subsystem = campaign.configuration.subsystem ?? .all
        if subsystem != .all {
            values = values.filter { $0.subsystem == subsystem }
        }
        if campaign.configuration.randomizesTrialOrder {
            var generator = LabResearchSeededGenerator(seed: seed)
            values.shuffle(using: &generator)
        }
        return Array(values.prefix(campaign.configuration.maximumTrials))
    }

    public static func decision(
        candidate: LabRunReport,
        champion: LabRunReport,
        controlP95Milliseconds: Int?,
        minimumImprovement: Double
    ) -> LabResearchDecision {
        let candidateRank = LabResearchRank(
            report: candidate,
            controlP95Milliseconds: controlP95Milliseconds,
            complexity: 1
        )
        let championRank = LabResearchRank(
            report: champion,
            controlP95Milliseconds: controlP95Milliseconds
        )
        return candidateRank.isBetter(than: championRank, minimumImprovement: minimumImprovement)
            ? .keep
            : .discard
    }
}

private struct LabResearchSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

public extension LabRunReport {
    var verdict: LabRunVerdict { LabRunVerdict(metrics: metrics) }

    var plainEnglishOutcome: String {
        if arm.scoring.usesModelOutputQuality {
            guard metrics.complete else {
                return "No quality result: the run had a timeout or protocol error."
            }
            let opportunities = cases.count(where: \.expectedSuggestion)
            return "\(metrics.useful) of \(opportunities) required reply opportunities produced a human-acceptable suggestion."
        }
        switch verdict {
        case .eligible:
            return "This configuration passed the direct-model research gates and is ready for protected confirmation. Interaction Bench must still pass before release."
        case .candidate:
            let failed = metrics.promotionGateFailures.count
            return "This configuration is usable, but missed \(failed) required threshold\(failed == 1 ? "" : "s")."
        case .degenerateSilence:
            return "No winner: this configuration avoided interruptions by giving no useful replies."
        case .incomplete:
            return "No winner: the run had a timeout or protocol error, so its score is withheld."
        }
    }
}
