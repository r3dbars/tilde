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

    @Test("Suppressed trace events include one silence reason code")
    func suppressedTraceEventsIncludeOneSilenceReasonCode() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTraceSilenceReasonTests-\(UUID().uuidString)")
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
            type: .suggestionSuppressed,
            suggestionID: "slow-one",
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: "phraseContinuation",
            triggerReason: "model-result",
            reason: "too-slow-to-display",
            metadata: [
                "displayScoreSuppressionReason": "too-slow-to-display"
            ]
        )

        let events = try waitForEvents(at: traceURL)
        let event = try #require(events.first)
        let reasonCodeKeys = event.metadata.keys.filter {
            $0 == SuggestionSilenceExplanationPolicy.traceReasonCodeMetadataKey
        }

        #expect(reasonCodeKeys.count == 1)
        #expect(event.metadata[SuggestionSilenceExplanationPolicy.traceReasonCodeMetadataKey] == "latency")
        #expect(event.reason == "too-slow-to-display")
    }

    @Test("Privacy bundle writes redacted HTML and survival reports")
    func privacyBundleWritesRedactedReports() throws {
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
                    systemPrompt: "private-system-prompt",
                    userPrompt: "private-user-prompt",
                    rawOutput: "private-raw-output",
                    cleanedVisibleText: "private-cleaned-output",
                    displayedText: "private-model-output",
                    screenshotPath: "/tmp/private-screenshot.png",
                    metadata: [
                        "contextPreview": "private-context-preview",
                        "documentTitle": "private document title",
                        "fieldKind": "multilineCompose",
                        "localCacheDirectory": "/Users/private/Library/Application Support/SteadyType/private-cache",
                        "neighborText": "private-neighbor-text",
                        "recipientEmail": "private-recipient@example.com",
                        "runtimeReason": "loaded from /Users/private/private-reason.md",
                        "subjectLine": "private subject line",
                        "visibleURL": "https://private.example/draft"
                    ]
                ),
                event(
                    .suggestionAccepted,
                    suggestionID: "one",
                    acceptedText: "private-accepted",
                    remainingVisibleText: "private-remaining",
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

        let bundleURL = try #require(log.exportPrivacyBundle(limit: 10))
        let htmlURL = bundleURL.appendingPathComponent("trace-report.html")
        let survivalURL = bundleURL.appendingPathComponent("survival-report.json")
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let survivalJSON = try String(contentsOf: survivalURL, encoding: .utf8)
        let exportedText = try recursiveTextContents(at: bundleURL)
        let manifest = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        )
        let survivalEvents = try JSONDecoder().decode(
            [AutocompleteTraceEvent].self,
            from: Data(survivalJSON.utf8)
        )
        let expectedFiles: Set<String> = [
            "PRIVACY-CHECKLIST.md",
            "manifest.json",
            "redacted-traces.jsonl",
            "survival-report.json",
            "trace-report.html",
            "visual-calibration-report.txt"
        ]
        let actualFiles = try Set(FileManager.default.contentsOfDirectory(atPath: bundleURL.path))
        let privateSentinels = [
            "private-before",
            "private-after",
            "private-system-prompt",
            "private-user-prompt",
            "private-raw-output",
            "private-cleaned-output",
            "private-model-output",
            "private-accepted",
            "private-remaining",
            "private-context-preview",
            "private document title",
            "private-neighbor-text",
            "private-recipient@example.com",
            "private subject line",
            "https://private.example/draft",
            "/tmp/private-screenshot.png",
            "/Users/private/Library/Application Support/SteadyType/private-cache",
            "/Users/private/private-reason.md"
        ]

        #expect(actualFiles == expectedFiles)
        #expect(manifest["privacyLane"] as? String == TracePrivacyLane.redactedBetaTelemetry.rawValue)
        #expect(manifest["rawTextIncluded"] as? Bool == false)
        #expect(manifest["screenshotsIncluded"] as? Bool == false)
        for sentinel in privateSentinels {
            #expect(!exportedText.contains(sentinel))
        }
        #expect(html.contains("SteadyType Redacted Trace Report"))
        #expect(html.contains("RAM-only retention proof"))
        #expect(html.contains("Generated locally from the default redacted trace. Nothing was uploaded."))

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

    private func recursiveTextContents(at folderURL: URL) throws -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ""
        }

        var contents = ""
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            contents += (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            contents += "\n"
        }
        return contents
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
        systemPrompt: String = "",
        userPrompt: String = "",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        remainingVisibleText: String = "",
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
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText,
            reason: reason,
            screenshotPath: screenshotPath,
            metadata: metadata
        )
    }
}
