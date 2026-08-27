import Foundation

public enum LabLearningStatus: String, Codable, CaseIterable, Sendable {
    case adopted
    case rejected
    case directional
    case superseded
    case incomplete
    case operational
    case boundary

    public var title: String {
        switch self {
        case .adopted: "Adopted"
        case .rejected: "Rejected"
        case .directional: "Directional"
        case .superseded: "Superseded"
        case .incomplete: "Incomplete"
        case .operational: "Operational"
        case .boundary: "Boundary"
        }
    }
}

public struct LabLearningLedgerPrivacy: Codable, Equatable, Sendable {
    public let aggregateOnly: Bool
    public let containsRawScenarioText: Bool
    public let containsRawModelOutput: Bool
    public let containsPersonalWriting: Bool
    public let containsFilePaths: Bool

    public var safeToCheckIn: Bool {
        aggregateOnly
            && !containsRawScenarioText
            && !containsRawModelOutput
            && !containsPersonalWriting
            && !containsFilePaths
    }
}

public struct LabLearningMetric: Codable, Equatable, Sendable {
    public let subjectID: String?
    public let key: String
    public let value: Double
    public let unit: String
}

public struct LabLearningEvidenceReference: Codable, Equatable, Sendable {
    public let kind: String
    public let id: String
}

public struct LabLearningLedgerEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let recordedAt: Date
    public let area: String
    public let status: LabLearningStatus
    public let title: String
    public let finding: String
    public let decision: String
    public let comparisonGroupID: String?
    public let evaluationCount: Int?
    public let metrics: [LabLearningMetric]
    public let evidence: [LabLearningEvidenceReference]
    public let limitations: [String]
    public let tags: [String]
}

public struct LabLearningResearchQuestion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let priority: Int
    public let status: String
    public let question: String
    public let hypothesis: String
    public let nextExperiment: String
    public let successCriteria: String
    public let dependencies: [String]
}

public enum LabResearchProgramStageStatus: String, Codable, CaseIterable, Sendable {
    case active
    case locked
    case completed

    public var title: String {
        switch self {
        case .active: "Active"
        case .locked: "Locked"
        case .completed: "Completed"
        }
    }
}

public struct LabResearchProgramHypothesis: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
}

public struct LabResearchProgramStage: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let status: LabResearchProgramStageStatus
    public let title: String
    public let objective: String
    public let exitGate: String
    public let hypotheses: [LabResearchProgramHypothesis]
}

public struct LabLearningPromotionStage: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let title: String
    public let requirement: String
}

public struct LabLearningLedgerSnapshot: Codable, Equatable, Sendable {
    public let schema: String
    public let updatedAt: Date
    public let mission: String
    public let privacy: LabLearningLedgerPrivacy
    public let operatingPrinciples: [String]
    public let researchProgram: [LabResearchProgramStage]
    public let entries: [LabLearningLedgerEntry]
    public let researchQueue: [LabLearningResearchQuestion]
    public let promotionPath: [LabLearningPromotionStage]

    public var currentLearnings: [LabLearningLedgerEntry] {
        entries.filter { $0.status != .superseded }
    }

    public var archivedLearnings: [LabLearningLedgerEntry] {
        entries.filter { $0.status == .superseded }
    }
}

public enum LabLearningLedgerError: Error, Equatable, LocalizedError {
    case invalidSchema
    case unsafePrivacyBoundary
    case duplicateEntryID(String)
    case duplicateResearchQuestionID(String)
    case duplicateResearchHypothesisID(String)
    case invalidEntry(String)
    case invalidResearchQuestion(String)
    case invalidResearchProgram
    case invalidPromotionPath
    case unresolvedBenchmarkReference(String)
    case forbiddenKey(String)
    case localPath

    public var errorDescription: String? {
        switch self {
        case .invalidSchema: "The learning ledger schema is unsupported."
        case .unsafePrivacyBoundary: "The learning ledger is not aggregate-only."
        case let .duplicateEntryID(id): "The learning ledger repeats entry ID \(id)."
        case let .duplicateResearchQuestionID(id): "The learning ledger repeats research question ID \(id)."
        case let .duplicateResearchHypothesisID(id): "The learning ledger repeats research hypothesis ID \(id)."
        case let .invalidEntry(id): "Learning ledger entry \(id) is incomplete."
        case let .invalidResearchQuestion(id): "Learning question \(id) is incomplete."
        case .invalidResearchProgram: "The staged research program is invalid."
        case .invalidPromotionPath: "The learning ledger promotion path is invalid."
        case let .unresolvedBenchmarkReference(id): "Learning ledger benchmark reference \(id) does not resolve."
        case let .forbiddenKey(key): "The learning ledger contains forbidden raw-data key \(key)."
        case .localPath: "The learning ledger contains a local file path."
        }
    }
}

