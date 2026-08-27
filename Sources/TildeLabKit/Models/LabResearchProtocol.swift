import CryptoKit
import Foundation

/// The scientific phase of a Tilde Lab campaign. Protected partitions are
/// deliberately represented here rather than inferred from a scenario filter.
public enum LabCampaignPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case discovery
    case developmentConfirmation = "development-confirmation"
    case validation
    case holdout
    case shadow
    case dogfood
    case regression
    case soak

    public var id: String { rawValue }

    public var title: String {
        rawValue.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }
}

/// One campaign answers one causal question. Keeping these classes separate
/// prevents a faster runtime or looser cleaner from being credited as a better
/// generator.
public enum LabExperimentClass: String, Codable, CaseIterable, Identifiable, Sendable {
    case generator
    case context
    case displayPolicy = "display-policy"
    case personalization
    case runtime
    case interaction

    public var id: String { rawValue }

    public var title: String {
        rawValue.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }
}

public enum LabSearchStrategy: String, Codable, CaseIterable, Sendable {
    case fixed
    case quasiRandom = "quasi-random"
    case successiveHalving = "successive-halving"
    case adaptive

    public var isAdaptive: Bool { self != .fixed }
}

public enum LabPrimaryResearchMetric: String, Codable, CaseIterable, Sendable {
    case expectedUtility = "expected-utility"
    case oracleNetKeystrokeSavings = "oracle-net-keystroke-savings"
    case precisionWhenShown = "precision-when-shown"
}

/// A narrow non-promotional exception for the corpus falsification proof. It
/// exercises every partition to establish that context is causally useful; it
/// never ranks or mutates candidate arms.
public enum LabProtectedEvaluationPurpose: Equatable, Sendable {
    case none
    case corpusCertification
}

/// Transparent starting assumptions for the offline utility proxy. Dogfood can
/// replace these with locally estimated values later; a campaign may not tune
/// the weights after protected evaluation begins.
public struct LabUtilityConfiguration: Codable, Equatable, Sendable {
    public var firstStableWordDeadlineMilliseconds: Int
    public var typingCharactersPerSecond: Double
    public var usefulAcceptanceProbability: Double
    public var acceptanceActionMilliseconds: Double
    public var ignoredAttentionMilliseconds: Double
    public var wrongAttentionMilliseconds: Double
    public var correctionMillisecondsPerCharacter: Double

    public init(
        firstStableWordDeadlineMilliseconds: Int = 400,
        typingCharactersPerSecond: Double = 5,
        usefulAcceptanceProbability: Double = 0.65,
        acceptanceActionMilliseconds: Double = 90,
        ignoredAttentionMilliseconds: Double = 80,
        wrongAttentionMilliseconds: Double = 220,
        correctionMillisecondsPerCharacter: Double = 80
    ) {
        self.firstStableWordDeadlineMilliseconds = firstStableWordDeadlineMilliseconds
        self.typingCharactersPerSecond = typingCharactersPerSecond
        self.usefulAcceptanceProbability = usefulAcceptanceProbability
        self.acceptanceActionMilliseconds = acceptanceActionMilliseconds
        self.ignoredAttentionMilliseconds = ignoredAttentionMilliseconds
        self.wrongAttentionMilliseconds = wrongAttentionMilliseconds
        self.correctionMillisecondsPerCharacter = correctionMillisecondsPerCharacter
    }

    @discardableResult
    public func validated() throws -> LabUtilityConfiguration {
        guard (50...5_000).contains(firstStableWordDeadlineMilliseconds),
              (0.5...30).contains(typingCharactersPerSecond),
              (0...1).contains(usefulAcceptanceProbability),
              acceptanceActionMilliseconds >= 0,
              ignoredAttentionMilliseconds >= 0,
              wrongAttentionMilliseconds >= 0,
              correctionMillisecondsPerCharacter >= 0 else {
            throw LabResearchProtocolError.invalidUtilityConfiguration
        }
        return self
    }
}

