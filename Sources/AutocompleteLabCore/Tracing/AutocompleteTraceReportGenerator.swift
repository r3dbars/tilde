import Foundation

public struct AutocompleteTraceReportGenerator: Equatable, Sendable {
    public init() {}

    public func redactedJSONL(
        for events: [AutocompleteTraceEvent],
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> String {
        try redactedEvents(events)
            .map { event in
                let data = try encoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            }
            .joined(separator: "\n")
            .appending(events.isEmpty ? "" : "\n")
    }

    public func redactedSurvivalEvents(
        for events: [AutocompleteTraceEvent]
    ) -> [AutocompleteTraceEvent] {
        redactedEvents(events)
            .filter {
                $0.type == .suggestionAccepted
                    || $0.type == .acceptedTextEdited
                    || $0.type == .acceptanceRetentionCleared
            }
    }

    public func redactedSurvivalJSONData(
        for events: [AutocompleteTraceEvent],
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        try encoder.encode(redactedSurvivalEvents(for: events))
    }

    public func debugSurvivalInspectorJSONData(
        for events: [AutocompleteTraceEvent],
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        let survivalEvents = events.filter {
            $0.type == .suggestionAccepted
                || $0.type == .acceptedTextEdited
                || $0.type == .acceptanceRetentionCleared
        }
        return try encoder.encode(survivalEvents)
    }

    public func htmlReport(
        summary _: AutocompleteTraceSummary,
        events: [AutocompleteTraceEvent]
    ) -> String {
        let redacted = redactedEvents(events)
        let safeSummary = AutocompleteTraceAnalyzer().summary(for: redacted)
        return htmlReport(forRedactedEvents: redacted, summary: safeSummary)
    }

    public func htmlReport(for events: [AutocompleteTraceEvent]) -> String {
        let redacted = redactedEvents(events)
        return htmlReport(
            forRedactedEvents: redacted,
            summary: AutocompleteTraceAnalyzer().summary(for: redacted)
        )
    }

    public func visualCalibrationReport(for events: [AutocompleteTraceEvent]) -> String {
        let redacted = redactedEvents(events)
        let rows = visualCalibrationRows(from: redacted)
        let body = rows.isEmpty
            ? "none yet"
            : rows.map { row in
                let rate = percent(row.caretFailureRate)
                let offset = row.latestOffset ?? "none"
                return "\(row.appBundleIdentifier) / \(row.renderMode): shown=\(row.shown) caretFailures=\(row.caretFailures) failureRate=\(rate) missingCaret=\(row.missingCaretRectPresentations) flicker=\(row.flickerCount) learningApplied=\(row.learningAppliedCount) latestOffset=\(offset)"
            }.joined(separator: "\n")

        return """
        Visual calibration report (no screenshots required)
        Screenshots are not read or linked. This uses redacted trace geometry only.
        \(body)
        """
    }

    private func htmlReport(
        forRedactedEvents events: [AutocompleteTraceEvent],
        summary: AutocompleteTraceSummary
    ) -> String {
        let rows = events.suffix(200).reversed().map { event in
            """
            <tr>
              <td>\(escape(event.timestamp))</td>
              <td>\(escape(event.type.rawValue))</td>
              <td>\(escape(event.experimentArm))</td>
              <td>\(escape(event.requestMode))</td>
              <td>\(escape(event.appBundleIdentifier))</td>
              <td>\(escape(event.reason))</td>
              <td>\(event.latencyMilliseconds.map(String.init) ?? "")</td>
              <td>\(escape(event.metadata["displayedTextChars"] ?? ""))</td>
              <td>\(escape(event.metadata["acceptedTextChars"] ?? ""))</td>
              <td>\(escape(event.metadata["screenshotCaptured"] ?? "false"))</td>
            </tr>
            """
        }.joined(separator: "\n")

        let supportStates = CompatibilitySupportEvaluator()
            .evaluations(for: events)
            .map { evaluation in
                "<tr><td><code>\(escape(evaluation.bundleIdentifier))</code></td><td>\(escape(evaluation.state.rawValue))</td><td>\(evaluation.presentedCount)</td><td>\(percent(evaluation.acceptedAndKeptShownRate))</td><td>\(percent(evaluation.insertionVerificationSuccessRate))</td><td>\(evaluation.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</td><td>\(String(format: "%.2f", evaluation.annoyanceScore))</td></tr>"
            }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Autocomplete Lab Redacted Trace Report</title>
          <style>
            body { font: 14px -apple-system, BlinkMacSystemFont, sans-serif; margin: 28px; color: #1d1d1f; }
            h1 { font-size: 24px; }
            .grid { display: grid; grid-template-columns: repeat(5, minmax(120px, 1fr)); gap: 10px; margin: 18px 0; }
            .metric { border: 1px solid #ddd; border-radius: 6px; padding: 10px; }
            .metric b { display: block; font-size: 22px; }
            table { width: 100%; border-collapse: collapse; margin-top: 18px; }
            th, td { border-bottom: 1px solid #e5e5e5; text-align: left; padding: 7px; vertical-align: top; }
            th { background: #f7f7f7; position: sticky; top: 0; }
            code { background: #f5f5f5; padding: 1px 4px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <h1>Autocomplete Lab Redacted Trace Report</h1>
          <p>Generated locally from the default redacted trace. Nothing was uploaded.</p>
          <div class="grid">
            <div class="metric"><b>\(summary.totalEvents)</b>events</div>
            <div class="metric"><b>\(summary.presentedCount)</b>shown</div>
            <div class="metric"><b>\(summary.acceptedAndKeptCount)</b>accepted kept</div>
            <div class="metric"><b>\(percent(summary.acceptedAndKeptRateShown))</b>kept / shown</div>
            <div class="metric"><b>\(percent(summary.acceptedAndKeptRateAccepted))</b>kept / accepted</div>
            <div class="metric"><b>\(summary.acceptedCount)</b>accepted</div>
            <div class="metric"><b>\(summary.acceptanceRetentionClearedCount)</b>retention cleared</div>
            <div class="metric"><b>\(summary.suppressedCount)</b>suppressed</div>
            <div class="metric"><b>\(percent(summary.acceptRate))</b>accept rate</div>
            <div class="metric"><b>\(percent(summary.usefulRate))</b>useful rate</div>
            <div class="metric"><b>\(percent(summary.tabAcceptShare))</b>Tab accept share</div>
            <div class="metric"><b>\(percent(summary.insertionVerificationSuccessRate))</b>verified inserts</div>
            <div class="metric"><b>\(percent(summary.caretGeometryFailureRate))</b>caret failure rate</div>
            <div class="metric"><b>\(String(format: "%.2f", summary.annoyanceScore))</b>annoyance score</div>
            <div class="metric"><b>\(summary.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</b>first-visible p95</div>
            <div class="metric"><b>\(summary.doNotShipCounters.values.reduce(0, +))</b>do-not-ship</div>
          </div>
          <h2>RAM-only retention proof</h2>
          <p>Accepted text is kept only for checkpoint comparison. The durable proof is the redacted <code>acceptanceRetentionCleared</code> event with counts and fingerprints, not raw text.</p>
          <ul>\(sortedCountList(summary.acceptanceRetentionClearedByReason))</ul>
          <h2>Privacy checklist</h2>
          <ul>
            <li>This report is generated locally from the default redacted trace.</li>
            <li>Typed text, accepted text, screenshots, screenshot paths, document names, URLs, recipients, and subject lines are not included.</li>
            <li>Share only this redacted report for normal beta feedback.</li>
            <li>Use raw debug exports only for explicit local debugging sessions.</li>
          </ul>
          <h2>Accepted-and-kept survival slices</h2>
          <h3>By app</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByApp))</ul>
          <h3>By field kind</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByFieldKind))</ul>
          <h3>By render mode</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByRenderMode))</ul>
          <h3>By insertion mode</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByInsertionMode))</ul>
          <h3>By request mode</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByRequestMode))</ul>
          <h3>By model</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByModel))</ul>
          <h3>By experiment arm</h3><ul>\(sortedRateList(summary.acceptedAndKeptRateByExperimentArm))</ul>
          <h2>Visual calibration, no screenshots</h2>
          <p>This section uses redacted caret and panel metadata only. Screenshot paths are not included.</p>
          \(visualCalibrationHTMLTable(from: events))
          <h2>Do-not-ship blockers</h2>
          <p>These are hard trust failures. A beta proof run should keep every counter at zero.</p>
          <ul>\(sortedCountList(summary.doNotShipCounters))</ul>
          <h2>Recommended next fix</h2>
          <ol>\(recommendedFixList(summary.recommendedFixes))</ol>
          <h2>Support state by app</h2>
          <table>
            <thead><tr><th>App</th><th>State</th><th>Shown</th><th>Kept</th><th>Insert</th><th>p95</th><th>Annoyance</th></tr></thead>
            <tbody>\(supportStates)</tbody>
          </table>
          <h2>Top failure reasons</h2>
          <ul>\(failureReasonList(summary.topFailureReasons))</ul>
          <h2>Recent redacted events</h2>
          <table>
            <thead><tr><th>Time</th><th>Type</th><th>Arm</th><th>Mode</th><th>App</th><th>Reason</th><th>Latency ms</th><th>Shown chars</th><th>Accepted chars</th><th>Screenshot captured</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </body>
        </html>
        """
    }

    private func redactedEvents(_ events: [AutocompleteTraceEvent]) -> [AutocompleteTraceEvent] {
        events.map { $0.redactedForDefaultTrace() }
    }

    private func visualCalibrationHTMLTable(from events: [AutocompleteTraceEvent]) -> String {
        let rows = visualCalibrationRows(from: events)
        guard !rows.isEmpty else {
            return "<p>none yet</p>"
        }

        let body = rows.map { row in
            """
            <tr>
              <td><code>\(escape(row.appBundleIdentifier))</code></td>
              <td>\(escape(row.renderMode))</td>
              <td>\(row.shown)</td>
              <td>\(row.caretFailures)</td>
              <td>\(percent(row.caretFailureRate))</td>
              <td>\(row.missingCaretRectPresentations)</td>
              <td>\(row.flickerCount)</td>
              <td>\(row.learningAppliedCount)</td>
              <td>\(escape(row.latestOffset ?? "none"))</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <table>
          <thead><tr><th>App</th><th>Render</th><th>Shown</th><th>Caret failures</th><th>Failure rate</th><th>Missing caret rect</th><th>Flicker</th><th>Learning applied</th><th>Latest offset</th></tr></thead>
          <tbody>\(body)</tbody>
        </table>
        """
    }

    private func visualCalibrationRows(from events: [AutocompleteTraceEvent]) -> [VisualCalibrationRow] {
        var buckets: [VisualCalibrationKey: VisualCalibrationAccumulator] = [:]
        var seenPresentedIDs: Set<String> = []

        for event in events {
            switch event.type {
            case .suggestionPresented:
                guard !event.suggestionID.isEmpty, !seenPresentedIDs.contains(event.suggestionID) else {
                    continue
                }
                seenPresentedIDs.insert(event.suggestionID)
                let key = visualKey(for: event)
                buckets[key, default: VisualCalibrationAccumulator()].shown += 1
                if event.metadata["hasCaretRect"] == "false" {
                    buckets[key, default: VisualCalibrationAccumulator()].missingCaretRectPresentations += 1
                }
                if event.metadata["learningApplied"] == "true" {
                    buckets[key, default: VisualCalibrationAccumulator()].learningAppliedCount += 1
                }
                if let xOffset = event.metadata["learningXOffset"],
                   let yOffset = event.metadata["learningYOffset"] {
                    buckets[key, default: VisualCalibrationAccumulator()].latestOffset = "(\(xOffset), \(yOffset))"
                }

            case .caretGeometryFailed:
                let key = visualKey(for: event)
                buckets[key, default: VisualCalibrationAccumulator()].caretFailures += 1

            case .suggestionHidden:
                guard let lifetime = Int(event.metadata["lifetimeMs"] ?? ""), lifetime < 150 else {
                    continue
                }
                let key = visualKey(for: event)
                buckets[key, default: VisualCalibrationAccumulator()].flickerCount += 1

            default:
                continue
            }
        }

        return buckets
            .map { key, value in
                VisualCalibrationRow(
                    appBundleIdentifier: key.appBundleIdentifier,
                    renderMode: key.renderMode,
                    shown: value.shown,
                    caretFailures: value.caretFailures,
                    missingCaretRectPresentations: value.missingCaretRectPresentations,
                    flickerCount: value.flickerCount,
                    learningAppliedCount: value.learningAppliedCount,
                    latestOffset: value.latestOffset
                )
            }
            .sorted { lhs, rhs in
                if lhs.caretFailures == rhs.caretFailures {
                    if lhs.appBundleIdentifier == rhs.appBundleIdentifier {
                        return lhs.renderMode < rhs.renderMode
                    }

                    return lhs.appBundleIdentifier < rhs.appBundleIdentifier
                }

                return lhs.caretFailures > rhs.caretFailures
            }
    }

    private func visualKey(for event: AutocompleteTraceEvent) -> VisualCalibrationKey {
        VisualCalibrationKey(
            appBundleIdentifier: event.appBundleIdentifier.isEmpty ? "unknown" : event.appBundleIdentifier,
            renderMode: event.metadata["effectiveRenderMode"] ?? event.metadata["renderMode"] ?? "unknown"
        )
    }

    private func sortedCountList(_ buckets: [String: Int]) -> String {
        guard !buckets.isEmpty else {
            return "<li>none yet</li>"
        }

        return buckets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map { "<li><code>\(escape($0.key))</code>: \($0.value)</li>" }
            .joined(separator: "\n")
    }

    private func sortedRateList(_ buckets: [String: Double]) -> String {
        guard !buckets.isEmpty else {
            return "<li>none yet</li>"
        }

        return buckets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map { "<li><code>\(escape($0.key))</code>: \(percent($0.value))</li>" }
            .joined(separator: "\n")
    }

    private func failureReasonList(_ reasons: [AutocompleteTraceFailureReason]) -> String {
        guard !reasons.isEmpty else {
            return "<li>none yet</li>"
        }

        return reasons.map { reason in
            "<li><strong>\(escape(reason.title))</strong> count=\(reason.count) priority=\(reason.priority) category=\(escape(reason.category))</li>"
        }.joined(separator: "\n")
    }

    private func recommendedFixList(_ fixes: [AutocompleteRecommendedFix]) -> String {
        guard !fixes.isEmpty else {
            return "<li>Keep collecting clean accepted-and-kept proof.</li>"
        }

        return fixes.map { fix in
            "<li><strong>\(escape(fix.title))</strong> priority=\(fix.priority) reason=\(escape(fix.reason))</li>"
        }.joined(separator: "\n")
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct VisualCalibrationKey: Hashable {
    let appBundleIdentifier: String
    let renderMode: String
}

private struct VisualCalibrationAccumulator {
    var shown = 0
    var caretFailures = 0
    var missingCaretRectPresentations = 0
    var flickerCount = 0
    var learningAppliedCount = 0
    var latestOffset: String?
}

private struct VisualCalibrationRow {
    let appBundleIdentifier: String
    let renderMode: String
    let shown: Int
    let caretFailures: Int
    let missingCaretRectPresentations: Int
    let flickerCount: Int
    let learningAppliedCount: Int
    let latestOffset: String?

    var caretFailureRate: Double {
        let denominator = shown + caretFailures
        return denominator == 0 ? 0 : Double(caretFailures) / Double(denominator)
    }
}