public enum LabLearningLedgerCatalog {
    public static let schema = "tilde-lab.learning-ledger.v1"

    private static let forbiddenKeys: Set<String> = [
        "scenariotext",
        "rawscenariotext",
        "rawprompt",
        "prompttext",
        "candidatetext",
        "modeloutput",
        "rawmodeloutput",
        "personalwriting",
        "filepath",
    ]

    public static func loadBundled() throws -> LabLearningLedgerSnapshot {
        guard let url = Bundle.module.url(
            forResource: "learning-ledger-v1",
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decodeAndValidate(Data(contentsOf: url))
    }

    public static func decodeAndValidate(_ data: Data) throws -> LabLearningLedgerSnapshot {
        try validateRawJSON(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(LabLearningLedgerSnapshot.self, from: data)
        try validate(snapshot)
        return snapshot
    }

    public static func validate(_ snapshot: LabLearningLedgerSnapshot) throws {
        guard snapshot.schema == schema else { throw LabLearningLedgerError.invalidSchema }
        guard snapshot.privacy.safeToCheckIn else {
            throw LabLearningLedgerError.unsafePrivacyBoundary
        }
        guard !snapshot.mission.trimmed.isEmpty,
              !snapshot.operatingPrinciples.isEmpty,
              snapshot.operatingPrinciples.allSatisfy({ !$0.trimmed.isEmpty }) else {
            throw LabLearningLedgerError.invalidEntry("mission")
        }

        let researchStages = snapshot.researchProgram.sorted { $0.order < $1.order }
        guard !researchStages.isEmpty,
              Set(researchStages.map(\.id)).count == researchStages.count,
              researchStages.map(\.order) == Array(0..<researchStages.count),
              researchStages.filter({ $0.status == .active }).count <= 1 else {
            throw LabLearningLedgerError.invalidResearchProgram
        }
        var hypothesisIDs = Set<String>()
        for stage in researchStages {
            guard !stage.id.trimmed.isEmpty,
                  !stage.title.trimmed.isEmpty,
                  !stage.objective.trimmed.isEmpty,
                  !stage.exitGate.trimmed.isEmpty,
                  !stage.hypotheses.isEmpty else {
                throw LabLearningLedgerError.invalidResearchProgram
            }
            for hypothesis in stage.hypotheses {
                guard hypothesisIDs.insert(hypothesis.id).inserted else {
                    throw LabLearningLedgerError.duplicateResearchHypothesisID(hypothesis.id)
                }
                guard !hypothesis.id.trimmed.isEmpty, !hypothesis.title.trimmed.isEmpty else {
                    throw LabLearningLedgerError.invalidResearchProgram
                }
            }
        }
        let stageStatuses = researchStages.map(\.status)
        if let activeIndex = stageStatuses.firstIndex(of: .active) {
            for (index, status) in stageStatuses.enumerated() {
                guard index == activeIndex
                    || (index < activeIndex && status == .completed)
                    || (index > activeIndex && status == .locked) else {
                    throw LabLearningLedgerError.invalidResearchProgram
                }
            }
        } else if !stageStatuses.allSatisfy({ $0 == .completed }) {
            throw LabLearningLedgerError.invalidResearchProgram
        }

        var entryIDs = Set<String>()
        let benchmark = try LabModelBenchmarkCatalog.loadBundled()
        let benchmarkIDs = Set(benchmark.entries.map(\.id))
        let promotedIDs = Set(benchmark.promotedConfigurations.map(\.id))
        for entry in snapshot.entries {
            guard entryIDs.insert(entry.id).inserted else {
                throw LabLearningLedgerError.duplicateEntryID(entry.id)
            }
            guard !entry.id.trimmed.isEmpty,
                  !entry.area.trimmed.isEmpty,
                  !entry.title.trimmed.isEmpty,
                  !entry.finding.trimmed.isEmpty,
                  !entry.decision.trimmed.isEmpty,
                  !entry.evidence.isEmpty,
                  entry.evidence.allSatisfy({ !$0.kind.trimmed.isEmpty && !$0.id.trimmed.isEmpty }),
                  entry.metrics.allSatisfy({
                      !$0.key.trimmed.isEmpty && !$0.unit.trimmed.isEmpty && $0.value.isFinite
                  }),
                  entry.evaluationCount.map({ $0 > 0 }) ?? true else {
                throw LabLearningLedgerError.invalidEntry(entry.id)
            }
            if [.directional, .superseded, .incomplete].contains(entry.status),
               entry.limitations.isEmpty {
                throw LabLearningLedgerError.invalidEntry(entry.id)
            }
            for reference in entry.evidence where reference.kind == "model-benchmark-entry" {
                guard benchmarkIDs.contains(reference.id) else {
                    throw LabLearningLedgerError.unresolvedBenchmarkReference(reference.id)
                }
            }
            for reference in entry.evidence where reference.kind == "promoted-configuration" {
                guard promotedIDs.contains(reference.id) else {
                    throw LabLearningLedgerError.unresolvedBenchmarkReference(reference.id)
                }
            }
        }

        var questionIDs = Set<String>()
        var priorities = Set<Int>()
        for question in snapshot.researchQueue {
            guard questionIDs.insert(question.id).inserted else {
                throw LabLearningLedgerError.duplicateResearchQuestionID(question.id)
            }
            guard priorities.insert(question.priority).inserted,
                  question.priority > 0,
                  !question.id.trimmed.isEmpty,
                  !question.status.trimmed.isEmpty,
                  !question.question.trimmed.isEmpty,
                  !question.hypothesis.trimmed.isEmpty,
                  !question.nextExperiment.trimmed.isEmpty,
                  !question.successCriteria.trimmed.isEmpty else {
                throw LabLearningLedgerError.invalidResearchQuestion(question.id)
            }
        }

        let stages = snapshot.promotionPath.sorted { $0.order < $1.order }
        guard !stages.isEmpty,
              Set(stages.map(\.id)).count == stages.count,
              stages.map(\.order) == Array(1...stages.count),
              stages.allSatisfy({
                  !$0.id.trimmed.isEmpty && !$0.title.trimmed.isEmpty && !$0.requirement.trimmed.isEmpty
              }) else {
            throw LabLearningLedgerError.invalidPromotionPath
        }
    }

    private static func validateRawJSON(_ data: Data) throws {
        let root = try JSONSerialization.jsonObject(with: data)
        try visit(root)
    }

    private static func visit(_ value: Any) throws {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if forbiddenKeys.contains(key.lowercased()) {
                    throw LabLearningLedgerError.forbiddenKey(key)
                }
                try visit(child)
            }
        } else if let array = value as? [Any] {
            for child in array { try visit(child) }
        } else if let string = value as? String {
            if string.contains("/Users/") || string.contains("file://") || string.hasPrefix("~/") {
                throw LabLearningLedgerError.localPath
            }
        }
    }
}

