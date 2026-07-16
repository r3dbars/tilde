import Foundation
import AutocompleteLabCore

public enum SuggestionEpisodeOutcome: String, Codable, CaseIterable, Equatable, Sendable {
    case shown
    case accepted
    case ignored
    case dismissed
    case typedPast
    case deletedFast
    case kept
    case suppressed
    case insertionFailed
    case unknown
}

public struct SuggestionEpisodeAction: Codable, Equatable, Sendable {
    public let outcome: SuggestionEpisodeOutcome
    public let timestamp: String
    public let reason: String
    public let metadata: [String: String]

    public init(
        outcome: SuggestionEpisodeOutcome,
        timestamp: String,
        reason: String = "",
        metadata: [String: String] = [:]
    ) {
        self.outcome = outcome
        self.timestamp = timestamp
        self.reason = reason
        self.metadata = metadata
    }
}

public struct SuggestionEpisodeSurvivalCheckpoint: Codable, Equatable, Sendable {
    public let checkpoint: String
    public let survivalClass: String
    public let tokenRecall: Double?
    public let normalizedEditDistance: Double?
    public let timestamp: String

    public init(
        checkpoint: String,
        survivalClass: String,
        tokenRecall: Double? = nil,
        normalizedEditDistance: Double? = nil,
        timestamp: String
    ) {
        self.checkpoint = checkpoint
        self.survivalClass = survivalClass
        self.tokenRecall = tokenRecall
        self.normalizedEditDistance = normalizedEditDistance
        self.timestamp = timestamp
    }

    public var countsAsKept: Bool {
        survivalClass == AcceptanceSurvivalClass.exactKept.rawValue
            || survivalClass == AcceptanceSurvivalClass.lightlyEditedKept.rawValue
            || survivalClass == AcceptanceSurvivalClass.partiallyKept.rawValue
    }

    public var countsAsScoreableKept: Bool {
        countsAsKept
            && checkpoint != AcceptanceSurvivalCheckpoint.twoSeconds.rawValue
            && checkpoint != AcceptanceSurvivalCheckpoint.tenSeconds.rawValue
    }

    public var countsAsDeletedFast: Bool {
        survivalClass == AcceptanceSurvivalClass.rejectedAfterAccept.rawValue
            && (checkpoint == AcceptanceSurvivalCheckpoint.twoSeconds.rawValue
                || checkpoint == AcceptanceSurvivalCheckpoint.tenSeconds.rawValue)
    }
}

public struct SuggestionEpisodeModelContext: Codable, Equatable, Sendable {
    public let modelName: String
    public let runtime: String
    public let asset: String
    public let promptVersion: String
    public let experimentArm: String
    public let triggerReason: String
    public let candidateSource: String
    public let latencyMilliseconds: Int?
    public let firstTokenLatencyMilliseconds: Int?

    public init(
        modelName: String,
        runtime: String,
        asset: String,
        promptVersion: String,
        experimentArm: String,
        triggerReason: String,
        candidateSource: String,
        latencyMilliseconds: Int? = nil,
        firstTokenLatencyMilliseconds: Int? = nil
    ) {
        self.modelName = modelName
        self.runtime = runtime
        self.asset = asset
        self.promptVersion = promptVersion
        self.experimentArm = experimentArm
        self.triggerReason = triggerReason
        self.candidateSource = candidateSource
        self.latencyMilliseconds = latencyMilliseconds
        self.firstTokenLatencyMilliseconds = firstTokenLatencyMilliseconds
    }
}

public struct SuggestionEpisodePlacementContext: Codable, Equatable, Sendable {
    public let renderMode: String
    public let anchorRect: String
    public let textLineRect: String
    public let panelRect: String
    public let confidenceBand: String
    public let screenshotCaptured: Bool

    public init(
        renderMode: String,
        anchorRect: String = "",
        textLineRect: String = "",
        panelRect: String = "",
        confidenceBand: String = "",
        screenshotCaptured: Bool = false
    ) {
        self.renderMode = renderMode
        self.anchorRect = anchorRect
        self.textLineRect = textLineRect
        self.panelRect = panelRect
        self.confidenceBand = confidenceBand
        self.screenshotCaptured = screenshotCaptured
    }
}

