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
}
