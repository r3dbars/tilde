import Foundation

/// Aggregate simulated behavior for one persona. Counts and rates only.
public struct LabSimulatedTypistPersonaSlice: Codable, Equatable, Sendable {
    public let personaID: String
    public let register: LabOnlineRegister
    public let typingSpeed: LabTypingSpeedBucket
    public let interruptionTolerance: LabTypistInterruptionTolerance
    public let scenarios: Int
    public let opportunities: Int
    public let displays: Int
    public let accepts: Int
    public let wordAccepts: Int
    public let typeThroughs: Int
    public let dismissals: Int
    public let wrongDisplays: Int
    public let silentMoments: Int
    public let baselineCharacters: Int
    public let acceptedCharacters: Int
    public let correctionCharacters: Int
    public let retainedCharacterPotential: Int

    public var simulatedAcceptanceRate: Double {
        displays > 0 ? Double(accepts + wordAccepts) / Double(displays) : 0
    }

    public var simulatedTypeThroughRate: Double {
        displays > 0 ? Double(typeThroughs) / Double(displays) : 0
    }

    public var simulatedWrongDisplayRate: Double {
        displays > 0 ? Double(wrongDisplays) / Double(displays) : 0
    }

    public var retainedCharacterPotentialRate: Double {
        baselineCharacters > 0
            ? Double(retainedCharacterPotential) / Double(baselineCharacters)
            : 0
    }

    public init(
        personaID: String,
        register: LabOnlineRegister,
        typingSpeed: LabTypingSpeedBucket,
        interruptionTolerance: LabTypistInterruptionTolerance,
        scenarios: Int,
        opportunities: Int,
        displays: Int,
        accepts: Int,
        wordAccepts: Int,
        typeThroughs: Int,
        dismissals: Int,
        wrongDisplays: Int,
        silentMoments: Int,
        baselineCharacters: Int,
        acceptedCharacters: Int,
        correctionCharacters: Int,
        retainedCharacterPotential: Int
    ) {
        self.personaID = personaID
        self.register = register
        self.typingSpeed = typingSpeed
        self.interruptionTolerance = interruptionTolerance
        self.scenarios = scenarios
        self.opportunities = opportunities
        self.displays = displays
        self.accepts = accepts
        self.wordAccepts = wordAccepts
        self.typeThroughs = typeThroughs
        self.dismissals = dismissals
        self.wrongDisplays = wrongDisplays
        self.silentMoments = silentMoments
        self.baselineCharacters = baselineCharacters
        self.acceptedCharacters = acceptedCharacters
        self.correctionCharacters = correctionCharacters
        self.retainedCharacterPotential = retainedCharacterPotential
    }
}

/// The simulated-typist artifact. It reuses the report provenance envelope,
/// the aggregate-only privacy contract, and the same evidence-eligibility
/// vocabulary that fences legacy and dirty reports — and it is permanently
/// ineligible, because a simulated writer is not a human judge.
///
/// It is deliberately not a `LabRunReport` and is never written into a
/// campaign's reports directory, so `compare`, `nominate`, and every protected
/// command are structurally unable to see it.
public struct LabSimulatedTypistReport: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.simulated-typist-report.v1"

    public static let limitation = """
    Discovery-grade simulation. A simulated decision layer stood in for a human, \
    the simulator is uncalibrated, and no ranking-agreement protocol has run. \
    It may reorder the research queue and must never advance a protected phase \
    or mix with live evidence in one verdict.
    """

    public let schema: String
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let suiteName: String
    public let suiteDigestSHA256: String
    public let scenarioCount: Int
    public let arm: LabArmConfiguration
    public let decisionPolicyIdentifier: String
    /// Moments resolved per decision-policy call. 1 is one moment per call;
    /// above 1 the run batched decision-independent moments across sessions.
    /// Recorded so a run's aggregates can be read next to how they were driven.
    public let decisionBatchSize: Int
    public let personaCatalogSchema: String
    public let provenance: LabReportProvenance
    public let privacy: LabPrivacyContract
    public let evidenceEligibility: LabEvidenceEligibility
    public let personas: [LabSimulatedTypistPersonaSlice]
    public let limitation: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        suiteName: String,
        suiteDigestSHA256: String,
        scenarioCount: Int,
        arm: LabArmConfiguration,
        decisionPolicyIdentifier: String,
        decisionBatchSize: Int = 1,
        personaCatalogSchema: String = LabTypistPersonaCatalog.currentSchema,
        provenance: LabReportProvenance,
        privacy: LabPrivacyContract = LabPrivacyContract(),
        personas: [LabSimulatedTypistPersonaSlice]
    ) {
        schema = Self.currentSchema
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.suiteName = suiteName
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.scenarioCount = scenarioCount
        self.arm = arm
        self.decisionPolicyIdentifier = decisionPolicyIdentifier
        self.decisionBatchSize = max(1, decisionBatchSize)
        self.personaCatalogSchema = personaCatalogSchema
        self.provenance = provenance
        self.privacy = privacy
        self.personas = personas
        // A simulated report carries the fence in its own body. Even a clean,
        // registered, reviewed provenance envelope cannot make it eligible.
        evidenceEligibility = LabEvidenceEligibility(reasons: [.simulatedDecisionLayer])
        limitation = Self.limitation
    }

    /// Always false. Kept as an explicit property so callers read the fence
    /// rather than infer it.
    public var isDecisionGrade: Bool { evidenceEligibility.eligible }

    public var totalDisplays: Int { personas.reduce(0) { $0 + $1.displays } }
    public var totalBaselineCharacters: Int { personas.reduce(0) { $0 + $1.baselineCharacters } }
    public var totalRetainedCharacterPotential: Int {
        personas.reduce(0) { $0 + $1.retainedCharacterPotential }
    }

    @discardableResult
    public func validated() throws -> LabSimulatedTypistReport {
        guard schema == Self.currentSchema else {
            throw LabSimulatedTypistError.unsupportedSchema
        }
        guard (1...LabTypistMomentBatch.maximumSize).contains(decisionBatchSize) else {
            throw LabSimulatedTypistError.invalidDecisionBatchSize
        }
        guard privacy.aggregateOnly,
              !privacy.rawScenarioText,
              !privacy.rawModelOutput,
              !privacy.filePaths,
              !privacy.networkInference else {
            throw LabSimulatedTypistError.unsafePrivacyContract
        }
        guard evidenceEligibility == LabEvidenceEligibility(
            reasons: [.simulatedDecisionLayer]
        ) else {
            throw LabSimulatedTypistError.evidenceFenceRemoved
        }
        try provenance.validated()
        return self
    }
}

public enum LabSimulatedTypistError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case unsafePrivacyContract
    case evidenceFenceRemoved
    case noSimulatableScenarios
    case invalidDecisionBatchSize

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The simulated-typist report schema is unsupported."
        case .unsafePrivacyContract:
            "The simulated-typist report violates Tilde Lab's aggregate-only privacy contract."
        case .evidenceFenceRemoved:
            "A simulated-typist report must stay fenced as discovery-grade simulated evidence."
        case .noSimulatableScenarios:
            "No selected scenario has a golden continuation to type through."
        case .invalidDecisionBatchSize:
            "The simulated-typist report records a decision batch size outside 1...\(LabTypistMomentBatch.maximumSize)."
        }
    }
}