public struct SuggestionEpisodeReplyContext: Codable, Equatable, Sendable {
    public let source: String
    public let captureScope: String
    public let text: String

    public init?(visiblePageContext: VisiblePageContext) {
        guard visiblePageContext.captureScope == .focusedRegion else {
            return nil
        }

        self.init(
            source: visiblePageContext.source.rawValue,
            captureScope: visiblePageContext.captureScope.rawValue,
            text: visiblePageContext.text
        )
    }

    public init(source: String, captureScope: String, text: String) {
        self.source = source
        self.captureScope = captureScope
        self.text = text
    }
}

public struct SuggestionEpisodeRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let createdAt: String
    public var updatedAt: String
    public var appDisplayName: String
    public var appBundleIdentifier: String
    public var fieldIdentity: String
    public var fieldKind: String
    public var fieldKindReason: String
    public var requestMode: String
    public var userTypedContext: String
    public var textAfterCursor: String
    public var replyContext: SuggestionEpisodeReplyContext?
    public var suggestedText: String
    public var acceptedText: String
    public var model: SuggestionEpisodeModelContext
    public var placement: SuggestionEpisodePlacementContext
    public var outcome: SuggestionEpisodeOutcome
    public var actions: [SuggestionEpisodeAction]
    public var survivalCheckpoints: [SuggestionEpisodeSurvivalCheckpoint]
    public var safetyPolicyVersion: String
    public var metadata: [String: String]

    public init(
        id: String,
        createdAt: String,
        updatedAt: String? = nil,
        appDisplayName: String,
        appBundleIdentifier: String,
        fieldIdentity: String,
        fieldKind: String,
        fieldKindReason: String,
        requestMode: String,
        userTypedContext: String,
        textAfterCursor: String = "",
        replyContext: SuggestionEpisodeReplyContext? = nil,
        suggestedText: String,
        acceptedText: String = "",
        model: SuggestionEpisodeModelContext,
        placement: SuggestionEpisodePlacementContext,
        outcome: SuggestionEpisodeOutcome = .shown,
        actions: [SuggestionEpisodeAction] = [],
        survivalCheckpoints: [SuggestionEpisodeSurvivalCheckpoint] = [],
        safetyPolicyVersion: String = "personal-capture-v1",
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.appDisplayName = appDisplayName
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentity = fieldIdentity
        self.fieldKind = fieldKind
        self.fieldKindReason = fieldKindReason
        self.requestMode = requestMode
        self.userTypedContext = userTypedContext
        self.textAfterCursor = textAfterCursor
        self.replyContext = replyContext
        self.suggestedText = suggestedText
        self.acceptedText = acceptedText
        self.model = model
        self.placement = placement
        self.outcome = outcome
        self.actions = actions.isEmpty
            ? [SuggestionEpisodeAction(outcome: outcome, timestamp: createdAt, reason: "presented")]
            : actions
        self.survivalCheckpoints = survivalCheckpoints
        self.safetyPolicyVersion = safetyPolicyVersion
        self.metadata = metadata
    }

    public var acceptedAndKeptScore: Int {
        if outcome == .deletedFast || survivalCheckpoints.contains(where: \.countsAsDeletedFast) {
            return 0
        }
        if survivalCheckpoints.contains(where: { $0.countsAsKept && $0.checkpoint == AcceptanceSurvivalCheckpoint.fiveMinutes.rawValue }) {
            return 5
        }
        if survivalCheckpoints.contains(where: { $0.countsAsKept && $0.checkpoint == AcceptanceSurvivalCheckpoint.oneMinute.rawValue }) {
            return 4
        }
        if survivalCheckpoints.contains(where: { $0.countsAsKept && $0.checkpoint == AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue }) {
            return 3
        }
        if survivalCheckpoints.contains(where: \.countsAsScoreableKept) || (
            outcome == .kept && survivalCheckpoints.isEmpty
        ) {
            return 2
        }
        if outcome == .accepted {
            return 1
        }
        return 0
    }

    public var isEvalCandidate: Bool {
        acceptedAndKeptScore >= 2
            && !acceptedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !userTypedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public mutating func mergePresentation(_ newer: SuggestionEpisodeRecord) {
        updatedAt = newer.updatedAt
        appDisplayName = newer.appDisplayName
        appBundleIdentifier = newer.appBundleIdentifier
        fieldIdentity = newer.fieldIdentity
        fieldKind = newer.fieldKind
        fieldKindReason = newer.fieldKindReason
        requestMode = newer.requestMode
        userTypedContext = newer.userTypedContext
        textAfterCursor = newer.textAfterCursor
        replyContext = newer.replyContext
        suggestedText = newer.suggestedText
        model = newer.model
        placement = newer.placement
        metadata.merge(newer.metadata) { _, new in new }
        if outcome == .unknown || outcome == .suppressed {
            outcome = .shown
        }
        appendAction(.shown, timestamp: newer.updatedAt, reason: "presented")
    }

    public mutating func appendAction(
        _ action: SuggestionEpisodeOutcome,
        timestamp: String,
        reason: String = "",
        acceptedText: String = "",
        metadata: [String: String] = [:]
    ) {
        updatedAt = timestamp
        if !acceptedText.isEmpty {
            self.acceptedText = acceptedText
        }

        actions.append(SuggestionEpisodeAction(
            outcome: action,
            timestamp: timestamp,
            reason: reason,
            metadata: metadata
        ))

        switch action {
        case .kept:
            if outcome != .deletedFast {
                outcome = .kept
            }
        case .deletedFast:
            outcome = .deletedFast
        case .accepted:
            if outcome != .kept && outcome != .deletedFast {
                outcome = .accepted
            }
        case .ignored, .dismissed, .typedPast, .suppressed, .insertionFailed:
            if outcome != .accepted && outcome != .kept && outcome != .deletedFast {
                outcome = action
            }
        case .shown, .unknown:
            if outcome == .unknown {
                outcome = action
            }
        }
    }

    public mutating func appendSurvivalCheckpoint(
        _ checkpoint: SuggestionEpisodeSurvivalCheckpoint
    ) {
        updatedAt = checkpoint.timestamp
        survivalCheckpoints.removeAll { $0.checkpoint == checkpoint.checkpoint }
        survivalCheckpoints.append(checkpoint)
        survivalCheckpoints.sort { $0.checkpoint < $1.checkpoint }

        if checkpoint.countsAsDeletedFast {
            appendAction(
                .deletedFast,
                timestamp: checkpoint.timestamp,
                reason: checkpoint.checkpoint,
                metadata: ["survivalClass": checkpoint.survivalClass]
            )
        } else if checkpoint.countsAsScoreableKept {
            appendAction(
                .kept,
                timestamp: checkpoint.timestamp,
                reason: checkpoint.checkpoint,
                metadata: ["survivalClass": checkpoint.survivalClass]
            )
        }
    }
}

