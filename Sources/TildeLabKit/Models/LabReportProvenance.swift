import Foundation

public enum LabSourceTreeState: String, Codable, CaseIterable, Sendable {
    case clean
    case dirty
    case unavailable
}

public struct LabReportSourceProvenance: Codable, Equatable, Sendable {
    public let gitCommitSHA: String?
    public let treeState: LabSourceTreeState
    public let runnerSHA256: String?

    public init(
        gitCommitSHA: String?,
        treeState: LabSourceTreeState,
        runnerSHA256: String?
    ) {
        self.gitCommitSHA = gitCommitSHA
        self.treeState = treeState
        self.runnerSHA256 = runnerSHA256
    }
}

public struct LabReportEnvironmentProvenance: Codable, Equatable, Sendable {
    public let operatingSystemVersion: String?
    public let operatingSystemBuild: String?
    public let hardwareClass: String?
    public let machine: LabResearchMachineState

    public init(
        operatingSystemVersion: String?,
        operatingSystemBuild: String?,
        hardwareClass: String?,
        machine: LabResearchMachineState
    ) {
        self.operatingSystemVersion = operatingSystemVersion
        self.operatingSystemBuild = operatingSystemBuild
        self.hardwareClass = hardwareClass
        self.machine = machine
    }
}

public struct LabReportInvocationProvenance: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.canonical-invocation.v1"

    public let schema: String
    public let digestSHA256: String?

    public init(
        schema: String = Self.currentSchema,
        digestSHA256: String?
    ) {
        self.schema = schema
        self.digestSHA256 = digestSHA256
    }
}

public struct LabExperimentRegistration: Codable, Equatable, Sendable {
    public let id: String
    public let campaignID: UUID
    public let manifestDigestSHA256: String
    public let hypothesis: String

    public init(
        id: String,
        campaignID: UUID,
        manifestDigestSHA256: String,
        hypothesis: String
    ) {
        self.id = id
        self.campaignID = campaignID
        self.manifestDigestSHA256 = manifestDigestSHA256
        self.hypothesis = hypothesis
    }
}

public struct LabReportProvenance: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.report-provenance.v1"

    public let schema: String
    public let capturedAt: Date
    public let source: LabReportSourceProvenance
    public let environment: LabReportEnvironmentProvenance
    public let invocation: LabReportInvocationProvenance
    public let experiment: LabExperimentRegistration?

    public init(
        schema: String = Self.currentSchema,
        capturedAt: Date = Date(),
        source: LabReportSourceProvenance,
        environment: LabReportEnvironmentProvenance,
        invocation: LabReportInvocationProvenance,
        experiment: LabExperimentRegistration?
    ) {
        self.schema = schema
        self.capturedAt = capturedAt
        self.source = source
        self.environment = environment
        self.invocation = invocation
        self.experiment = experiment
    }

    public static func unavailable(capturedAt: Date = Date()) -> LabReportProvenance {
        LabReportProvenance(
            capturedAt: capturedAt,
            source: LabReportSourceProvenance(
                gitCommitSHA: nil,
                treeState: .unavailable,
                runnerSHA256: nil
            ),
            environment: LabReportEnvironmentProvenance(
                operatingSystemVersion: nil,
                operatingSystemBuild: nil,
                hardwareClass: nil,
                machine: LabResearchMachineState(
                    powerSourceKnown: false,
                    isOnACPower: false,
                    lowPowerModeEnabled: false,
                    thermalLevel: .unknown,
                    checkedAt: capturedAt
                )
            ),
            invocation: LabReportInvocationProvenance(digestSHA256: nil),
            experiment: nil
        )
    }

    public var campaignID: UUID? { experiment?.campaignID }
}

public enum LabReportReviewStatus: String, Codable, CaseIterable, Sendable {
    case unreviewed
    case supported
    case rejected
    case inconclusive

    public var title: String {
        switch self {
        case .unreviewed: "Unreviewed"
        case .supported: "Supported"
        case .rejected: "Rejected"
        case .inconclusive: "Inconclusive"
        }
    }
}

public struct LabReportReview: Codable, Equatable, Sendable {
    public let status: LabReportReviewStatus
    public let conclusion: String?
    public let reviewedAt: Date?

    public init(
        status: LabReportReviewStatus,
        conclusion: String? = nil,
        reviewedAt: Date? = nil
    ) {
        self.status = status
        self.conclusion = conclusion
        self.reviewedAt = reviewedAt
    }

    public static let unreviewed = LabReportReview(status: .unreviewed)
}

