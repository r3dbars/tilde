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

public struct AutocompleteTraceReplayReport: Equatable, Sendable {
    public let summary: AutocompleteTraceSummary
    public let triggerRequestCount: Int
    public let triggerDelayCoveredCount: Int
    public let displayScoreCandidateCount: Int
    public let displayScoreCoveredCount: Int
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

    public var passesReplayProofGate: Bool {
        requirements.allSatisfy(\.passed)
    }

    public var markdown: String {
        var lines: [String] = [
            "# Autocomplete Trace Replay",
            "",
            "- events: \(summary.totalEvents)",
            "- presented: \(summary.presentedCount)",
            "- accepted-and-kept: \(summary.acceptedAndKeptCount)",
            "- trigger delay coverage: \(Self.percent(triggerDelayCoverageRate)) (\(triggerDelayCoveredCount)/\(triggerRequestCount))",
            "- display score coverage: \(Self.percent(displayScoreCoverageRate)) (\(displayScoreCoveredCount)/\(displayScoreCandidateCount))",
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

    public func report(for events: [AutocompleteTraceEvent]) -> AutocompleteTraceReplayReport {
        let summary = AutocompleteTraceAnalyzer().summary(for: events)
        let requests = events.filter { $0.type == .suggestionRequested }
        let triggerDelayCoveredCount = requests.filter(hasResearchedTriggerDelay).count
        let displayCandidates = displayScoreCandidateEvents(in: events)
        let displayCovered = displayCandidates.filter(hasDisplayScoreMetadata)
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

        let requirements = [
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
                name: "kept horizon replay",
                passed: !acceptedTextEdited.isEmpty && !finalHorizonEvents.isEmpty,
                detail: "\(acceptedTextEdited.count) survival events, \(finalHorizonEvents.count) final horizon events"
            ),
            TraceReplayRequirement(
                name: "latency slices",
                passed: !latencyByApp.isEmpty && !latencyByMode.isEmpty,
                detail: "\(latencyByApp.count) app slices, \(latencyByMode.count) mode slices"
            ),
            TraceReplayRequirement(
                name: "annoyance replay",
                passed: summary.presentedCount > 0 || !summary.annoyanceSignalCounts.isEmpty,
                detail: "\(summary.annoyanceSignalCounts.values.reduce(0, +)) annoyance signals"
            ),
            TraceReplayRequirement(
                name: "redacted trace compatible",
                passed: true,
                detail: "uses event types, metadata, ids, timestamps, and latencies; raw text is optional"
            )
        ]

        return AutocompleteTraceReplayReport(
            summary: summary,
            triggerRequestCount: requests.count,
            triggerDelayCoveredCount: triggerDelayCoveredCount,
            displayScoreCandidateCount: displayCandidates.count,
            displayScoreCoveredCount: displayCovered.count,
            staleCancellationCount: staleCancellations.count,
            keptHorizonEventCount: acceptedTextEdited.count,
            keptFinalHorizonEventCount: finalHorizonEvents.count,
            latencyByApp: latencyByApp,
            latencyByMode: latencyByMode,
            annoyanceSignalCounts: summary.annoyanceSignalCounts,
            requirements: requirements
        )
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
    }

    private func hasResearchedTriggerDelay(_ event: AutocompleteTraceEvent) -> Bool {
        guard let delay = intMetadata(event, key: "delayMilliseconds") else {
            return false
        }

        switch event.requestMode {
        case CompletionRequestMode.wordCompletion.rawValue:
            return (90...140).contains(delay)
        case CompletionRequestMode.phraseContinuation.rawValue:
            return (140...450).contains(delay)
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
