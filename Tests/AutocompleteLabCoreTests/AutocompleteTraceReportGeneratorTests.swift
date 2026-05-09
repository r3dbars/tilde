import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace report generator")
struct AutocompleteTraceReportGeneratorTests {
    private let generator = AutocompleteTraceReportGenerator()

    @Test("JSONL export redaction removes raw text and screenshot paths")
    func jsonlExportRedactionRemovesRawTextAndScreenshotPaths() throws {
        let events = [
            event(
                .suggestionPresented,
                suggestionID: "one",
                textBeforeCursor: "violet-draft-before",
                textAfterCursor: "violet-draft-after",
                displayedText: "violet-model-output",
                acceptedText: "violet-accepted",
                screenshotPath: "/tmp/violet-private.png",
                metadata: [
                    "selectedText": "violet-selection",
                    "fieldKind": "multilineCompose"
                ]
            )
        ]

        let jsonl = try generator.redactedJSONL(for: events)
        let decoded = try JSONDecoder().decode(
            AutocompleteTraceEvent.self,
            from: Data(jsonl.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )

        #expect(decoded.displayedText.isEmpty)
        #expect(decoded.acceptedText.isEmpty)
        #expect(decoded.screenshotPath.isEmpty)
        #expect(decoded.metadata["displayedTextChars"] == "19")
        #expect(decoded.metadata["acceptedTextChars"] == "15")
        #expect(decoded.metadata["selectedText"] == "String(16 chars)")
        #expect(!jsonl.contains("violet-draft"))
        #expect(!jsonl.contains("violet-model-output"))
        #expect(!jsonl.contains("violet-accepted"))
        #expect(!jsonl.contains("/tmp/violet-private.png"))
    }

    @Test("HTML export redaction removes raw text and screenshot paths")
    func htmlExportRedactionRemovesRawTextAndScreenshotPaths() {
        let events = reportFixtureEvents()

        let html = generator.htmlReport(for: events)

        #expect(html.contains("Autocomplete Lab Redacted Trace Report"))
        #expect(html.contains("Do-not-ship blockers"))
        #expect(html.contains("Sensitive-field silence"))
        #expect(html.contains("RAM-only retention proof"))
        #expect(html.contains("Privacy checklist"))
        #expect(html.contains("Share only this redacted report for normal beta feedback."))
        #expect(html.contains("Accepted-and-kept survival slices"))
        #expect(html.contains("Visual calibration, no screenshots"))
        #expect(html.contains("thirty-second-retention-expiry"))
        #expect(!html.contains("violet-draft"))
        #expect(!html.contains("violet-model-output"))
        #expect(!html.contains("violet-accepted"))
        #expect(!html.contains("/tmp/violet-private.png"))
    }

    @Test("Survival export includes retention proof without raw accepted text")
    func survivalExportIncludesRetentionProofWithoutRawAcceptedText() throws {
        let data = try generator.redactedSurvivalJSONData(for: reportFixtureEvents())
        let events = try JSONDecoder().decode([AutocompleteTraceEvent].self, from: data)

        #expect(events.map(\.type).contains(.suggestionAccepted))
        #expect(events.map(\.type).contains(.acceptedTextEdited))
        #expect(events.map(\.type).contains(.acceptanceRetentionCleared))
        #expect(events.allSatisfy { $0.acceptedText.isEmpty })
        #expect(events.allSatisfy { $0.displayedText.isEmpty })
        #expect(String(decoding: data, as: UTF8.self).contains("retentionCleared"))
        #expect(!String(decoding: data, as: UTF8.self).contains("violet-accepted"))
    }

    @Test("Debug survival inspector preserves raw text only for explicit debug export")
    func debugSurvivalInspectorPreservesRawTextOnlyForExplicitDebugExport() throws {
        let data = try generator.debugSurvivalInspectorJSONData(for: reportFixtureEvents())
        let events = try JSONDecoder().decode([AutocompleteTraceEvent].self, from: data)
        let json = String(decoding: data, as: UTF8.self)

        #expect(events.map(\.type).contains(.suggestionAccepted))
        #expect(events.map(\.type).contains(.acceptedTextEdited))
        #expect(events.map(\.type).contains(.acceptanceRetentionCleared))
        #expect(json.contains("violet-accepted"))
        #expect(!json.contains("violet-draft-before"))
    }

    @Test("Field-send survival checkpoint is included in survival reports")
    func fieldSendSurvivalCheckpointIsIncludedInSurvivalReports() throws {
        let data = try generator.redactedSurvivalJSONData(for: [
            event(
                .acceptedTextEdited,
                suggestionID: "send",
                acceptedText: "violet-accepted",
                metadata: [
                    "acceptanceID": "send-one",
                    "checkpoint": "fieldSend",
                    "survivalClass": "exactKept",
                    "finalAcceptedAndKept": "true"
                ]
            )
        ])
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("fieldSend"))
        #expect(!json.contains("violet-accepted"))
    }

