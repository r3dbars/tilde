import Testing
@testable import AutocompleteLabApp

@Suite("Diagnostics typing health")
struct DiagnosticsTypingHealthTests {
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
        #expect(health.keySampleDescription == "raw=1, summary=2, p95=96us, max=96us")
        #expect(health.axPollingStatus == "warning - suggestions may lag, typing should pass through")
        #expect(health.axSampleDescription == "summary=60, p95=14ms, max=420ms, slow=1, skipped=3, cooldowns=0")
    }

    @Test("Flags event tap disabled as key capture attention")
    func flagsEventTapDisabledAsKeyCaptureAttention() {
        let health = DiagnosticsTypingHealth(events: [
            "2026-05-07T01:44:41Z keyboard-event-tap-disabled reason=timeout"
        ])

        #expect(health.keyCaptureStatus == "needs attention - event tap disabled 1x")
        #expect(health.axPollingStatus == "no recent AX samples")
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
}
