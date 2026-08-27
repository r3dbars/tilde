import CryptoKit
import Foundation

public struct LabResearchPlan: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.frozen-plan.v2"
    public static let supportedSchemas = ["tilde-lab.frozen-plan.v1", currentSchema]

    public let schema: String
    public let id: UUID
    public let sourceCampaignID: UUID
    public let createdAt: Date
    public let manifest: LabExperimentManifest
    public let sourceComparisonDigestsSHA256: [String]
    public let suiteReference: LabResearchSuiteReference?
    public let sourceFailureEvidenceDigestsSHA256: [String]?

    public init(
        id: UUID = UUID(),
        sourceCampaignID: UUID,
        createdAt: Date = Date(),
        manifest: LabExperimentManifest,
        sourceComparisonDigestsSHA256: [String],
        suiteReference: LabResearchSuiteReference? = nil,
        sourceFailureEvidenceDigestsSHA256: [String]? = nil
    ) {
        schema = Self.currentSchema
        self.id = id
        self.sourceCampaignID = sourceCampaignID
        self.createdAt = createdAt
        self.manifest = manifest
        self.sourceComparisonDigestsSHA256 = sourceComparisonDigestsSHA256
        self.suiteReference = suiteReference
        self.sourceFailureEvidenceDigestsSHA256 = sourceFailureEvidenceDigestsSHA256
    }

    @discardableResult
    public func validated() throws -> LabResearchPlan {
        guard Self.supportedSchemas.contains(schema) else {
            throw LabResearchPlanError.unsupportedSchema
        }
        try manifest.validated()
        guard let research = manifest.research,
              research.phase == .developmentConfirmation
                || research.phase == .validation
                || research.phase == .holdout
                || research.phase == .regression,
              research.searchStrategy == .fixed,
              research.frozenInputs != nil else {
            throw LabResearchPlanError.notFrozen
        }
        if research.phase == .holdout, sourceComparisonDigestsSHA256.isEmpty {
            throw LabResearchPlanError.holdoutRequiresValidationEvidence
        }
        if research.phase == .regression {
            guard let suiteReference,
                  let evidence = sourceFailureEvidenceDigestsSHA256,
                  !evidence.isEmpty,
                  evidence.allSatisfy(Self.isSHA256) else {
                throw LabResearchPlanError.regressionRequiresFailureEvidence
            }
            try suiteReference.validated()
        } else if suiteReference != nil || sourceFailureEvidenceDigestsSHA256 != nil {
            throw LabResearchPlanError.regressionRequiresFailureEvidence
        }
        guard sourceComparisonDigestsSHA256.allSatisfy(Self.isSHA256) else {
            throw LabResearchPlanError.invalidComparisonDigest
        }
        return self
    }

    public func digestSHA256() throws -> String {
        try LabCanonicalDigest.sha256(self, dateEncodingStrategy: .iso8601)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.range(of: "^[a-f0-9]{64}$", options: .regularExpression)
            == value.startIndex..<value.endIndex
    }
}

public enum LabResearchPlanError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case invalidPhase
    case invalidCandidateCount
    case baselineAmongCandidates
    case selectedSuiteMismatch
    case notFrozen
    case holdoutRequiresValidationEvidence
    case regressionRequiresFailureEvidence
    case invalidComparisonDigest

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The frozen research plan schema is unsupported."
        case .invalidPhase:
            "Only development confirmation, validation, holdout, and regression can be frozen."
        case .invalidCandidateCount:
            "Development confirmation allows ten candidates, validation three, and holdout or regression exactly one."
        case .baselineAmongCandidates: "The baseline cannot also be nominated as a candidate."
        case .selectedSuiteMismatch: "Every frozen arm must select the exact same situations."
        case .notFrozen: "The research plan is mutable or lacks its frozen input hashes."
        case .holdoutRequiresValidationEvidence:
            "A holdout plan requires the digest of the candidate's passing validation comparison."
        case .regressionRequiresFailureEvidence:
            "A regression plan requires an exact suite reference and at least one SHA-256 failure-evidence digest."
        case .invalidComparisonDigest: "A source comparison digest is not a SHA-256 value."
        }
    }
}

