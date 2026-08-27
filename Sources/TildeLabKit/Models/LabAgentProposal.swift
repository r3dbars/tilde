import Foundation

public enum LabProposalValue: Codable, Equatable, Sendable {
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .boolean(value) }
        else if let value = try? container.decode(Int.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .boolean(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        }
    }

    var double: Double? {
        switch self {
        case let .integer(value): Double(value)
        case let .number(value): value
        case .boolean, .string: nil
        }
    }

    var integer: Int? {
        switch self {
        case let .integer(value): value
        case let .number(value) where value.rounded() == value: Int(value)
        case .number, .boolean, .string: nil
        }
    }

    var boolean: Bool? {
        if case let .boolean(value) = self { return value }
        return nil
    }

    var string: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}

public struct LabAgentSuccessRule: Codable, Equatable, Sendable {
    public let minimumDeltaExpectedUtility: Double
    public let maximumDeltaBadWhenShown: Double
    public let latencyNoninferiorityMilliseconds: Double

    public init(
        minimumDeltaExpectedUtility: Double,
        maximumDeltaBadWhenShown: Double,
        latencyNoninferiorityMilliseconds: Double
    ) {
        self.minimumDeltaExpectedUtility = minimumDeltaExpectedUtility
        self.maximumDeltaBadWhenShown = maximumDeltaBadWhenShown
        self.latencyNoninferiorityMilliseconds = latencyNoninferiorityMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case minimumDeltaExpectedUtility = "minimum_delta_expected_utility"
        case maximumDeltaBadWhenShown = "maximum_delta_bad_when_shown"
        case latencyNoninferiorityMilliseconds = "latency_noninferiority_ms"
    }
}

public struct LabAgentProposalBudget: Codable, Equatable, Sendable {
    public let roots: Int
    public let seeds: [Int]

    public init(roots: Int, seeds: [Int]) {
        self.roots = roots
        self.seeds = seeds
    }
}

public struct LabAgentProposal: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.agent-proposal.v1"

    public let schema: String
    public let hypothesis: String
    public let parentArmID: String
    public let experimentClass: LabExperimentClass
    public let phase: LabCampaignPhase
    public let changes: [String: LabProposalValue]
    public let expectedAffectedSlices: [String]
    public let successRule: LabAgentSuccessRule
    public let budget: LabAgentProposalBudget
    public let stopConditions: [String]

    public init(
        schema: String = Self.currentSchema,
        hypothesis: String,
        parentArmID: String,
        experimentClass: LabExperimentClass,
        phase: LabCampaignPhase,
        changes: [String: LabProposalValue],
        expectedAffectedSlices: [String],
        successRule: LabAgentSuccessRule,
        budget: LabAgentProposalBudget,
        stopConditions: [String]
    ) {
        self.schema = schema
        self.hypothesis = hypothesis
        self.parentArmID = parentArmID
        self.experimentClass = experimentClass
        self.phase = phase
        self.changes = changes
        self.expectedAffectedSlices = expectedAffectedSlices
        self.successRule = successRule
        self.budget = budget
        self.stopConditions = stopConditions
    }

    private enum CodingKeys: String, CodingKey {
        case schema, hypothesis, phase, changes, budget
        case parentArmID = "parent_arm_id"
        case experimentClass = "experiment_class"
        case expectedAffectedSlices = "expected_affected_slices"
        case successRule = "success_rule"
        case stopConditions = "stop_conditions"
    }
}

