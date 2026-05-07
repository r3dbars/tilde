import Foundation
import AutocompleteLabCore

final class RawAutocompleteTraceLog: @unchecked Sendable {
    static let shared = RawAutocompleteTraceLog()

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.raw-trace-log")
    private let logURL: URL
    private let screenshotsURL: URL
    private let sessionID = UUID().uuidString
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let pauseDefaultsKey = "AutocompleteLabTracePaused"
    private let screenshotDefaultsKey = "AutocompleteLabScreenshotTraceEnabled"
    private var experimentArmName = ""
    private var runtimeMetadata: [String: String] = [:]

    private init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/traces.jsonl")
        screenshotsURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/screenshots")
    }

    var currentSessionID: String {
        sessionID
    }

    var experimentArm: String {
        get {
            queue.sync { experimentArmName }
        }
        set {
            queue.sync {
                experimentArmName = newValue
            }
        }
    }

    var folderURL: URL {
        logURL.deletingLastPathComponent()
    }

    var screenshotFolderURL: URL {
        screenshotsURL
    }

    var path: String {
        logURL.path
    }

    var isEnabled: Bool {
        if isPaused {
            return false
        }

        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_TRACE"] ?? ""
        if ["0", "false", "no", "off"].contains(value.lowercased()) {
            return false
        }

        return true
    }

    var isPaused: Bool {
        UserDefaults.standard.bool(forKey: pauseDefaultsKey)
    }

    func setPaused(_ paused: Bool) {
        UserDefaults.standard.set(paused, forKey: pauseDefaultsKey)
    }

    func deleteAll() {
        queue.sync { [logURL, screenshotsURL] in
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: screenshotsURL)
        }
    }

    var screenshotTracingEnabled: Bool {
        if UserDefaults.standard.bool(forKey: screenshotDefaultsKey) {
            return true
        }

        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] ?? ""
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    func setScreenshotTracingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: screenshotDefaultsKey)
    }

    func configureRuntimeMetadata(_ metadata: [String: String]) {
        queue.sync {
            runtimeMetadata = metadata
            if let experimentArm = metadata["experimentArm"], !experimentArm.isEmpty {
                experimentArmName = experimentArm
            }
        }
    }

    func recordModelResult(
        request: CompletionRequest,
        prompt: CompletionPrompt,
        rawOutput: String,
        cleanedSuggestion: CompletionSuggestion?,
        suggestionID: String = ""
    ) {
        guard isEnabled else {
            return
        }

        record(
            type: .modelResult,
            suggestionID: suggestionID,
            appBundleIdentifier: request.appBundleIdentifier ?? "",
            requestMode: request.mode.rawValue,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            systemPrompt: prompt.system,
            userPrompt: prompt.user,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedSuggestion?.visibleText ?? "",
            displayedText: cleanedSuggestion?.visibleText ?? "",
            metadata: [
                "cleanedWordCount": String(cleanedSuggestion?.visibleWordCount ?? 0)
            ]
        )
    }

    func recordAcceptance(
        action: String,
        acceptanceID: String,
        acceptMode: String,
        appBundleIdentifier: String,
        acceptedText: String,
        remainingVisibleText: String?,
        suggestionID: String = "",
        fieldIdentity: String = "",
        fieldKind: AXFieldKind = .unknown,
        fieldKindReason: String = "unknown",
        requestMode: String = ""
    ) {
        guard isEnabled else {
            return
        }

        record(
            type: .suggestionAccepted,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText ?? "",
            outcome: action,
            metadata: [
                "acceptanceID": acceptanceID,
                "acceptMode": acceptMode,
                "fieldKind": fieldKind.rawValue,
                "fieldKindReason": fieldKindReason,
                "acceptedChars": String(acceptedText.count),
                "acceptedWords": String(acceptedText.split(whereSeparator: \.isWhitespace).count)
            ]
        )
    }

    func record(
        type: AutocompleteTraceEventType,
        suggestionID: String,
        appBundleIdentifier: String = "",
        fieldIdentity: String = "",
        requestMode: String = "",
        triggerReason: String = "",
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        systemPrompt: String = "",
        userPrompt: String = "",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        remainingVisibleText: String = "",
        latencyMilliseconds: Int? = nil,
        outcome: String = "",
        reason: String = "",
        screenshotPath: String = "",
        metadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        let traceConfiguration = queue.sync {
            let resolvedExperimentArm = experimentArmName.isEmpty
                ? AutocompleteExperimentArm.length3Word.rawValue
                : experimentArmName
            var mergedMetadata = runtimeMetadata
            for (key, value) in metadata {
                mergedMetadata[key] = value
            }
            mergedMetadata["experimentArm"] = resolvedExperimentArm

            return (experimentArm: resolvedExperimentArm, metadata: mergedMetadata)
        }

        let event = AutocompleteTraceEvent(
            experimentArm: traceConfiguration.experimentArm,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            sessionID: sessionID,
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            triggerReason: triggerReason,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText,
            latencyMilliseconds: latencyMilliseconds,
            outcome: outcome,
            reason: reason,
            screenshotPath: screenshotPath,
            metadata: traceConfiguration.metadata
        )

        queue.async { [logURL, encoder] in
            do {
                let fileManager = FileManager.default
                try fileManager.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let data = try encoder.encode(event)
                guard var line = String(data: data, encoding: .utf8) else {
                    return
                }

                line.append("\n")

                if !fileManager.fileExists(atPath: logURL.path) {
                    fileManager.createFile(atPath: logURL.path, contents: nil)
                }

                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                // Raw tracing is diagnostic only and must never affect typing.
            }
        }
    }

    func recentEvents(limit: Int) -> [AutocompleteTraceEvent] {
        queue.sync { [logURL, decoder] in
            guard limit > 0,
                  let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return []
            }

            return contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .suffix(limit)
                .compactMap { line in
                    try? decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
                }
        }
    }

    func summary(limit: Int = 2_000) -> AutocompleteTraceSummary {
        AutocompleteTraceAnalyzer().summary(for: recentEvents(limit: limit))
    }

    func exportHTMLReport(limit: Int = 2_000) -> URL? {
        queue.sync { [folderURL, decoder] in
            let logURL = folderURL.appendingPathComponent("traces.jsonl")
            guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return nil
            }

            let events = contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .suffix(limit)
                .compactMap { line in
                    try? decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
                }

            let summary = AutocompleteTraceAnalyzer().summary(for: events)
            let html = Self.htmlReport(summary: summary, events: events)
            let reportURL = folderURL.appendingPathComponent("trace-report.html")

            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                try html.write(to: reportURL, atomically: true, encoding: .utf8)
                return reportURL
            } catch {
                return nil
            }
        }
    }

    private static func htmlReport(
        summary: AutocompleteTraceSummary,
        events: [AutocompleteTraceEvent]
    ) -> String {
        let rows = events.suffix(200).reversed().map { event in
            """
            <tr>
              <td>\(escape(event.timestamp))</td>
              <td>\(escape(event.type.rawValue))</td>
              <td>\(escape(event.experimentArm))</td>
              <td>\(escape(event.requestMode))</td>
              <td>\(escape(event.appBundleIdentifier))</td>
              <td>\(escape(event.displayedText))</td>
              <td>\(escape(event.acceptedText))</td>
              <td>\(escape(event.reason))</td>
              <td>\(screenshotLink(event.screenshotPath))</td>
              <td>\(event.latencyMilliseconds.map(String.init) ?? "")</td>
            </tr>
            """
        }.joined(separator: "\n")

        let misses = summary.topMisses.map { miss in
            "<li><strong>\(escape(miss.title))</strong> count=\(miss.count) app=<code>\(escape(miss.appBundleIdentifier.isEmpty ? "unknown" : miss.appBundleIdentifier))</code> mode=<code>\(escape(miss.requestMode.isEmpty ? "unknown" : miss.requestMode))</code> fix=\(escape(miss.fixCategory)) cause=\(escape(miss.suggestedCause)) example=\(escape(miss.exampleSuggestionID))</li>"
        }.joined(separator: "\n")
        let appRates = summary.acceptRateByApp
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let modeRates = summary.acceptRateByMode
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let usefulAppRates = summary.usefulRateByApp
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let usefulModeRates = summary.usefulRateByMode
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let armRates = summary.acceptRateByExperimentArm
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let usefulArmRates = summary.usefulRateByExperimentArm
            .sorted { $0.key < $1.key }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
        let suppressedReasons = summary.suppressedByReason
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map { "<li><code>\(escape($0.key))</code>: \($0.value)</li>" }
            .joined(separator: "\n")
        let suppressedApps = sortedCountList(summary.suppressedByApp)
        let suppressedModes = sortedCountList(summary.suppressedByMode)
        let presentedArms = sortedCountList(summary.presentedByExperimentArm)
        let acceptedAndKeptArms = sortedCountList(summary.acceptedAndKeptByExperimentArm)
        let suppressedArms = sortedCountList(summary.suppressedByExperimentArm)
        let presentedFieldKinds = sortedCountList(summary.presentedByFieldKind)
        let acceptedAndKeptFieldKinds = sortedCountList(summary.acceptedAndKeptByFieldKind)
        let suppressedFieldKinds = sortedCountList(summary.suppressedByFieldKind)
        let actionableSuppressedApps = sortedCountList(summary.actionableSuppressedByApp)
        let actionableSuppressedModes = sortedCountList(summary.actionableSuppressedByMode)
        let annoyanceSignals = sortedCountList(summary.annoyanceSignalCounts)
        let supportStates = CompatibilitySupportEvaluator()
            .evaluations(for: events)
            .map { evaluation in
                "<tr><td><code>\(escape(evaluation.bundleIdentifier))</code></td><td>\(escape(evaluation.state.rawValue))</td><td>\(evaluation.presentedCount)</td><td>\(Int((evaluation.acceptedAndKeptShownRate * 100).rounded()))%</td><td>\(Int((evaluation.insertionVerificationSuccessRate * 100).rounded()))%</td><td>\(evaluation.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</td><td>\(String(format: "%.2f", evaluation.annoyanceScore))</td></tr>"
            }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Autocomplete Lab Trace Report</title>
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
          <h1>Autocomplete Lab Trace Report</h1>
          <p>Generated locally. Nothing was uploaded.</p>
          <div class="grid">
            <div class="metric"><b>\(summary.totalEvents)</b>events</div>
            <div class="metric"><b>\(summary.presentedCount)</b>shown</div>
            <div class="metric"><b>\(summary.acceptedCount)</b>accepted</div>
            <div class="metric"><b>\(summary.typedThroughCount)</b>typed through</div>
            <div class="metric"><b>\(summary.typedOverCount)</b>typed over</div>
            <div class="metric"><b>\(summary.suppressedCount)</b>suppressed</div>
            <div class="metric"><b>\(summary.actionableSuppressedCount)</b>actionable suppressed</div>
            <div class="metric"><b>\(Int((summary.acceptRate * 100).rounded()))%</b>accept rate</div>
            <div class="metric"><b>\(Int((summary.usefulRate * 100).rounded()))%</b>useful rate</div>
            <div class="metric"><b>\(summary.acceptedAndKeptCount)</b>accepted kept</div>
            <div class="metric"><b>\(Int((summary.acceptedAndKeptRateShown * 100).rounded()))%</b>kept / shown</div>
            <div class="metric"><b>\(Int((summary.acceptedAndKeptRateAccepted * 100).rounded()))%</b>kept / accepted</div>
            <div class="metric"><b>\(Int((summary.tabAcceptShare * 100).rounded()))%</b>Tab accept share</div>
            <div class="metric"><b>\(Int((summary.insertionVerificationSuccessRate * 100).rounded()))%</b>verified inserts</div>
            <div class="metric"><b>\(String(format: "%.2f", summary.annoyanceScore))</b>annoyance score</div>
          </div>
          <h2>Accept rate by app</h2>
          <ul>\(appRates)</ul>
          <h2>Accept rate by mode</h2>
          <ul>\(modeRates)</ul>
          <h2>Accept rate by experiment arm</h2>
          <ul>\(armRates)</ul>
          <h2>Useful rate by app</h2>
          <ul>\(usefulAppRates)</ul>
          <h2>Useful rate by mode</h2>
          <ul>\(usefulModeRates)</ul>
          <h2>Useful rate by experiment arm</h2>
          <ul>\(usefulArmRates)</ul>
          <h2>Presented by experiment arm</h2>
          <ul>\(presentedArms)</ul>
          <h2>Accepted and kept by experiment arm</h2>
          <ul>\(acceptedAndKeptArms)</ul>
          <h2>Suppressed by experiment arm</h2>
          <ul>\(suppressedArms)</ul>
          <h2>Presented by field kind</h2>
          <ul>\(presentedFieldKinds)</ul>
          <h2>Accepted and kept by field kind</h2>
          <ul>\(acceptedAndKeptFieldKinds)</ul>
          <h2>Suppressed by reason</h2>
          <ul>\(suppressedReasons)</ul>
          <h2>Suppressed by app</h2>
          <ul>\(suppressedApps)</ul>
          <h2>Suppressed by mode</h2>
          <ul>\(suppressedModes)</ul>
          <h2>Suppressed by field kind</h2>
          <ul>\(suppressedFieldKinds)</ul>
          <h2>Actionable suppressed by app</h2>
          <ul>\(actionableSuppressedApps)</ul>
          <h2>Actionable suppressed by mode</h2>
          <ul>\(actionableSuppressedModes)</ul>
          <h2>Annoyance signals</h2>
          <ul>\(annoyanceSignals)</ul>
          <h2>Support state by app</h2>
          <table>
            <thead><tr><th>App</th><th>State</th><th>Shown</th><th>Kept</th><th>Insert</th><th>p95</th><th>Annoyance</th></tr></thead>
            <tbody>\(supportStates)</tbody>
          </table>
          <h2>Top 5 misses</h2>
          <ol>\(misses)</ol>
          <h2>Recent events</h2>
          <table>
            <thead><tr><th>Time</th><th>Type</th><th>Arm</th><th>Mode</th><th>App</th><th>Shown</th><th>Accepted</th><th>Reason</th><th>Screenshot</th><th>Latency ms</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </body>
        </html>
        """
    }

    private static func sortedCountList(_ buckets: [String: Int]) -> String {
        buckets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map { "<li><code>\(escape($0.key))</code>: \($0.value)</li>" }
            .joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func screenshotLink(_ path: String) -> String {
        guard !path.isEmpty else {
            return ""
        }

        return "<a href=\"file://\(escape(path))\">open</a>"
    }
}
