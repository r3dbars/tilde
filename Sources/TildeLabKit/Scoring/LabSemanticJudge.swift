import Foundation

public struct LabCandidateObservation: Equatable, Sendable {
    public let scenarioID: String
    public let suggestion: String?

    public init(scenarioID: String, suggestion: String?) {
        self.scenarioID = scenarioID
        self.suggestion = suggestion
    }
}

public struct LabSemanticJudgePromptItem: Codable, Equatable, Sendable {
    public let id: String
    public let prompt: String
    public let candidateA: String?
    public let candidateB: String?

    public init(id: String, prompt: String, candidateA: String?, candidateB: String?) {
        self.id = id
        self.prompt = prompt
        self.candidateA = candidateA
        self.candidateB = candidateB
    }
}

public struct LabSemanticScores: Codable, Equatable, Sendable {
    public let intent: Int
    public let usefulness: Int
    public let naturalness: Int
    public let factuality: Int

    public init(intent: Int, usefulness: Int, naturalness: Int, factuality: Int) {
        self.intent = intent
        self.usefulness = usefulness
        self.naturalness = naturalness
        self.factuality = factuality
    }

    public var isValid: Bool {
        [intent, usefulness, naturalness, factuality].allSatisfy { (0...4).contains($0) }
    }

    public var overall: Double {
        guard isValid else { return 0 }
        let weighted = Double(intent) * 0.35
            + Double(usefulness) * 0.35
            + Double(naturalness) * 0.15
            + Double(factuality) * 0.15
        return weighted / 4 * 100
    }

    public var isHumanUseful: Bool {
        intent >= 3 && usefulness >= 3 && naturalness >= 2 && factuality >= 3
    }
}

public struct LabSemanticPairJudgment: Codable, Equatable, Sendable {
    public let id: String
    public let candidateA: LabSemanticScores
    public let candidateB: LabSemanticScores

    public init(id: String, candidateA: LabSemanticScores, candidateB: LabSemanticScores) {
        self.id = id
        self.candidateA = candidateA
        self.candidateB = candidateB
    }
}

public protocol LabSemanticJudgeBatchClient: Sendable {
    func verifySubscription(model: String) async throws -> LabAssetSnapshot
    func judge(
        items: [LabSemanticJudgePromptItem],
        model: String,
        timeoutSeconds: Double
    ) async throws -> [LabSemanticPairJudgment]
    func cancel() async
}

public struct LabSemanticModelSummary: Codable, Equatable, Sendable {
    public let modelIdentifier: String
    public let strictQualityScore: Int
    public let strictAcceptableRate: Double
    public let semanticOverallScore: Int
    public let semanticUsefulRate: Double
    public let intentScore: Int
    public let usefulnessScore: Int
    public let naturalnessScore: Int
    public let factualityScore: Int

    public init(
        modelIdentifier: String,
        strictQualityScore: Int,
        strictAcceptableRate: Double,
        semanticOverallScore: Int,
        semanticUsefulRate: Double,
        intentScore: Int,
        usefulnessScore: Int,
        naturalnessScore: Int,
        factualityScore: Int
    ) {
        self.modelIdentifier = modelIdentifier
        self.strictQualityScore = strictQualityScore
        self.strictAcceptableRate = strictAcceptableRate
        self.semanticOverallScore = semanticOverallScore
        self.semanticUsefulRate = semanticUsefulRate
        self.intentScore = intentScore
        self.usefulnessScore = usefulnessScore
        self.naturalnessScore = naturalnessScore
        self.factualityScore = factualityScore
    }
}

public struct LabSemanticShootoutReport: Codable, Equatable, Sendable {
    public static let schema = "tilde-lab.semantic-shootout.v1"

    public let schema: String
    public let scenarioCount: Int
    public let judgeModel: String
    public let first: LabSemanticModelSummary
    public let second: LabSemanticModelSummary
    public let networkInference: Bool
    public let rawTextPersisted: Bool

    public init(
        scenarioCount: Int,
        judgeModel: String,
        first: LabSemanticModelSummary,
        second: LabSemanticModelSummary
    ) {
        schema = Self.schema
        self.scenarioCount = scenarioCount
        self.judgeModel = judgeModel
        self.first = first
        self.second = second
        networkInference = true
        rawTextPersisted = false
    }
}

public enum LabSemanticJudgeScorer {
    public static func summarize(
        modelIdentifier: String,
        strictReport: LabRunReport,
        scores: [LabSemanticScores]
    ) -> LabSemanticModelSummary {
        let count = scores.count
        func average(_ value: (LabSemanticScores) -> Int) -> Int {
            guard count > 0 else { return 0 }
            return Int((Double(scores.reduce(0) { $0 + value($1) }) / Double(count) / 4 * 100).rounded())
        }
        let overall = count > 0
            ? Int((scores.reduce(0) { $0 + $1.overall } / Double(count)).rounded())
            : 0
        let useful = count > 0
            ? Double(scores.count(where: \.isHumanUseful)) / Double(count)
            : 0
        return LabSemanticModelSummary(
            modelIdentifier: modelIdentifier,
            strictQualityScore: strictReport.metrics.qualityScore ?? 0,
            strictAcceptableRate: strictReport.metrics.usefulnessRate,
            semanticOverallScore: overall,
            semanticUsefulRate: useful,
            intentScore: average(\.intent),
            usefulnessScore: average(\.usefulness),
            naturalnessScore: average(\.naturalness),
            factualityScore: average(\.factuality)
        )
    }
}

public actor LabCandidateObservationStore {
    private var values: [String: LabCandidateObservation] = [:]

    public init() {}

    public func record(_ observation: LabCandidateObservation) {
        values[observation.scenarioID] = observation
    }

    public func snapshot() -> [String: String?] {
        values.mapValues(\.suggestion)
    }
}
