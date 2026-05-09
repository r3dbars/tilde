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
                return "\(row.appBundleIdentifier) / \(row.renderMode): shown=\(row.shown) caretFailures=\(row.caretFailures) failureRate=\(rate) missingCaret=\(row.missingCaretRectPresentations) flicker=\(row.flickerCount) learningApplied=\(row.learningAppliedCount) latestOffset=\(offset) trustedCorrection=applied:\(row.trustedCorrectionAppliedCount) refused:\(row.trustedCorrectionRefusedCount) refusedReasons=\(row.trustedCorrectionRefusedReasons)"
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
        let nonAnnoyance = AutocompleteNonAnnoyanceReporter().reportForRedactedEvents(events)
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
            <div class="metric"><b>\(summary.sensitiveSuppressedByCategory.values.reduce(0, +))</b>sensitive suppressed</div>
            <div class="metric"><b>\(percent(summary.acceptRate))</b>accept rate</div>
            <div class="metric"><b>\(percent(summary.usefulRate))</b>useful rate</div>
            <div class="metric"><b>\(percent(summary.tabAcceptShare))</b>Tab accept share</div>
            <div class="metric"><b>\(percent(summary.insertionVerificationSuccessRate))</b>verified inserts</div>
            <div class="metric"><b>\(percent(summary.caretGeometryFailureRate))</b>caret failure rate</div>
            <div class="metric"><b>\(String(format: "%.2f", summary.annoyanceScore))</b>annoyance score</div>
            <div class="metric"><b>\(String(format: "%.2f", summary.shownPerActiveMinute))</b>shown / active min</div>
            <div class="metric"><b>\(percent(summary.explicitDismissalsPerShown))</b>Esc / shown</div>
            <div class="metric"><b>\(percent(summary.typedOverRate))</b>typed-over rate</div>
            <div class="metric"><b>\(percent(summary.staleOrWrongContextRate))</b>stale/wrong-context</div>
            <div class="metric"><b>\(summary.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</b>first-visible p95</div>
            <div class="metric"><b>\(summary.p95VisibleLifetimeMilliseconds.map { "\($0)ms" } ?? "n/a")</b>visible lifetime p95</div>
            <div class="metric"><b>\(summary.p95HideLatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</b>hide p95</div>
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
          <h2>Non-annoyance gate</h2>
          <p>This gate uses the default redacted trace. Raw typed text, model text, accepted text, screenshots, and screenshot paths are not included.</p>
          \(nonAnnoyanceHTML(nonAnnoyance))
          <h2>Do-not-ship blockers</h2>
          <p>These are hard trust failures. A beta proof run should keep every counter at zero.</p>
          <ul>\(sortedCountList(summary.doNotShipCounters))</ul>
          <h2>Sensitive-field silence</h2>
          <p>Categories are redacted proof labels only. Raw typed text, URLs, titles, field values, and fixture contents are not included.</p>
          <h3>Suppressed</h3><ul>\(sortedCountList(summary.sensitiveSuppressedByCategory))</ul>
          <h3>Presented</h3><ul>\(sortedCountList(summary.sensitivePresentedByCategory))</ul>
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

    private func nonAnnoyanceHTML(_ report: AutocompleteNonAnnoyanceReport) -> String {
        let gateLabel = report.gatePassed ? "pass" : "fail"
        let failures = report.gateFailures.isEmpty
            ? "<li>none</li>"
            : report.gateFailures.map { "<li>\(escape($0))</li>" }.joined(separator: "\n")

        return """
        <div class="grid">
          <div class="metric"><b>\(escape(gateLabel))</b>gate</div>
          <div class="metric"><b>\(String(format: "%.2f", report.shownPerActiveMinute))</b>shown / active min</div>
          <div class="metric"><b>\(percent(report.dismissalsPerShown))</b>dismissals / shown</div>
          <div class="metric"><b>\(percent(report.typedOverWithinOneSecondRate))</b>typed-over &lt;1s</div>
          <div class="metric"><b>\(report.acceptedThenDeleted)</b>accepted then deleted</div>
          <div class="metric"><b>\(report.immediateResurfacing)</b>immediate resurfacing</div>
          <div class="metric"><b>\(percent(report.lateSuggestionsHiddenRate))</b>late hidden</div>
          <div class="metric"><b>\(percent(report.pauseDisablePerShown))</b>pause+disable / shown</div>
          <div class="metric"><b>\(percent(report.severeSuppressionRate))</b>severe suppression</div>
        </div>
        <ul>\(failures)</ul>
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
              <td>applied \(row.trustedCorrectionAppliedCount), refused \(row.trustedCorrectionRefusedCount)</td>
              <td>\(escape(row.trustedCorrectionRefusedReasons))</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <table>
          <thead><tr><th>App</th><th>Render</th><th>Shown</th><th>Caret failures</th><th>Failure rate</th><th>Missing caret rect</th><th>Flicker</th><th>Learning applied</th><th>Latest offset</th><th>Trusted correction</th><th>Refusal reason</th></tr></thead>
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
                let trustStatus = event.metadata["learningVisualOffsetStatus"]
                    ?? legacyTrustStatus(from: event.metadata["learningVisualOffsetTrusted"])
                switch trustStatus {
                case CompatibilityLearningVisualOffsetTrustStatus.applied.rawValue:
                    buckets[key, default: VisualCalibrationAccumulator()].trustedCorrectionAppliedCount += 1
                case CompatibilityLearningVisualOffsetTrustStatus.refused.rawValue:
                    buckets[key, default: VisualCalibrationAccumulator()].trustedCorrectionRefusedCount += 1
                    let reason = event.metadata["learningVisualOffsetReason"] ?? "unknown"
                    buckets[key, default: VisualCalibrationAccumulator()].trustedCorrectionRefusedReasons[reason, default: 0] += 1
                default:
                    break
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
                    latestOffset: value.latestOffset,
                    trustedCorrectionAppliedCount: value.trustedCorrectionAppliedCount,
                    trustedCorrectionRefusedCount: value.trustedCorrectionRefusedCount,
                    trustedCorrectionRefusedReasons: reasonSummary(value.trustedCorrectionRefusedReasons)
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

    private func legacyTrustStatus(from value: String?) -> String {
        switch value {
        case "true":
            CompatibilityLearningVisualOffsetTrustStatus.applied.rawValue
        case "false":
            CompatibilityLearningVisualOffsetTrustStatus.refused.rawValue
        default:
            CompatibilityLearningVisualOffsetTrustStatus.none.rawValue
        }
    }

    private func reasonSummary(_ reasons: [String: Int]) -> String {
        guard !reasons.isEmpty else {
            return "none"
        }

        return reasons
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
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
    var trustedCorrectionAppliedCount = 0
    var trustedCorrectionRefusedCount = 0
    var trustedCorrectionRefusedReasons: [String: Int] = [:]
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
    let trustedCorrectionAppliedCount: Int
    let trustedCorrectionRefusedCount: Int
    let trustedCorrectionRefusedReasons: String

    var caretFailureRate: Double {
        let denominator = shown + caretFailures
        return denominator == 0 ? 0 : Double(caretFailures) / Double(denominator)
    }
}
