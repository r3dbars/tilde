import Foundation

/// Aggregate simulated behavior for one persona. Counts and rates only.
public struct LabSimulatedTypistPersonaSlice: Codable, Equatable, Sendable {
    public let personaID: String
    public let register: LabOnlineRegister
    public let typingSpeed: LabTypingSpeedBucket
    public let interruptionTolerance: LabTypistInterruptionTolerance
    /// Scenarios this persona actually finished — every count below is over
    /// exactly these.
    public let scenarios: Int
    /// Scenarios whose decision batch failed and whose partial results were
    /// discarded. They are excluded from every count below rather than
    /// zero-filled into it, so a reader can tell a persona that ignored its
    /// ghosts from a persona whose data a provider hiccup threw away.
    public let abandonedScenarios: Int
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
        abandonedScenarios: Int = 0,
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
        self.abandonedScenarios = abandonedScenarios
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

    /// The limitation text a report with skipped batches must carry. A run that
    /// abandoned part of its own sample says so in the sentence every reader
    /// already reads, not only in a field they might not look at.
    public static func limitation(
        skippedBatches: Int,
        abandonedSessions: Int,
        abandonedMoments: Int
    ) -> String {
        guard skippedBatches > 0 else { return limitation }
        let batches = skippedBatches == 1 ? "1 decision batch" : "\(skippedBatches) decision batches"
        let sessions = abandonedSessions == 1
            ? "1 persona/scenario session"
            : "\(abandonedSessions) persona/scenario sessions"
        let moments = abandonedMoments == 1 ? "1 decision moment" : "\(abandonedMoments) decision moments"
        return limitation + " Incomplete sample: \(batches) failed after the decision "
            + "policy's own retries and \(skippedBatches == 1 ? "was" : "were") skipped, "
            + "abandoning \(sessions) that carried \(moments). Those sessions are excluded "
            + "from every persona aggregate, so this run covers less than the suite and "
            + "persona set it names."
    }