/// Pre-registered statistical decision rule. A composite rank may help order a
/// discovery queue, but it cannot overrule these constraints.
public struct LabPromotionRule: Codable, Equatable, Sendable {
    public var bootstrapIterations: Int
    public var minimumProbabilityPositive: Double
    public var minimumPrimaryEffect: Double
    public var maximumBadWhenShownIncrease: Double
    public var latencyNoninferiorityMilliseconds: Double
    public var maximumProtectedSliceRegression: Double

    public init(
        bootstrapIterations: Int = 10_000,
        minimumProbabilityPositive: Double = 0.95,
        minimumPrimaryEffect: Double = 0,
        maximumBadWhenShownIncrease: Double = 0,
        latencyNoninferiorityMilliseconds: Double = 25,
        maximumProtectedSliceRegression: Double = 0
    ) {
        self.bootstrapIterations = bootstrapIterations
        self.minimumProbabilityPositive = minimumProbabilityPositive
        self.minimumPrimaryEffect = minimumPrimaryEffect
        self.maximumBadWhenShownIncrease = maximumBadWhenShownIncrease
        self.latencyNoninferiorityMilliseconds = latencyNoninferiorityMilliseconds
        self.maximumProtectedSliceRegression = maximumProtectedSliceRegression
    }

    @discardableResult
    public func validated() throws -> LabPromotionRule {
        guard (100...100_000).contains(bootstrapIterations),
              (0...1).contains(minimumProbabilityPositive),
              maximumBadWhenShownIncrease >= 0,
              latencyNoninferiorityMilliseconds >= 0,
              maximumProtectedSliceRegression >= 0 else {
            throw LabResearchProtocolError.invalidPromotionRule
        }
        return self
    }
}

/// Immutable evidence recorded before validation or holdout begins. Hashes bind
/// the decision to exact candidates, suite, scorecard, model, and helper bytes.
public struct LabFrozenResearchInputs: Codable, Equatable, Sendable {
    public let suiteDigestSHA256: String
    public let scoringDigestSHA256: String
    public let modelSHA256: String
    public let helperSHA256: String
    public let armDigestsSHA256: [String: String]
    public let runtimeDigestsSHA256: [String: String]?
    public let frozenAt: Date

    public init(
        suiteDigestSHA256: String,
        scoringDigestSHA256: String,
        modelSHA256: String,
        helperSHA256: String,
        armDigestsSHA256: [String: String],
        runtimeDigestsSHA256: [String: String]? = nil,
        frozenAt: Date = Date()
    ) {
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.scoringDigestSHA256 = scoringDigestSHA256
        self.modelSHA256 = modelSHA256
        self.helperSHA256 = helperSHA256
        self.armDigestsSHA256 = armDigestsSHA256
        self.runtimeDigestsSHA256 = runtimeDigestsSHA256
        self.frozenAt = frozenAt
    }
}

