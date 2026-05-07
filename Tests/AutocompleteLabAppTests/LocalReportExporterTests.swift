import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Local report exporter")
struct LocalReportExporterTests {
    @Test("Privacy bundle exports only redacted local artifacts")
    func privacyBundleExportsOnlyRedactedLocalArtifacts() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalReportExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try writeJSONL(
            [
                event(
                    .suggestionPresented,
                    suggestionID: "one",
                    textBeforeCursor: "violet-private-before",
                    textAfterCursor: "violet-private-after",
                    displayedText: "violet-model-output",
                    screenshotPath: "/tmp/violet-private.png",
                    metadata: [
                        "fieldKind": "multilineCompose",
                        "effectiveRenderMode": "inlineAdjacent",
                        "selectedText": "violet-selection"
                    ]
                ),
                event(
                    .suggestionAccepted,
                    suggestionID: "one",
                    acceptedText: "violet-accepted",
                    metadata: ["acceptanceID": "accept-one"]
                )
            ],
            to: folderURL.appendingPathComponent("traces.jsonl")
        )

        let bundleURL = try #require(LocalReportExporter(folderURL: folderURL).exportPrivacyBundle())
        let expectedFiles = [
            "PRIVACY-CHECKLIST.md",
            "manifest.json",
            "redacted-traces.jsonl",
            "survival-report.json",
            "trace-report.html",
            "visual-calibration-report.txt"
        ]
        let combinedExport = try expectedFiles
            .map { fileName in
                let url = bundleURL.appendingPathComponent(fileName)
                #expect(FileManager.default.fileExists(atPath: url.path))
                return try String(contentsOf: url, encoding: .utf8)
            }
            .joined(separator: "\n")

        #expect(combinedExport.contains("redacted-local-beta-telemetry"))
        #expect(combinedExport.contains("Review this folder before sharing it."))
        #expect(combinedExport.contains("\"rawTextIncluded\":false"))
        #expect(combinedExport.contains("\"screenshotsIncluded\":false"))
        #expect(!combinedExport.contains("violet-private"))
        #expect(!combinedExport.contains("violet-model-output"))
        #expect(!combinedExport.contains("violet-accepted"))
        #expect(!combinedExport.contains("/tmp/violet-private.png"))
    }

    @Test("Redacted HTML export stays safe even when trace rows contain raw text")
    func redactedHTMLExportStaysSafeEvenWhenTraceRowsContainRawText() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalReportExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try writeJSONL(
            [
                event(
                    .suggestionPresented,
                    suggestionID: "one",
                    textBeforeCursor: "violet-private-before",
                    displayedText: "violet-model-output",
                    acceptedText: "violet-accepted",
                    screenshotPath: "/tmp/violet-private.png"
                )
            ],
            to: folderURL.appendingPathComponent("traces.jsonl")
        )

        let reportURL = try #require(LocalReportExporter(folderURL: folderURL).exportHTMLReport())
        let html = try String(contentsOf: reportURL, encoding: .utf8)

        #expect(html.contains("Autocomplete Lab Redacted Trace Report"))
        #expect(!html.contains("violet-private"))
        #expect(!html.contains("violet-model-output"))
        #expect(!html.contains("violet-accepted"))
        #expect(!html.contains("/tmp/violet-private.png"))
    }

    private func writeJSONL(_ events: [AutocompleteTraceEvent], to url: URL) throws {
        let encoder = JSONEncoder()
        let contents = try events
            .map { event in
                let data = try encoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            }
            .joined(separator: "\n")
            .appending("\n")
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        suggestionID: String,
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        screenshotPath: String = "",
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
            screenshotPath: screenshotPath,
            metadata: metadata
        )
    }
}
