import Foundation

public struct AutocompleteExperimentPhase: Equatable, Sendable {
    public let index: Int
    public let arm: AutocompleteExperimentArm
    public let label: String

    public init(index: Int, arm: AutocompleteExperimentArm, label: String) {
        self.index = index
        self.arm = arm
        self.label = label
    }
}

public struct AutocompleteWithinUserCrossoverPlan: Equatable, Sendable {
    public let testerIdentifier: String
    public let counterbalanceBucket: Int
    public let phases: [AutocompleteExperimentPhase]

    public init(
        testerIdentifier: String,
        counterbalanceBucket: Int,
        phases: [AutocompleteExperimentPhase]
    ) {
        self.testerIdentifier = testerIdentifier
        self.counterbalanceBucket = counterbalanceBucket
        self.phases = phases
    }

    public var armOrder: [AutocompleteExperimentArm] {
        phases.map(\.arm)
    }
}

public enum AutocompleteExperimentResultLabel: String, Equatable, Sendable {
    case noSignal = "no-signal"
    case directional = "directional"
    case guardrailBlocked = "guardrail-blocked"
    case candidate = "candidate"

    public var treatsAsWinner: Bool {
        self == .candidate
    }
}

public struct AutocompleteExperimentGuardrailThresholds: Equatable, Sendable {
    public let minimumShownSamples: Int
    public let maximumAnnoyanceScore: Double
    public let maximumP95LatencyMilliseconds: Int
    public let minimumInsertionSuccessRate: Double
    public let maximumDuplicateRate: Double
    public let maximumAppDisableRate: Double

    public init(
        minimumShownSamples: Int = 20,
        maximumAnnoyanceScore: Double = 0.20,
        maximumP95LatencyMilliseconds: Int = 1_000,
        minimumInsertionSuccessRate: Double = 0.95,
        maximumDuplicateRate: Double = 0,
        maximumAppDisableRate: Double = 0.02
    ) {
        self.minimumShownSamples = max(1, minimumShownSamples)
        self.maximumAnnoyanceScore = maximumAnnoyanceScore
        self.maximumP95LatencyMilliseconds = maximumP95LatencyMilliseconds
        self.minimumInsertionSuccessRate = minimumInsertionSuccessRate
        self.maximumDuplicateRate = maximumDuplicateRate
        self.maximumAppDisableRate = maximumAppDisableRate
    }
}

public struct AutocompleteExperimentGuardrailReport: Equatable, Sendable {
    public let passed: Bool
    public let reasons: [String]

    public init(passed: Bool, reasons: [String]) {
        self.passed = passed
        self.reasons = reasons
    }
}

public struct AutocompleteExperimentArmOutcome: Equatable, Sendable {
    public let arm: String
    public let shown: Int
    public let acceptedAndKept: Int
    public let acceptedAndKeptShownRate: Double
    public let p95LatencyMilliseconds: Int?
    public let annoyanceScore: Double
    public let insertionSuccessRate: Double
    public let duplicateRate: Double
    public let appDisableRate: Double
    public let guardrails: AutocompleteExperimentGuardrailReport
    public let label: AutocompleteExperimentResultLabel

    public init(
        arm: String,
        shown: Int,
        acceptedAndKept: Int,
        acceptedAndKeptShownRate: Double,
        p95LatencyMilliseconds: Int?,
        annoyanceScore: Double,
        insertionSuccessRate: Double,
        duplicateRate: Double,
        appDisableRate: Double,
        guardrails: AutocompleteExperimentGuardrailReport,
        label: AutocompleteExperimentResultLabel
    ) {
        self.arm = arm
        self.shown = shown
        self.acceptedAndKept = acceptedAndKept
        self.acceptedAndKeptShownRate = acceptedAndKeptShownRate
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.annoyanceScore = annoyanceScore
        self.insertionSuccessRate = insertionSuccessRate
        self.duplicateRate = duplicateRate
        self.appDisableRate = appDisableRate
        self.guardrails = guardrails
        self.label = label
    }
}

public enum AutocompleteExperimentPlanner {
    public static func counterbalancedOrder(
        testerIdentifier: String,
        arms: [AutocompleteExperimentArm] = [.length1Word, .length3Word]
    ) -> [AutocompleteExperimentArm] {
        guard arms.count > 1 else {
            return arms
        }

        let bucket = stableBucket(for: testerIdentifier, bucketCount: arms.count)
        return Array(arms[bucket...]) + Array(arms[..<bucket])
    }

    public static func withinUserCrossoverPlan(
        testerIdentifier: String,
        sessionsPerArm: Int = 1,
        arms: [AutocompleteExperimentArm] = [.length1Word, .length3Word]
    ) -> AutocompleteWithinUserCrossoverPlan {
        let order = counterbalancedOrder(testerIdentifier: testerIdentifier, arms: arms)
        let repeats = max(1, sessionsPerArm)
        let phases = (0..<repeats).flatMap { repeatIndex in
            order.enumerated().map { offset, arm in
                let index = repeatIndex * order.count + offset + 1
                return AutocompleteExperimentPhase(
                    index: index,
                    arm: arm,
                    label: "session-\(index)-\(arm.rawValue)"
                )
            }
        }

        return AutocompleteWithinUserCrossoverPlan(
            testerIdentifier: testerIdentifier,
            counterbalanceBucket: stableBucket(for: testerIdentifier, bucketCount: max(1, arms.count)),
            phases: phases
        )
    }

    public static func outcomes(
        for events: [AutocompleteTraceEvent],
        thresholds: AutocompleteExperimentGuardrailThresholds = AutocompleteExperimentGuardrailThresholds()
    ) -> [AutocompleteExperimentArmOutcome] {
        let arms = Set(events.map(experimentArm)).filter { !$0.isEmpty }.sorted()
        return arms.map { arm in
            outcome(forArm: arm, events: events.filter { experimentArm($0) == arm }, thresholds: thresholds)
        }
    }

