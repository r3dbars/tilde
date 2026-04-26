import Foundation
import AutocompleteLabCore

final class RawAutocompleteTraceLog: @unchecked Sendable {
    static let shared = RawAutocompleteTraceLog()

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.raw-trace-log")
    private let logURL: URL

    private init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/raw-traces.jsonl")
    }

    var isEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_RAW_TRACE"] ?? ""
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    func recordModelResult(
        request: CompletionRequest,
        prompt: CompletionPrompt,
        rawOutput: String,
        cleanedSuggestion: CompletionSuggestion?
    ) {
        guard isEnabled else {
            return
        }

        record([
            "type": "model-result",
            "mode": request.mode.rawValue,
            "appBundleIdentifier": request.appBundleIdentifier ?? "",
            "textBeforeCursor": request.textBeforeCursor,
            "textAfterCursor": request.textAfterCursor,
            "systemPrompt": prompt.system,
            "userPrompt": prompt.user,
            "rawOutput": rawOutput,
            "cleanedVisibleText": cleanedSuggestion?.visibleText ?? "",
            "cleanedWordCount": String(cleanedSuggestion?.visibleWordCount ?? 0)
        ])
    }

    func recordAcceptance(
        action: String,
        appBundleIdentifier: String,
        acceptedText: String,
        remainingVisibleText: String?
    ) {
        guard isEnabled else {
            return
        }

        record([
            "type": "acceptance",
            "action": action,
            "appBundleIdentifier": appBundleIdentifier,
            "acceptedText": acceptedText,
            "remainingVisibleText": remainingVisibleText ?? ""
        ])
    }

    private func record(_ fields: [String: String]) {
        var mutablePayload = fields
        mutablePayload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        let payload = mutablePayload

        queue.async { [logURL] in
            do {
                let fileManager = FileManager.default
                try fileManager.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
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
}