/// Aggregate-only summary suitable for an external reasoning agent. There is
/// intentionally no scenario, prompt, continuation, or protected-example field.
public struct LabAgentEvidenceEnvelope: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.agent-evidence.v1"

    public let schema: String
    public let campaignGoal: String
    public let permittedExperimentClass: LabExperimentClass
    public let aggregateComparisons: [LabPairedComparisonReport]
    public let failureReasonCounts: [String: Int]
    public let sliceRedBars: [LabSliceComparison]
    public let testedArmDigests: [String: String]
    public let remainingBudget: LabResearchBudget

    public init(
        campaignGoal: String,
        permittedExperimentClass: LabExperimentClass,
        aggregateComparisons: [LabPairedComparisonReport],
        failureReasonCounts: [String: Int],
        sliceRedBars: [LabSliceComparison],
        testedArmDigests: [String: String],
        remainingBudget: LabResearchBudget
    ) {
        schema = Self.currentSchema
        self.campaignGoal = campaignGoal
        self.permittedExperimentClass = permittedExperimentClass
        self.aggregateComparisons = aggregateComparisons
        self.failureReasonCounts = failureReasonCounts
        self.sliceRedBars = sliceRedBars
        self.testedArmDigests = testedArmDigests
        self.remainingBudget = remainingBudget
    }

    private enum CodingKeys: String, CodingKey {
        case schema
        case campaignGoal = "campaign_goal"
        case permittedExperimentClass = "permitted_experiment_class"
        case aggregateComparisons = "aggregate_comparisons"
        case failureReasonCounts = "failure_reason_counts"
        case sliceRedBars = "slice_red_bars"
        case testedArmDigests = "tested_arm_digests"
        case remainingBudget = "remaining_budget"
    }
}

public enum LabAgentProposalError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case invalidText
    case parentMissing
    case phaseForbidden
    case experimentClassMismatch
    case tooManyChanges
    case forbiddenChange(String)
    case invalidValue(String)
    case budgetExceeded
    case seedMutation
    case resultingArmInvalid

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The agent proposal schema is unsupported."
        case .invalidText: "Agent proposal prose must be bounded and contain no control characters."
        case .parentMissing: "The proposal parent arm does not exist."
        case .phaseForbidden: "Agent proposals are accepted only during discovery."
        case .experimentClassMismatch: "The proposal targets a frozen experiment class."
        case .tooManyChanges: "A discovery proposal may change at most four declared knobs."
        case let .forbiddenChange(key): "The agent proposal may not change \(key)."
        case let .invalidValue(key): "The agent proposal supplied an invalid value for \(key)."
        case .budgetExceeded: "The agent proposal exceeds the remaining campaign budget."
        case .seedMutation: "The agent may use only the pre-registered measurement seed set."
        case .resultingArmInvalid: "The proposed arm failed normal Tilde Lab validation."
        }
    }
}

public enum LabAgentProposalValidator {
    public static func apply(
        _ proposal: LabAgentProposal,
        protocolDefinition: LabResearchProtocol,
        campaignBudget: LabResearchBudget,
        arms: [LabArmConfiguration],
        resultingArmID: String
    ) throws -> LabArmConfiguration {
        guard proposal.schema == LabAgentProposal.currentSchema else {
            throw LabAgentProposalError.unsupportedSchema
        }
        guard bounded(proposal.hypothesis, maximum: 1_000),
              proposal.changes.keys.allSatisfy({ bounded($0, maximum: 128) }),
              proposal.expectedAffectedSlices.count <= 32,
              proposal.expectedAffectedSlices.allSatisfy({ bounded($0, maximum: 128) }),
              proposal.stopConditions.count <= 32,
              proposal.stopConditions.allSatisfy({ bounded($0, maximum: 256) }) else {
            throw LabAgentProposalError.invalidText
        }
        guard protocolDefinition.phase == .discovery, proposal.phase == .discovery else {
            throw LabAgentProposalError.phaseForbidden
        }
        guard proposal.experimentClass == protocolDefinition.experimentClass else {
            throw LabAgentProposalError.experimentClassMismatch
        }
        guard var arm = arms.first(where: { $0.id == proposal.parentArmID }) else {
            throw LabAgentProposalError.parentMissing
        }
        guard (1...4).contains(proposal.changes.count) else {
            throw LabAgentProposalError.tooManyChanges
        }
        guard proposal.successRule.minimumDeltaExpectedUtility.isFinite,
              proposal.successRule.maximumDeltaBadWhenShown.isFinite,
              proposal.successRule.maximumDeltaBadWhenShown >= 0,
              proposal.successRule.latencyNoninferiorityMilliseconds.isFinite,
              proposal.successRule.latencyNoninferiorityMilliseconds >= 0 else {
            throw LabAgentProposalError.invalidValue("successRule")
        }
        try campaignBudget.validated()
        guard proposal.budget.roots > 0,
              proposal.budget.roots <= campaignBudget.maximumRootsPerTrial else {
            throw LabAgentProposalError.budgetExceeded
        }
        guard proposal.budget.seeds == protocolDefinition.fixedGenerationSeeds else {
            throw LabAgentProposalError.seedMutation
        }
        arm.id = resultingArmID
        for (key, value) in proposal.changes.sorted(by: { $0.key < $1.key }) {
            try apply(key: key, value: value, to: &arm, kind: proposal.experimentClass)
        }
        // An agent can never smuggle a seed or safety mutation through another
        // field. The same phase/class validator used by real manifests gets the
        // final word.
        arm.generation.seed = arms.first(where: { $0.id == proposal.parentArmID })!.generation.seed
        do {
            try arm.validated()
            var validationProtocol = protocolDefinition
            validationProtocol.baselineArmID = proposal.parentArmID
            try LabResearchProtocolValidator.validate(
                validationProtocol,
                arms: [arms.first(where: { $0.id == proposal.parentArmID })!, arm]
            )
        } catch let error as LabAgentProposalError {
            throw error
        } catch {
            throw LabAgentProposalError.resultingArmInvalid
        }
        return arm
    }