public struct SuggestionEpisodeEvalCase: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let appBundleIdentifier: String
    public let requestMode: String
    public let modelName: String
    public let promptVersion: String
    public let context: String
    public let expectedContinuation: String
    public let acceptedAndKeptScore: Int

    public init(record: SuggestionEpisodeRecord) {
        id = record.id
        appBundleIdentifier = record.appBundleIdentifier
        requestMode = record.requestMode
        modelName = record.model.modelName
        promptVersion = record.model.promptVersion
        context = [
            record.replyContext?.text,
            record.userTypedContext
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\nBefore cursor:\n")
        expectedContinuation = record.acceptedText
        acceptedAndKeptScore = record.acceptedAndKeptScore
    }
}

public struct SuggestionEpisodeEvalGenerator: Equatable, Sendable {
    public init() {}

    public func cases(from records: [SuggestionEpisodeRecord]) -> [SuggestionEpisodeEvalCase] {
        records
            .filter(\.isEvalCandidate)
            .sorted { $0.updatedAt < $1.updatedAt }
            .map(SuggestionEpisodeEvalCase.init(record:))
    }
}

public struct SuggestionEpisodeScorecard: Equatable, Sendable {
    public let total: Int
    public let shown: Int
    public let accepted: Int
    public let kept: Int
    public let ignored: Int
    public let dismissed: Int
    public let typedPast: Int
    public let typeThroughSurvivals: Int
    public let typeThroughSurvivalRate: Double
    public let deletedFast: Int
    public let averageLatencyMilliseconds: Int?
    public let evalCaseCount: Int
    public let score: Int
    public let modelPromptRows: [String]

