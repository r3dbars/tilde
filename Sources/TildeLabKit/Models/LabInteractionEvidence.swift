import Foundation

public enum LabInteractionCheck: String, Codable, CaseIterable, Sendable {
    case suggestionRoundTrip = "suggestion-round-trip"
    case markedText = "marked-text"
    case tabAcceptance = "tab-acceptance"
    case wordAcceptance = "word-acceptance"
    case escapeDismissal = "escape-dismissal"
    case typingThrough = "typing-through"
    case backspaceDuringInference = "backspace-during-inference"
    case caretMovement = "caret-movement"
    case selectionChange = "selection-change"
    case focusChange = "focus-change"
    case appSwitch = "app-switch"
    case conversationSwitch = "conversation-switch"
    case runtimeRestart = "runtime-restart"
    case committedTextIntegrity = "committed-text-integrity"
}

/// Aggregate, text-free output from an owner-triggered real macOS host probe.
/// The schema cannot represent typed text, marked text, a bundle identifier,
/// a window title, a file path, or a candidate.
public struct LabInteractionEvidenceRecord: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.interaction-evidence.v1"

    public let schema: String
    public let id: UUID
    public let campaignID: UUID
    public let candidateArmID: String
    public let candidateArmDigestSHA256: String
    public let occurredAt: Date
    public let host: LabInteractionHost
    public let check: LabInteractionCheck
    public let attempts: Int
    public let failures: Int
    public let p95Milliseconds: Int?
    public let committedTextCorruptions: Int
    public let staleInsertions: Int

    public init(
        id: UUID = UUID(),
        campaignID: UUID,
        candidateArmID: String,
        candidateArmDigestSHA256: String,
        occurredAt: Date = Date(),
        host: LabInteractionHost,
        check: LabInteractionCheck,
        attempts: Int,
        failures: Int = 0,
        p95Milliseconds: Int? = nil,
        committedTextCorruptions: Int = 0,
        staleInsertions: Int = 0
    ) {
        schema = Self.currentSchema
        self.id = id
        self.campaignID = campaignID
        self.candidateArmID = candidateArmID
        self.candidateArmDigestSHA256 = candidateArmDigestSHA256
        self.occurredAt = occurredAt
        self.host = host
        self.check = check
        self.attempts = attempts
        self.failures = failures
        self.p95Milliseconds = p95Milliseconds
        self.committedTextCorruptions = committedTextCorruptions
        self.staleInsertions = staleInsertions
    }

    @discardableResult
    public func validated() throws -> LabInteractionEvidenceRecord {
        guard schema == Self.currentSchema,
              candidateArmID.range(
                  of: "^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$",
                  options: .regularExpression
              ) == candidateArmID.startIndex..<candidateArmID.endIndex,
              candidateArmDigestSHA256.range(
                  of: "^[a-f0-9]{64}$", options: .regularExpression
              ) == candidateArmDigestSHA256.startIndex..<candidateArmDigestSHA256.endIndex,
              (1...1_000_000).contains(attempts),
              (0...attempts).contains(failures),
              (0...attempts).contains(committedTextCorruptions),
              (0...attempts).contains(staleInsertions),
              p95Milliseconds.map({ (0...300_000).contains($0) }) ?? true else {
            throw LabInteractionEvidenceError.invalidRecord
        }
        return self
    }
}

public struct LabInteractionEvidenceReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.interaction-report.v1"

    public let schema: String
    public let campaignID: UUID
    public let candidateArmID: String
    public let candidateArmDigestSHA256: String
    public let holdoutEvidenceDigestSHA256: String
    public let records: Int
    public let attempts: Int
    public let failures: Int
    public let committedTextCorruptions: Int
    public let staleInsertions: Int
    public let maximumP95Milliseconds: Int?
    public let missingCoverage: [String]
    public let passed: Bool
    public let limitation: String
}

public enum LabInteractionEvidenceError: Error, LocalizedError, Equatable, Sendable {
    case invalidRecord
    case mixedIdentity
    case invalidHoldoutDigest

    public var errorDescription: String? {
        switch self {
        case .invalidRecord: "A text-free interaction evidence record is invalid."
        case .mixedIdentity: "Interaction evidence cannot mix campaigns or candidate arms."
        case .invalidHoldoutDigest: "Interaction evidence requires a passing holdout digest."
        }
    }
}

public enum LabInteractionEvidenceAnalyzer {
    public static func analyze(
        _ records: [LabInteractionEvidenceRecord],
        holdoutEvidenceDigestSHA256: String
    ) throws -> LabInteractionEvidenceReport {
        guard holdoutEvidenceDigestSHA256.range(
            of: "^[a-f0-9]{64}$", options: .regularExpression
        ) == holdoutEvidenceDigestSHA256.startIndex..<holdoutEvidenceDigestSHA256.endIndex else {
            throw LabInteractionEvidenceError.invalidHoldoutDigest
        }
        guard let first = records.first else { throw LabInteractionEvidenceError.invalidRecord }
        for record in records { try record.validated() }
        guard records.allSatisfy({
            $0.campaignID == first.campaignID
                && $0.candidateArmID == first.candidateArmID
                && $0.candidateArmDigestSHA256 == first.candidateArmDigestSHA256
        }) else { throw LabInteractionEvidenceError.mixedIdentity }

        let observed = Set(records.map { "\($0.host.rawValue):\($0.check.rawValue)" })
        let required = Set(LabInteractionHost.allCases.flatMap { host in
            LabInteractionCheck.allCases.map { "\(host.rawValue):\($0.rawValue)" }
        })
        let missing = required.subtracting(observed).sorted()
        let failures = records.reduce(0) { $0 + $1.failures }
        let corruptions = records.reduce(0) { $0 + $1.committedTextCorruptions }
        let stale = records.reduce(0) { $0 + $1.staleInsertions }
        return LabInteractionEvidenceReport(
            schema: LabInteractionEvidenceReport.currentSchema,
            campaignID: first.campaignID,
            candidateArmID: first.candidateArmID,
            candidateArmDigestSHA256: first.candidateArmDigestSHA256,
            holdoutEvidenceDigestSHA256: holdoutEvidenceDigestSHA256,
            records: records.count,
            attempts: records.reduce(0) { $0 + $1.attempts },
            failures: failures,
            committedTextCorruptions: corruptions,
            staleInsertions: stale,
            maximumP95Milliseconds: records.compactMap(\.p95Milliseconds).max(),
            missingCoverage: missing,
            passed: missing.isEmpty && failures == 0 && corruptions == 0 && stale == 0,
            limitation: "Owner-triggered real-host evidence. The CLI verifies coverage and integrity aggregates but cannot seize focus, switch accounts, or infer that an unreported host passed."
        )
    }
}
