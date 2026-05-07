import Foundation
import AutocompleteLabCore

final class RawAutocompleteTraceLog: @unchecked Sendable {
    static let shared = RawAutocompleteTraceLog()

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.raw-trace-log")
    private let logURL: URL
    private let rawLogURL: URL
    private let screenshotsURL: URL
    private let secretStore = TracePrivacySecretStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let pauseDefaultsKey = "AutocompleteLabTracePaused"
    private let screenshotDefaultsKey = "AutocompleteLabScreenshotTraceEnabled"
    private let rawTraceDefaultsKey = "AutocompleteLabRawDebugTraceEnabled"
    private let sessionIDDefaultsKey = "AutocompleteLabTraceSessionID"
    private let sessionDayDefaultsKey = "AutocompleteLabTraceSessionDay"
    private var experimentArmName = ""
    private var runtimeMetadata: [String: String] = [:]

    private init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/traces.jsonl")
        rawLogURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/raw-traces.jsonl")
        screenshotsURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/screenshots")
    }

    var currentSessionID: String {
        defaultTraceSessionID()
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

    var rawPath: String {
        rawLogURL.path
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
        queue.sync { [logURL, rawLogURL, screenshotsURL] in
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: rawLogURL)
            try? FileManager.default.removeItem(at: screenshotsURL)
        }
    }

    func applyRetentionControls(
        traceMaxAgeDays: Int = 14,
        screenshotMaxAgeDays: Int = 3
    ) {
        Task {
            await TraceLogger.shared.applyRetentionControls(
                traceMaxAgeDays: traceMaxAgeDays,
                screenshotMaxAgeDays: screenshotMaxAgeDays
            )
        }
    }

    var rawDebugTracingEnabled: Bool {
        if UserDefaults.standard.bool(forKey: rawTraceDefaultsKey) {
            return true
        }

        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_RAW_TRACE"] ?? ""
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    func setRawDebugTracingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: rawTraceDefaultsKey)
    }

    var screenshotTracingEnabled: Bool {
        guard rawDebugTracingEnabled else {
            return false
        }

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
        suggestionID: String = "",
        latencyMilliseconds: Int? = nil,
        firstTokenLatencyMilliseconds: Int? = nil
    ) {
        guard isEnabled else {
            return
        }

        var metadata = [
            "cleanedWordCount": String(cleanedSuggestion?.visibleWordCount ?? 0),
            "emptyResult": String(cleanedSuggestion == nil)
        ]
        if let latencyMilliseconds {
            metadata["totalGenerationLatencyMilliseconds"] = String(latencyMilliseconds)
        }
        if let firstTokenLatencyMilliseconds {
            metadata["firstTokenLatencyMilliseconds"] = String(firstTokenLatencyMilliseconds)
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
            latencyMilliseconds: latencyMilliseconds,
            metadata: metadata
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

        var metadata = [
            "acceptanceID": acceptanceID,
            "acceptMode": acceptMode,
            "fieldKind": fieldKind.rawValue,
            "fieldKindReason": fieldKindReason,
            "acceptedChars": String(acceptedText.count),
            "acceptedWords": String(acceptedText.split(whereSeparator: \.isWhitespace).count)
        ]
        metadata.merge(survivalFingerprintMetadata(for: acceptedText)) { current, _ in current }

        record(
            type: .suggestionAccepted,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText ?? "",
            outcome: action,
            metadata: metadata
        )
    }

    func survivalFingerprintMetadata(for acceptedText: String) -> [String: String] {
        TracePrivacyFingerprint.metadata(for: acceptedText, secret: secretStore.secret())
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
        applyRetentionControls()

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
            sessionID: defaultTraceSessionID(),
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

        let writesRawDebugTrace = rawDebugTracingEnabled

        Task(priority: .utility) {
            await TraceLogger.shared.record(
                event,
                writesRawDebugTrace: writesRawDebugTrace
            )
        }
    }

    private static func append(
        _ event: AutocompleteTraceEvent,
        to logURL: URL,
        encoder: JSONEncoder
    ) throws {
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
    }

    private func defaultTraceSessionID(now: Date = Date()) -> String {
        let rotation = TraceSessionRotator.session(
            existingID: UserDefaults.standard.string(forKey: sessionIDDefaultsKey),
            existingDay: UserDefaults.standard.string(forKey: sessionDayDefaultsKey),
            now: now,
            generateID: { UUID().uuidString }
        )
        if rotation.rotated {
            UserDefaults.standard.set(rotation.sessionID, forKey: sessionIDDefaultsKey)
            UserDefaults.standard.set(rotation.day, forKey: sessionDayDefaultsKey)
        }

        return rotation.sessionID
    }

    private static func pruneTrace(
        at url: URL,
        maxAgeDays: Int,
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) {
        guard maxAgeDays > 0,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
        let formatter = ISO8601DateFormatter()
        let keptEvents = contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                try? decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
            }
            .filter { event in
                guard let date = formatter.date(from: event.timestamp) else {
                    return true
                }

                return date >= cutoff
            }

        let lines = keptEvents.compactMap { event -> String? in
            guard let data = try? encoder.encode(event) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }
        guard let data = lines
            .joined(separator: "\n")
            .appending(keptEvents.isEmpty ? "" : "\n")
            .data(using: .utf8) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    private static func pruneScreenshots(at url: URL, maxAgeDays: Int) {
        guard maxAgeDays > 0,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: url,
                  includingPropertiesForKeys: [.contentModificationDateKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < cutoff else {
                continue
            }

            try? FileManager.default.removeItem(at: file)
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
                .map(RedactionLayer.redactedDefaultTrace)
        }
    }

    func summary(limit: Int = 2_000) -> AutocompleteTraceSummary {
        AutocompleteTraceAnalyzer().summary(for: recentEvents(limit: limit))
    }

    func exportRedactedSurvivalReport(limit: Int = 2_000) -> URL? {
        queue.sync {
            LocalReportExporter(folderURL: folderURL)
                .exportRedactedSurvivalReport(limit: limit)
        }
    }

    func exportDebugSurvivalInspector(limit: Int = 2_000) -> URL? {
        guard rawDebugTracingEnabled else {
            return nil
        }

        return queue.sync {
            LocalReportExporter(folderURL: folderURL)
                .exportDebugSurvivalInspector(limit: limit)
        }
    }

    func exportHTMLReport(limit: Int = 2_000) -> URL? {
        queue.sync {
            LocalReportExporter(folderURL: folderURL)
                .exportHTMLReport(limit: limit)
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
        let caretFailuresByApp = sortedCountList(summary.caretGeometryFailuresByApp)
        let caretFailureRatesByApp = sortedRateList(summary.caretGeometryFailureRateByApp)
        let caretFailuresByRenderMode = sortedCountList(summary.caretGeometryFailuresByRenderMode)
        let caretFailureRatesByRenderMode = sortedRateList(summary.caretGeometryFailureRateByRenderMode)
        let annoyanceSignals = sortedCountList(summary.annoyanceSignalCounts)
        let dailySummaries = dailySummaryRows(summary.dailySummaries)
        let topFailureReasons = failureReasonList(summary.topFailureReasons)
        let recommendedFixes = recommendedFixList(summary.recommendedFixes)
        let supportStates = CompatibilitySupportEvaluator()
            .evaluations(for: events)
            .map { evaluation in
                "<tr><td><code>\(escape(evaluation.bundleIdentifier))</code></td><td>\(escape(evaluation.state.rawValue))</td><td>\(escape(evaluation.appFamily))</td><td>\(evaluation.presentedCount)/\(evaluation.minimumSampleSize)</td><td>\(Int((evaluation.acceptedAndKeptShownRate * 100).rounded()))%</td><td>\(Int((evaluation.insertionVerificationSuccessRate * 100).rounded()))%</td><td>\(evaluation.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</td><td>\(String(format: "%.2f", evaluation.annoyanceScore))</td></tr>"
            }
            .joined(separator: "\n")
        let insertionReliabilityRows = summary.insertionReliabilityByAppAndMode
            .map { row in
                "<tr><td><code>\(escape(row.appBundleIdentifier))</code></td><td><code>\(escape(row.insertionMode))</code></td><td>\(Int((row.successRate * 100).rounded()))%</td><td>\(row.verifiedCount)</td><td>\(row.failedCount)</td></tr>"
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
            <div class="metric"><b>\(Int((summary.acceptedAndKeptRateShown * 100).rounded()))%</b>kept / shown</div>
            <div class="metric"><b>\(Int((summary.acceptedAndKeptRateAccepted * 100).rounded()))%</b>kept / accepted</div>
            <div class="metric"><b>\(summary.acceptedCount)</b>accepted</div>
            <div class="metric"><b>\(summary.suppressedCount)</b>suppressed</div>
            <div class="metric"><b>\(summary.actionableSuppressedCount)</b>actionable suppressed</div>
            <div class="metric"><b>\(Int((summary.acceptRate * 100).rounded()))%</b>accept rate</div>
            <div class="metric"><b>\(Int((summary.usefulRate * 100).rounded()))%</b>useful rate</div>
            <div class="metric"><b>\(summary.typedThroughCount)</b>typed through</div>
            <div class="metric"><b>\(summary.typedOverCount)</b>typed over</div>
            <div class="metric"><b>\(Int((summary.tabAcceptShare * 100).rounded()))%</b>Tab accept share</div>
            <div class="metric"><b>\(Int((summary.insertionVerificationSuccessRate * 100).rounded()))%</b>verified inserts</div>
            <div class="metric"><b>\(Int((summary.caretGeometryFailureRate * 100).rounded()))%</b>caret failure rate</div>
            <div class="metric"><b>\(String(format: "%.2f", summary.annoyanceScore))</b>annoyance score</div>
            <div class="metric"><b>\(summary.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</b>first-visible p95</div>
            <div class="metric"><b>\(summary.modelResultP95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</b>total-generation p95</div>
          </div>
          <h2>Recommended next fix</h2>
          <ol>\(recommendedFixes)</ol>
          <h2>Daily summary</h2>
          <table>
            <thead><tr><th>Date</th><th>Active</th><th>Shown</th><th>Accepted</th><th>Kept</th><th>p50</th><th>p95</th><th>Severe</th><th>Pauses</th><th>Disables</th></tr></thead>
            <tbody>\(dailySummaries)</tbody>
          </table>
          <h2>Acceptance funnel</h2>
          <ul>
            <li>requested: \(summary.acceptanceFunnel.requested)</li>
            <li>model returned: \(summary.acceptanceFunnel.modelReturned)</li>
            <li>shown: \(summary.acceptanceFunnel.shown)</li>
            <li>accepted: \(summary.acceptanceFunnel.accepted)</li>
            <li>kept at 10s: \(summary.acceptanceFunnel.keptAt10Seconds)</li>
            <li>kept at 30s/blur: \(summary.acceptanceFunnel.keptAt30SecondsOrBlur)</li>
          </ul>
          <h2>Annoyance funnel</h2>
          <ul>
            <li>shown: \(summary.annoyanceFunnel.shown)</li>
            <li>ignored: \(summary.annoyanceFunnel.ignored)</li>
            <li>typed over: \(summary.annoyanceFunnel.typedOver)</li>
            <li>Esc dismiss: \(summary.annoyanceFunnel.escapeDismissed)</li>
            <li>accepted then deleted: \(summary.annoyanceFunnel.acceptedThenDeleted)</li>
            <li>paused: \(summary.annoyanceFunnel.paused)</li>
            <li>disabled: \(summary.annoyanceFunnel.disabled)</li>
          </ul>
          <h2>Top failure reasons</h2>
          <ul>\(topFailureReasons)</ul>
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
          <h2>Caret failures by app</h2>
          <ul>\(caretFailuresByApp)</ul>
          <h2>Caret failure rate by app</h2>
          <ul>\(caretFailureRatesByApp)</ul>
          <h2>Caret failures by render mode</h2>
          <ul>\(caretFailuresByRenderMode)</ul>
          <h2>Caret failure rate by render mode</h2>
          <ul>\(caretFailureRatesByRenderMode)</ul>
          <h2>Annoyance signals</h2>
          <ul>\(annoyanceSignals)</ul>
          <h2>Support state by app</h2>
          <table>
            <thead><tr><th>App</th><th>State</th><th>Family</th><th>Shown/min</th><th>Kept</th><th>Insert</th><th>p95</th><th>Annoyance</th></tr></thead>
            <tbody>\(supportStates)</tbody>
          </table>
          <h2>Insertion reliability by app and mode</h2>
          <table>
            <thead><tr><th>App</th><th>Mode</th><th>Success</th><th>Verified</th><th>Failed</th></tr></thead>
            <tbody>\(insertionReliabilityRows)</tbody>
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

    private static func sortedRateList(_ buckets: [String: Double]) -> String {
        buckets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map { "<li><code>\(escape($0.key))</code>: \(Int(($0.value * 100).rounded()))%</li>" }
            .joined(separator: "\n")
    }

    private static func dailySummaryRows(_ summaries: [AutocompleteTraceDailySummary]) -> String {
        guard !summaries.isEmpty else {
            return "<tr><td colspan=\"10\">none yet</td></tr>"
        }

        return summaries.prefix(7).map { summary in
            "<tr><td>\(escape(summary.date))</td><td>\(summary.activeWritingMinutes)m</td><td>\(summary.shown)</td><td>\(summary.accepted)</td><td>\(summary.acceptedAndKept)</td><td>\(summary.p50LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</td><td>\(summary.p95LatencyMilliseconds.map { "\($0)ms" } ?? "n/a")</td><td>\(summary.severeFailures)</td><td>\(summary.pauses)</td><td>\(summary.disables)</td></tr>"
        }.joined(separator: "\n")
    }

    private static func failureReasonList(_ reasons: [AutocompleteTraceFailureReason]) -> String {
        guard !reasons.isEmpty else {
            return "<li>none yet</li>"
        }

        return reasons.map { reason in
            "<li><strong>\(escape(reason.title))</strong> count=\(reason.count) priority=\(reason.priority) category=\(escape(reason.category))</li>"
        }.joined(separator: "\n")
    }

    private static func recommendedFixList(_ fixes: [AutocompleteRecommendedFix]) -> String {
        guard !fixes.isEmpty else {
            return "<li>Keep collecting clean accepted-and-kept proof.</li>"
        }

        return fixes.map { fix in
            "<li><strong>\(escape(fix.title))</strong> priority=\(fix.priority) reason=\(escape(fix.reason))</li>"
        }.joined(separator: "\n")
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
