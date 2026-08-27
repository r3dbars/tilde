import CSQLite
import CryptoKit
import Foundation

public enum LabWorkStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

public struct LabDurableWorkItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let campaignID: UUID
    public let trialID: String
    public let armHash: String
    public let rootScenarioID: String
    public let scenarioID: String
    public let checkpoint: LabReplayCheckpoint
    public let contextVariant: LabContextVariant
    public let generationSeed: Int
    public let repetition: Int
    public let blockIndex: Int
    public var status: LabWorkStatus
    public var leaseOwner: String?
    public var leaseExpiration: Date?
    public var attempt: Int

    public init(
        campaignID: UUID,
        trialID: String,
        armHash: String,
        scenario: LabScenario,
        generationSeed: Int,
        repetition: Int,
        blockIndex: Int,
        status: LabWorkStatus = .pending,
        leaseOwner: String? = nil,
        leaseExpiration: Date? = nil,
        attempt: Int = 0
    ) {
        self.campaignID = campaignID
        self.trialID = trialID
        self.armHash = armHash
        rootScenarioID = scenario.evaluation.rootScenarioID ?? scenario.id
        scenarioID = scenario.id
        checkpoint = scenario.evaluation.checkpoint
        contextVariant = scenario.evaluation.contextVariant
        self.generationSeed = generationSeed
        self.repetition = repetition
        self.blockIndex = blockIndex
        self.status = status
        self.leaseOwner = leaseOwner
        self.leaseExpiration = leaseExpiration
        self.attempt = attempt
        id = Self.identifier(
            campaignID: campaignID,
            trialID: trialID,
            armHash: armHash,
            scenarioID: scenario.id,
            checkpoint: scenario.evaluation.checkpoint,
            contextVariant: scenario.evaluation.contextVariant,
            generationSeed: generationSeed,
            repetition: repetition
        )
    }

    private static func identifier(
        campaignID: UUID,
        trialID: String,
        armHash: String,
        scenarioID: String,
        checkpoint: LabReplayCheckpoint,
        contextVariant: LabContextVariant,
        generationSeed: Int,
        repetition: Int
    ) -> String {
        let source = [
            campaignID.uuidString.lowercased(), trialID, armHash, scenarioID,
            checkpoint.rawValue, contextVariant.rawValue,
            String(generationSeed), String(repetition),
        ].joined(separator: "\u{1f}")
        return SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public struct LabResearchCampaignRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let manifestDigestSHA256: String
    public let suiteDigestSHA256: String
    public let modelSHA256: String
    public let helperSHA256: String
    public let gitCommit: String
    public let protocolDefinition: LabResearchProtocol

    public init(
        id: UUID,
        name: String,
        manifestDigestSHA256: String,
        suiteDigestSHA256: String,
        modelSHA256: String,
        helperSHA256: String,
        gitCommit: String,
        protocolDefinition: LabResearchProtocol
    ) {
        self.id = id
        self.name = name
        self.manifestDigestSHA256 = manifestDigestSHA256
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.modelSHA256 = modelSHA256
        self.helperSHA256 = helperSHA256
        self.gitCommit = gitCommit
        self.protocolDefinition = protocolDefinition
    }
}

public struct LabResearchWorkSummary: Codable, Equatable, Sendable {
    public let pending: Int
    public let running: Int
    public let completed: Int
    public let failed: Int

    public var total: Int { pending + running + completed + failed }
}

public struct LabDurableExecutionContext: Sendable {
    public let database: LabResearchDatabase
    public let campaignID: UUID
    public let trialID: String
    public let blockIndex: Int
    public let leaseOwner: String
    public let leaseDuration: TimeInterval

    public init(
        database: LabResearchDatabase,
        campaignID: UUID,
        trialID: String,
        blockIndex: Int,
        leaseOwner: String,
        leaseDuration: TimeInterval = 120
    ) {
        self.database = database
        self.campaignID = campaignID
        self.trialID = trialID
        self.blockIndex = blockIndex
        self.leaseOwner = leaseOwner
        self.leaseDuration = leaseDuration
    }
}

/// Opt-in durable execution metadata supplied by the research control plane.
/// The runner derives the suite/model/helper fingerprints after verification,
/// so callers cannot accidentally register optimistic asset identities.
public struct LabDurableRunConfiguration: Sendable {
    public let database: LabResearchDatabase
    public let campaignID: UUID
    public let campaignName: String
    public let manifestDigestSHA256: String
    public let gitCommit: String
    public let reportProvenance: LabReportProvenance
    public let leaseOwner: String
    public let leaseDuration: TimeInterval