public enum LabLearningLedgerRenderer {
    public static func humanSummary(_ snapshot: LabLearningLedgerSnapshot) -> String {
        var lines = [
            "Tilde Learning Ledger",
            "  mission: \(snapshot.mission)",
            "  updated: \(snapshot.updatedAt.formatted(.iso8601))",
            "  evidence: \(snapshot.currentLearnings.count) current, \(snapshot.archivedLearnings.count) archived",
            "  staged research program:",
        ]
        for stage in snapshot.researchProgram.sorted(by: { $0.order < $1.order }) {
            lines.append("    [\(stage.status.title)] Stage \(stage.order): \(stage.title)")
            lines.append("      objective: \(stage.objective)")
            lines.append("      hypotheses: \(stage.hypotheses.map(\.id).joined(separator: ", "))")
        }
        lines.append("  current learnings:")
        for entry in snapshot.currentLearnings.sorted(by: newestFirst) {
            lines.append("    [\(entry.status.title)] \(entry.title)")
            lines.append("      finding: \(entry.finding)")
            lines.append("      decision: \(entry.decision)")
            if !entry.limitations.isEmpty {
                lines.append("      limitations: \(entry.limitations.joined(separator: " "))")
            }
        }
        lines.append("  next experiments:")
        for question in snapshot.researchQueue.sorted(by: { $0.priority < $1.priority }) {
            lines.append("    \(question.priority). \(question.question)")
            lines.append("       \(question.nextExperiment)")
        }
        return lines.joined(separator: "\n")
    }

    private static func newestFirst(_ lhs: LabLearningLedgerEntry, _ rhs: LabLearningLedgerEntry) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
        return lhs.id < rhs.id
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
