import Foundation

public enum LabResearchRunState: String, Codable, CaseIterable, Sendable {
    case ready
    case running
    case completed
    case failed
    case aborted

    public var isTerminal: Bool {
        self == .completed || self == .failed || self == .aborted
    }
}

public enum LabResearchFailureCategory: String, Codable, CaseIterable, Sendable {
    case invariantSmoke = "invariant-smoke"
    case helperUnavailable = "helper-unavailable"
    case modelUnavailable = "model-unavailable"
    case protocolFailure = "protocol-failure"
    case budgetExpired = "budget-expired"
    case runnerTerminated = "runner-terminated"
    case stalledSession = "stalled-session"
    case cancelled
    case unexpectedFailure = "unexpected-failure"
}

public enum LabResearchFailureReason: String, Codable, CaseIterable, Sendable {
    case unsafeSentinelOutput = "unsafe-sentinel-output"
    case sensitiveSuggestion = "sensitive-suggestion"
    case forbiddenFact = "forbidden-fact"
    case temporalIntegrity = "temporal-integrity"
    case protocolOrTimeout = "protocol-or-timeout"
    case missingSentinelProvenance = "missing-sentinel-provenance"
    case missingInvariantSentinel = "missing-invariant-sentinel"
    case unreadableHelper = "unreadable-helper"
    case unreadableModel = "unreadable-model"
    case invalidModel = "invalid-model"
    case localProtocolFailure = "local-protocol-failure"
    case activeBudgetExhausted = "active-budget-exhausted"
    case processNotAlive = "process-not-alive"
    case heartbeatExpired = "heartbeat-expired"
    case legacyOrphanedRun = "legacy-orphaned-run"
    case cooperativeCancellation = "cooperative-cancellation"
    case unclassifiedFailure = "unclassified-failure"
}

public struct LabResearchFailureClassification: Equatable, Sendable {
    public let state: LabResearchRunState
    public let category: LabResearchFailureCategory
    public let reasons: [LabResearchFailureReason]

    public init(
        state: LabResearchRunState,
        category: LabResearchFailureCategory,
        reasons: [LabResearchFailureReason]
    ) {
        precondition(state == .failed || state == .aborted)
        self.state = state
        self.category = category
        self.reasons = Array(Set(reasons)).sorted { $0.rawValue < $1.rawValue }
    }
}

public struct LabResearchTerminalFailure: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.terminal-failure.v1"

    public let schema: String
    public let campaignID: UUID
    public let state: LabResearchRunState
    public let category: LabResearchFailureCategory
    public let reasons: [LabResearchFailureReason]
    public let work: LabResearchWorkSummary
    public let occurredAt: Date
    public let review: LabReportReview

    public init(
        campaignID: UUID,
        state: LabResearchRunState,
        category: LabResearchFailureCategory,
        reasons: [LabResearchFailureReason],
        work: LabResearchWorkSummary,
        occurredAt: Date = Date(),
        review: LabReportReview = .unreviewed
    ) {
        schema = Self.currentSchema
        self.campaignID = campaignID
        self.state = state
        self.category = category
        self.reasons = Array(Set(reasons)).sorted { $0.rawValue < $1.rawValue }
        self.work = work
        self.occurredAt = occurredAt
        self.review = review
    }

    @discardableResult
    public func validated() throws -> LabResearchTerminalFailure {
        guard schema == Self.currentSchema,
              state == .failed || state == .aborted,
              !reasons.isEmpty,
              reasons.count <= 8,
              Set(reasons).count == reasons.count,
              reasons == reasons.sorted(by: { $0.rawValue < $1.rawValue }),
              work.pending >= 0, work.running >= 0,
              work.completed >= 0, work.failed >= 0 else {
            throw LabResearchTerminalFailureError.invalidArtifact
        }
        try review.validated()
        return self
    }

    public func reviewed(
        status: LabReportReviewStatus,
        conclusion: String,
        at reviewedAt: Date = Date()
    ) throws -> LabResearchTerminalFailure {
        guard status != .unreviewed else {
            throw LabResearchTerminalFailureError.invalidReview
        }
        return try LabResearchTerminalFailure(
            campaignID: campaignID,
            state: state,
            category: category,
            reasons: reasons,
            work: work,
            occurredAt: occurredAt,
            review: LabReportReview(
                status: status,
                conclusion: conclusion,
                reviewedAt: reviewedAt
            )
        ).validated()
    }
}

public struct LabResearchCampaignSnapshot: Codable, Equatable, Sendable {
    public let campaignID: UUID
    public let state: LabResearchRunState?
    public let activeSessions: Int
    public let work: LabResearchWorkSummary
    public let terminalFailure: LabResearchTerminalFailure?

    public init(
        campaignID: UUID,
        state: LabResearchRunState?,
        activeSessions: Int,
        work: LabResearchWorkSummary,
        terminalFailure: LabResearchTerminalFailure?
    ) {
        self.campaignID = campaignID
        self.state = state
        self.activeSessions = activeSessions
        self.work = work
        self.terminalFailure = terminalFailure
    }
}

public enum LabResearchTerminalFailureError: Error, LocalizedError, Equatable, Sendable {
    case invalidArtifact
    case invalidReview

    public var errorDescription: String? {
        switch self {
        case .invalidArtifact:
            "The aggregate terminal-failure artifact is malformed."
        case .invalidReview:
            "A terminal failure requires an explicit supported, rejected, or inconclusive review."
        }
    }
}

public enum LabResearchFailureClassifier {
    public static func classify(_ error: Error) -> LabResearchFailureClassification {
        if let invariant = error as? LabInvariantSmokeError {
            switch invariant {
            case .missingSentinel:
                return .init(
                    state: .failed,
                    category: .invariantSmoke,
                    reasons: [.missingInvariantSentinel]
                )
            case let .failed(_, rawReasons):
                let reasons = rawReasons.compactMap(LabResearchFailureReason.init(rawValue:))
                return .init(
                    state: .failed,
                    category: .invariantSmoke,
                    reasons: reasons.isEmpty ? [.unclassifiedFailure] : reasons
                )
            }
        }
        if let asset = error as? LabAssetError {
            switch asset {
            case .unreadableServer:
                return .init(
                    state: .failed,
                    category: .helperUnavailable,
                    reasons: [.unreadableHelper]
                )
            case .unreadableModel:
                return .init(
                    state: .failed,
                    category: .modelUnavailable,
                    reasons: [.unreadableModel]
                )
            case .invalidModelSize, .invalidModelHash, .invalidModelFormat:
                return .init(
                    state: .failed,
                    category: .modelUnavailable,
                    reasons: [.invalidModel]
                )
            }
        }
        if error is CancellationError {
            return .init(
                state: .aborted,
                category: .cancelled,
                reasons: [.cooperativeCancellation]
            )
        }
        if error is LabCompletionError || error is LabServerPoolError {
            return .init(
                state: .failed,
                category: .protocolFailure,
                reasons: [.localProtocolFailure]
            )
        }
        return .init(
            state: .failed,
            category: .unexpectedFailure,
            reasons: [.unclassifiedFailure]
        )
    }
}