    public init(
        database: LabResearchDatabase,
        campaignID: UUID,
        campaignName: String,
        manifestDigestSHA256: String,
        gitCommit: String,
        reportProvenance: LabReportProvenance = .unavailable(),
        leaseOwner: String = "tilde-lab-\(ProcessInfo.processInfo.processIdentifier)",
        leaseDuration: TimeInterval = 300
    ) {
        self.database = database
        self.campaignID = campaignID
        self.campaignName = campaignName
        self.manifestDigestSHA256 = manifestDigestSHA256
        self.gitCommit = gitCommit
        self.reportProvenance = reportProvenance
        self.leaseOwner = leaseOwner
        self.leaseDuration = max(30, leaseDuration)
    }
}

public enum LabResearchDatabaseError: Error, LocalizedError, Equatable, Sendable {
    case unsafePath
    case openFailed(String)
    case statementFailed(String)
    case bindFailed
    case decodeFailed
    case leaseConflict
    case campaignFingerprintMismatch
    case holdoutAlreadyConsumed
    case durableProtocolRequired

    public var errorDescription: String? {
        switch self {
        case .unsafePath:
            "The research database path is not a regular owner-controlled file."
        case let .openFailed(message):
            "The research database could not be opened: \(message)"
        case let .statementFailed(message):
            "The research database rejected a statement: \(message)"
        case .bindFailed:
            "A research database value could not be bound safely."
        case .decodeFailed:
            "A durable research result could not be decoded."
        case .leaseConflict:
            "The work item lease belongs to another worker."
        case .campaignFingerprintMismatch:
            "Resume was blocked because the campaign code, suite, model, helper, or protocol fingerprint changed."
        case .holdoutAlreadyConsumed:
            "This suite digest has already consumed its one protected holdout evaluation."
        case .durableProtocolRequired:
            "Durable research execution requires an explicit research protocol and one paired selected-suite digest."
        }
    }
}