    @Test("Visual calibration report uses redacted geometry without screenshots")
    func visualCalibrationReportUsesRedactedGeometryWithoutScreenshots() {
        let report = generator.visualCalibrationReport(for: reportFixtureEvents())

        #expect(report.contains("no screenshots required"))
        #expect(report.contains("com.apple.TextEdit / inlineAdjacent"))
        #expect(report.contains("shown=1"))
        #expect(report.contains("caretFailures=1"))
        #expect(report.contains("latestOffset=(4.0, -2.0)"))
        #expect(!report.contains("/tmp/violet-private.png"))
        #expect(!report.contains("violet-model-output"))
    }

    private func reportFixtureEvents() -> [AutocompleteTraceEvent] {
        [
            event(
                .suggestionPresented,
                suggestionID: "one",
                textBeforeCursor: "violet-draft-before",
                textAfterCursor: "violet-draft-after",
                displayedText: "violet-model-output",
                screenshotPath: "/tmp/violet-private.png",
                metadata: [
                    "fieldKind": "multilineCompose",
                    "effectiveRenderMode": "inlineAdjacent",
                    "hasCaretRect": "false",
                    "learningApplied": "true",
                    "learningXOffset": "4.0",
                    "learningYOffset": "-2.0",
                    "model": "qwen35-4b"
                ]
            ),
            event(
                .suggestionAccepted,
                suggestionID: "one",
                acceptedText: "violet-accepted",
                metadata: [
                    "acceptanceID": "accept-one",
                    "acceptedChars": "15",
                    "acceptedWords": "1"
                ]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                acceptedText: "violet-accepted",
                metadata: [
                    "acceptanceID": "accept-one",
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true",
                    "tokenRecall": "1.000",
                    "normalizedEditDistance": "0.000"
                ]
            ),
            event(
                .acceptanceRetentionCleared,
                suggestionID: "one",
                acceptedText: "violet-accepted",
                reason: "thirty-second-retention-expiry",
                metadata: [
                    "acceptanceID": "accept-one",
                    "retentionCleared": "true",
                    "retentionPolicy": "ram-only-30s-blur-10m-max",
                    "rawAcceptedTextDurable": "false"
                ]
            ),
            event(
                .caretGeometryFailed,
                suggestionID: "two",
                reason: "missing-anchor",
                metadata: [
                    "effectiveRenderMode": "inlineAdjacent"
                ]
            ),
            event(
                .suggestionSuppressed,
                suggestionID: "three",
                reason: "wrong-app-or-field-before-accept",
                metadata: [
                    "doNotShip": "true",
                    "severe": "true"
                ]
            ),
            event(
                .suggestionSuppressed,
                suggestionID: "sensitive",
                reason: "sensitive-field",
                metadata: [
                    "sensitiveSuppressionCategory": "password",
                    "sensitiveSuppressionProof": "boundedNative",
                    "sensitiveSuppressionDecision": "blocked",
                    "fieldKind": "secure"
                ]
            )
        ]
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
