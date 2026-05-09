import Foundation

public struct TraceReplayLatencySlice: Equatable, Sendable {
    public let key: String
    public let count: Int
    public let p50Milliseconds: Int?
    public let p95Milliseconds: Int?

    public init(
        key: String,
        count: Int,
        p50Milliseconds: Int?,
        p95Milliseconds: Int?
    ) {
        self.key = key
        self.count = count
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
    }
}

public struct TraceReplayRequirement: Equatable, Sendable {
    public let name: String
    public let passed: Bool
    public let detail: String

    public init(name: String, passed: Bool, detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public enum AutocompleteTraceReplayProfile: String, CaseIterable, Equatable, Sendable {
    case full
    case smokeSlice = "smoke-slice"

    public static var cliValues: String {
        allCases.map(\.rawValue).joined(separator: "|")
    }
}

public struct AutocompleteTraceReplayReport: Equatable, Sendable {
    public let profile: AutocompleteTraceReplayProfile
    public let summary: AutocompleteTraceSummary
    public let triggerRequestCount: Int
    public let triggerDelayCoveredCount: Int
    public let displayScoreCandidateCount: Int
    public let displayScoreCoveredCount: Int
    public let candidateSelectionCandidateCount: Int
    public let candidateSelectionCoveredCount: Int
    public let proofFingerprintCandidateCount: Int
    public let proofFingerprintCoveredCount: Int
    public let placementCandidateCount: Int
    public let placementCoveredCount: Int
    public let trustedPlacementCount: Int
    public let acceptedCount: Int
    public let acceptedInsertionVerifiedCount: Int
    public let staleCancellationCount: Int
    public let keptHorizonEventCount: Int
    public let keptFinalHorizonEventCount: Int
    public let latencyByApp: [TraceReplayLatencySlice]
    public let latencyByMode: [TraceReplayLatencySlice]
    public let annoyanceSignalCounts: [String: Int]
    public let requirements: [TraceReplayRequirement]

    public var triggerDelayCoverageRate: Double {
        rate(triggerDelayCoveredCount, triggerRequestCount)
    }

    public var displayScoreCoverageRate: Double {
        rate(displayScoreCoveredCount, displayScoreCandidateCount)
    }

    public var candidateSelectionCoverageRate: Double {
        rate(candidateSelectionCoveredCount, candidateSelectionCandidateCount)
    }

    public var proofFingerprintCoverageRate: Double {
        rate(proofFingerprintCoveredCount, proofFingerprintCandidateCount)
    }

    public var placementCoverageRate: Double {
        rate(placementCoveredCount, placementCandidateCount)
    }

    public var acceptedInsertionCoverageRate: Double {
        rate(acceptedInsertionVerifiedCount, acceptedCount)
    }

    public var passesReplayProofGate: Bool {
        requirements.allSatisfy(\.passed)
    }

    public var markdown: String {
        var lines: [String] = [
            "# Autocomplete Trace Replay",
            "",
            "- profile: \(profile.rawValue)",
            "- events: \(summary.totalEvents)",
            "- presented: \(summary.presentedCount)",
            "- accepted-and-kept: \(summary.acceptedAndKeptCount)",
            "- trigger delay coverage: \(Self.percent(triggerDelayCoverageRate)) (\(triggerDelayCoveredCount)/\(triggerRequestCount))",
            "- display score coverage: \(Self.percent(displayScoreCoverageRate)) (\(displayScoreCoveredCount)/\(displayScoreCandidateCount))",
            "- candidate selection coverage: \(Self.percent(candidateSelectionCoverageRate)) (\(candidateSelectionCoveredCount)/\(candidateSelectionCandidateCount))",
            "- proof fingerprint coverage: \(Self.percent(proofFingerprintCoverageRate)) (\(proofFingerprintCoveredCount)/\(proofFingerprintCandidateCount))",
            "- placement coverage: \(Self.percent(placementCoverageRate)) (\(placementCoveredCount)/\(placementCandidateCount), trusted=\(trustedPlacementCount))",
            "- accepted insertion coverage: \(Self.percent(acceptedInsertionCoverageRate)) (\(acceptedInsertionVerifiedCount)/\(acceptedCount))",
            "- stale cancellations: \(staleCancellationCount)",
            "- kept horizon events: \(keptHorizonEventCount)",
            "- final kept horizon events: \(keptFinalHorizonEventCount)",
            "- annoyance score: \(Self.format(summary.annoyanceScore))",
            "",
            "## Requirements"
        ]

        lines += requirements.map { requirement in
            "- [\(requirement.passed ? "x" : " ")] \(requirement.name): \(requirement.detail)"
        }

        lines.append("")
        lines.append("## Latency By App")
        lines += latencyByApp.map(Self.sliceLine)

        lines.append("")
        lines.append("## Latency By Mode")
        lines += latencyByMode.map(Self.sliceLine)

        if !annoyanceSignalCounts.isEmpty {
            lines.append("")
            lines.append("## Annoyance Signals")
            lines += annoyanceSignalCounts
                .sorted { lhs, rhs in lhs.key < rhs.key }
                .map { "- \($0.key): \($0.value)" }
        }

        return lines.joined(separator: "\n")
    }

    private func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func sliceLine(_ slice: TraceReplayLatencySlice) -> String {
        "- \(slice.key): count=\(slice.count), p50=\(slice.p50Milliseconds.map(String.init) ?? "n/a")ms, p95=\(slice.p95Milliseconds.map(String.init) ?? "n/a")ms"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public struct AutocompleteTraceReplay: Sendable {
    public init() {}

    public func report(
        for events: [AutocompleteTraceEvent],
        profile: AutocompleteTraceReplayProfile = .full
    ) -> AutocompleteTraceReplayReport {
        let summary = AutocompleteTraceAnalyzer().summary(for: events)
        let requests = events.filter { $0.type == .suggestionRequested }
        let triggerDelayCoveredCount = requests.filter(hasResearchedTriggerDelay).count
        let displayCandidates = displayScoreCandidateEvents(in: events)
        let displayCovered = displayCandidates.filter(hasDisplayScoreMetadata)
        let candidateSelectionCandidates = candidateSelectionCandidateEvents(in: events)
        let candidateSelectionCovered = candidateSelectionCandidates.filter(hasCandidateSelectionMetadata)
        let proofFingerprintCandidates = proofFingerprintCandidateEvents(in: events)
        let proofFingerprintCovered = proofFingerprintCandidates.filter {
            AutocompleteTraceProofMetadata.isCurrent($0.metadata)
        }
        let presentedEvents = events.filter { $0.type == .suggestionPresented }
        let placementCovered = presentedEvents.filter(hasPlacementMetadata)
        let trustedPlacementCount = presentedEvents.filter(hasTrustedPlacement).count
        let acceptedEvents = events.filter { $0.type == .suggestionAccepted }
        let insertionVerifiedEvents = events.filter { $0.type == .insertionVerified }
        let acceptedInsertionVerifiedCount = acceptedInsertionVerifiedCount(
            acceptedEvents: acceptedEvents,
            insertionVerifiedEvents: insertionVerifiedEvents
        )
        let acceptedTextEdited = events.filter { $0.type == .acceptedTextEdited }
        let finalHorizonEvents = acceptedTextEdited.filter(isFinalKeptHorizonEvent)
        let staleCancellations = events.filter(isStaleCancellation)
        let latencyByApp = latencySlices(
            events.filter { $0.type == .suggestionPresented },
            key: \.appBundleIdentifier
        )
        let latencyByMode = latencySlices(
            events.filter { $0.type == .suggestionPresented },
            key: \.requestMode
        )

        var requirements = [
            TraceReplayRequirement(
                name: "trace events loaded",
                passed: !events.isEmpty,
                detail: "\(events.count) events"
            ),
            TraceReplayRequirement(
                name: "trigger policy replay",
                passed: !requests.isEmpty && triggerDelayCoveredCount == requests.count,
                detail: "\(triggerDelayCoveredCount)/\(requests.count) request delays in researched ranges"
            ),
            TraceReplayRequirement(
                name: "display scoring replay",
                passed: !displayCandidates.isEmpty && displayCovered.count == displayCandidates.count,
                detail: "\(displayCovered.count)/\(displayCandidates.count) display candidates include score metadata"
            ),
            TraceReplayRequirement(
                name: "proof fingerprint freshness",
                passed: !proofFingerprintCandidates.isEmpty
                    && proofFingerprintCovered.count == proofFingerprintCandidates.count,
                detail: "\(proofFingerprintCovered.count)/\(proofFingerprintCandidates.count) proof events match \(AutocompleteTraceProofMetadata.traceProofVersion)"
            ),
            TraceReplayRequirement(
                name: "placement replay",
                passed: !presentedEvents.isEmpty
                    && placementCovered.count == presentedEvents.count
                    && trustedPlacementCount > 0,
                detail: "\(placementCovered.count)/\(presentedEvents.count) presented events include placement metadata, \(trustedPlacementCount) trusted"
            ),
            TraceReplayRequirement(
                name: "accepted insertion replay",
                passed: !acceptedEvents.isEmpty && acceptedInsertionVerifiedCount == acceptedEvents.count,
                detail: "\(acceptedInsertionVerifiedCount)/\(acceptedEvents.count) accepted suggestions have insertion verification"
            )
        ]

        requirements += profileRequirements(
            profile: profile,
            candidateSelectionCandidates: candidateSelectionCandidates,
            candidateSelectionCoveredCount: candidateSelectionCovered.count,
            staleCancellationCount: staleCancellations.count,
            acceptedTextEditedCount: acceptedTextEdited.count,
            finalHorizonEventCount: finalHorizonEvents.count,
            annoyanceSignalCount: summary.annoyanceSignalCounts.values.reduce(0, +)
        )

        requirements += [
            TraceReplayRequirement(
                name: "latency slices",
                passed: !latencyByApp.isEmpty && !latencyByMode.isEmpty,
                detail: "\(latencyByApp.count) app slices, \(latencyByMode.count) mode slices"
            ),
            TraceReplayRequirement(
                name: "redacted trace compatible",
                passed: true,
                detail: "uses event types, metadata, ids, timestamps, and latencies; raw text is optional"
            )
        ]

        return AutocompleteTraceReplayReport(
            profile: profile,
            summary: summary,
            triggerRequestCount: requests.count,
            triggerDelayCoveredCount: triggerDelayCoveredCount,
            displayScoreCandidateCount: displayCandidates.count,
            displayScoreCoveredCount: displayCovered.count,
            candidateSelectionCandidateCount: candidateSelectionCandidates.count,
            candidateSelectionCoveredCount: candidateSelectionCovered.count,
            proofFingerprintCandidateCount: proofFingerprintCandidates.count,
            proofFingerprintCoveredCount: proofFingerprintCovered.count,
            placementCandidateCount: presentedEvents.count,
            placementCoveredCount: placementCovered.count,
            trustedPlacementCount: trustedPlacementCount,
            acceptedCount: acceptedEvents.count,
            acceptedInsertionVerifiedCount: acceptedInsertionVerifiedCount,
            staleCancellationCount: staleCancellations.count,
            keptHorizonEventCount: acceptedTextEdited.count,
            keptFinalHorizonEventCount: finalHorizonEvents.count,
            latencyByApp: latencyByApp,
            latencyByMode: latencyByMode,
            annoyanceSignalCounts: summary.annoyanceSignalCounts,
            requirements: requirements
        )
    }

    private func profileRequirements(
        profile: AutocompleteTraceReplayProfile,
        candidateSelectionCandidates: [AutocompleteTraceEvent],
        candidateSelectionCoveredCount: Int,
        staleCancellationCount: Int,
        acceptedTextEditedCount: Int,
        finalHorizonEventCount: Int,
        annoyanceSignalCount: Int
    ) -> [TraceReplayRequirement] {
        switch profile {
        case .full:
            return [
                TraceReplayRequirement(
                    name: "candidate selection replay",
                    passed: !candidateSelectionCandidates.isEmpty
                        && candidateSelectionCoveredCount == candidateSelectionCandidates.count,
                    detail: "\(candidateSelectionCoveredCount)/\(candidateSelectionCandidates.count) candidate events include selection metadata"
                ),
                TraceReplayRequirement(
                    name: "stale cancellation replay",
                    passed: staleCancellationCount > 0,
                    detail: "\(staleCancellationCount) stale focus selection or request cancellations"
                ),
                TraceReplayRequirement(
                    name: "kept horizon replay",
                    passed: acceptedTextEditedCount > 0 && finalHorizonEventCount > 0,
                    detail: "\(acceptedTextEditedCount) survival events, \(finalHorizonEventCount) final horizon events"
                ),
                TraceReplayRequirement(
                    name: "annoyance replay",
                    passed: annoyanceSignalCount > 0,
                    detail: "\(annoyanceSignalCount) annoyance signals"
                )
            ]
        case .smokeSlice:
            let candidateSelectionPassed = candidateSelectionCandidates.isEmpty
                || candidateSelectionCoveredCount == candidateSelectionCandidates.count
            let candidateSelectionDetail = candidateSelectionCandidates.isEmpty
                ? "not required for smoke-slice; 0 candidate events in bounded local completion slice"
                : "\(candidateSelectionCoveredCount)/\(candidateSelectionCandidates.count) candidate events include selection metadata"

            return [
                TraceReplayRequirement(
                    name: "candidate selection replay",
                    passed: candidateSelectionPassed,
                    detail: candidateSelectionDetail
                ),
                TraceReplayRequirement(
                    name: "stale cancellation replay",
                    passed: true,
                    detail: "not required for smoke-slice; \(staleCancellationCount) stale cancellations observed"
                ),
                TraceReplayRequirement(
                    name: "kept horizon replay",
                    passed: acceptedTextEditedCount > 0,
                    detail: "\(acceptedTextEditedCount) short-horizon survival events; final horizon is full-profile only"
                ),
                TraceReplayRequirement(
                    name: "annoyance replay",
                    passed: true,
                    detail: "not required for smoke-slice; \(annoyanceSignalCount) annoyance signals observed"
                )
            ]
        }
    }

    private func displayScoreCandidateEvents(in events: [AutocompleteTraceEvent]) -> [AutocompleteTraceEvent] {
        events.filter { event in
            if event.type == .suggestionPresented {
                return true
            }

            guard event.type == .suggestionSuppressed else {
                return false
            }

            return event.metadata["displayScoreDecision"] != nil
                || event.metadata["displayScoreFinal"] != nil
                || event.reason.hasPrefix("high-")
                || event.reason == "below-threshold"
        }
    }

    private func hasDisplayScoreMetadata(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["displayScoreDecision"] != nil
            && event.metadata["displayScoreFinal"] != nil
            && event.metadata["displayScoreUtility"] != nil
            && event.metadata["displayScoreRisk"] != nil
            && event.metadata["displayScoreAcceptedAndKeptProbability"] != nil
            && event.metadata["displayScoreAcceptedAndKeptSamples"] != nil
    }

    private func candidateSelectionCandidateEvents(in events: [AutocompleteTraceEvent]) -> [AutocompleteTraceEvent] {
        events.filter { event in
            if event.type == .modelResult {
                return true
            }

            return event.type == .suggestionPresented
                && event.metadata["candidateSelectionSource"] == "fast-word-completion"
        }
    }

    private func hasCandidateSelectionMetadata(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["cleanedCandidateCount"] != nil
            && event.metadata["candidateTopScore"] != nil
            && event.metadata["candidateScoreMargin"] != nil
            && event.metadata["candidateSuppressionReason"] != nil
    }

    private func proofFingerprintCandidateEvents(in events: [AutocompleteTraceEvent]) -> [AutocompleteTraceEvent] {
        events.filter { event in
            switch event.type {
            case .suggestionRequested,
                    .modelResult,
                    .suggestionPresented,
                    .suggestionHidden,
                    .suggestionAccepted,
                    .suggestionSuppressed,
                    .insertionVerified,
                    .insertionFailed,
                    .acceptedInsertionUndone,
                    .acceptedTextEdited,
                    .caretGeometryFailed:
                return true
            case .suggestionTypedOver,
                    .acceptanceRetentionCleared,
                    .appPaused,
                    .fieldPaused,
                    .appDisabled,
                    .renderModeChanged:
                return false
            }
        }
    }

    private func hasPlacementMetadata(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["placementAnchorSource"] != nil
            && event.metadata["placementConfidenceBand"] != nil
            && event.metadata["hasCaretRect"] != nil
    }

    private func hasTrustedPlacement(_ event: AutocompleteTraceEvent) -> Bool {
        guard hasPlacementMetadata(event) else {
            return false
        }

        let anchor = event.metadata["placementAnchorSource"] ?? ""
        let confidence = event.metadata["placementConfidenceBand"] ?? ""
        let hasCaretRect = event.metadata["hasCaretRect"] ?? "false"

        return hasCaretRect == "true"
            && (
                (anchor == "caret" && confidence == "high")
                    || (anchor == "synthetic-caret" && confidence == "medium")
            )
    }

    private func acceptedInsertionVerifiedCount(
        acceptedEvents: [AutocompleteTraceEvent],
        insertionVerifiedEvents: [AutocompleteTraceEvent]
    ) -> Int {
        acceptedEvents.filter { accepted in
            insertionVerifiedEvents.contains { verification in
                hasSameAcceptanceProof(accepted, verification)
            }
        }.count
    }

    private func hasSameAcceptanceProof(
        _ accepted: AutocompleteTraceEvent,
        _ verification: AutocompleteTraceEvent
    ) -> Bool {
        if let acceptedID = accepted.metadata["acceptanceID"],
           let verifiedID = verification.metadata["acceptanceID"],
           !acceptedID.isEmpty || !verifiedID.isEmpty {
            return acceptedID == verifiedID
        }

        return !accepted.suggestionID.isEmpty && accepted.suggestionID == verification.suggestionID
    }

    private func hasResearchedTriggerDelay(_ event: AutocompleteTraceEvent) -> Bool {
        guard let delay = intMetadata(event, key: "delayMilliseconds") else {
            return false
        }

        switch event.requestMode {
        case CompletionRequestMode.wordCompletion.rawValue:
            return (90...140).contains(delay)
        case CompletionRequestMode.sentenceContinuation.rawValue:
            return (280...450).contains(delay)
        case CompletionRequestMode.phraseContinuation.rawValue:
            return (140...240).contains(delay)
        default:
            return delay >= 90 && delay <= 450
        }
    }

    private func isFinalKeptHorizonEvent(_ event: AutocompleteTraceEvent) -> Bool {
        guard event.type == .acceptedTextEdited else {
            return false
        }

        return event.metadata["checkpoint"] == AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue
            || event.metadata["finishReason"] == "thirty-second-finalized"
            || event.metadata["finishReason"] == "field-blur-finalized"
            || event.metadata["checkpoint"] == AcceptanceSurvivalCheckpoint.fieldSend.rawValue
    }

    private func isStaleCancellation(_ event: AutocompleteTraceEvent) -> Bool {
        guard event.type == .suggestionSuppressed || event.type == .suggestionHidden else {
            return false
        }

        return event.reason.contains("stale")
            || event.reason.contains("focus-changed")
            || event.reason.contains("selection")
    }

    private func latencySlices(
        _ events: [AutocompleteTraceEvent],
        key: (AutocompleteTraceEvent) -> String
    ) -> [TraceReplayLatencySlice] {
        Dictionary(grouping: events) { event in
            let value = key(event)
            return value.isEmpty ? "unknown" : value
        }
        .map { item in
            let latencies = item.value.compactMap(\.latencyMilliseconds).sorted()
            return TraceReplayLatencySlice(
                key: item.key,
                count: item.value.count,
                p50Milliseconds: percentile(0.50, in: latencies),
                p95Milliseconds: percentile(0.95, in: latencies)
            )
        }
        .sorted { lhs, rhs in lhs.key < rhs.key }
    }

    private func percentile(_ percentile: Double, in values: [Int]) -> Int? {
        guard !values.isEmpty else {
            return nil
        }

        let index = Int((Double(values.count - 1) * percentile).rounded())
        return values[max(0, min(values.count - 1, index))]
    }

    private func intMetadata(_ event: AutocompleteTraceEvent, key: String) -> Int? {
        guard let value = event.metadata[key] else {
            return nil
        }

        return Int(value)
    }
}