/// SQLite WAL is the durable control plane for multi-hour and multi-day Lab
/// work. Model grading remains in Swift; this actor only coordinates immutable
/// work identities, leases, atomic results, comparisons, and promotion receipts.
public actor LabResearchDatabase {
    nonisolated(unsafe) private var database: OpaquePointer?
    public nonisolated let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public static var defaultURL: URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tilde Lab/Research", isDirectory: true)
        let current = directory.appendingPathComponent("tilde-lab.sqlite3")
        if FileManager.default.fileExists(atPath: current.path) {
            return current
        }

        // Preserve resumability for campaigns created before the CLI was
        // folded into the single Tilde Lab name.
        let legacy = directory.appendingPathComponent("tilde-research.sqlite3")
        return FileManager.default.fileExists(atPath: legacy.path) ? legacy : current
    }

    public init(fileURL: URL = LabResearchDatabase.defaultURL) throws {
        self.fileURL = fileURL.standardizedFileURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try Self.preparePath(self.fileURL)
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        var handle: OpaquePointer?
        guard sqlite3_open_v2(self.fileURL.path, &handle, flags, nil) == SQLITE_OK,
              let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let handle { sqlite3_close(handle) }
            throw LabResearchDatabaseError.openFailed(message)
        }
        database = handle
        do {
            try Self.execute("PRAGMA journal_mode=WAL", on: handle)
            try Self.execute("PRAGMA synchronous=FULL", on: handle)
            try Self.execute("PRAGMA foreign_keys=ON", on: handle)
            try Self.execute("PRAGMA busy_timeout=5000", on: handle)
            try Self.execute(Self.schemaSQL, on: handle)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: self.fileURL.path
            )
        } catch {
            sqlite3_close(handle)
            database = nil
            throw error
        }
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    public func registerCampaign(_ campaign: LabResearchCampaignRecord) throws {
        let protocolJSON = try encoder.encode(campaign.protocolDefinition)
        if let existing = try campaignFingerprint(id: campaign.id) {
            let expected = Self.campaignFingerprint(campaign)
            guard existing == expected else {
                throw LabResearchDatabaseError.campaignFingerprintMismatch
            }
            return
        }
        try withStatement(
            """
            INSERT INTO campaign(
              id, name, manifest_digest, suite_digest, model_sha, helper_sha,
              git_commit, protocol_json, fingerprint, status, created_at, updated_at
            ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 'running', ?, ?)
            """
        ) { statement in
            let now = Date().timeIntervalSince1970
            try bind(campaign.id.uuidString.lowercased(), at: 1, in: statement)
            try bind(campaign.name, at: 2, in: statement)
            try bind(campaign.manifestDigestSHA256, at: 3, in: statement)
            try bind(campaign.suiteDigestSHA256, at: 4, in: statement)
            try bind(campaign.modelSHA256, at: 5, in: statement)
            try bind(campaign.helperSHA256, at: 6, in: statement)
            try bind(campaign.gitCommit, at: 7, in: statement)
            try bind(protocolJSON, at: 8, in: statement)
            try bind(Self.campaignFingerprint(campaign), at: 9, in: statement)
            sqlite3_bind_double(statement, 10, now)
            sqlite3_bind_double(statement, 11, now)
            try stepDone(statement)
        }
    }

    public func registerTrial(
        campaignID: UUID,
        trialID: String,
        armID: String,
        armHash: String,
        stage: String,
        rootBudget: Int
    ) throws {
        try withStatement(
            """
            INSERT INTO trial(id, campaign_id, arm_id, arm_hash, stage, root_budget, status, created_at)
            VALUES(?, ?, ?, ?, ?, ?, 'pending', ?)
            ON CONFLICT(campaign_id, id) DO UPDATE SET
              arm_hash=excluded.arm_hash,
              stage=excluded.stage,
              root_budget=MAX(trial.root_budget, excluded.root_budget)
            """
        ) { statement in
            try bind(trialID, at: 1, in: statement)
            try bind(campaignID.uuidString.lowercased(), at: 2, in: statement)
            try bind(armID, at: 3, in: statement)
            try bind(armHash, at: 4, in: statement)
            try bind(stage, at: 5, in: statement)
            sqlite3_bind_int64(statement, 6, sqlite3_int64(rootBudget))
            sqlite3_bind_double(statement, 7, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func enqueue(_ items: [LabDurableWorkItem]) throws {
        guard !items.isEmpty else { return }
        try transaction {
            for item in items {
                try withStatement(
                    """
                    INSERT OR IGNORE INTO work_item(
                      id, campaign_id, trial_id, arm_hash, root_id, scenario_id,
                      checkpoint, context_variant, generation_seed, repetition,
                      block_index, status, attempt, created_at, updated_at
                    ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0, ?, ?)
                    """
                ) { statement in
                    try bind(item.id, at: 1, in: statement)
                    try bind(item.campaignID.uuidString.lowercased(), at: 2, in: statement)
                    try bind(item.trialID, at: 3, in: statement)
                    try bind(item.armHash, at: 4, in: statement)
                    try bind(item.rootScenarioID, at: 5, in: statement)
                    try bind(item.scenarioID, at: 6, in: statement)
                    try bind(item.checkpoint.rawValue, at: 7, in: statement)
                    try bind(item.contextVariant.rawValue, at: 8, in: statement)
                    sqlite3_bind_int64(statement, 9, sqlite3_int64(item.generationSeed))
                    sqlite3_bind_int64(statement, 10, sqlite3_int64(item.repetition))
                    sqlite3_bind_int64(statement, 11, sqlite3_int64(item.blockIndex))
                    let now = Date().timeIntervalSince1970
                    sqlite3_bind_double(statement, 12, now)
                    sqlite3_bind_double(statement, 13, now)
                    try stepDone(statement)
                }
            }
        }
    }

    /// Claims one exact work identity. Expired leases are recoverable; a
    /// completed item returns false and is loaded from observations instead.
    public func claim(
        workItemID: String,
        owner: String,
        leaseDuration: TimeInterval = 120,
        now: Date = Date()
    ) throws -> Bool {
        try recoverExpiredLeases(now: now)
        return try transaction {
            let changed = try withStatementReturningChanges(
                """
                UPDATE work_item
                SET status='running', lease_owner=?, lease_expires_at=?,
                    attempt=attempt+1, updated_at=?
                WHERE id=? AND status='pending'
                """
            ) { statement in
                try bind(owner, at: 1, in: statement)
                sqlite3_bind_double(statement, 2, now.addingTimeInterval(leaseDuration).timeIntervalSince1970)
                sqlite3_bind_double(statement, 3, now.timeIntervalSince1970)
                try bind(workItemID, at: 4, in: statement)
            }
            return changed == 1
        }
    }

    public func heartbeat(
        workItemID: String,
        owner: String,
        leaseDuration: TimeInterval = 120,
        now: Date = Date()
    ) throws {
        let changed = try withStatementReturningChanges(
            """
            UPDATE work_item SET lease_expires_at=?, updated_at=?
            WHERE id=? AND status='running' AND lease_owner=?
            """
        ) { statement in
            sqlite3_bind_double(statement, 1, now.addingTimeInterval(leaseDuration).timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, now.timeIntervalSince1970)
            try bind(workItemID, at: 3, in: statement)
            try bind(owner, at: 4, in: statement)
        }
        guard changed == 1 else { throw LabResearchDatabaseError.leaseConflict }
    }

    public func complete(
        workItemID: String,
        owner: String,
        result: LabCaseResult,
        completedAt: Date = Date()
    ) throws {
        let bytes = try encoder.encode(result)
        try transaction {
            let changed = try withStatementReturningChanges(
                """
                UPDATE work_item SET status='completed', lease_owner=NULL,
                    lease_expires_at=NULL, updated_at=?
                WHERE id=? AND status='running' AND lease_owner=?
                """
            ) { statement in
                sqlite3_bind_double(statement, 1, completedAt.timeIntervalSince1970)
                try bind(workItemID, at: 2, in: statement)
                try bind(owner, at: 3, in: statement)
            }
            if changed == 0 {
                var existing: Data?
                try withStatement(
                    "SELECT result_json FROM observation WHERE work_item_id=?"
                ) { statement in
                    try bind(workItemID, at: 1, in: statement)
                    if sqlite3_step(statement) == SQLITE_ROW {
                        existing = blobColumn(statement, 0)
                    }
                }
                if existing == bytes { return }
                throw LabResearchDatabaseError.leaseConflict
            }
            try withStatement(
                """
                INSERT INTO observation(work_item_id, result_json, completed_at)
                VALUES(?, ?, ?)
                ON CONFLICT(work_item_id) DO NOTHING
                """
            ) { statement in
                try bind(workItemID, at: 1, in: statement)
                try bind(bytes, at: 2, in: statement)
                sqlite3_bind_double(statement, 3, completedAt.timeIntervalSince1970)
                try stepDone(statement)
            }
        }
    }

    /// A cooperative cancellation returns the owned lease immediately. A
    /// process crash still relies on normal lease expiry and recovery.
    public func release(workItemID: String, owner: String) throws {
        let changed = try withStatementReturningChanges(
            """
            UPDATE work_item SET status='pending', lease_owner=NULL,
                lease_expires_at=NULL, updated_at=?
            WHERE id=? AND status='running' AND lease_owner=?
            """
        ) { statement in
            sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
            try bind(workItemID, at: 2, in: statement)
            try bind(owner, at: 3, in: statement)
        }
        guard changed == 1 else { throw LabResearchDatabaseError.leaseConflict }
    }

    public func markFailed(workItemID: String, owner: String, reason: String) throws {
        let changed = try withStatementReturningChanges(
            """
            UPDATE work_item SET status='failed', lease_owner=NULL,
                lease_expires_at=NULL, failure_reason=?, updated_at=?
            WHERE id=? AND status='running' AND lease_owner=?
            """
        ) { statement in
            try bind(String(reason.prefix(200)), at: 1, in: statement)
            sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
            try bind(workItemID, at: 3, in: statement)
            try bind(owner, at: 4, in: statement)
        }
        guard changed == 1 else { throw LabResearchDatabaseError.leaseConflict }
    }

    @discardableResult
    public func recoverExpiredLeases(now: Date = Date()) throws -> Int {
        try withStatementReturningChanges(
            """
            UPDATE work_item SET status='pending', lease_owner=NULL,
                lease_expires_at=NULL, updated_at=?
            WHERE status='running' AND lease_expires_at < ?
            """
        ) { statement in
            sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, now.timeIntervalSince1970)
        }
    }

    public func completedResults(
        campaignID: UUID,
        trialID: String,
        workItemIDs: Set<String>? = nil
    ) throws -> [String: LabCaseResult] {
        var result: [String: LabCaseResult] = [:]
        try withStatement(
            """
            SELECT w.id, o.result_json
            FROM work_item w JOIN observation o ON o.work_item_id=w.id
            WHERE w.campaign_id=? AND w.trial_id=? AND w.status='completed'
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            try bind(trialID, at: 2, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = textColumn(statement, 0),
                      workItemIDs == nil || workItemIDs!.contains(id) else { continue }
                guard let bytes = blobColumn(statement, 1) else {
                    throw LabResearchDatabaseError.decodeFailed
                }
                let value: LabCaseResult
                do {
                    value = try decoder.decode(LabCaseResult.self, from: bytes)
                } catch {
                    throw LabResearchDatabaseError.decodeFailed
                }
                result[id] = value
            }
        }
        return result
    }

    public func summary(campaignID: UUID) throws -> LabResearchWorkSummary {
        var counts: [String: Int] = [:]
        try withStatement(
            "SELECT status, COUNT(*) FROM work_item WHERE campaign_id=? GROUP BY status"
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let status = textColumn(statement, 0) {
                    counts[status] = Int(sqlite3_column_int64(statement, 1))
                }
            }
        }
        return LabResearchWorkSummary(
            pending: counts[LabWorkStatus.pending.rawValue, default: 0],
            running: counts[LabWorkStatus.running.rawValue, default: 0],
            completed: counts[LabWorkStatus.completed.rawValue, default: 0],
            failed: counts[LabWorkStatus.failed.rawValue, default: 0]
        )
    }

    public func activeDurationSeconds(campaignID: UUID) throws -> Double {
        var result = 0.0
        try withStatement(
            "SELECT active_seconds FROM campaign_budget_usage WHERE campaign_id=?"
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            if sqlite3_step(statement) == SQLITE_ROW {
                result = max(0, sqlite3_column_double(statement, 0))
            }
        }
        return result
    }

    public func recordActiveDuration(campaignID: UUID, seconds: Double) throws {
        guard seconds.isFinite, seconds >= 0 else { return }
        try withStatement(
            """
            INSERT INTO campaign_budget_usage(campaign_id, active_seconds, updated_at)
            VALUES(?, ?, ?)
            ON CONFLICT(campaign_id) DO UPDATE SET
              active_seconds=campaign_budget_usage.active_seconds+excluded.active_seconds,
              updated_at=excluded.updated_at
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            sqlite3_bind_double(statement, 2, seconds)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func recordBlockEnvironment(
        campaignID: UUID,
        environment: LabResearchBlockEnvironment
    ) throws {
        let bytes = try encoder.encode(environment)
        try withStatement(
            """
            INSERT INTO event_log(campaign_id, kind, aggregate_json, created_at)
            VALUES(?, 'block-environment', ?, ?)
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            try bind(bytes, at: 2, in: statement)
            sqlite3_bind_double(statement, 3, environment.machine.checkedAt.timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func blockEnvironments(campaignID: UUID) throws -> [LabResearchBlockEnvironment] {
        var result: [LabResearchBlockEnvironment] = []
        try withStatement(
            """
            SELECT aggregate_json FROM event_log
            WHERE campaign_id=? AND kind='block-environment'
            ORDER BY id
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let bytes = blobColumn(statement, 0),
                      let value = try? decoder.decode(
                        LabResearchBlockEnvironment.self, from: bytes
                      ) else {
                    throw LabResearchDatabaseError.decodeFailed
                }
                result.append(value)
            }
        }
        return result
    }

    public func saveComparison(
        campaignID: UUID,
        trialID: String,
        report: LabPairedComparisonReport
    ) throws {
        let bytes = try encoder.encode(report)
        try withStatement(
            """
            INSERT INTO comparison(id, campaign_id, trial_id, report_json, decision, created_at)
            VALUES(?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET report_json=excluded.report_json,
              decision=excluded.decision
            """
        ) { statement in
            let id = "\(report.baselineReportID.uuidString):\(report.candidateReportID.uuidString)"
            try bind(id, at: 1, in: statement)
            try bind(campaignID.uuidString.lowercased(), at: 2, in: statement)
            try bind(trialID, at: 3, in: statement)
            try bind(bytes, at: 4, in: statement)
            try bind(report.decision.rawValue, at: 5, in: statement)
            sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func recordPromotion(
        campaignID: UUID,
        armDigestSHA256: String,
        fromPhase: LabCampaignPhase,
        toPhase: LabCampaignPhase,
        decision: String
    ) throws {
        try withStatement(
            """
            INSERT INTO promotion(
              campaign_id, arm_digest, from_phase, to_phase, decision, created_at
            ) VALUES(?, ?, ?, ?, ?, ?)
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            try bind(armDigestSHA256, at: 2, in: statement)
            try bind(fromPhase.rawValue, at: 3, in: statement)
            try bind(toPhase.rawValue, at: 4, in: statement)
            try bind(decision, at: 5, in: statement)
            sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func saveAgentProposal(
        id: UUID,
        campaignID: UUID,
        proposal: LabAgentProposal,
        validationStatus: String,
        rejectionReason: String? = nil
    ) throws {
        let bytes = try encoder.encode(proposal)
        try withStatement(
            """
            INSERT INTO agent_proposal(
              id, campaign_id, proposal_json, validation_status, rejection_reason, created_at
            ) VALUES(?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              validation_status=excluded.validation_status,
              rejection_reason=excluded.rejection_reason
            """
        ) { statement in
            try bind(id.uuidString.lowercased(), at: 1, in: statement)
            try bind(campaignID.uuidString.lowercased(), at: 2, in: statement)
            try bind(bytes, at: 3, in: statement)
            try bind(validationStatus, at: 4, in: statement)
            if let rejectionReason {
                try bind(rejectionReason, at: 5, in: statement)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func saveOnlinePlan(_ plan: LabOnlineExperimentPlan) throws {
        try plan.validated()
        let bytes = try encoder.encode(plan)
        try withStatement(
            """
            INSERT INTO online_plan(campaign_id, plan_json, phase, updated_at)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(campaign_id) DO UPDATE SET
              plan_json=excluded.plan_json,
              phase=excluded.phase,
              updated_at=excluded.updated_at
            """
        ) { statement in
            try bind(plan.campaignID.uuidString.lowercased(), at: 1, in: statement)
            try bind(bytes, at: 2, in: statement)
            try bind(plan.phase.rawValue, at: 3, in: statement)
            sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func onlinePlan(campaignID: UUID) throws -> LabOnlineExperimentPlan? {
        var result: LabOnlineExperimentPlan?
        try withStatement(
            "SELECT plan_json FROM online_plan WHERE campaign_id=?"
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let bytes = blobColumn(statement, 0) else { return }
            guard let decoded = try? decoder.decode(LabOnlineExperimentPlan.self, from: bytes) else {
                throw LabResearchDatabaseError.decodeFailed
            }
            result = try decoded.validated()
        }
        return result
    }

    public func recordOnlineEvent(
        _ event: LabOnlineExperimentEvent,
        plan: LabOnlineExperimentPlan
    ) throws {
        try event.validated(for: plan)
        let bytes = try encoder.encode(event)
        try withStatement(
            """
            INSERT INTO online_event(id, campaign_id, event_json, occurred_at)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(id) DO NOTHING
            """
        ) { statement in
            try bind(event.id.uuidString.lowercased(), at: 1, in: statement)
            try bind(event.campaignID.uuidString.lowercased(), at: 2, in: statement)
            try bind(bytes, at: 3, in: statement)
            sqlite3_bind_double(statement, 4, event.occurredAt.timeIntervalSince1970)
            try stepDone(statement)
        }
    }

    public func onlineEvents(campaignID: UUID) throws -> [LabOnlineExperimentEvent] {
        var result: [LabOnlineExperimentEvent] = []
        try withStatement(
            """
            SELECT event_json FROM online_event
            WHERE campaign_id=? ORDER BY occurred_at, id
            """
        ) { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let bytes = blobColumn(statement, 0),
                      let event = try? decoder.decode(LabOnlineExperimentEvent.self, from: bytes) else {
                    throw LabResearchDatabaseError.decodeFailed
                }
                result.append(event)
            }
        }
        return result
    }

    public func deleteOnlineEvents(campaignID: UUID) throws {
        try withStatement("DELETE FROM online_event WHERE campaign_id=?") { statement in
            try bind(campaignID.uuidString.lowercased(), at: 1, in: statement)
            try stepDone(statement)
        }
    }

    /// Atomic one-time receipt. A failed insert does not partially consume the
    /// holdout; a successful insert cannot be repeated for the suite digest.
    public func consumeHoldout(
        suiteDigestSHA256: String,
        baselineArmDigestSHA256: String,
        candidateArmDigestSHA256: String,
        campaignID: UUID,
        allowResume: Bool = false
    ) throws {
        do {
            try withStatement(
                """
                INSERT INTO holdout_receipt(
                  suite_digest, campaign_id, baseline_arm_digest,
                  candidate_arm_digest, consumed_at
                ) VALUES(?, ?, ?, ?, ?)
                """
            ) { statement in
                try bind(suiteDigestSHA256, at: 1, in: statement)
                try bind(campaignID.uuidString.lowercased(), at: 2, in: statement)
                try bind(baselineArmDigestSHA256, at: 3, in: statement)
                try bind(candidateArmDigestSHA256, at: 4, in: statement)
                sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
                try stepDone(statement)
            }
        } catch let error as LabResearchDatabaseError {
            if case let .statementFailed(message) = error,
               message.lowercased().contains("unique") {
                if allowResume,
                   try holdoutReceiptMatches(
                    suiteDigestSHA256: suiteDigestSHA256,
                    baselineArmDigestSHA256: baselineArmDigestSHA256,
                    candidateArmDigestSHA256: candidateArmDigestSHA256,
                    campaignID: campaignID
                   ) {
                    return
                }
                throw LabResearchDatabaseError.holdoutAlreadyConsumed
            }
            throw error
        }
    }

    private func holdoutReceiptMatches(
        suiteDigestSHA256: String,
        baselineArmDigestSHA256: String,
        candidateArmDigestSHA256: String,
        campaignID: UUID
    ) throws -> Bool {
        var matches = false
        try withStatement(
            """
            SELECT campaign_id, baseline_arm_digest, candidate_arm_digest
            FROM holdout_receipt WHERE suite_digest=?
            """
        ) { statement in
            try bind(suiteDigestSHA256, at: 1, in: statement)
            guard sqlite3_step(statement) == SQLITE_ROW else { return }
            matches = textColumn(statement, 0) == campaignID.uuidString.lowercased()
                && textColumn(statement, 1) == baselineArmDigestSHA256
                && textColumn(statement, 2) == candidateArmDigestSHA256
        }
        return matches
    }

    public func journalMode() throws -> String {
        var value = ""
        try withStatement("PRAGMA journal_mode") { statement in
            if sqlite3_step(statement) == SQLITE_ROW {
                value = textColumn(statement, 0) ?? ""
            }
        }
        return value
    }

    private func createSchema() throws {
        try execute(Self.schemaSQL)
    }

    private static let schemaSQL =
        """
            CREATE TABLE IF NOT EXISTS campaign(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              manifest_digest TEXT NOT NULL,
              suite_digest TEXT NOT NULL,
              model_sha TEXT NOT NULL,
              helper_sha TEXT NOT NULL,
              git_commit TEXT NOT NULL,
              protocol_json BLOB NOT NULL,
              fingerprint TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at REAL NOT NULL,
              updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS trial(
              id TEXT NOT NULL,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              arm_id TEXT NOT NULL,
              arm_hash TEXT NOT NULL,
              stage TEXT NOT NULL,
              root_budget INTEGER NOT NULL,
              status TEXT NOT NULL,
              created_at REAL NOT NULL,
              PRIMARY KEY(campaign_id, id)
            );
            CREATE TABLE IF NOT EXISTS work_item(
              id TEXT PRIMARY KEY,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              trial_id TEXT NOT NULL,
              arm_hash TEXT NOT NULL,
              root_id TEXT NOT NULL,
              scenario_id TEXT NOT NULL,
              checkpoint TEXT NOT NULL,
              context_variant TEXT NOT NULL,
              generation_seed INTEGER NOT NULL,
              repetition INTEGER NOT NULL,
              block_index INTEGER NOT NULL,
              status TEXT NOT NULL,
              lease_owner TEXT,
              lease_expires_at REAL,
              attempt INTEGER NOT NULL,
              failure_reason TEXT,
              created_at REAL NOT NULL,
              updated_at REAL NOT NULL,
              FOREIGN KEY(campaign_id, trial_id)
                REFERENCES trial(campaign_id, id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS work_pending
              ON work_item(campaign_id, status, block_index, trial_id, root_id);
            CREATE TABLE IF NOT EXISTS observation(
              work_item_id TEXT PRIMARY KEY REFERENCES work_item(id) ON DELETE CASCADE,
              result_json BLOB NOT NULL,
              completed_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS comparison(
              id TEXT PRIMARY KEY,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              trial_id TEXT NOT NULL,
              report_json BLOB NOT NULL,
              decision TEXT NOT NULL,
              created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS promotion(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              arm_digest TEXT NOT NULL,
              from_phase TEXT NOT NULL,
              to_phase TEXT NOT NULL,
              decision TEXT NOT NULL,
              created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS agent_proposal(
              id TEXT PRIMARY KEY,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              proposal_json BLOB NOT NULL,
              validation_status TEXT NOT NULL,
              rejection_reason TEXT,
              created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS event_log(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              kind TEXT NOT NULL,
              aggregate_json BLOB,
              created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS campaign_budget_usage(
              campaign_id TEXT PRIMARY KEY REFERENCES campaign(id) ON DELETE CASCADE,
              active_seconds REAL NOT NULL DEFAULT 0,
              updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS online_plan(
              campaign_id TEXT PRIMARY KEY REFERENCES campaign(id) ON DELETE CASCADE,
              plan_json BLOB NOT NULL,
              phase TEXT NOT NULL,
              updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS online_event(
              id TEXT PRIMARY KEY,
              campaign_id TEXT NOT NULL REFERENCES campaign(id) ON DELETE CASCADE,
              event_json BLOB NOT NULL,
              occurred_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS online_event_campaign_time
              ON online_event(campaign_id, occurred_at);
            CREATE TABLE IF NOT EXISTS holdout_receipt(
              suite_digest TEXT PRIMARY KEY,
              campaign_id TEXT NOT NULL REFERENCES campaign(id),
              baseline_arm_digest TEXT NOT NULL,
              candidate_arm_digest TEXT NOT NULL,
              consumed_at REAL NOT NULL
            );
            """

    private func campaignFingerprint(id: UUID) throws -> String? {
        var result: String?
        try withStatement("SELECT fingerprint FROM campaign WHERE id=?") { statement in
            try bind(id.uuidString.lowercased(), at: 1, in: statement)
            if sqlite3_step(statement) == SQLITE_ROW { result = textColumn(statement, 0) }
        }
        return result
    }

    private static func campaignFingerprint(_ value: LabResearchCampaignRecord) -> String {
        let source = [
            value.manifestDigestSHA256, value.suiteDigestSHA256, value.modelSHA256,
            value.helperSHA256, value.gitCommit,
            (try? LabResearchDigestProxy.digest(value.protocolDefinition)) ?? "invalid",
        ].joined(separator: ":")
        return SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func preparePath(_ url: URL) throws {
        guard url.isFileURL, !url.path.isEmpty else { throw LabResearchDatabaseError.unsafePath }
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if manager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw LabResearchDatabaseError.unsafePath
            }
        }
    }

    private func execute(_ sql: String) throws {
        guard let database else { throw LabResearchDatabaseError.openFailed("closed") }
        try Self.execute(sql, on: database)
    }

    private static func execute(_ sql: String, on database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw LabResearchDatabaseError.statementFailed(message)
        }
    }

    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func withStatement<T>(_ sql: String, body: (OpaquePointer) throws -> T) throws -> T {
        guard let database else { throw LabResearchDatabaseError.openFailed("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw LabResearchDatabaseError.statementFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func withStatementReturningChanges(
        _ sql: String,
        body: (OpaquePointer) throws -> Void
    ) throws -> Int {
        try withStatement(sql) { statement in
            try body(statement)
            try stepDone(statement)
            return Int(sqlite3_changes(database))
        }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "closed"
            throw LabResearchDatabaseError.statementFailed(message)
        }
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer) throws {
        let code = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }
        guard code == SQLITE_OK else { throw LabResearchDatabaseError.bindFailed }
    }

    private func bind(_ value: Data, at index: Int32, in statement: OpaquePointer) throws {
        let code = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), sqliteTransient)
        }
        guard code == SQLITE_OK else { throw LabResearchDatabaseError.bindFailed }
    }

    private func textColumn(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
    }

    private func blobColumn(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        guard let pointer = sqlite3_column_blob(statement, index) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: pointer, count: count)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum LabResearchDigestProxy {
    static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
