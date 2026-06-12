import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace event schema")
struct AutocompleteTraceEventTests {
    @Test("Encodes current schema and privacy versions")
    func encodesCurrentVersions() throws {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: .suggestionPresented
        )

        let data = try JSONEncoder().encode(event)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["schemaVersion"] as? Int == AutocompleteTraceEvent.currentSchemaVersion)
        #expect(object["privacyVersion"] as? Int == AutocompleteTraceEvent.currentPrivacyVersion)
        #expect(object["experimentArm"] as? String == "length_3_word")
    }

    @Test("Decodes old trace events without schema fields")
    func decodesOldTraceEventsWithoutSchemaFields() throws {
        let json = """
        {
          "timestamp": "2026-04-01T00:00:00Z",
          "sessionID": "session",
          "suggestionID": "suggestion",
          "type": "suggestionPresented",
          "metadata": {"fieldKind": "multilineCompose"}
        }
        """

        let event = try JSONDecoder().decode(AutocompleteTraceEvent.self, from: Data(json.utf8))

        #expect(event.schemaVersion == 1)
        #expect(event.privacyVersion == 0)
        #expect(event.experimentArm == "length_3_word")
        #expect(event.type == .suggestionPresented)
        #expect(event.metadata["fieldKind"] == "multilineCompose")
    }

    @Test("Default trace redaction removes raw text and keeps shape")
    func defaultTraceRedactionRemovesRawTextAndKeepsShape() throws {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: .suggestionPresented,
            fieldIdentity: "com.apple.TextEdit|pid:1|element:2",
            triggerReason: "violet-trigger-token",
            textBeforeCursor: "secret draft",
            textAfterCursor: "private tail",
            systemPrompt: "secret system prompt",
            userPrompt: "private user prompt",
            rawOutput: "model secret output",
            cleanedVisibleText: "secret suggestion",
            displayedText: "secret suggestion",
            acceptedText: "secret",
            remainingVisibleText: "suggestion",
            outcome: "violet-outcome-token",
            reason: "violet-reason-token",
            screenshotPath: "/tmp/private.png",
            metadata: [
                "selectedText": "private selection",
                "visibleChars": "17",
                "fieldKind": "multilineCompose",
                "fieldKindReason": "violet-field-reason-token",
                "suppressionOutcome": "violet-suppression-outcome-token"
            ]
        )

        let redacted = event.redactedForDefaultTrace()
        let data = try JSONEncoder().encode(redacted)
        let json = String(decoding: data, as: UTF8.self)

        #expect(redacted.privacyVersion == AutocompleteTraceEvent.currentPrivacyVersion)
        #expect(redacted.textBeforeCursor.isEmpty)
        #expect(redacted.textAfterCursor.isEmpty)
        #expect(redacted.systemPrompt.isEmpty)
        #expect(redacted.userPrompt.isEmpty)
        #expect(redacted.rawOutput.isEmpty)
        #expect(redacted.cleanedVisibleText.isEmpty)
        #expect(redacted.displayedText.isEmpty)
        #expect(redacted.acceptedText.isEmpty)
        #expect(redacted.remainingVisibleText.isEmpty)
        #expect(redacted.screenshotPath.isEmpty)
        #expect(redacted.triggerReason == DiagnosticValueRedactor.stringSummary(length: "violet-trigger-token".count))
        #expect(redacted.outcome == DiagnosticValueRedactor.stringSummary(length: "violet-outcome-token".count))
        #expect(redacted.reason == DiagnosticValueRedactor.stringSummary(length: "violet-reason-token".count))
        #expect(redacted.metadata["textBeforeCursorChars"] == "12")
        #expect(redacted.metadata["displayedTextChars"] == "17")
        #expect(redacted.metadata["acceptedTextChars"] == "6")
        #expect(redacted.metadata["screenshotCaptured"] == "true")
        #expect(redacted.metadata["selectedText"] == "String(17 chars)")
        #expect(redacted.metadata["visibleChars"] == "17")
        #expect(redacted.metadata["fieldKindReason"] == DiagnosticValueRedactor.stringSummary(length: "violet-field-reason-token".count))
        #expect(redacted.metadata["suppressionOutcome"] == DiagnosticValueRedactor.stringSummary(length: "violet-suppression-outcome-token".count))
        #expect(!json.contains("secret"))
        #expect(!json.contains("private"))
        #expect(!json.contains("violet"))
        #expect(!json.contains("/tmp/private.png"))
    }

    @Test("Type-through survival signal survives default trace redaction")
    func typeThroughSurvivalSignalSurvivesDefaultTraceRedaction() throws {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: .suggestionHidden,
            textBeforeCursor: "private prefix",
            displayedText: "private suggestion",
            outcome: "survived",
            reason: "survived_typethrough",
            metadata: [
                "reason": "survived_typethrough",
                "typeThroughSurvival": "true",
                "typedThroughChars": "4",
                "remainingVisibleChars": "12"
            ]
        )

        let redacted = event.redactedForDefaultTrace()
        let json = String(decoding: try JSONEncoder().encode(redacted), as: UTF8.self)

        #expect(redacted.outcome == "survived")
        #expect(redacted.reason == "survived_typethrough")
        #expect(redacted.metadata["reason"] == "survived_typethrough")
        #expect(redacted.metadata["typeThroughSurvival"] == "true")
        #expect(redacted.metadata["typedThroughChars"] == "4")
        #expect(redacted.metadata["remainingVisibleChars"] == "12")
        #expect(!json.contains("private"))
    }

    @Test("Shared trace signal helpers classify trust signals")
    func sharedTraceSignalHelpersClassifyTrustSignals() {
        let kept = event(metadata: [
            "acceptanceID": "accept-1",
            "checkpoint": "10s",
            "survivalClass": "exactKept"
        ])
        let earlyKept = event(metadata: [
            "checkpoint": "2s",
            "survivalClass": "exactKept"
        ])
        let duplicate = event(
            type: .insertionFailed,
            reason: "duplicate text",
            metadata: ["duplicateDetected": "true"]
        )
        let tabConflict = event(reason: "tab-conflict")
        let focusSteal = event(outcome: "focus steal")
        let rejected = event(
            type: .acceptedTextEdited,
            metadata: [
                "checkpoint": "2s",
                "survivalClass": "rejectedAfterAccept",
                "firstEditDelayMs": "1400"
            ]
        )

        #expect(kept.acceptanceIdentifier == "accept-1")
        #expect(kept.isAcceptedAndKeptSignal)
        #expect(!earlyKept.isAcceptedAndKeptSignal)
        #expect(duplicate.isDuplicateInsertionSignal)
        #expect(tabConflict.isTabConflictSignal)
        #expect(focusSteal.isFocusStealSignal)
        #expect(rejected.isAcceptedThenDeletedWithinTwoSecondsSignal)
    }

    private func event(
        type: AutocompleteTraceEventType = .acceptedTextEdited,
        reason: String = "",
        outcome: String = "",
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: type,
            outcome: outcome,
            reason: reason,
            metadata: metadata
        )
    }
}