public enum LabResearchPlanBuilder {
    public static func freeze(
        sourceCampaignID: UUID,
        name: String,
        phase: LabCampaignPhase,
        experimentClass: LabExperimentClass,
        baseline: LabArmConfiguration,
        candidates: [LabArmConfiguration],
        suite: LabScenarioSuite,
        assets: LabAssetSnapshot,
        runtime: LabRuntimeConfiguration,
        runtimeByArm: [String: LabRuntimeConfiguration]? = nil,
        suiteReference: LabResearchSuiteReference? = nil,
        regressionPartition: LabScenarioPartition = .regression,
        promotionRule: LabPromotionRule = .init(),
        utility: LabUtilityConfiguration = .init(),
        primaryMetric: LabPrimaryResearchMetric = .expectedUtility,
        fixedGenerationSeeds: [Int],
        sourceComparisonDigestsSHA256: [String] = [],
        sourceFailureEvidenceDigestsSHA256: [String]? = nil
    ) throws -> LabResearchPlan {
        guard phase == .developmentConfirmation || phase == .validation
                || phase == .holdout || phase == .regression else {
            throw LabResearchPlanError.invalidPhase
        }
        let maximumCandidates = phase == .developmentConfirmation ? 10 : phase == .validation ? 3 : 1
        guard !candidates.isEmpty, candidates.count <= maximumCandidates,
              phase != .holdout || candidates.count == 1 else {
            throw LabResearchPlanError.invalidCandidateCount
        }
        guard !candidates.contains(where: { $0.id == baseline.id }) else {
            throw LabResearchPlanError.baselineAmongCandidates
        }
        let partition: LabScenarioPartition
        switch phase {
        case .developmentConfirmation: partition = .development
        case .validation: partition = .validation
        case .holdout: partition = .holdout
        case .regression:
            guard regressionPartition == .regression || regressionPartition == .adversarial else {
                throw LabResearchPlanError.invalidPhase
            }
            partition = regressionPartition
        default: throw LabResearchPlanError.invalidPhase
        }
        var arms = [baseline] + candidates
        for index in arms.indices { arms[index].scenarios.partition = partition }
        let selected = try arms.map {
            try LabResearchScenarioSelection.select(
                from: suite,
                configuration: $0.scenarios,
                phase: phase
            )
        }
        let digests = try selected.map { try $0.digestSHA256() }
        guard Set(digests).count == 1, let suiteDigest = digests.first else {
            throw LabResearchPlanError.selectedSuiteMismatch
        }
        let scoringDigest = try arms[0].scoring.digestSHA256()
        let armDigests = try Dictionary(uniqueKeysWithValues: arms.map {
            ($0.id, try $0.digestSHA256())
        })
        let selectedRuntimeByArm: [String: LabRuntimeConfiguration]?
        if experimentClass == .runtime {
            guard let runtimeByArm else {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
            selectedRuntimeByArm = try Dictionary(uniqueKeysWithValues: arms.map { arm in
                guard let configuration = runtimeByArm[arm.id] else {
                    throw LabResearchProtocolError.runtimeConfigurationRequired
                }
                return (arm.id, configuration)
            })
        } else {
            guard runtimeByArm == nil else {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
            selectedRuntimeByArm = nil
        }
        let runtimeDigests = try selectedRuntimeByArm.map { configurations in
            try Dictionary(uniqueKeysWithValues: configurations.map {
                ($0.key, try $0.value.digestSHA256())
            })
        }
        let frozen = LabFrozenResearchInputs(
            suiteDigestSHA256: suiteDigest,
            scoringDigestSHA256: scoringDigest,
            modelSHA256: assets.modelSHA256,
            helperSHA256: assets.helperSHA256,
            armDigestsSHA256: armDigests,
            runtimeDigestsSHA256: runtimeDigests
        )
        let research = LabResearchProtocol(
            phase: phase,
            experimentClass: experimentClass,
            searchStrategy: .fixed,
            baselineArmID: baseline.id,
            fixedGenerationSeeds: fixedGenerationSeeds,
            primaryMetric: primaryMetric,
            utility: utility,
            promotionRule: promotionRule,
            runtimeByArm: selectedRuntimeByArm,
            frozenInputs: frozen
        )
        let manifest = try LabExperimentManifest(
            name: name,
            arms: arms,
            runtime: runtime,
            research: research
        ).validated()
        return try LabResearchPlan(
            sourceCampaignID: sourceCampaignID,
            manifest: manifest,
            sourceComparisonDigestsSHA256: sourceComparisonDigestsSHA256,
            suiteReference: suiteReference,
            sourceFailureEvidenceDigestsSHA256: sourceFailureEvidenceDigestsSHA256
        ).validated()
    }

    public static func comparisonDigest(_ report: LabPairedComparisonReport) throws -> String {
        try LabCanonicalDigest.sha256(report)
    }
}
