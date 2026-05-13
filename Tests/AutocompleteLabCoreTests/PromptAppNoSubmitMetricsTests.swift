import Testing
@testable import AutocompleteLabCore

@Suite("Prompt app no-submit metrics")
struct PromptAppNoSubmitMetricsTests {
    @Test("Empty prompt proof metrics pass release gate")
    func emptyPromptProofMetricsPassReleaseGate() {
        let metrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: [
            event(app: "com.openai.codex", type: .suggestionPresented),
            event(app: "com.openai.codex", type: .suggestionAccepted)
        ])

        #expect(metrics == PromptAppNoSubmitMetrics())
        #expect(metrics.passesReleaseGate)
    }

    @Test("Counts prompt-app hard gate failures")
    func countsPromptAppHardGateFailures() {
        let metrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: [
            event(app: "com.openai.codex", metadata: ["checkpoint": "fieldSend"]),
            event(app: "com.anthropic.claude-code", reason: "tab-conflict"),
            event(app: "com.anthropic.claudefordesktop", reason: "prompt-mutation-outside-accepted-span"),
            event(app: "com.openai.chat", reason: "wrong-app-or-field-before-accept"),
            event(app: "com.openai.codex", type: .suggestionAccepted, metadata: ["acceptMode": "acceptAllVisible"]),
            event(app: "ru.keepcoder.Telegram", reason: "accepted-text-prompt-command-prefix")
        ])

        #expect(metrics.accidentalSubmitCount == 1)
        #expect(metrics.sendKeyCollisionCount == 1)
        #expect(metrics.promptMutationWithoutUserIntentCount == 1)
        #expect(metrics.wrongContextInsertionCount == 1)
        #expect(metrics.fullAcceptWithoutProofCount == 1)
        #expect(metrics.suggestionContentViolationCount == 1)
        #expect(!metrics.passesReleaseGate)
    }

    @Test("Ignores non-prompt app failures for prompt no-submit score")
    func ignoresNonPromptAppFailuresForPromptNoSubmitScore() {
        let metrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: [
            event(app: "com.apple.TextEdit", reason: "tab-conflict"),
            event(app: "com.apple.TextEdit", metadata: ["checkpoint": "fieldSend"])
        ])

        #expect(metrics == PromptAppNoSubmitMetrics())
    }

    @Test("Treats AI chat metadata as prompt app evidence")
    func treatsAIChatMetadataAsPromptAppEvidence() {
        let metrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: [
            event(
                app: "com.example.UnknownPrompt",
                reason: "wrong-context",
                metadata: ["behaviorProfile": "ai_chat"]
            )
        ])

        #expect(metrics.wrongContextInsertionCount == 1)
    }

    @Test("Treats browser chat metadata as prompt no-submit evidence")
    func treatsBrowserChatMetadataAsPromptNoSubmitEvidence() {
        let metrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: [
            event(
                app: "com.google.Chrome",
                reason: "send-key-collision",
                metadata: [
                    "browserSurface": "chatgpt",
                    "browserSurfaceSafetyClass": "browser-chat"
                ]
            ),
            event(
                app: "com.google.Chrome",
                reason: "prompt-mutation-outside-accepted-span",
                metadata: ["browserChatProofSurface": "browser-chat-harness"]
            )
        ])

        #expect(metrics.sendKeyCollisionCount == 1)
        #expect(metrics.promptMutationWithoutUserIntentCount == 1)
    }

    private func event(
        app: String,
        type: AutocompleteTraceEventType = .suggestionSuppressed,
        reason: String = "",
        outcome: String = "",
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-08T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: type,
            appBundleIdentifier: app,
            outcome: outcome,
            reason: reason,
            metadata: metadata
        )
    }
}
