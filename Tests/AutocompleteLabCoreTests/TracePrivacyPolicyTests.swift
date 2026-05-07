import Testing
@testable import AutocompleteLabCore

@Suite("Trace privacy policy")
struct TracePrivacyPolicyTests {
    @Test("Default policy removes raw text and screenshots")
    func defaultPolicyRemovesRawTextAndScreenshots() {
        let event = rawEvent()

        let safe = TracePrivacyPolicy.default.logSafeEvent(event)

        #expect(safe.textBeforeCursor.isEmpty)
        #expect(safe.textAfterCursor.isEmpty)
        #expect(safe.systemPrompt.isEmpty)
        #expect(safe.userPrompt.isEmpty)
        #expect(safe.rawOutput.isEmpty)
        #expect(safe.cleanedVisibleText.isEmpty)
        #expect(safe.displayedText.isEmpty)
        #expect(safe.acceptedText.isEmpty)
        #expect(safe.remainingVisibleText.isEmpty)
        #expect(safe.screenshotPath.isEmpty)
        #expect(safe.metadata["typedSuffix"] == nil)
        #expect(safe.metadata["typedSuffixChars"] == "12")
        #expect(safe.metadata["textBeforeCursorChars"] == "18")
        #expect(safe.metadata["rawOutputChars"] == "19")
        #expect(safe.metadata["hasCaretRect"] == "true")
        #expect(safe.metadata["acceptanceSource"] == "visiblePrefix")
        #expect(safe.metadata["visibleBeforeAcceptChars"] == "15")
        #expect(safe.metadata["remainingVisibleAfterAcceptChars"] == "12")
        #expect(safe.metadata["acceptanceMatchesVisiblePrefix"] == "true")
    }

    @Test("Environment opt-in keeps raw text")
    func environmentOptInKeepsRawText() {
        let policy = TracePrivacyPolicy.fromEnvironment([
            "AUTOCOMPLETE_LAB_RAW_TRACE": "1",
            "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE": "1"
        ])
        let event = rawEvent()

        let safe = policy.logSafeEvent(event)

        #expect(safe.textBeforeCursor == "private draft text")
        #expect(safe.userPrompt == "Before cursor: private draft text")
        #expect(safe.rawOutput == "secret model output")
        #expect(safe.displayedText == "model output")
        #expect(safe.acceptedText == "model")
        #expect(safe.screenshotPath == "/tmp/private-screen.png")
        #expect(safe.metadata["typedSuffix"] == "private next")
    }

    @Test("Diagnostics opt-in keeps raw text without enabling screenshots")
    func diagnosticsOptInKeepsRawTextWithoutScreenshots() {
        let policy = TracePrivacyPolicy.fromEnvironment(
            [:],
            diagnosticsRawTextTracingEnabled: true
        )
        let event = rawEvent()

        let safe = policy.logSafeEvent(event)

        #expect(safe.textBeforeCursor == "private draft text")
        #expect(safe.rawOutput == "secret model output")
        #expect(safe.screenshotPath.isEmpty)
    }

    private func rawEvent() -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T10:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: .modelResult,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field",
            requestMode: "phraseContinuation",
            triggerReason: "pause",
            textBeforeCursor: "private draft text",
            textAfterCursor: "after text",
            systemPrompt: "system prompt",
            userPrompt: "Before cursor: private draft text",
            rawOutput: "secret model output",
            cleanedVisibleText: "model output",
            displayedText: "model output",
            acceptedText: "model",
            remainingVisibleText: " output",
            latencyMilliseconds: 42,
            outcome: "accepted",
            reason: "tab",
            screenshotPath: "/tmp/private-screen.png",
            metadata: [
                "typedSuffix": "private next",
                "hasCaretRect": "true",
                "acceptanceSource": "visiblePrefix",
                "visibleBeforeAcceptChars": "15",
                "remainingVisibleAfterAcceptChars": "12",
                "acceptanceMatchesVisiblePrefix": "true"
            ]
        )
    }
}