public enum LabEvidenceIneligibilityReason: String, Codable, CaseIterable, Sendable {
    case legacyReportSchema = "legacy-report-schema"
    case missingProvenance = "missing-provenance"
    case unsupportedProvenanceSchema = "unsupported-provenance-schema"
    case sourceRevisionUnavailable = "source-revision-unavailable"
    case dirtySourceTree = "dirty-source-tree"
    case runnerHashUnavailable = "runner-hash-unavailable"
    case operatingSystemUnavailable = "operating-system-unavailable"
    case hardwareClassUnavailable = "hardware-class-unavailable"
    case machineStateUnavailable = "machine-state-unavailable"
    case invocationUnavailable = "invocation-unavailable"
    case hypothesisUnregistered = "hypothesis-unregistered"
    case unsafePrivacyContract = "unsafe-privacy-contract"
    case incompleteRun = "incomplete-run"
    case reviewPending = "review-pending"
    case reviewInvalid = "review-invalid"
}

public enum LabRunReportValidationError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case missingProvenance
    case missingReview
    case unsafePrivacyContract

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The report schema is unsupported."
        case .missingProvenance: "A v6 report must contain a provenance envelope."
        case .missingReview: "A v6 report must contain an explicit review state."
        case .unsafePrivacyContract:
            "The report violates Tilde Lab's aggregate-only privacy contract."
        }
    }
}

public struct LabEvidenceEligibility: Codable, Equatable, Sendable {
    public let eligible: Bool
    public let reasons: [LabEvidenceIneligibilityReason]

    public init(reasons: [LabEvidenceIneligibilityReason]) {
        self.reasons = reasons
        eligible = reasons.isEmpty
    }
}

public enum LabReportProvenanceError: Error, LocalizedError, Equatable, Sendable {
    case invalidSource
    case invalidEnvironment
    case invalidInvocation
    case invalidExperiment
    case invalidReview

    public var errorDescription: String? {
        switch self {
        case .invalidSource: "The report source provenance is malformed."
        case .invalidEnvironment: "The report environment provenance is malformed."
        case .invalidInvocation: "The report invocation provenance is malformed."
        case .invalidExperiment: "The report experiment registration is malformed."
        case .invalidReview: "The report review is malformed."
        }
    }
}

extension LabReportProvenance {
    @discardableResult
    public func validated() throws -> LabReportProvenance {
        guard schema == Self.currentSchema else {
            throw LabReportProvenanceError.invalidSource
        }
        if let commit = source.gitCommitSHA, !commit.isLowercaseHex(count: 40) {
            throw LabReportProvenanceError.invalidSource
        }
        switch source.treeState {
        case .clean, .dirty:
            guard source.gitCommitSHA != nil else {
                throw LabReportProvenanceError.invalidSource
            }
        case .unavailable:
            guard source.gitCommitSHA == nil else {
                throw LabReportProvenanceError.invalidSource
            }
        }
        if let runner = source.runnerSHA256, !runner.isLowercaseHex(count: 64) {
            throw LabReportProvenanceError.invalidSource
        }
        guard environment.operatingSystemVersion.isNilOrSafeToken(maximum: 128),
              environment.operatingSystemBuild.isNilOrSafeToken(maximum: 128),
              environment.hardwareClass.isNilOrSafeToken(maximum: 128) else {
            throw LabReportProvenanceError.invalidEnvironment
        }
        guard invocation.schema == LabReportInvocationProvenance.currentSchema,
              invocation.digestSHA256.map({ $0.isLowercaseHex(count: 64) }) ?? true else {
            throw LabReportProvenanceError.invalidInvocation
        }
        if let experiment {
            guard experiment.id.range(
                of: #"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$"#,
                options: .regularExpression
            ) == experiment.id.startIndex..<experiment.id.endIndex,
            experiment.manifestDigestSHA256.isLowercaseHex(count: 64),
            experiment.hypothesis.isSafeResearchText(maximum: 1_000) else {
                throw LabReportProvenanceError.invalidExperiment
            }
        }
        return self
    }

