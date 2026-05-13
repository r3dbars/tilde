import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Diagnostics typing health")
struct DiagnosticsTypingHealthTests {
    @Test("Diagnostics inspector summary leads with current utility state")
    func diagnosticsInspectorSummaryLeadsWithCurrentUtilityState() {
        let state = DiagnosticsInspectorState(
            appTrusted: true,
            appEnabled: false,
            compatibilityStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.Notes"),
            lastSuggestionDecision: "Blocked: field quieted",
            runtimeReport: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            ),
            runtimeTargetSummary: "Qwen3.5 4B MLX",
            tracePath: "/tmp/traces.jsonl",
            tracingPaused: false,
            screenshotTracingEnabled: true,
            compatibilityLearningPath: "/tmp/learning.json",
            compatibilityLearningProfile: nil
        )

        #expect(
            state.summaryText
                == """
                Current state:
                  Accessibility: allowed
                  Suggestions: Blocked: field quieted
                  Global pause: off
                  App: Yellow: Notes, blocked
                  Mode: mirror
                  Local model: ready
                  Runtime target: Qwen3.5 4B MLX
                  Next action: Model ready
                  Traces: recording
                  Screenshots: on
                  Trace file: /tmp/traces.jsonl
                  Learning file: /tmp/learning.json
                  Learned adapter: none
                """
        )
    }

    @Test("Separates healthy key capture from AX polling warnings")
    func separatesKeyCaptureFromAXPollingWarnings() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-latency decision=consume durationMicros=96 key=tab",
            "2026-05-07T01:44:44Z keyboard-event-tap-latency-summary count=2 maxMicros=96 p50Micros=96 p95Micros=96 p99Micros=96 reason=idle",
            "2026-05-07T01:44:45Z focused-text-poll-latency-summary count=60 maxMilliseconds=121 p50Milliseconds=2 p95Milliseconds=14",
            "2026-05-07T01:44:45Z focused-text-ax-read-slow app=com.openai.codex hasContext=true queueDelayMilliseconds=0 readDurationMilliseconds=420",
            "2026-05-07T01:44:45Z focused-text-poll-skip-summary count=3 durationMilliseconds=110 reason=in-flight"
        ])

        #expect(health.keyCaptureStatus == "healthy")
        #expect(health.keySampleDescription == "raw=1, summary=2, p95=96us, max=96us, replayed=0, dropped=0")
        #expect(health.axPollingStatus == "warning - suggestions may lag, typing should pass through")
        #expect(health.axSampleDescription == "summary=60, p95=14ms, max=420ms, slow=1, skipped=3, cooldowns=0")
    }

    @Test("Replayed captured keys stay in key lane without making AX warnings fatal")
    func replayedCapturedKeysStayInKeyLaneWithoutMakingAXWarningsFatal() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-latency decision=consume durationMicros=70 key=tab",
            "2026-05-07T01:44:41Z keyboard-event-tap-replayed-captured-key key=tab reason=focus-changed diagnosticLayer=keyCapture safetyFailure=false",
            "2026-05-07T01:44:45Z focused-text-ax-read-slow app=com.openai.codex hasContext=true readDurationMilliseconds=420"
        ])

        #expect(health.keyCaptureStatus == "healthy")
        #expect(health.keySampleDescription == "raw=1, summary=0, p95=n/a, max=70us, replayed=1, dropped=0")
        #expect(health.axPollingStatus == "warning - suggestions may lag, typing should pass through")
        #expect(health.axSampleDescription == "summary=0, p95=n/a, max=420ms, slow=1, skipped=0, cooldowns=0")
    }

    @Test("Dropped captured keys are key capture failures separate from AX health")
    func droppedCapturedKeysAreKeyCaptureFailuresSeparateFromAXHealth() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-latency decision=consume durationMicros=70 key=tab",
            "2026-05-07T01:44:41Z keyboard-event-tap-unhandled-consumed-key-dropped key=tab reason=acceptance-proof-failed diagnosticLayer=keyCapture safetyFailure=true",
            "2026-05-07T01:44:42Z focused-text-poll-latency-summary count=30 maxMilliseconds=12 p95Milliseconds=8"
        ])

        #expect(health.keyCaptureStatus == "needs attention - captured key dropped 1x")
        #expect(health.keySampleDescription == "raw=1, summary=0, p95=n/a, max=70us, replayed=0, dropped=1")
        #expect(health.axPollingStatus == "healthy")
    }

    @Test("Flags event tap disabled as key capture attention")
    func flagsEventTapDisabledAsKeyCaptureAttention() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-disabled reason=timeout"
        ])

        #expect(health.keyCaptureStatus == "needs attention - event tap disabled 1x")
        #expect(health.axPollingStatus == "no recent AX samples")
    }

    @Test("Flags event tap start failure as key capture attention")
    func flagsEventTapStartFailureAsKeyCaptureAttention() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-start-failed",
            "2026-05-07T01:44:42Z focused-text-poll-latency-summary count=30 maxMilliseconds=12 p95Milliseconds=8"
        ])

        #expect(health.keyCaptureStatus == "needs attention - event tap start failed 1x")
        #expect(health.axPollingStatus == "healthy")
    }

    @Test("Flags failed closed event tap as key capture attention")
    func flagsFailedClosedEventTapAsKeyCaptureAttention() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-failed-closed reason=timeout",
            "2026-05-07T01:44:42Z focused-text-ax-read-slow app=com.apple.TextEdit readDurationMilliseconds=220"
        ])

        #expect(health.keyCaptureStatus == "needs attention - event tap failed closed 1x")
        #expect(health.axPollingStatus == "warning - suggestions may lag, typing should pass through")
    }

    @Test("Shows AX health cooldown separately from key capture")
    func showsAXHealthCooldownSeparatelyFromKeyCapture() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-latency-summary count=4 maxMicros=120 p95Micros=110",
            "2026-05-07T01:44:42Z focused-text-ax-health-cooldown-started app=md.obsidian reason=read-duration slowReadCount=2 cooldownMilliseconds=750",
            "2026-05-07T01:44:43Z focused-text-ax-health-cooldown app=md.obsidian reason=read-duration slowReadCount=2 remainingMilliseconds=410"
        ])

        #expect(health.keyCaptureStatus == "healthy")
        #expect(health.axPollingStatus == "cooling down slow app reads, typing should pass through")
        #expect(health.axSampleDescription == "summary=0, p95=n/a, max=n/a, slow=0, skipped=0, cooldowns=2")
    }

    @Test("Diagnostics trace history hides raw text")
    func diagnosticsTraceHistoryHidesRawText() {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T13:45:00Z",
            sessionID: "test-session",
            suggestionID: "safe-id",
            type: .suggestionPresented,
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: "phrase",
            displayedText: "private client sentence",
            acceptedText: "private",
            latencyMilliseconds: 24,
            reason: "shown",
            metadata: [
                "effectiveRenderMode": "inlineAdjacent",
                "placementConfidenceBand": "high",
                "visibleChars": "23"
            ]
        )

        let text = DiagnosticsTraceHistory(events: [event]).summaryText

        #expect(text.contains("shownChars=23"))
        #expect(text.contains("acceptedChars=7"))
        #expect(text.contains("confidence=high"))
        #expect(text.contains("render=inlineAdjacent"))
        #expect(!text.contains("private client sentence"))
        #expect(!text.contains("private"))
    }

    @Test("Diagnostics placement evidence shows confidence without raw text")
    func diagnosticsPlacementEvidenceShowsConfidenceWithoutRawText() {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T13:46:00Z",
            sessionID: "test-session",
            suggestionID: "placement-id",
            type: .suggestionPresented,
            appBundleIdentifier: "md.obsidian",
            requestMode: "wordCompletion",
            displayedText: "private project name",
            acceptedText: "",
            screenshotPath: "/tmp/local-proof.png",
            metadata: [
                "placementRequestedRenderMode": "inlineAdjacent",
                "placementEffectiveRenderMode": "floatingMirror",
                "placementAnchorSource": "synthetic-caret",
                "placementHealthReason": "missing-caret",
                "placementSelfHealingAction": "fallback-floating-mirror",
                "placementConfidenceScore": "0.40",
                "placementConfidenceBand": "low",
                "visibleChars": "20"
            ]
        )

        let text = DiagnosticsPlacementEvidence(events: [event]).summaryText

        #expect(text.contains("mode=inlineAdjacent->floatingMirror"))
        #expect(text.contains("confidence=low"))
        #expect(text.contains("score=0.40"))
        #expect(text.contains("anchor=synthetic-caret"))
        #expect(text.contains("health=missing-caret"))
        #expect(text.contains("action=fallback-floating-mirror"))
        #expect(text.contains("screenshot=captured"))
        #expect(text.contains("shownChars=20"))
        #expect(!text.contains("private project name"))
    }
}
