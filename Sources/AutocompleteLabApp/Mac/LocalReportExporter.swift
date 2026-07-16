import Foundation
import AutocompleteLabCore

struct LocalReportExporter {
    let folderURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let generator = AutocompleteTraceReportGenerator()

    // Export artifacts contain redacted diagnostic data, so write them owner-only.
    // See docs/security/threat-model.md (F2).
    private func writeSecure(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        SecureLocalStorage.restrictFile(at: url)
    }

    private func writeSecure(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        SecureLocalStorage.restrictFile(at: url)
    }

    func exportPrivacyBundle(limit: Int = 2_000) -> URL? {
        let events = storedEvents(limit: limit)
        guard !events.isEmpty else {
            return nil
        }

        let bundleURL = folderURL.appendingPathComponent("privacy-export", isDirectory: true)
        let redactedEvents = events.map(RedactionLayer.redactedDefaultTrace)

        do {
            try? FileManager.default.removeItem(at: bundleURL)
            SecureLocalStorage.createDirectory(at: bundleURL)
            try writeSecure(
                redactedJSONL(for: redactedEvents),
                to: bundleURL.appendingPathComponent("redacted-traces.jsonl")
            )
            try writeSecure(
                generator.htmlReport(for: redactedEvents),
                to: bundleURL.appendingPathComponent("trace-report.html")
            )
            try writeSecure(
                generator.visualCalibrationReport(for: redactedEvents),
                to: bundleURL.appendingPathComponent("visual-calibration-report.txt")
            )
            let survivalData = try generator.redactedSurvivalJSONData(for: redactedEvents, encoder: encoder)
            try writeSecure(survivalData, to: bundleURL.appendingPathComponent("survival-report.json"))
            try writeSecure(
                privacyChecklist(eventCount: redactedEvents.count),
                to: bundleURL.appendingPathComponent("PRIVACY-CHECKLIST.md")
            )
            let manifest = LocalPrivacyExportManifest(
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                privacyLane: TracePrivacyLane.redactedBetaTelemetry.rawValue,
                eventCount: redactedEvents.count,
                rawTextIncluded: false,
                screenshotsIncluded: false,
                files: [
                    "PRIVACY-CHECKLIST.md",
                    "redacted-traces.jsonl",
                    "survival-report.json",
                    "trace-report.html",
                    "visual-calibration-report.txt"
                ]
            )
            let manifestData = try encoder.encode(manifest)
            try writeSecure(manifestData, to: bundleURL.appendingPathComponent("manifest.json"))
            return bundleURL
        } catch {
            return nil
        }
    }

    private func storedEvents(limit: Int) -> [AutocompleteTraceEvent] {
        storedEvents(fileName: "traces.jsonl", limit: limit)
    }

    private func storedEvents(
        fileName: String,
        limit: Int
    ) -> [AutocompleteTraceEvent] {
        let logURL = folderURL.appendingPathComponent(fileName)
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

    private func redactedJSONL(for events: [AutocompleteTraceEvent]) throws -> String {
        try events
            .map { event in
                let data = try encoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            }
            .joined(separator: "\n")
            .appending(events.isEmpty ? "" : "\n")
    }

    private func privacyChecklist(eventCount: Int) -> String {
        """
        # SteadyType Privacy Export

        - [x] Generated locally on this Mac.
        - [x] Uses the redacted beta telemetry lane.
        - [x] Includes \(eventCount) redacted trace event(s).
        - [x] Excludes raw typed text, prompts, model output, accepted text, screenshot files, and screenshot paths.
        - [x] Uses counts, fingerprints, latency, app IDs, request modes, and geometry metadata for debugging.
        - [ ] Review this folder before sharing it.

        ## Default Field Checklist

        | Field | Stored by default | Retention | Opt-in state | Can leave the Mac |
        | --- | --- | --- | --- | --- |
        | Typed text near cursor | No, length only | No raw default retention | Raw local debug only | No |
        | Prompt text | No, length only | No raw default retention | Raw local debug only | No |
        | Model output or visible suggestion | No, length only | No raw default retention | Raw local debug only | No |
        | Accepted text | No, length/fingerprint only | RAM checks at 2s/10s/30s/1m/5m, then cleared | Raw local debug only | No |
        | Screenshot path or image | No | No default retention | Screenshot proof only | No |
        | Personal Capture journal and episodes | No | Until user deletes Personal Capture | Local Personal Capture opt-in only | No |
        | App bundle identifier | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares export |
        | Field kind and request mode | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares export |
        | Timing, counts, scores, and reasons | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares export |
        | HMAC fingerprints | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares export |
        | URL, document title, recipient, subject | No, length only if seen in metadata | No raw default retention | Raw local debug only | No |
        """
    }
}

private struct LocalPrivacyExportManifest: Codable, Equatable {
    let generatedAt: String
    let privacyLane: String
    let eventCount: Int
    let rawTextIncluded: Bool
    let screenshotsIncluded: Bool
    let files: [String]
}
