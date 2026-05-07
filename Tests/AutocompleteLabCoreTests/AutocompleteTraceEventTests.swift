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
            textBeforeCursor: "secret draft",
            textAfterCursor: "private tail",
            systemPrompt: "secret system prompt",
            userPrompt: "private user prompt",
            rawOutput: "model secret output",
            cleanedVisibleText: "secret suggestion",
            displayedText: "secret suggestion",
            acceptedText: "secret",
            remainingVisibleText: "suggestion",
            screenshotPath: "/tmp/private.png",
            metadata: [
                "selectedText": "private selection",
                "visibleChars": "17",
                "fieldKind": "multilineCompose"
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
        #expect(redacted.metadata["textBeforeCursorChars"] == "12")
        #expect(redacted.metadata["displayedTextChars"] == "17")
        #expect(redacted.metadata["acceptedTextChars"] == "6")
        #expect(redacted.metadata["screenshotCaptured"] == "true")
        #expect(redacted.metadata["selectedText"] == "String(17 chars)")
        #expect(redacted.metadata["visibleChars"] == "17")
        #expect(!json.contains("secret"))
        #expect(!json.contains("private"))
        #expect(!json.contains("/tmp/private.png"))
    }
}