    var ineligibilityReasons: [LabEvidenceIneligibilityReason] {
        var reasons: [LabEvidenceIneligibilityReason] = []
        if schema != Self.currentSchema { reasons.append(.unsupportedProvenanceSchema) }
        if source.gitCommitSHA?.isLowercaseHex(count: 40) != true
            || source.treeState == .unavailable {
            reasons.append(.sourceRevisionUnavailable)
        } else if source.treeState == .dirty {
            reasons.append(.dirtySourceTree)
        }
        if source.runnerSHA256?.isLowercaseHex(count: 64) != true {
            reasons.append(.runnerHashUnavailable)
        }
        if environment.operatingSystemVersion?.isSafeToken(maximum: 128) != true
            || environment.operatingSystemBuild?.isSafeToken(maximum: 128) != true {
            reasons.append(.operatingSystemUnavailable)
        }
        if environment.hardwareClass?.isSafeToken(maximum: 128) != true {
            reasons.append(.hardwareClassUnavailable)
        }
        if !environment.machine.powerSourceKnown || environment.machine.thermalLevel == .unknown {
            reasons.append(.machineStateUnavailable)
        }
        if invocation.schema != LabReportInvocationProvenance.currentSchema
            || invocation.digestSHA256?.isLowercaseHex(count: 64) != true {
            reasons.append(.invocationUnavailable)
        }
        if experiment == nil
            || experiment?.manifestDigestSHA256.isLowercaseHex(count: 64) != true
            || experiment?.hypothesis.isSafeResearchText(maximum: 1_000) != true {
            reasons.append(.hypothesisUnregistered)
        }
        return reasons
    }
}

extension LabReportReview {
    @discardableResult
    public func validated() throws -> LabReportReview {
        switch status {
        case .unreviewed:
            guard conclusion == nil, reviewedAt == nil else {
                throw LabReportProvenanceError.invalidReview
            }
        case .supported, .rejected, .inconclusive:
            guard conclusion?.isSafeResearchText(maximum: 2_000) == true,
                  reviewedAt != nil else {
                throw LabReportProvenanceError.invalidReview
            }
        }
        return self
    }
}

private extension Optional where Wrapped == String {
    func isNilOrSafeToken(maximum: Int) -> Bool {
        self?.isSafeToken(maximum: maximum) ?? true
    }
}

private extension String {
    func isLowercaseHex(count: Int) -> Bool {
        self.count == count
            && range(of: "^[a-f0-9]{\(count)}$", options: .regularExpression)
                == startIndex..<endIndex
    }

    func isSafeToken(maximum: Int) -> Bool {
        !isEmpty && count <= maximum
            && range(of: #"^[A-Za-z0-9][A-Za-z0-9._:+(), -]*$"#, options: .regularExpression)
                == startIndex..<endIndex
            && !containsUnsafePath
    }

    func isSafeResearchText(maximum: Int) -> Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximum
            && !containsUnsafePath
            && !contains("\n") && !contains("\r")
    }

    var containsUnsafePath: Bool {
        contains("/Users/") || contains("file://") || contains("~/")
    }
}

public extension LabRunReport {
    /// Evidence eligibility means the report is complete enough to support a
    /// research decision. It does not, by itself, promote an arm or authorize
    /// a production change.
    var evidenceEligibility: LabEvidenceEligibility {
        var reasons: [LabEvidenceIneligibilityReason] = []
        if schema != Self.currentSchema { reasons.append(.legacyReportSchema) }
        if let provenance {
            reasons.append(contentsOf: provenance.ineligibilityReasons)
        } else {
            reasons.append(.missingProvenance)
        }
        if !privacy.aggregateOnly || privacy.rawScenarioText || privacy.rawModelOutput
            || privacy.filePaths {
            reasons.append(.unsafePrivacyContract)
        }
        if !metrics.complete { reasons.append(.incompleteRun) }
        guard let review else {
            reasons.append(.reviewPending)
            return LabEvidenceEligibility(reasons: Array(Set(reasons)).sorted {
                $0.rawValue < $1.rawValue
            })
        }
        if (try? review.validated()) == nil {
            reasons.append(.reviewInvalid)
        } else if review.status == .unreviewed {
            reasons.append(.reviewPending)
        }
        return LabEvidenceEligibility(reasons: Array(Set(reasons)).sorted {
            $0.rawValue < $1.rawValue
        })
    }

    @discardableResult
    func validatedForPersistence() throws -> LabRunReport {
        guard Self.supportedSchemas.contains(schema) else {
            throw LabRunReportValidationError.unsupportedSchema
        }
        guard privacy.aggregateOnly,
              !privacy.rawScenarioText,
              !privacy.rawModelOutput,
              !privacy.filePaths else {
            throw LabRunReportValidationError.unsafePrivacyContract
        }

        if schema == Self.currentSchema {
            guard let provenance else {
                throw LabRunReportValidationError.missingProvenance
            }
            guard let review else {
                throw LabRunReportValidationError.missingReview
            }
            try provenance.validated()
            try review.validated()
        } else {
            if let provenance { try provenance.validated() }
            if let review { try review.validated() }
        }
        return self
    }
}
