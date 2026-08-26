import Foundation

public enum LabLearningCycleOutcome: String, Codable, Sendable {
    case accepted
    case rejectedOnValidation = "rejected-on-validation"
    case rejectedOnHoldout = "rejected-on-holdout"
}

/// Aggregate-only score snapshot. It is deliberately small enough to compare
/// learning cycles without retaining prompts, model output, or personal text.
public struct LabLearningScoreSnapshot: Codable, Equatable, Sendable {
    public let partition: LabScenarioPartition
    public let reportID: UUID
    public let tildeScore: Int?
    public let netKeystrokeSavingsRate: Double?
    public let netKeystrokesSavedPer1000Characters: Double?
    public let usefulnessRate: Double
    public let ordinaryRestraintRate: Double?
    public let sensitiveRestraintRate: Double?
    public let counterfactualPairPassRate: Double?
    public let p95LatencyMilliseconds: Int?
    public let errors: Int
    public let timeouts: Int

    public init(partition: LabScenarioPartition, report: LabRunReport) {
        self.partition = partition
        reportID = report.id
        tildeScore = report.metrics.qualityScore
        netKeystrokeSavingsRate = report.metrics.netKeystrokeSavingsRate
        netKeystrokesSavedPer1000Characters = report.metrics.netKeystrokesSavedPer1000Characters
        usefulnessRate = report.metrics.usefulnessRate
        ordinaryRestraintRate = report.metrics.ordinaryRestraintRate
        sensitiveRestraintRate = report.metrics.sensitiveRestraintRate
        counterfactualPairPassRate = report.metrics.counterfactualPairPassRate
        p95LatencyMilliseconds = report.metrics.latency.p95Milliseconds
        errors = report.metrics.errors
        timeouts = report.metrics.timeouts
    }

    public init(
        partition: LabScenarioPartition,
        reportID: UUID = UUID(),
        tildeScore: Int?,
        netKeystrokeSavingsRate: Double? = nil,
        netKeystrokesSavedPer1000Characters: Double? = nil,
        usefulnessRate: Double,
        ordinaryRestraintRate: Double?,
        sensitiveRestraintRate: Double?,
        counterfactualPairPassRate: Double?,
        p95LatencyMilliseconds: Int?,
        errors: Int = 0,
        timeouts: Int = 0
    ) {
        self.partition = partition
        self.reportID = reportID
        self.tildeScore = tildeScore
        self.netKeystrokeSavingsRate = netKeystrokeSavingsRate
        self.netKeystrokesSavedPer1000Characters = netKeystrokesSavedPer1000Characters
        self.usefulnessRate = usefulnessRate
        self.ordinaryRestraintRate = ordinaryRestraintRate
        self.sensitiveRestraintRate = sensitiveRestraintRate
        self.counterfactualPairPassRate = counterfactualPairPassRate
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.errors = errors
        self.timeouts = timeouts
    }

    public var hardGatesPassed: Bool {
        errors == 0 && timeouts == 0 && sensitiveRestraintRate == 1
    }
}

public struct LabLearningCycleSummary: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.learning-cycle.v1"

    public let schema: String
    public let id: UUID
    public let campaignID: UUID
    public let suiteDigestSHA256: String?
    public let outcome: LabLearningCycleOutcome
    public let acceptedArm: LabArmConfiguration?
    public let developmentCandidate: LabLearningScoreSnapshot
    public let validationBaseline: LabLearningScoreSnapshot
    public let validationCandidate: LabLearningScoreSnapshot
    public let holdoutBaseline: LabLearningScoreSnapshot?
    public let holdoutCandidate: LabLearningScoreSnapshot?
    public let startedAt: Date
    public let finishedAt: Date

    public init(
        id: UUID = UUID(),
        campaignID: UUID,
        suiteDigestSHA256: String? = nil,
        outcome: LabLearningCycleOutcome,
        acceptedArm: LabArmConfiguration?,
        developmentCandidate: LabLearningScoreSnapshot,
        validationBaseline: LabLearningScoreSnapshot,
        validationCandidate: LabLearningScoreSnapshot,
        holdoutBaseline: LabLearningScoreSnapshot?,
        holdoutCandidate: LabLearningScoreSnapshot?,
        startedAt: Date,
        finishedAt: Date = Date()
    ) {
        schema = Self.currentSchema
        self.id = id
        self.campaignID = campaignID
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.outcome = outcome
        self.acceptedArm = acceptedArm
        self.developmentCandidate = developmentCandidate
        self.validationBaseline = validationBaseline
        self.validationCandidate = validationCandidate
        self.holdoutBaseline = holdoutBaseline
        self.holdoutCandidate = holdoutCandidate
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var finalTildeScore: Int? {
        switch outcome {
        case .accepted: holdoutCandidate?.tildeScore
        case .rejectedOnHoldout: holdoutBaseline?.tildeScore
        case .rejectedOnValidation: validationBaseline.tildeScore
        }
    }

    public var finalNetKeystrokeSavingsRate: Double? {
        switch outcome {
        case .accepted: holdoutCandidate?.netKeystrokeSavingsRate
        case .rejectedOnHoldout: holdoutBaseline?.netKeystrokeSavingsRate
        case .rejectedOnValidation: validationBaseline.netKeystrokeSavingsRate
        }
    }
}

public actor LabLearningCycleStore {
    public nonisolated let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.directory = support
                .appendingPathComponent("Tilde Lab", isDirectory: true)
                .appendingPathComponent("Learning Cycles", isDirectory: true)
        }
    }

    public func save(_ summary: LabLearningCycleSummary) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let destination = directory.appendingPathComponent("\(summary.id.uuidString).json")
        try encoder.encode(summary).write(to: destination, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }

    public func loadAll() -> [LabLearningCycleSummary] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? decoder.decode(LabLearningCycleSummary.self, from: $0) }
            .filter { $0.schema == LabLearningCycleSummary.currentSchema }
            .sorted { $0.finishedAt > $1.finishedAt }
    }

    public func hasConsumedHoldout(forSuiteDigest digest: String) -> Bool {
        loadAll().contains {
            $0.suiteDigestSHA256 == digest && $0.holdoutCandidate != nil
        }
    }
}
