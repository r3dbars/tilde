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
        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] ?? ""
        return ["1", "true", "yes", "on"].contains(value.lowercased())
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
        appBundleIdentifier: String,
        acceptedText: String,
        remainingVisibleText: String?,
        suggestionID: String = "",
        fieldIdentity: String = "",
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
            outcome: action
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

        let event = AutocompleteTraceEvent(
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
            metadata: metadata
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
              <td>\(escape(event.requestMode))</td>
              <td>\(escape(event.appBundleIdentifier))</td>
              <td>\(escape(event.displayedText))</td>
              <td>\(escape(event.acceptedText))</td>
              <td>\(escape(event.reason))</td>
              <td>\(event.latencyMilliseconds.map(String.init) ?? "")</td>
            </tr>
            """
        }.joined(separator: "\n")

        let misses = summary.topMisses.map { miss in
            "<li><strong>\(escape(miss.title))</strong> count=\(miss.count) fix=\(escape(miss.fixCategory)) example=\(escape(miss.exampleSuggestionID))</li>"
        }.joined(separator: "\n")

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
            <div class="metric"><b>\(summary.typedOverCount)</b>typed over</div>
            <div class="metric"><b>\(Int((summary.acceptRate * 100).rounded()))%</b>accept rate</div>
          </div>
          <h2>Top 5 misses</h2>
          <ol>\(misses)</ol>
          <h2>Recent events</h2>
          <table>
            <thead><tr><th>Time</th><th>Type</th><th>Mode</th><th>App</th><th>Shown</th><th>Accepted</th><th>Reason</th><th>Latency ms</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </body>
        </html>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
