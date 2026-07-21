import Foundation
import AutocompleteLabCore

enum TraceContentSensitivity: Equatable, Sendable {
    case standard
    case sensitiveSurface
}

final class RawAutocompleteTraceLog: @unchecked Sendable {
    static let shared = RawAutocompleteTraceLog(
        logURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/traces.jsonl"),
        screenshotsURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/screenshots")
    )

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.raw-trace-log")
    private let logURL: URL
    private let screenshotsURL: URL
    private let userDefaults: UserDefaults
    private let environment: [String: String]
    private let debugCaptureDuration: TimeInterval
    private let now: () -> Date
    private let sessionID = UUID().uuidString
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let pauseDefaultsKey = "AutocompleteLabTracePaused"
    private let screenshotDefaultsKey = "AutocompleteLabScreenshotTraceEnabled"
    private let screenshotExpiryDefaultsKey = "AutocompleteLabScreenshotTraceExpiresAt"
    private let rawContentDefaultsKey = "AutocompleteLabRawTraceContentEnabled"
    private let rawContentExpiryDefaultsKey = "AutocompleteLabRawTraceContentExpiresAt"

    init(
        logURL: URL,
        screenshotsURL: URL,
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        debugCaptureDuration: TimeInterval = 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.logURL = logURL
        self.screenshotsURL = screenshotsURL
        self.userDefaults = userDefaults
        self.environment = environment
        self.debugCaptureDuration = debugCaptureDuration
        self.now = now
    }