    private static func outcome(
        forArm arm: String,
        events: [AutocompleteTraceEvent],
        thresholds: AutocompleteExperimentGuardrailThresholds
    ) -> AutocompleteExperimentArmOutcome {
        let presentedByID = firstEventsBySuggestionID(
            from: events.filter { $0.type == .suggestionPresented }
        )
        let shown = presentedByID.count
        let acceptedAndKept = Set(events
            .filter { $0.type == .acceptedTextEdited && $0.isAcceptedAndKeptSignal }
            .map(\.acceptanceIdentifier))
            .count
        let shownRate = shown == 0 ? 0 : Double(acceptedAndKept) / Double(shown)
        let latencies = presentedByID.values.compactMap(\.latencyMilliseconds).sorted()
        let insertionVerified = events.filter { $0.type == .insertionVerified }.count
        let insertionFailed = events.filter { $0.type == .insertionFailed }
        let insertionAttempts = insertionVerified + insertionFailed.count
        let insertionSuccess = insertionAttempts == 0
            ? 0
            : Double(insertionVerified) / Double(insertionAttempts)
        let duplicateCount = insertionFailed.filter(\.isDuplicateInsertionSignal).count
        let duplicateRate = shown == 0 ? 0 : Double(duplicateCount) / Double(shown)
        let appDisableRate = shown == 0
            ? 0
            : Double(events.filter { $0.type == .appDisabled }.count) / Double(shown)
        let annoyance = AutocompleteTraceAnalyzer().summary(for: events).annoyanceScore
        let p95 = percentile(0.95, in: latencies)
        let guardrails = guardrailReport(
            shown: shown,
            p95LatencyMilliseconds: p95,
            annoyanceScore: annoyance,
            insertionSuccessRate: insertionSuccess,
            insertionAttempts: insertionAttempts,
            duplicateRate: duplicateRate,
            appDisableRate: appDisableRate,
            thresholds: thresholds
        )
        let label: AutocompleteExperimentResultLabel
        if shown == 0 {
            label = .noSignal
        } else if shown < thresholds.minimumShownSamples {
            label = .directional
        } else if !guardrails.passed {
            label = .guardrailBlocked
        } else {
            label = .candidate
        }

        return AutocompleteExperimentArmOutcome(
            arm: arm,
            shown: shown,
            acceptedAndKept: acceptedAndKept,
            acceptedAndKeptShownRate: shownRate,
            p95LatencyMilliseconds: p95,
            annoyanceScore: annoyance,
            insertionSuccessRate: insertionSuccess,
            duplicateRate: duplicateRate,
            appDisableRate: appDisableRate,
            guardrails: guardrails,
            label: label
        )
    }

    private static func guardrailReport(
        shown: Int,
        p95LatencyMilliseconds: Int?,
        annoyanceScore: Double,
        insertionSuccessRate: Double,
        insertionAttempts: Int,
        duplicateRate: Double,
        appDisableRate: Double,
        thresholds: AutocompleteExperimentGuardrailThresholds
    ) -> AutocompleteExperimentGuardrailReport {
        var reasons: [String] = []

        if shown < thresholds.minimumShownSamples {
            reasons.append("sample is below \(thresholds.minimumShownSamples); treat as directional")
        }
        if let p95LatencyMilliseconds,
           p95LatencyMilliseconds > thresholds.maximumP95LatencyMilliseconds {
            reasons.append("p95 first-visible latency is above \(thresholds.maximumP95LatencyMilliseconds)ms")
        }
        if annoyanceScore > thresholds.maximumAnnoyanceScore {
            reasons.append("annoyance score is above \(thresholds.maximumAnnoyanceScore)")
        }
        if insertionAttempts > 0 && insertionSuccessRate < thresholds.minimumInsertionSuccessRate {
            reasons.append("insertion success is below \(thresholds.minimumInsertionSuccessRate)")
        }
        if duplicateRate > thresholds.maximumDuplicateRate {
            reasons.append("duplicate rate is above \(thresholds.maximumDuplicateRate)")
        }
        if appDisableRate > thresholds.maximumAppDisableRate {
            reasons.append("app disable rate is above \(thresholds.maximumAppDisableRate)")
        }

        let hardFailures = reasons.filter { !$0.contains("sample is below") }
        return AutocompleteExperimentGuardrailReport(
            passed: hardFailures.isEmpty,
            reasons: reasons
        )
    }

    private static func firstEventsBySuggestionID(
        from events: [AutocompleteTraceEvent]
    ) -> [String: AutocompleteTraceEvent] {
        var eventsByID: [String: AutocompleteTraceEvent] = [:]
        for event in events where !event.suggestionID.isEmpty && eventsByID[event.suggestionID] == nil {
            eventsByID[event.suggestionID] = event
        }
        return eventsByID
    }

    private static func experimentArm(_ event: AutocompleteTraceEvent) -> String {
        let arm = event.experimentArm.isEmpty ? event.metadata["experimentArm"] ?? "" : event.experimentArm
        return arm.isEmpty ? "unknown" : arm
    }

    private static func percentile(_ fraction: Double, in values: [Int]) -> Int? {
        guard !values.isEmpty else {
            return nil
        }

        let index = min(values.count - 1, Int((Double(values.count - 1) * fraction).rounded()))
        return values[index]
    }

    private static func stableBucket(for value: String, bucketCount: Int) -> Int {
        guard bucketCount > 0 else {
            return 0
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in value.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(bucketCount))
    }
}