    public init(records: [SuggestionEpisodeRecord]) {
        total = records.count
        shown = records.filter { $0.actions.contains { $0.outcome == .shown } }.count
        accepted = records.filter { $0.actions.contains { $0.outcome == .accepted } }.count
        kept = records.filter { $0.acceptedAndKeptScore >= 2 }.count
        ignored = records.filter { $0.outcome == .ignored }.count
        dismissed = records.filter { $0.outcome == .dismissed }.count
        typedPast = records.filter { $0.outcome == .typedPast }.count
        typeThroughSurvivals = records.filter { record in
            record.actions.contains { action in
                action.reason == "survived_typethrough"
                    || action.metadata["typeThroughSurvival"] == "true"
            }
        }.count
        typeThroughSurvivalRate = total == 0 ? 0 : Double(typeThroughSurvivals) / Double(total)
        deletedFast = records.filter { $0.outcome == .deletedFast }.count
        evalCaseCount = SuggestionEpisodeEvalGenerator().cases(from: records).count

        let latencies = records.compactMap(\.model.latencyMilliseconds)
        averageLatencyMilliseconds = latencies.isEmpty ? nil : latencies.reduce(0, +) / latencies.count

        let keptScore = total == 0 ? 0 : Int((Double(kept) / Double(total) * 45).rounded())
        let acceptedScore = total == 0 ? 0 : Int((Double(accepted) / Double(total) * 25).rounded())
        let coverageScore = min(20, evalCaseCount * 2)
        let latencyScore: Int
        if let averageLatencyMilliseconds {
            latencyScore = averageLatencyMilliseconds <= 250 ? 10 : averageLatencyMilliseconds <= 750 ? 6 : 2
        } else {
            latencyScore = 0
        }
        score = min(100, keptScore + acceptedScore + coverageScore + latencyScore)

        let grouped = Dictionary(grouping: records) { record in
            "\(record.model.modelName)|\(record.model.promptVersion)"
        }
        modelPromptRows = grouped
            .map { key, records in
                let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                let model = parts.first ?? "unknown"
                let prompt = parts.dropFirst().first ?? "unknown"
                let kept = records.filter { $0.acceptedAndKeptScore >= 2 }.count
                return "\(model) / \(prompt): shown \(records.count), kept \(kept)"
            }
            .sorted()
    }

    public var markdown: String {
        let latency = averageLatencyMilliseconds.map { "\($0)ms" } ?? "n/a"
        let typeThroughRate = Self.percent(typeThroughSurvivalRate)
        let rows = modelPromptRows.isEmpty
            ? "- No model/prompt rows yet."
            : modelPromptRows.map { "- \($0)" }.joined(separator: "\n")
        return """
        # Suggestion Episode Scorecard

        - Score: \(score)/100
        - Episodes: \(total)
        - Shown: \(shown)
        - Accepted: \(accepted)
        - Kept: \(kept)
        - Ignored: \(ignored)
        - Dismissed: \(dismissed)
        - Typed past: \(typedPast)
        - Type-through survival rate: \(typeThroughRate) (\(typeThroughSurvivals)/\(total))
        - Deleted fast: \(deletedFast)
        - Eval cases: \(evalCaseCount)
        - Average latency: \(latency)

        ## Model / Prompt

        \(rows)

        """
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
