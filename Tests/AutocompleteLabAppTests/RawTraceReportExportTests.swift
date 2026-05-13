import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Raw trace report export")
struct RawTraceReportExportTests {
    @Test("Raw trace events include current proof metadata")
    func rawTraceEventsIncludeCurrentProofMetadata() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTraceProofMetadataTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let traceURL = temporaryFolder.appendingPathComponent("traces.jsonl")
        let log = RawAutocompleteTraceLog(
            logURL: traceURL,
            screenshotsURL: temporaryFolder.appendingPathComponent("screenshots"),
            environment: [:]
        )

        log.record(
            type: .acceptedTextEdited,
            suggestionID: "one",
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: "wordCompletion",
            metadata: [
                "acceptanceID": "accept-one",
                "traceProofVersion": "stale"
            ]
        )

        let events = try waitForEvents(at: traceURL)
        let event = try #require(events.first)

        #expect(event.metadata["traceProofVersion"] == AutocompleteTraceProofMetadata.traceProofVersion)
        #expect(event.metadata["placementProofVersion"] == AutocompleteTraceProofMetadata.placementProofVersion)
        #expect(event.metadata["keyCaptureProofVersion"] == AutocompleteTraceProofMetadata.keyCaptureProofVersion)
        #expect(event.metadata["runtimeProofVersion"] == AutocompleteTraceProofMetadata.runtimeProofVersion)
        #expect(event.metadata["acceptanceID"] == "accept-one")
    }

    @Test("Diagnostics export writes redacted HTML and survival reports")
    func diagnosticsExportWritesRedactedReports() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTraceReportExportTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        let traceURL = temporaryFolder.appendingPathComponent("traces.jsonl")
        try writeEvents(
            [
                event(
                    .suggestionPresented,
                    suggestionID: "one",
                    textBeforeCursor: "private-before",
                    textAfterCursor: "private-after",
                    displayedText: "private-model-output",
                    screenshotPath: "/tmp/private-screenshot.png",
                    metadata: [
                        "documentTitle": "private document title",
                        "fieldKind": "multilineCompose",
                        "recipientEmail": "private-recipient@example.com",
                        "subjectLine": "private subject line",
                        "visibleURL": "https://private.example/draft"
                    ]
                ),
                event(
                    .suggestionAccepted,
                    suggestionID: "one",
                    acceptedText: "private-accepted",
                    metadata: ["acceptanceID": "accept-one"]
                ),
                event(
                    .acceptanceRetentionCleared,
                    suggestionID: "one",
                    acceptedText: "private-accepted",
                    reason: "thirty-second-retention-expiry",
                    metadata: [
                        "acceptanceID": "accept-one",
                        "retentionCleared": "true"
                    ]
                )
            ],
            to: traceURL
        )

        let log = RawAutocompleteTraceLog(
            logURL: traceURL,
            screenshotsURL: temporaryFolder.appendingPathComponent("screenshots"),
            environment: [:]
        )

        let htmlURL = try #require(log.exportHTMLReport(limit: 10))
        let survivalURL = try #require(log.exportRedactedSurvivalReport(limit: 10))
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let survivalJSON = try String(contentsOf: survivalURL, encoding: .utf8)
        let survivalEvents = try JSONDecoder().decode(
            [AutocompleteTraceEvent].self,
            from: Data(survivalJSON.utf8)
        )

        #expect(html.contains("SteadyType Redacted Trace Report"))
        #expect(html.contains("RAM-only retention proof"))
        #expect(html.contains("Generated locally from the default redacted trace. Nothing was uploaded."))
        #expect(!html.contains("private-before"))
        #expect(!html.contains("private-after"))
        #expect(!html.contains("private-model-output"))
        #expect(!html.contains("private-accepted"))
        #expect(!html.contains("/tmp/private-screenshot.png"))
        #expect(!html.contains("private document title"))
        #expect(!html.contains("private-recipient@example.com"))
        #expect(!html.contains("private subject line"))
        #expect(!html.contains("https://private.example/draft"))

        #expect(survivalEvents.map(\.type).contains(.suggestionAccepted))
        #expect(survivalEvents.map(\.type).contains(.acceptanceRetentionCleared))
        #expect(survivalEvents.allSatisfy { $0.acceptedText.isEmpty })
        #expect(survivalEvents.allSatisfy { $0.displayedText.isEmpty })
        #expect(!survivalJSON.contains("private-accepted"))
    }

    @Test("Privacy bundle export clears stale private files first")
    func privacyBundleExportClearsStalePrivateFilesFirst() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTraceReportExportTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let traceURL = temporaryFolder.appendingPathComponent("traces.jsonl")
        let bundleURL = temporaryFolder.appendingPathComponent("privacy-export", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try "private raw trace\n".write(
            to: bundleURL.appendingPathComponent("raw-traces.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try "private screenshot path\n".write(
            to: bundleURL.appendingPathComponent("private-screenshot.txt"),
            atomically: true,
            encoding: .utf8
        )
        try writeEvents(
            [
                event(
                    .suggestionPresented,
                    suggestionID: "one",
                    displayedText: "private-model-output"
                )
            ],
            to: traceURL
        )

        let exportURL = try #require(LocalReportExporter(folderURL: temporaryFolder).exportPrivacyBundle(limit: 10))

        #expect(exportURL == bundleURL)
        #expect(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("redacted-traces.jsonl").path))
        #expect(!FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("raw-traces.jsonl").path))
        #expect(!FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("private-screenshot.txt").path))
    }

    private func writeEvents(
        _ events: [AutocompleteTraceEvent],
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        let jsonl = try events
            .map { event in
                let data = try encoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            }
            .joined(separator: "\n")
            .appending("\n")
        try jsonl.write(to: url, atomically: true, encoding: .utf8)
    }

    private func waitForEvents(at url: URL) throws -> [AutocompleteTraceEvent] {
        let decoder = JSONDecoder()
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: url),
               !data.isEmpty {
                return try data
                    .split(separator: UInt8(ascii: "\n"))
                    .map { try decoder.decode(AutocompleteTraceEvent.self, from: Data($0)) }
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        return []
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        suggestionID: String,
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        screenshotPath: String = "",
        reason: String = "",
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: "wordCompletion",
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            displayedText: displayedText,
            acceptedText: acceptedText,
            reason: reason,
            screenshotPath: screenshotPath,
            metadata: metadata
        )
    }
}