    var currentSessionID: String {
        sessionID
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

    var rawContentTracingEnabled: Bool {
        if let override = environmentFlag("AUTOCOMPLETE_LAB_RAW_TRACE") {
            return override
        }

        return activeDefaultFlag(
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    func setRawContentTracingEnabled(_ enabled: Bool) {
        setExpiringDefaultFlag(
            enabled,
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    var rawContentTracingExpiresAt: Date? {
        activeDefaultExpirationDate(
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    var isPaused: Bool {
        userDefaults.bool(forKey: pauseDefaultsKey)
    }

    func setPaused(_ paused: Bool) {
        userDefaults.set(paused, forKey: pauseDefaultsKey)
    }

    func deleteAll() {
        setRawContentTracingEnabled(false)
        setScreenshotTracingEnabled(false)
        queue.sync { [logURL, screenshotsURL] in
            let folderURL = logURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("raw-traces.jsonl"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("trace-report.html"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("survival-report.json"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("survival-inspector-debug.json"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("privacy-export"))
            try? FileManager.default.removeItem(at: screenshotsURL)
        }
    }

    var screenshotTracingEnabled: Bool {
        if activeDefaultFlag(
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        ) {
            return true
        }

        return environmentFlag("AUTOCOMPLETE_LAB_SCREENSHOT_TRACE") == true
    }

    func setScreenshotTracingEnabled(_ enabled: Bool) {
        setExpiringDefaultFlag(
            enabled,
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        )
    }

    var screenshotTracingExpiresAt: Date? {
        activeDefaultExpirationDate(
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        )
    }

    private func environmentFlag(_ key: String) -> Bool? {
        guard let value = environment[key]?.lowercased() else {
            return nil
        }

        if ["1", "true", "yes", "on"].contains(value) {
            return true
        }

        if ["0", "false", "no", "off"].contains(value) {
            return false
        }

        return nil
    }

    private func activeDefaultFlag(flagKey: String, expiryKey: String) -> Bool {
        activeDefaultExpirationDate(flagKey: flagKey, expiryKey: expiryKey) != nil
    }

    private func activeDefaultExpirationDate(flagKey: String, expiryKey: String) -> Date? {
        guard userDefaults.bool(forKey: flagKey) else {
            return nil
        }

        guard let expiresAt = expirationDate(forKey: expiryKey),
              expiresAt > now() else {
            clearExpiringDefaultFlag(flagKey: flagKey, expiryKey: expiryKey)
            expireArtifacts(for: flagKey)
            return nil
        }

        return expiresAt
    }

    private func setExpiringDefaultFlag(_ enabled: Bool, flagKey: String, expiryKey: String) {
        guard enabled else {
            clearExpiringDefaultFlag(flagKey: flagKey, expiryKey: expiryKey)
            return
        }

        userDefaults.set(true, forKey: flagKey)
        userDefaults.set(
            now().addingTimeInterval(debugCaptureDuration).timeIntervalSince1970,
            forKey: expiryKey
        )
    }

    private func clearExpiringDefaultFlag(flagKey: String, expiryKey: String) {
        userDefaults.set(false, forKey: flagKey)
        userDefaults.removeObject(forKey: expiryKey)
    }

    private func expireArtifacts(for flagKey: String) {
        if flagKey == rawContentDefaultsKey {
            redactStoredTraceFile()
            removeSurvivalInspectorDebugFile()
        }
        if flagKey == screenshotDefaultsKey {
            queue.sync { [screenshotsURL] in
                try? FileManager.default.removeItem(at: screenshotsURL)
            }
        }
    }

    private func removeSurvivalInspectorDebugFile() {
        queue.sync { [logURL] in
            let folderURL = logURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(
                at: folderURL.appendingPathComponent("survival-inspector-debug.json")
            )
        }
    }

    private func redactStoredTraceFile() {
        queue.sync { [logURL, decoder, encoder] in
            guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return
            }

            let redactedLines = contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .compactMap { line -> String? in
                    guard let event = try? decoder.decode(
                        AutocompleteTraceEvent.self,
                        from: Data(line.utf8)
                    ) else {
                        return nil
                    }
                    guard let data = try? encoder.encode(RedactionLayer.redactedDefaultTrace(event)) else {
                        return nil
                    }
                    return String(data: data, encoding: .utf8)
                }

            guard !redactedLines.isEmpty else {
                try? FileManager.default.removeItem(at: logURL)
                return
            }

            try? (redactedLines.joined(separator: "\n") + "\n").write(
                to: logURL,
                atomically: true,
                encoding: .utf8
            )
            // Atomic write replaces the file with a fresh inode at the process umask, so
            // re-tighten to owner-only after rewriting.
            SecureLocalStorage.restrictFile(at: logURL)
        }
    }

    private func expirationDate(forKey key: String) -> Date? {
        let value = userDefaults.double(forKey: key)
        guard value > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: value)
    }

    func recordModelResult(
        request: CompletionRequest,
        prompt: CompletionPrompt,
        rawOutput: String,
        cleanedSuggestion: CompletionSuggestion?,
        cleanedCandidateCount: Int = 0,
        candidateTopScore: Double? = nil,
        candidateScoreMargin: Double? = nil,
        candidateSuppressionReason: String? = nil,
        suggestionID: String = "",
        latencyMilliseconds: Int? = nil,
        firstTokenLatencyMilliseconds: Int? = nil,
        extraMetadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        var metadata = [
            "cleanedWordCount": String(cleanedSuggestion?.visibleWordCount ?? 0),
            "cleanedCandidateCount": String(cleanedCandidateCount),
            "candidateTopScore": Self.formattedCandidateScore(candidateTopScore),
            "candidateScoreMargin": Self.formattedCandidateScore(candidateScoreMargin),
            "candidateSuppressionReason": candidateSuppressionReason ?? "none",
            "emptyResult": String(cleanedSuggestion == nil)
        ]
        metadata.merge(request.behaviorProfileTraceMetadata) { current, _ in current }
        if let latencyMilliseconds {
            metadata["totalGenerationLatencyMilliseconds"] = String(latencyMilliseconds)
        }
        if let firstTokenLatencyMilliseconds {
            metadata["firstTokenLatencyMilliseconds"] = String(firstTokenLatencyMilliseconds)
        }
        metadata.merge(extraMetadata) { current, _ in current }

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
        appBundleIdentifier: String,
        acceptedText: String,
        remainingVisibleText: String?,
        suggestionID: String = "",
        fieldIdentity: String = "",
        requestMode: String = "",
        metadata: [String: String] = [:]
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
            metadata: metadata
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
        screenshotPathAuthorized: Bool = false,
        contentSensitivity: TraceContentSensitivity = .standard,
        metadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        // Raw and screenshot debug opt-ins never override a sensitive-surface hard block.
        // The metadata check keeps the logger boundary fail-closed if a caller carrying the
        // standard AX classification forgets to mark the sensitivity explicitly.
        let isSensitiveSurface = contentSensitivity == .sensitiveSurface
            || metadata["fieldKindSuppressed"] == "true"
        let rawContentEnabled = rawContentTracingEnabled && !isSensitiveSurface
        var traceMetadata = metadata
        if type == .suggestionSuppressed {
            traceMetadata.merge(
                SuggestionSilenceExplanationPolicy().traceMetadata(
                    forTraceReason: reason,
                    metadata: metadata,
                    triggerReason: triggerReason
                )
            ) { _, code in code }
        }
        let proofMetadata = traceMetadata.merging(AutocompleteTraceProofMetadata.current) { _, current in
            current
        }
        let event = AutocompleteTraceEvent(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            sessionID: sessionID,
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            triggerReason: triggerReason,
            textBeforeCursor: AutocompleteTracePrivacyFilter.textValue(
                textBeforeCursor,
                rawContentEnabled: rawContentEnabled
            ),
            textAfterCursor: AutocompleteTracePrivacyFilter.textValue(
                textAfterCursor,
                rawContentEnabled: rawContentEnabled
            ),
            systemPrompt: AutocompleteTracePrivacyFilter.textValue(
                systemPrompt,
                rawContentEnabled: rawContentEnabled
            ),
            userPrompt: AutocompleteTracePrivacyFilter.textValue(
                userPrompt,
                rawContentEnabled: rawContentEnabled
            ),
            rawOutput: AutocompleteTracePrivacyFilter.textValue(
                rawOutput,
                rawContentEnabled: rawContentEnabled
            ),
            cleanedVisibleText: AutocompleteTracePrivacyFilter.textValue(
                cleanedVisibleText,
                rawContentEnabled: rawContentEnabled
            ),
            displayedText: AutocompleteTracePrivacyFilter.textValue(
                displayedText,
                rawContentEnabled: rawContentEnabled
            ),
            acceptedText: AutocompleteTracePrivacyFilter.textValue(
                acceptedText,
                rawContentEnabled: rawContentEnabled
            ),
            remainingVisibleText: AutocompleteTracePrivacyFilter.textValue(
                remainingVisibleText,
                rawContentEnabled: rawContentEnabled
            ),
            latencyMilliseconds: latencyMilliseconds,
            outcome: outcome,
            reason: reason,
            screenshotPath: !isSensitiveSurface
                && (screenshotTracingEnabled || screenshotPathAuthorized) ? screenshotPath : "",
            metadata: AutocompleteTracePrivacyFilter.metadata(
                proofMetadata,
                rawContentEnabled: rawContentEnabled
            )
        )

        queue.async { [logURL, encoder] in
            do {
                // Owner-only (0700 dir / 0600 file): traces can hold raw text when raw-content
                // dogfood tracing is opted in, so the file must not rely on the parent
                // directory's mode to stay private. See docs/security/threat-model.md (F2).
                SecureLocalStorage.createDirectory(at: logURL.deletingLastPathComponent())

                let data = try encoder.encode(event)
                guard var line = String(data: data, encoding: .utf8) else {
                    return
                }

                line.append("\n")

                SecureLocalStorage.ensureFile(at: logURL)

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

    func exportPrivacyBundle(limit: Int = 2_000) -> URL? {
        queue.sync { [folderURL] in
            LocalReportExporter(folderURL: folderURL).exportPrivacyBundle(limit: limit)
        }
    }

    func exportHTMLReport(limit: Int = 2_000) -> URL? {
        queue.sync { [folderURL] in
            LocalReportExporter(folderURL: folderURL).exportHTMLReport(limit: limit)
        }
    }

    func exportRedactedSurvivalReport(limit: Int = 2_000) -> URL? {
        queue.sync { [folderURL] in
            LocalReportExporter(folderURL: folderURL).exportRedactedSurvivalReport(limit: limit)
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
        let actionableSuppressedApps = sortedCountList(summary.actionableSuppressedByApp)
        let actionableSuppressedModes = sortedCountList(summary.actionableSuppressedByMode)

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>SteadyType Trace Report</title>
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
          <h1>SteadyType Trace Report</h1>
          <p>Generated locally. Nothing was uploaded.</p>
          <div class="grid">
            <div class="metric"><b>\(summary.totalEvents)</b>events</div>
            <div class="metric"><b>\(summary.presentedCount)</b>shown</div>
            <div class="metric"><b>\(summary.acceptedCount)</b>accepted</div>
            <div class="metric"><b>\(summary.typedThroughCount)</b>typed through</div>
            <div class="metric"><b>\(Int((summary.typeThroughSurvivalRate * 100).rounded()))%</b>type-through survival</div>
            <div class="metric"><b>\(summary.typedThroughCharacterCount)</b>matched typed characters</div>
            <div class="metric"><b>\(summary.typedOverCount)</b>typed over</div>
            <div class="metric"><b>\(summary.suppressedCount)</b>suppressed</div>
            <div class="metric"><b>\(summary.actionableSuppressedCount)</b>actionable suppressed</div>
            <div class="metric"><b>\(Int((summary.acceptRate * 100).rounded()))%</b>accept rate</div>
            <div class="metric"><b>\(Int((summary.usefulRate * 100).rounded()))%</b>useful rate</div>
          </div>
          <h2>Accept rate by app</h2>
          <ul>\(appRates)</ul>
          <h2>Accept rate by mode</h2>
          <ul>\(modeRates)</ul>
          <h2>Useful rate by app</h2>
          <ul>\(usefulAppRates)</ul>
          <h2>Useful rate by mode</h2>
          <ul>\(usefulModeRates)</ul>
          <h2>Suppressed by reason</h2>
          <ul>\(suppressedReasons)</ul>
          <h2>Suppressed by app</h2>
          <ul>\(suppressedApps)</ul>
          <h2>Suppressed by mode</h2>
          <ul>\(suppressedModes)</ul>
          <h2>Actionable suppressed by app</h2>
          <ul>\(actionableSuppressedApps)</ul>
          <h2>Actionable suppressed by mode</h2>
          <ul>\(actionableSuppressedModes)</ul>
          <h2>Top 5 misses</h2>
          <ol>\(misses)</ol>
          <h2>Recent events</h2>
          <table>
            <thead><tr><th>Time</th><th>Type</th><th>Mode</th><th>App</th><th>Shown</th><th>Accepted</th><th>Reason</th><th>Screenshot</th><th>Latency ms</th></tr></thead>
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

    private static func formattedCandidateScore(_ score: Double?) -> String {
        guard let score else {
            return "none"
        }

        return String(format: "%.3f", score)
    }

    private static func screenshotLink(_ path: String) -> String {
        guard !path.isEmpty else {
            return ""
        }

        return "<a href=\"file://\(escape(path))\">open</a>"
    }
}
