import Foundation
import AutocompleteLabCore

actor TraceLogger {
    static let shared = TraceLogger()

    private let logURL: URL
    private let rawLogURL: URL
    private let screenshotsURL: URL
    private let redactionLayer: RedactionLayer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        logURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/traces.jsonl"),
        rawLogURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/raw-traces.jsonl"),
        screenshotsURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/screenshots"),
        redactionLayer: RedactionLayer = .shared
    ) {
        self.logURL = logURL
        self.rawLogURL = rawLogURL
        self.screenshotsURL = screenshotsURL
        self.redactionLayer = redactionLayer
    }

    func record(
        _ event: AutocompleteTraceEvent,
        writesRawDebugTrace: Bool,
        traceMaxAgeDays: Int = 14,
        screenshotMaxAgeDays: Int = 3
    ) async {
        do {
            pruneTrace(at: logURL, maxAgeDays: traceMaxAgeDays)
            pruneTrace(at: rawLogURL, maxAgeDays: max(1, min(traceMaxAgeDays, 3)))
            pruneScreenshots(at: screenshotsURL, maxAgeDays: screenshotMaxAgeDays)

            try append(
                await redactionLayer.redactedDefaultTrace(event),
                to: logURL
            )

            if writesRawDebugTrace {
                try append(
                    await redactionLayer.rawDogfoodDiagnosticsTrace(event),
                    to: rawLogURL
                )
            }
        } catch {
            // Trace logging is diagnostic only and must never affect typing.
        }
    }

    func applyRetentionControls(
        traceMaxAgeDays: Int = 14,
        screenshotMaxAgeDays: Int = 3
    ) {
        pruneTrace(at: logURL, maxAgeDays: traceMaxAgeDays)
        pruneTrace(at: rawLogURL, maxAgeDays: max(1, min(traceMaxAgeDays, 3)))
        pruneScreenshots(at: screenshotsURL, maxAgeDays: screenshotMaxAgeDays)
    }

    private func append(
        _ event: AutocompleteTraceEvent,
        to logURL: URL
    ) throws {
        // raw-traces.jsonl carries raw dogfood content when enabled — keep owner-only
        // (0700 dir / 0600 file). See docs/security/threat-model.md (F2).
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
    }

    private func pruneTrace(at url: URL, maxAgeDays: Int) {
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
        // Atomic rewrite creates a fresh inode at umask; re-tighten to owner-only.
        SecureLocalStorage.restrictFile(at: url)
    }

    private func pruneScreenshots(at url: URL, maxAgeDays: Int) {
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
}
