import Foundation
import AutocompleteLabCore

struct LocalReportExporter {
    let folderURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let generator = AutocompleteTraceReportGenerator()

    func exportRedactedSurvivalReport(limit: Int = 2_000) -> URL? {
        let events = storedEvents(limit: limit)
        let reportURL = folderURL.appendingPathComponent("survival-report.json")

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let data = try generator.redactedSurvivalJSONData(for: events, encoder: encoder)
            try data.write(to: reportURL, options: .atomic)
            return reportURL
        } catch {
            return nil
        }
    }

    func exportDebugSurvivalInspector(limit: Int = 2_000) -> URL? {
        let events = storedEvents(
            fileName: "raw-traces.jsonl",
            limit: limit
        )
        guard !events.isEmpty else {
            return nil
        }

        let reportURL = folderURL.appendingPathComponent("survival-inspector-debug.json")

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let data = try generator.debugSurvivalInspectorJSONData(for: events, encoder: encoder)
            try data.write(to: reportURL, options: .atomic)
            return reportURL
        } catch {
            return nil
        }
    }

    func exportHTMLReport(limit: Int = 2_000) -> URL? {
        let events = storedEvents(limit: limit)
            .map(RedactionLayer.redactedDefaultTrace)
        guard !events.isEmpty else {
            return nil
        }

        let summary = AutocompleteTraceAnalyzer().summary(for: events)
        let reportURL = folderURL.appendingPathComponent("trace-report.html")

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try generator.htmlReport(
                summary: summary,
                events: events
            ).write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
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
}