    public let schema: String
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let suiteName: String
    public let suiteDigestSHA256: String
    public let scenarioCount: Int
    public let arm: LabArmConfiguration
    /// Which model bytes and helper produced the candidates the personas typed
    /// against. Two simulated runs are only comparable if this matches, and
    /// without it a Gemma run and a Qwen run are indistinguishable once the
    /// report leaves the machine that made it. Nil only for a run against a
    /// stubbed client, which has no generation stack to fingerprint.
    public let assets: LabAssetSnapshot?
    public let decisionPolicyIdentifier: String
    /// Moments resolved per decision-policy call. 1 is one moment per call;
    /// above 1 the run batched decision-independent moments across sessions.
    /// Recorded so a run's aggregates can be read next to how they were driven.
    public let decisionBatchSize: Int
    /// Decision-policy calls the run allowed in flight at once. 1 is the
    /// sequential driver; above 1 the run resolved a round's independent
    /// batches concurrently. It changes only how long the run took — decisions
    /// are applied in batch order after each round joins — and is recorded so a
    /// run's aggregates can be read next to how they were driven.
    public let decisionWorkers: Int
    /// How many failed decision batches this run was permitted to skip. 0 is
    /// the strict run: any failed batch aborts it.
    public let skippedBatchAllowance: Int
    /// Decision batches that failed after the policy's own retries and were
    /// skipped instead of aborting the run. Always 0 when the allowance is 0.
    public let skippedBatches: Int
    /// Persona/scenario sessions the skipped batches abandoned. Their partial
    /// results are excluded from every persona slice — never counted as
    /// type-throughs or dismissals — so the run's coverage is smaller than the
    /// suite and persona set it names by exactly this many sessions.
    public let abandonedSessions: Int
    /// Decision moments discarded with those sessions, including the ones that
    /// had already been decided before the failure.
    public let abandonedMoments: Int
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
        assets: LabAssetSnapshot? = nil,
        decisionPolicyIdentifier: String,
        decisionBatchSize: Int = 1,
        decisionWorkers: Int = 1,
        skippedBatchAllowance: Int = 0,
        skippedBatches: Int = 0,
        abandonedSessions: Int = 0,
        abandonedMoments: Int = 0,
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
        self.assets = assets
        self.decisionPolicyIdentifier = decisionPolicyIdentifier
        self.decisionBatchSize = max(1, decisionBatchSize)
        self.decisionWorkers = max(1, decisionWorkers)
        self.skippedBatchAllowance = max(0, skippedBatchAllowance)
        self.skippedBatches = max(0, skippedBatches)
        self.abandonedSessions = max(0, abandonedSessions)
        self.abandonedMoments = max(0, abandonedMoments)
        self.personaCatalogSchema = personaCatalogSchema
        self.provenance = provenance
        self.privacy = privacy
        self.personas = personas
        // A simulated report carries the fence in its own body. Even a clean,
        // registered, reviewed provenance envelope cannot make it eligible.
        evidenceEligibility = LabEvidenceEligibility(reasons: [.simulatedDecisionLayer])
        limitation = Self.limitation(
            skippedBatches: self.skippedBatches,
            abandonedSessions: self.abandonedSessions,
            abandonedMoments: self.abandonedMoments
        )
    }

    /// Always false. Kept as an explicit property so callers read the fence
    /// rather than infer it.
    public var isDecisionGrade: Bool { evidenceEligibility.eligible }

    /// True when a provider failure cost this run part of its own sample. The
    /// counts below say how much.
    public var hasSkippedBatches: Bool { skippedBatches > 0 }

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
        guard (1...LabSimulatedTypistConfiguration.maximumDecisionWorkers)
            .contains(decisionWorkers) else {
            throw LabSimulatedTypistError.invalidDecisionWorkers
        }
        guard (0...LabSimulatedTypistConfiguration.maximumSkippedBatches)
            .contains(skippedBatchAllowance),
            (0...skippedBatchAllowance).contains(skippedBatches) else {
            throw LabSimulatedTypistError.invalidSkippedBatchCount
        }
        // A skip that cost nothing, or a loss with no skip behind it, means the
        // accounting is wrong — and a wrong count here is exactly the silent
        // cap this option exists not to be.
        let abandonedByPersona = personas.reduce(0) { $0 + $1.abandonedScenarios }
        let consistent = skippedBatches > 0
            ? (abandonedSessions >= skippedBatches && abandonedMoments >= abandonedSessions)
            : (abandonedSessions == 0 && abandonedMoments == 0)
        guard consistent, abandonedSessions == abandonedByPersona,
              personas.allSatisfy({ $0.abandonedScenarios >= 0 }) else {
            throw LabSimulatedTypistError.inconsistentAbandonment
        }
        guard limitation == Self.limitation(
            skippedBatches: skippedBatches,
            abandonedSessions: abandonedSessions,
            abandonedMoments: abandonedMoments
        ) else {
            throw LabSimulatedTypistError.limitationMisstatesSkips
        }
        if let assets {
            guard (try? LabModelProfile(
                verificationMode: assets.verificationMode,
                identifier: assets.modelIdentifier,
                revision: assets.modelRevision
            ).validated()) != nil,
            Self.isSHA256(assets.modelSHA256), Self.isSHA256(assets.helperSHA256) else {
                throw LabSimulatedTypistError.invalidModelIdentity
            }
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

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

public enum LabSimulatedTypistError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case unsafePrivacyContract
    case evidenceFenceRemoved
    case noSimulatableScenarios
    case invalidDecisionBatchSize
    case invalidDecisionWorkers
    case invalidSkippedBatchCount
    case inconsistentAbandonment
    case limitationMisstatesSkips
    case invalidModelIdentity
    case sessionCollisionInRound

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
        case .invalidDecisionWorkers:
            "The simulated-typist report records a decision worker count outside 1...\(LabSimulatedTypistConfiguration.maximumDecisionWorkers)."
        case .invalidSkippedBatchCount:
            "The simulated-typist report records more skipped decision batches than the run allowed, or an allowance outside 0...\(LabSimulatedTypistConfiguration.maximumSkippedBatches)."
        case .inconsistentAbandonment:
            "The simulated-typist report's skipped-batch, abandoned-session, and abandoned-moment counts do not agree; a skipped batch must always name the sessions and moments it cost."
        case .limitationMisstatesSkips:
            "A simulated-typist report that skipped decision batches must say so in its limitation text."
        case .invalidModelIdentity:
            "The simulated-typist report does not name a valid generation model identity, revision, and asset digest."
        case .sessionCollisionInRound:
            "A decision round collected two moments of one persona/scenario session; batches must never group moments from one timeline."
        }
    }
}