    private static func apply(
        key: String,
        value: LabProposalValue,
        to arm: inout LabArmConfiguration,
        kind: LabExperimentClass
    ) throws {
        guard allowedKeys[kind, default: []].contains(key) else {
            throw LabAgentProposalError.forbiddenChange(key)
        }
        switch key {
        case "generation.temperature":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.temperature = number
            arm.generation.preset = number == 0 ? .productionGreedy : .custom
        case "generation.predictionTokens":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.predictionTokens = number
        case "generation.topK":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.topK = number
        case "generation.topP":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.topP = number
        case "generation.minP":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.minP = number
        case "generation.typicalP":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.typicalP = number
        case "generation.repeatPenalty":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.repeatPenalty = number
        case "prompt.maximumContextCharacters":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.prompt.maximumContextCharacters = number
        case "prompt.maximumSceneCharacters":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.prompt.maximumSceneCharacters = number
        case "prompt.conversationTurnLimit":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.prompt.conversationTurnLimit = number
        case "judgment.maximumVisibleWords":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.judgment.maximumVisibleWords = number
        case "judgment.maximumVisibleCharacters":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.judgment.maximumVisibleCharacters = number
        case "generation.minimumMeanTokenProbability":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.minimumMeanTokenProbability = number
        case "generation.probabilityCount":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.generation.probabilityCount = number
        case "personalization.enabled":
            guard let flag = value.boolean else { throw LabAgentProposalError.invalidValue(key) }
            arm.personalization.enabled = flag
        case "personalization.minimumSupport":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.personalization.minimumSupport = number
        case "personalization.minimumConfidence":
            guard let number = value.double else { throw LabAgentProposalError.invalidValue(key) }
            arm.personalization.minimumConfidence = number
        case "interaction.socketTimeoutMilliseconds":
            guard let number = value.integer else { throw LabAgentProposalError.invalidValue(key) }
            arm.interaction.socketTimeoutMilliseconds = number
        default:
            throw LabAgentProposalError.forbiddenChange(key)
        }
    }

    private static let allowedKeys: [LabExperimentClass: Set<String>] = [
        .generator: [
            "generation.temperature", "generation.predictionTokens", "generation.topK",
            "generation.topP", "generation.minP", "generation.typicalP",
            "generation.repeatPenalty",
        ],
        .context: [
            "prompt.maximumContextCharacters", "prompt.maximumSceneCharacters",
            "prompt.conversationTurnLimit",
        ],
        .displayPolicy: [
            "judgment.maximumVisibleWords", "judgment.maximumVisibleCharacters",
            "generation.minimumMeanTokenProbability", "generation.probabilityCount",
        ],
        .personalization: [
            "personalization.enabled", "personalization.minimumSupport",
            "personalization.minimumConfidence",
        ],
        .runtime: [],
        .interaction: ["interaction.socketTimeoutMilliseconds"],
    ]

    private static func bounded(_ value: String, maximum: Int) -> Bool {
        !value.isEmpty && value.count <= maximum
            && value.unicodeScalars.allSatisfy {
                $0 == "\n" || !CharacterSet.controlCharacters.contains($0)
            }
    }
}