public struct LabResearchProtocol: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.research-protocol.v2"

    public var schema: String
    public var phase: LabCampaignPhase
    public var experimentClass: LabExperimentClass
    public var searchStrategy: LabSearchStrategy
    public var baselineArmID: String
    public var fixedGenerationSeeds: [Int]
    public var interleavedRootBlockSize: Int
    public var primaryMetric: LabPrimaryResearchMetric
    public var utility: LabUtilityConfiguration
    public var promotionRule: LabPromotionRule
    /// Runtime campaigns keep product behavior identical across arms and vary
    /// only this explicit, per-arm helper configuration. Other experiment
    /// classes must leave the map nil.
    public var runtimeByArm: [String: LabRuntimeConfiguration]?
    public var frozenInputs: LabFrozenResearchInputs?

    public init(
        schema: String = Self.currentSchema,
        phase: LabCampaignPhase = .discovery,
        experimentClass: LabExperimentClass = .generator,
        searchStrategy: LabSearchStrategy = .fixed,
        baselineArmID: String,
        fixedGenerationSeeds: [Int] = [0],
        interleavedRootBlockSize: Int = 20,
        primaryMetric: LabPrimaryResearchMetric = .expectedUtility,
        utility: LabUtilityConfiguration = .init(),
        promotionRule: LabPromotionRule = .init(),
        runtimeByArm: [String: LabRuntimeConfiguration]? = nil,
        frozenInputs: LabFrozenResearchInputs? = nil
    ) {
        self.schema = schema
        self.phase = phase
        self.experimentClass = experimentClass
        self.searchStrategy = searchStrategy
        self.baselineArmID = baselineArmID
        self.fixedGenerationSeeds = fixedGenerationSeeds
        self.interleavedRootBlockSize = interleavedRootBlockSize
        self.primaryMetric = primaryMetric
        self.utility = utility
        self.promotionRule = promotionRule
        self.runtimeByArm = runtimeByArm
        self.frozenInputs = frozenInputs
    }
}

public enum LabResearchProtocolError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case missingBaseline
    case duplicateSeed
    case seedSearchForbidden
    case invalidBlockSize
    case invalidUtilityConfiguration
    case invalidPromotionRule
    case adaptiveProtectedPhase
    case protectedPartitionRequiresRegistration
    case phasePartitionMismatch
    case tooManyDevelopmentCandidates
    case tooManyValidationCandidates
    case holdoutRequiresOneCandidate
    case regressionRequiresOneCandidate
    case protectedInputsNotFrozen
    case frozenInputMismatch
    case scoringUnlocked
    case unsafeGuardrail
    case scenarioSelectionDrift
    case mixedExperimentClass
    case runtimeConfigurationRequired
    case runtimeMeasurementDrift
    case onlinePhaseRequiresTelemetry

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema:
            "The Tilde Lab research protocol schema is unsupported."
        case .missingBaseline:
            "The research baseline arm is missing from the manifest."
        case .duplicateSeed:
            "Generation seeds must be a unique, pre-registered set."
        case .seedSearchForbidden:
            "Generation seed is measurement control, not a search parameter. Every arm must use the same pre-registered seed."
        case .invalidBlockSize:
            "Interleaved root blocks must contain 1...500 independent situations."
        case .invalidUtilityConfiguration:
            "The expected-utility assumptions are outside their safe bounds."
        case .invalidPromotionRule:
            "The pre-registered promotion rule is invalid."
        case .adaptiveProtectedPhase:
            "Adaptive search is development-only. Validation and holdout accept frozen candidates only."
        case .protectedPartitionRequiresRegistration:
            "Validation and holdout require an explicit pre-registered research protocol."
        case .phasePartitionMismatch:
            "The campaign phase does not permit one or more selected scenario partitions."
        case .tooManyDevelopmentCandidates:
            "Development confirmation permits a baseline and at most ten frozen candidates."
        case .tooManyValidationCandidates:
            "Validation permits a baseline and at most three pre-registered candidates."
        case .holdoutRequiresOneCandidate:
            "Holdout requires exactly one frozen candidate versus one baseline."
        case .regressionRequiresOneCandidate:
            "Regression proof requires exactly one frozen candidate versus one baseline."
        case .protectedInputsNotFrozen:
            "Development confirmation, validation, and holdout require frozen suite, scorecard, model, helper, and candidate hashes."
        case .frozenInputMismatch:
            "A frozen suite, scorecard, model, helper, or candidate hash changed after pre-registration."
        case .scoringUnlocked:
            "Research scorecards must remain locked and identical across every arm."
        case .unsafeGuardrail:
            "A research arm disabled a non-negotiable safety guardrail."
        case .scenarioSelectionDrift:
            "Paired research arms must select the same underlying situations."
        case .mixedExperimentClass:
            "A campaign changed controls outside its declared experiment class."
        case .runtimeConfigurationRequired:
            "Runtime research requires one validated runtime configuration per arm, with the manifest runtime equal to the baseline. Other experiment classes may not carry per-arm runtimes."
        case .runtimeMeasurementDrift:
            "Runtime arms must share repetitions, timeout, and measurement seed so their timing samples remain paired."
        case .onlinePhaseRequiresTelemetry:
            "Shadow and dogfood are local telemetry phases, not offline fixture runs."
        }
    }
}

