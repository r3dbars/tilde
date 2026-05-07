import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace privacy")
struct AutocompleteTracePrivacyTests {
    @Test("Privacy modes define raw text and screenshot policy")
    func privacyModesDefineStoragePolicy() {
        #expect(AutocompleteTracePrivacyMode.lab.allowsRawTextPersistence)
        #expect(AutocompleteTracePrivacyMode.dogfood.allowsRawTextPersistence)
        #expect(!AutocompleteTracePrivacyMode.beta.allowsRawTextPersistence)
        #expect(!AutocompleteTracePrivacyMode.customer.allowsRawTextPersistence)

        #expect(AutocompleteTracePrivacyMode.lab.allowsScreenshotTracing)
        #expect(AutocompleteTracePrivacyMode.dogfood.allowsScreenshotTracing)
        #expect(!AutocompleteTracePrivacyMode.beta.allowsScreenshotTracing)
        #expect(!AutocompleteTracePrivacyMode.customer.allowsScreenshotTracing)
    }

    @Test("Redacted traces keep useful shape and drop typed text")
    func redactedTraceKeepsShapeAndDropsTypedText() throws {
        let event = AutocompleteTraceEvent(
            id: "event-1",
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session-1",
            suggestionID: "suggestion-1",
            type: .suggestionAccepted,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "AXTextArea",
            requestMode: "wordCompletion",
            triggerReason: "pause",
            textBeforeCursor: "private before cursor",
            textAfterCursor: "private after cursor",
            systemPrompt: "secret system prompt",
            userPrompt: "secret user prompt",
            rawOutput: "private model output",
            cleanedVisibleText: "private cleaned text",
            displayedText: "private display text",
            acceptedText: "private accepted text",
            remainingVisibleText: "private remainder text",
            latencyMilliseconds: 42,
            outcome: "accepted",
            reason: "tab",
            screenshotPath: "/tmp/private-screenshot.png",
            metadata: [
                "role": "AXTextArea",
                "visibleChars": "19\n",
                "hasCaretRect": "true",
                "promptMilliseconds": "7",
                "unknownNote": "private unknown text",
                "selectedText": "private selected text",
                "rawOutput": "private metadata output"
            ]
        )

        let redacted = event.redacted(privacyMode: .customer)

        #expect(redacted.id == "event-1")
        #expect(redacted.privacyMode == .customer)
        #expect(redacted.appBundleIdentifier == "com.apple.TextEdit")
        #expect(redacted.fieldIdentity == "AXTextArea")
        #expect(redacted.requestMode == "wordCompletion")
        #expect(redacted.triggerReason == "pause")
        #expect(redacted.latencyMilliseconds == 42)
        #expect(redacted.outcome == "accepted")
        #expect(redacted.reason == "tab")
        #expect(redacted.hasScreenshot)
        #expect(redacted.textBeforeCursorCharacterCount == 21)
        #expect(redacted.textAfterCursorCharacterCount == 20)
        #expect(redacted.rawOutputCharacterCount == 20)
        #expect(redacted.displayedTextCharacterCount == 20)
        #expect(redacted.acceptedTextCharacterCount == 21)
        #expect(Set(redacted.metadata.keys) == Set([
            "role",
            "visibleChars",
            "hasCaretRect",
            "promptMilliseconds",
            "unknownNote",
            "selectedText",
            "rawOutput"
        ]))
        #expect(redacted.metadata["visibleChars"] == "19 ")
        #expect(redacted.metadata["hasCaretRect"] == "true")
        #expect(redacted.metadata["promptMilliseconds"] == "7")
        #expect(redacted.metadata["unknownNote"] == "String(20 chars)")
        #expect(redacted.metadata["selectedText"] == "String(21 chars)")
        #expect(redacted.metadata["rawOutput"] == "String(23 chars)")

        let encoded = try JSONEncoder().encode(redacted)
        let json = String(decoding: encoded, as: UTF8.self)
        let topLevel = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(topLevel["textBeforeCursor"] == nil)
        #expect(topLevel["textAfterCursor"] == nil)
        #expect(topLevel["rawOutput"] == nil)
        #expect(topLevel["displayedText"] == nil)
        #expect(topLevel["acceptedText"] == nil)
        #expect(!json.contains("private before cursor"))
        #expect(!json.contains("private after cursor"))
        #expect(!json.contains("secret system prompt"))
        #expect(!json.contains("secret user prompt"))
        #expect(!json.contains("private model output"))
        #expect(!json.contains("private display text"))
        #expect(!json.contains("private accepted text"))
        #expect(!json.contains("private metadata output"))
        #expect(!json.contains("private unknown text"))
        #expect(!json.contains("/tmp/private-screenshot.png"))
    }
}