public enum LabResearchProtocolValidator {
    /// Structural validation available before a suite or model is loaded.
    public static func validate(
        _ research: LabResearchProtocol,
        arms: [LabArmConfiguration]
    ) throws {
        guard research.schema == LabResearchProtocol.currentSchema else {
            throw LabResearchProtocolError.unsupportedSchema
        }
        guard let baseline = arms.first(where: { $0.id == research.baselineArmID }) else {
            throw LabResearchProtocolError.missingBaseline
        }
        guard Set(research.fixedGenerationSeeds).count == research.fixedGenerationSeeds.count,
              !research.fixedGenerationSeeds.isEmpty else {
            throw LabResearchProtocolError.duplicateSeed
        }
        guard (1...500).contains(research.interleavedRootBlockSize) else {
            throw LabResearchProtocolError.invalidBlockSize
        }
        try research.utility.validated()
        try research.promotionRule.validated()
        if research.phase != .discovery, research.searchStrategy.isAdaptive {
            throw LabResearchProtocolError.adaptiveProtectedPhase
        }
        if research.phase == .shadow || research.phase == .dogfood {
            throw LabResearchProtocolError.onlinePhaseRequiresTelemetry
        }

        let candidates = arms.count - 1
        if research.phase == .developmentConfirmation, candidates > 10 {
            throw LabResearchProtocolError.tooManyDevelopmentCandidates
        }
        if research.phase == .validation, candidates > 3 {
            throw LabResearchProtocolError.tooManyValidationCandidates
        }
        if research.phase == .holdout, candidates != 1 || arms.count != 2 {
            throw LabResearchProtocolError.holdoutRequiresOneCandidate
        }
        if research.phase == .regression, candidates != 1 || arms.count != 2 {
            throw LabResearchProtocolError.regressionRequiresOneCandidate
        }
        if research.phase == .developmentConfirmation
            || research.phase == .validation
            || research.phase == .holdout
            || research.phase == .regression,
           research.frozenInputs == nil {
            throw LabResearchProtocolError.protectedInputsNotFrozen
        }
        guard arms.allSatisfy(\.scoring.weightsLockedDuringComparison),
              arms.allSatisfy({ $0.scoring == baseline.scoring }) else {
            throw LabResearchProtocolError.scoringUnlocked
        }
        guard arms.allSatisfy(hasHardGuardrails) else {
            throw LabResearchProtocolError.unsafeGuardrail
        }
        guard arms.allSatisfy({ $0.scenarios == baseline.scenarios }) else {
            throw LabResearchProtocolError.scenarioSelectionDrift
        }
        guard arms.allSatisfy({ $0.generation.seed == baseline.generation.seed }),
              research.fixedGenerationSeeds.contains(baseline.generation.seed) else {
            throw LabResearchProtocolError.seedSearchForbidden
        }
        guard arms.allSatisfy({ belongsToDeclaredClass($0, baseline: baseline, kind: research.experimentClass) }) else {
            throw LabResearchProtocolError.mixedExperimentClass
        }
        if research.experimentClass == .runtime {
            guard let runtimes = research.runtimeByArm,
                  Set(runtimes.keys) == Set(arms.map(\.id)),
                  arms.count >= 2 else {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
            for runtime in runtimes.values { try runtime.validated() }
            guard let baselineRuntime = runtimes[research.baselineArmID],
                  runtimes.values.allSatisfy({
                      $0.repetitions == baselineRuntime.repetitions
                          && $0.timeoutSeconds == baselineRuntime.timeoutSeconds
                          && $0.seed == baselineRuntime.seed
                  }) else {
                throw LabResearchProtocolError.runtimeMeasurementDrift
            }
            guard runtimes.values.contains(where: { $0 != baselineRuntime }) else {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
        } else if research.runtimeByArm != nil {
            throw LabResearchProtocolError.runtimeConfigurationRequired
        }

        let permittedPartitions = allowedPartitions(for: research.phase)
        guard arms.allSatisfy({ permittedPartitions.contains($0.scenarios.partition) }) else {
            throw LabResearchProtocolError.phasePartitionMismatch
        }
        try validateFrozenArmAndScoreHashes(research, arms: arms)
    }

    /// Final firewall after scenario selection and asset verification. This is
    /// what prevents an `.all` filter or stale plan from reaching protected data.
    public static func validateExecution(
        research: LabResearchProtocol?,
        arms: [LabArmConfiguration],
        selectedSuites: [LabScenarioSuite],
        selectedSuiteDigests: [String],
        assets: LabAssetSnapshot,
        protectedPurpose: LabProtectedEvaluationPurpose = .none
    ) throws {
        guard let research else {
            let partitions = Set(selectedSuites.flatMap { $0.scenarios.map(\.partition) })
            if partitions.contains(.validation) || partitions.contains(.holdout) {
                guard protectedPurpose == .corpusCertification,
                      (1...3).contains(arms.count),
                      arms.allSatisfy({ $0.id.hasPrefix("corpus-cert-") }),
                      arms.allSatisfy(hasHardGuardrails) else {
                    throw LabResearchProtocolError.protectedPartitionRequiresRegistration
                }
            }
            return
        }
        try validate(research, arms: arms)
        let selectedPartitions = Set(selectedSuites.flatMap { $0.scenarios.map(\.partition) })
        guard selectedPartitions.isSubset(of: allowedPartitions(for: research.phase)) else {
            throw LabResearchProtocolError.phasePartitionMismatch
        }
        guard Set(selectedSuiteDigests).count == 1 else {
            throw LabResearchProtocolError.scenarioSelectionDrift
        }
        guard let frozen = research.frozenInputs else {
            if research.phase == .developmentConfirmation
                || research.phase == .validation
                || research.phase == .holdout {
                throw LabResearchProtocolError.protectedInputsNotFrozen
            }
            return
        }
        guard selectedSuiteDigests.first == frozen.suiteDigestSHA256,
              assets.modelSHA256 == frozen.modelSHA256,
              assets.helperSHA256 == frozen.helperSHA256 else {
            throw LabResearchProtocolError.frozenInputMismatch
        }
    }

    public static func allowedPartitions(for phase: LabCampaignPhase) -> Set<LabScenarioPartition> {
        switch phase {
        case .discovery, .developmentConfirmation:
            [.development]
        case .validation:
            [.validation]
        case .holdout:
            [.holdout]
        case .regression:
            [.regression, .adversarial]
        case .soak:
            [.regression, .adversarial]
        case .shadow, .dogfood:
            []
        }
    }

    private static func hasHardGuardrails(_ arm: LabArmConfiguration) -> Bool {
        arm.judgment.suppressesSensitiveScenes
            && arm.judgment.rejectsSceneEcho
            && arm.judgment.rejectsPromptLeaks
            && arm.judgment.rejectsContextReplay
            && arm.judgment.rejectsSelfRepetition
            && arm.judgment.cleanerPreset != .diagnostic
            && arm.interaction.testsCancellation
            && arm.interaction.testsBackspaceDuringInference
            && arm.interaction.testsCursorMovement
            && arm.interaction.testsSelectionChanges
            && arm.interaction.testsFocusChanges
            && arm.interaction.testsRuntimeRestart
    }

    private static func belongsToDeclaredClass(
        _ arm: LabArmConfiguration,
        baseline: LabArmConfiguration,
        kind: LabExperimentClass
    ) -> Bool {
        guard arm.scoring == baseline.scoring,
              arm.scenarios == baseline.scenarios else { return false }
        switch kind {
        case .generator:
            return arm.generation.probabilityCount == baseline.generation.probabilityCount
                && arm.generation.minimumMeanTokenProbability
                    == baseline.generation.minimumMeanTokenProbability
                && arm.prompt == baseline.prompt
                && arm.judgment == baseline.judgment
                && arm.sceneBench == baseline.sceneBench
                && arm.personalization == baseline.personalization
                && arm.interaction == baseline.interaction
        case .context:
            return arm.generation == baseline.generation
                && arm.judgment == baseline.judgment
                && arm.personalization == baseline.personalization
                && arm.interaction == baseline.interaction
        case .displayPolicy:
            return generationWithoutConfidence(arm.generation)
                    == generationWithoutConfidence(baseline.generation)
                && arm.prompt == baseline.prompt
                && arm.sceneBench == baseline.sceneBench
                && arm.personalization == baseline.personalization
                && arm.interaction == baseline.interaction
                && hardGuardrailSignature(arm.judgment) == hardGuardrailSignature(baseline.judgment)
        case .personalization:
            return arm.generation == baseline.generation
                && arm.prompt == baseline.prompt
                && arm.judgment == baseline.judgment
                && arm.sceneBench == baseline.sceneBench
                && arm.interaction == baseline.interaction
        case .runtime:
            var candidate = arm
            candidate.id = baseline.id
            return candidate == baseline
        case .interaction:
            return arm.generation == baseline.generation
                && arm.prompt == baseline.prompt
                && arm.judgment == baseline.judgment
                && arm.sceneBench == baseline.sceneBench
                && arm.personalization == baseline.personalization
        }
    }

    private static func generationWithoutConfidence(
        _ source: LabGenerationConfiguration
    ) -> LabGenerationConfiguration {
        var result = source
        result.probabilityCount = 0
        result.minimumMeanTokenProbability = 0
        return result
    }

    private static func hardGuardrailSignature(_ value: LabJudgmentConfiguration) -> String {
        [
            String(value.suppressesSensitiveScenes),
            String(value.rejectsSceneEcho),
            String(value.rejectsPromptLeaks),
            String(value.rejectsContextReplay),
            String(value.rejectsSelfRepetition),
        ].joined(separator: ":")
    }

    private static func validateFrozenArmAndScoreHashes(
        _ research: LabResearchProtocol,
        arms: [LabArmConfiguration]
    ) throws {
        guard let frozen = research.frozenInputs else { return }
        let armHashes = try Dictionary(uniqueKeysWithValues: arms.map { arm in
            (arm.id, try arm.digestSHA256())
        })
        let scoringHash = try arms[0].scoring.digestSHA256()
        let runtimeHashes = try research.runtimeByArm.map { runtimes in
            try Dictionary(uniqueKeysWithValues: runtimes.map {
                ($0.key, try $0.value.digestSHA256())
            })
        }
        guard frozen.armDigestsSHA256 == armHashes,
              frozen.scoringDigestSHA256 == scoringHash,
              frozen.runtimeDigestsSHA256 == runtimeHashes else {
            throw LabResearchProtocolError.frozenInputMismatch
        }
    }
}

public extension LabArmConfiguration {
    func digestSHA256() throws -> String {
        try LabResearchDigest.sha256(self)
    }
}

public extension LabScoringConfiguration {
    func digestSHA256() throws -> String {
        try LabResearchDigest.sha256(self)
    }
}

public extension LabRuntimeConfiguration {
    func digestSHA256() throws -> String {
        try LabResearchDigest.sha256(self)
    }
}

private enum LabResearchDigest {
    static func sha256<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(value)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
