import Foundation
import Testing
@testable import TildeCore

/// Deterministic timing replay: one model answer is ready at every
/// keystroke, and a ghost is revealed only if the next key arrives after the
/// scheduled reveal delay. Times only, no text.
private struct FlowReplay {
    struct Result: Equatable {
        var shown = 0
        /// Shown, then hidden by the next key in under 120 ms: a mid-stride
        /// flash the writer could not have read.
        var midStrideFlickers = 0
        var revealDelays: [Int] = []
    }

    static let calmPostSpaceMilliseconds = 120

    /// `gaps[i]` is the interval after keystroke `i`. A ghost scheduled at
    /// keystroke `i` is visible for `gaps[i] - delay` when that is positive.
    static func run(
        gaps: [Int],
        flow: FlowRevealPolicy,
        warmUp: Int = 0,
        refractory initial: FlowRefractoryState = FlowRefractoryState(),
        closeOnFlicker: Bool = false,
        tracksCadence: Bool = true
    ) -> Result {
        var cadence = TypingCadenceTracker()
        var refractory = initial
        var result = Result()
        var clock: TimeInterval = 1_000
        cadence.noteKeystroke(atUptime: clock)
        for (index, gap) in gaps.enumerated() {
            let schedule = SuggestionRevealDelayPolicy.schedule(
                afterUserTyped: " ",
                calmMarkedText: true,
                flow: flow,
                cadence: cadence,
                refractory: refractory
            )
            let delay = Int(schedule.revealDelayNanoseconds / 1_000_000)
            clock += Double(gap) / 1_000
            if tracksCadence { cadence.noteKeystroke(atUptime: clock) }
            refractory.noteKeystroke(endsSentence: false, idleBeforeMilliseconds: gap, policy: flow)
            guard index >= warmUp else { continue }
            result.revealDelays.append(delay)
            guard gap >= delay else { continue }
            result.shown += 1
            let visible = gap - delay
            if visible < 120 { result.midStrideFlickers += 1 }
            if closeOnFlicker, visible < SettledVisibility.minimumReadMilliseconds {
                refractory.noteGhostClosed(.typedPast(visibleMilliseconds: visible), policy: flow)
            }
        }
        return result
    }

    /// A fast typist: 90–240 ms strides in words of 3–7 letters, with a
    /// genuine 700–1,500 ms pause every third word. Fixed seed.
    static func burstyTypist(words: Int, seed: UInt64 = 0x7117_DE00) -> (gaps: [Int], pauses: Int) {
        var state = seed
        func next(_ range: ClosedRange<Int>) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int((state >> 33) % span)
        }
        var gaps: [Int] = []
        var pauses = 0
        for word in 0..<words {
            for _ in 0..<next(3...7) { gaps.append(next(90...240)) }
            if word % 3 == 2 {
                gaps.append(next(700...1_500))
                pauses += 1
            } else {
                gaps.append(next(90...240))
            }
        }
        return (gaps, pauses)
    }
}

@Suite("Typing cadence: rolling stride and speed bucket")
struct TypingCadenceTrackerTests {
    private func tracker(intervals: [Int]) -> TypingCadenceTracker {
        var tracker = TypingCadenceTracker()
        var clock: TimeInterval = 50
        tracker.noteKeystroke(atUptime: clock)
        for interval in intervals {
            clock += Double(interval) / 1_000
            tracker.noteKeystroke(atUptime: clock)
        }
        return tracker
    }

    @Test("The median stride maps to fast, medium, and slow buckets")
    func bucketsPopulate() {
        #expect(tracker(intervals: [110, 120, 130, 125, 140]).speedBucket == .fast)
        #expect(tracker(intervals: [180, 200, 210, 190, 220]).speedBucket == .medium)
        #expect(tracker(intervals: [320, 400, 350, 380]).speedBucket == .slow)
        // Too few strides is honest missingness, not a guess.
        #expect(tracker(intervals: [110, 120]).speedBucket == .unknown)
        #expect(TypingCadenceTracker().speedBucket == .unknown)
        // Boundaries are half-open on the slow side.
        #expect(TextFreeTypingSpeedBucket.from(medianStrideMilliseconds: 149) == .fast)
        #expect(TextFreeTypingSpeedBucket.from(medianStrideMilliseconds: 150) == .medium)
        #expect(TextFreeTypingSpeedBucket.from(medianStrideMilliseconds: 279) == .medium)
        #expect(TextFreeTypingSpeedBucket.from(medianStrideMilliseconds: 280) == .slow)
    }

    @Test("Bucket raw values are the Lab schema's")
    func rawValuesMatchLab() {
        #expect(TextFreeTypingSpeedBucket.allCases.map(\.rawValue) == ["slow", "medium", "fast", "unknown"])
    }

    @Test("A pause is not a stride, and a broken run keeps the typist's history")
    func pausesStayOutOfTheMedian() {
        var cadence = tracker(intervals: [120, 130, 125, 135, 4_000, 128])
        #expect(cadence.strides == [120, 130, 125, 135, 128])
        #expect(cadence.medianStrideMilliseconds == 128)
        #expect(cadence.lastIntervalMilliseconds == 128)
        cadence.breakRun()
        #expect(cadence.lastIntervalMilliseconds == nil)
        #expect(cadence.lastKeystrokeUptime == nil)
        #expect(cadence.speedBucket == .fast)
        // The next key after a break is not measured against the old one.
        cadence.noteKeystroke(atUptime: 900)
        #expect(cadence.strides.count == 5)
        #expect(cadence.idleMilliseconds(atUptime: 900.25) == 250)
    }

    @Test("The rolling window forgets old strides")
    func windowIsBounded() {
        let cadence = tracker(intervals: Array(repeating: 400, count: 30) + Array(repeating: 120, count: 24))
        #expect(cadence.strides.count == TypingCadenceTracker.capacity)
        #expect(cadence.speedBucket == .fast)
    }
}

@Suite("Flow-aware reveal: no mid-stride flicker, instant chains")
struct FlowRevealPolicyTests {
    @Test("Off reproduces the fixed calm and native delays exactly")
    func offIsIdentity() {
        let fast = TypingCadenceTrackerTestsSupport.fastTracker()
        for (grapheme, calm, chained) in [(" ", true, false), ("a", true, false), (" ", false, false), ("a", false, false), (" ", true, true), (" ", false, true)] {
            let fixed = SuggestionRevealDelayPolicy.schedule(afterUserTyped: grapheme, calmMarkedText: calm, chained: chained)
            let flowed = SuggestionRevealDelayPolicy.schedule(
                afterUserTyped: grapheme, calmMarkedText: calm, chained: chained,
                flow: .off, cadence: fast, refractory: FlowRefractoryState()
            )
            #expect(fixed == flowed)
        }
        #expect(FlowRevealPolicy.off.isOff)
        #expect(!FlowRevealPolicy.production.isOff)
    }

    @Test("Reveal waits past 1.2x the upper stride, capped at 300 ms")
    func revealOutlastsStride() {
        let flow = FlowRevealPolicy.production
        let fast = TypingCadenceTrackerTestsSupport.fastTracker() // upper stride 140
        #expect(fast.upperStrideMilliseconds == 140)
        #expect(flow.revealMilliseconds(baseMilliseconds: 120, chained: false, cadence: fast, refractory: .init()) == 168)
        let medium = TypingCadenceTrackerTestsSupport.tracker(intervals: [240, 250, 260, 250, 255]) // upper 260
        #expect(flow.revealMilliseconds(baseMilliseconds: 120, chained: false, cadence: medium, refractory: .init()) == 300)
        // A native editor's 45 ms floor rises the same way.
        #expect(flow.revealMilliseconds(baseMilliseconds: 45, chained: false, cadence: fast, refractory: .init()) == 168)
        // Unknown cadence keeps the fixed floor.
        #expect(flow.revealMilliseconds(baseMilliseconds: 120, chained: false, cadence: TypingCadenceTracker(), refractory: .init()) == 120)
        // The first key after a long pause usually opens another burst, so
        // it is gated by the same stride.
        let afterPause = TypingCadenceTrackerTestsSupport.tracker(intervals: [130, 130, 130, 130, 1_800])
        #expect(flow.revealMilliseconds(baseMilliseconds: 120, chained: false, cadence: afterPause, refractory: .init()) == 156)
    }

    @Test("Chained Tab-to-Tab stays 0 ms native and 40 ms calm, even mid-burst and in cooldown")
    func chainedStaysInstant() {
        var engaged = FlowRefractoryState()
        engaged.noteGhostClosed(.dismissed, policy: .production)
        engaged.noteGhostClosed(.dismissed, policy: .production)
        #expect(engaged.isEngaged)
        let fast = TypingCadenceTrackerTestsSupport.fastTracker()
        let calm = SuggestionRevealDelayPolicy.schedule(
            afterUserTyped: " ", calmMarkedText: true, chained: true,
            flow: .production, cadence: fast, refractory: engaged
        )
        let native = SuggestionRevealDelayPolicy.schedule(
            afterUserTyped: " ", calmMarkedText: false, chained: true,
            flow: .production, cadence: fast, refractory: engaged
        )
        #expect(calm.revealDelayNanoseconds == 40_000_000)
        #expect(native.revealDelayNanoseconds == 0)
        #expect(calm.inferenceDelayNanoseconds == 0)
    }

    @Test("Replay: a fast burst produces zero mid-stride flickers while every pause reveals")
    func burstReplayHasNoFlicker() {
        let trace = FlowReplay.burstyTypist(words: 60)
        let warmUp = 8
        let fixed = FlowReplay.run(gaps: trace.gaps, flow: .off, warmUp: warmUp)
        let flowed = FlowReplay.run(gaps: trace.gaps, flow: .production, warmUp: warmUp)
        // The fixed 120 ms calm floor flashes ghosts between letters.
        #expect(fixed.midStrideFlickers > 50)
        // Cadence-aware reveal: none.
        #expect(flowed.midStrideFlickers == 0)
        // Every genuine pause still shows a ghost, at most 300 ms after the key.
        #expect(flowed.shown == trace.pauses)
        #expect(flowed.revealDelays.allSatisfy { $0 >= 120 && $0 <= 300 })
    }

    @Test("Replay: a medium typist gets the same guarantee at their own stride")
    func mediumTypistReplay() {
        // 170–250 ms strides with a pause every 8 keys.
        var gaps: [Int] = []
        for index in 0..<160 {
            gaps.append(index % 8 == 7 ? 900 : 170 + (index * 37) % 81)
        }
        let fixed = FlowReplay.run(gaps: gaps, flow: .off, warmUp: 8)
        let flowed = FlowReplay.run(gaps: gaps, flow: .production, warmUp: 8)
        #expect(fixed.midStrideFlickers > 80)
        #expect(flowed.midStrideFlickers == 0)
        #expect(flowed.shown == gaps.dropFirst(8).filter { $0 == 900 }.count)
    }

    @Test("Mid-word requests wait past 1.5x the upper stride, capped at 360 ms")
    func midWordGate() {
        let policy = InteractionPolicy.conservative
        let fast = TypingCadenceTrackerTestsSupport.tracker(intervals: [150, 160, 170, 180, 200]) // upper 200
        #expect(policy.flowReveal.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: fast) == 300)
        let medium = TypingCadenceTrackerTestsSupport.tracker(intervals: [200, 210, 220, 200, 215]) // upper 220
        #expect(policy.flowReveal.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: medium) == 330)
        let slow = TypingCadenceTrackerTestsSupport.tracker(intervals: [300, 310, 320, 300, 315])
        #expect(policy.flowReveal.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: slow) == 360)
        // Never below the served throttle, and the served throttle alone when
        // the cadence is unknown.
        #expect(policy.flowReveal.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: TypingCadenceTracker()) == 240)
        let veryFast = TypingCadenceTrackerTestsSupport.tracker(intervals: [60, 60, 60, 60, 1_500])
        #expect(policy.flowReveal.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: veryFast) == 240)
        #expect(FlowRevealPolicy.off.midWordThrottleMilliseconds(baseMilliseconds: 240, cadence: medium) == 240)
    }
}

@Suite("H04 refractory cooldown")
struct FlowRefractoryTests {
    private let flow = FlowRevealPolicy.production

    @Test("Two rapid rejects in a row engage the cooldown and hold reveals to a 450 ms pause")
    func engagesOnRapidRejects() {
        var state = FlowRefractoryState()
        state.noteGhostClosed(.typedPast(visibleMilliseconds: 60), policy: flow)
        #expect(!state.isEngaged)
        state.noteGhostClosed(.typedPast(visibleMilliseconds: 90), policy: flow)
        #expect(state.isEngaged)
        let fast = TypingCadenceTrackerTestsSupport.fastTracker()
        #expect(flow.revealMilliseconds(baseMilliseconds: 120, chained: false, cadence: fast, refractory: state) == 450)
        // Escape counts the same way.
        var dismissed = FlowRefractoryState()
        dismissed.noteGhostClosed(.dismissed, policy: flow)
        dismissed.noteGhostClosed(.typedPast(visibleMilliseconds: 10), policy: flow)
        #expect(dismissed.isEngaged)
    }

    @Test("A read-then-rejected ghost breaks the streak; Off never engages")
    func readRejectBreaksStreak() {
        var state = FlowRefractoryState()
        state.noteGhostClosed(.typedPast(visibleMilliseconds: 60), policy: flow)
        state.noteGhostClosed(.typedPast(visibleMilliseconds: 600), policy: flow)
        state.noteGhostClosed(.typedPast(visibleMilliseconds: 60), policy: flow)
        #expect(!state.isEngaged)
        var off = FlowRefractoryState()
        for _ in 0..<5 { off.noteGhostClosed(.dismissed, policy: .off) }
        #expect(!off.isEngaged)
    }

    @Test("Accept, sentence end, and a genuine pause each release the cooldown at once")
    func resets() {
        func engaged() -> FlowRefractoryState {
            var state = FlowRefractoryState()
            state.noteGhostClosed(.dismissed, policy: flow)
            state.noteGhostClosed(.dismissed, policy: flow)
            return state
        }
        var accepted = engaged()
        accepted.noteGhostClosed(.accepted, policy: flow)
        #expect(!accepted.isEngaged)

        var sentence = engaged()
        sentence.noteKeystroke(endsSentence: FlowRefractoryState.endsSentence("."), idleBeforeMilliseconds: 90, policy: flow)
        #expect(!sentence.isEngaged)
        #expect(FlowRefractoryState.endsSentence("?"))
        #expect(FlowRefractoryState.endsSentence("\n"))
        #expect(!FlowRefractoryState.endsSentence(","))
        #expect(!FlowRefractoryState.endsSentence("a"))

        var paused = engaged()
        paused.noteKeystroke(endsSentence: false, idleBeforeMilliseconds: 950, policy: flow)
        #expect(!paused.isEngaged)

        var burst = engaged()
        burst.noteKeystroke(endsSentence: false, idleBeforeMilliseconds: 120, policy: flow)
        #expect(burst.isEngaged)
    }

    @Test("The cooldown is bounded to 12 keystrokes")
    func bounded() {
        var state = FlowRefractoryState()
        state.noteGhostClosed(.dismissed, policy: flow)
        state.noteGhostClosed(.dismissed, policy: flow)
        for _ in 0..<11 { state.noteKeystroke(endsSentence: false, idleBeforeMilliseconds: 130, policy: flow) }
        #expect(state.isEngaged)
        state.noteKeystroke(endsSentence: false, idleBeforeMilliseconds: 130, policy: flow)
        #expect(!state.isEngaged)
        // And a fresh streak is needed to re-engage.
        state.noteGhostClosed(.dismissed, policy: flow)
        #expect(!state.isEngaged)
    }

    @Test("Replay: after rapid rejects, the cooldown stops flashing ghosts the stride gate missed")
    func replayCooldownSuppressesNearStrideGaps() {
        // Cadence not yet known (a cold start), so only the fixed 120 ms
        // floor stands between 130 ms strides and the screen: every key
        // flashes a ghost the writer types straight past.
        var gaps: [Int] = []
        for index in 0..<120 { gaps.append(index % 4 == 3 ? 250 : 130) }
        let withoutCooldown = FlowReplay.run(
            gaps: gaps,
            flow: FlowRevealPolicy(
                strideRevealPercent: 160, maximumStrideRevealMilliseconds: 300,
                midWordStridePercent: 200, maximumMidWordRequestMilliseconds: 360,
                refractoryRejectStreak: 0, refractoryRevealMilliseconds: 0,
                refractoryMaximumKeystrokes: 0, pauseResetMilliseconds: 900
            ),
            warmUp: 8,
            closeOnFlicker: true,
            tracksCadence: false
        )
        let withCooldown = FlowReplay.run(
            gaps: gaps, flow: .production, warmUp: 8, closeOnFlicker: true, tracksCadence: false
        )
        #expect(withoutCooldown.shown > 100)
        #expect(withCooldown.midStrideFlickers * 4 < withoutCooldown.midStrideFlickers)
        // Each cooldown swallows the near-stride hesitations it spans; a
        // fresh rapid-reject streak is needed to re-engage it.
        #expect(withCooldown.shown * 10 <= withoutCooldown.shown * 6)
    }
}

@Suite("Interaction policy decodes across app and keyboard versions")
struct FlowInteractionPolicyCodingTests {
    @Test("Production and the 9B preview serve the flow policy")
    func servedPolicy() {
        #expect(InteractionPolicy.conservative.flowReveal == .production)
        #expect(InteractionPolicy.tuned9B.flowReveal == .production)
    }

    @Test("An older app's interaction object decodes with flow gating off")
    func legacyObjectDecodes() throws {
        let legacy = Data(#"{"chainsCompletionAfterAccept":true,"calmRevealPostSpaceMilliseconds":120,"calmRevealMidWordMilliseconds":110,"requestsAfterPunctuation":true,"requestsMidWordContinuation":true,"midWordRequestThrottleMilliseconds":240}"#.utf8)
        let policy = try JSONDecoder().decode(InteractionPolicy.self, from: legacy)
        #expect(policy.flowReveal == .off)
        #expect(policy.midWordRequestThrottleMilliseconds == 240)
        #expect(policy.requestsMidWordContinuation)
    }

    @Test("A malformed flow object costs only the flow object")
    func malformedFlowDecodes() throws {
        let line = Data(#"{"chainsCompletionAfterAccept":true,"calmRevealPostSpaceMilliseconds":120,"calmRevealMidWordMilliseconds":110,"requestsAfterPunctuation":true,"flowReveal":{"strideRevealPercent":"fast"}}"#.utf8)
        let policy = try JSONDecoder().decode(InteractionPolicy.self, from: line)
        #expect(policy.flowReveal == .off)
        #expect(policy.chainsCompletionAfterAccept)
    }

    @Test("The served policy round-trips, and an older keyboard ignores the new key")
    func roundTripAndForwardCompatibility() throws {
        let data = try JSONEncoder().encode(InteractionPolicy.conservative)
        #expect(try JSONDecoder().decode(InteractionPolicy.self, from: data) == .conservative)
        // An older keyboard's shape: the same keys minus flowReveal.
        struct OlderKeyboardPolicy: Decodable {
            let chainsCompletionAfterAccept: Bool
            let calmRevealPostSpaceMilliseconds: Int
            let calmRevealMidWordMilliseconds: Int
            let requestsAfterPunctuation: Bool
            let midWordRequestThrottleMilliseconds: Int
        }
        let older = try JSONDecoder().decode(OlderKeyboardPolicy.self, from: data)
        #expect(older.midWordRequestThrottleMilliseconds == 240)
        #expect(older.calmRevealPostSpaceMilliseconds == 120)
    }

    @Test("Turning flow gating on changes the configuration digest")
    func digestMoves() {
        let on = TildeEffectiveConfiguration.resolve(
            build: .production, completionProfile: .production, modelIdentifier: "gemma-4-e2b-q4km"
        )
        let base = InteractionPolicy.conservative
        let off = TildeEffectiveConfiguration(
            generator: on.generator,
            decision: on.decision,
            interaction: InteractionPolicy(
                chainsCompletionAfterAccept: base.chainsCompletionAfterAccept,
                calmRevealPostSpaceMilliseconds: base.calmRevealPostSpaceMilliseconds,
                calmRevealMidWordMilliseconds: base.calmRevealMidWordMilliseconds,
                requestsAfterPunctuation: base.requestsAfterPunctuation,
                requestsMidWordContinuation: base.requestsMidWordContinuation,
                midWordRequestThrottleMilliseconds: base.midWordRequestThrottleMilliseconds,
                flowReveal: .off
            )
        )
        #expect(on.digestSHA256 != off.digestSHA256)
    }
}

@Suite("Chat send-to-clear keeps the sent span")
struct CommitClearRetentionTests {
    private func accepted(_ text: String, register: String = "chat") -> LiveOnlineOpportunity {
        let shownAt = Date(timeIntervalSince1970: 2_000)
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: String(repeating: "b", count: 64),
            appCategory: register,
            register: register,
            boundary: "word-boundary",
            typingSpeedBucket: .fast,
            safeOpportunity: true,
            candidateCharacters: text.count,
            candidateWordCount: 2,
            candidateSource: .baseModel,
            opportunityCharacters: 12
        )
        opportunity.noteAccepted(text, kind: .all, at: shownAt.addingTimeInterval(0.6))
        return opportunity
    }

    @Test("The commit rule tells a send from a newline and from nothing")
    func classify() {
        let before = "sounds good, see you tomorrow"
        #expect(CommitClearRule.classify(preCommitWindow: before, postCommitWindow: "") == .sentAndCleared)
        #expect(CommitClearRule.classify(preCommitWindow: before, postCommitWindow: before + "\n") == .stillPresent)
        #expect(CommitClearRule.classify(preCommitWindow: before, postCommitWindow: "o") == .sentAndCleared)
        #expect(CommitClearRule.classify(preCommitWindow: nil, postCommitWindow: "") == .unknown)
        #expect(CommitClearRule.classify(preCommitWindow: "", postCommitWindow: "") == .unknown)
        #expect(CommitClearRule.classify(preCommitWindow: before, postCommitWindow: nil) == .unknown)
        // A long document whose bounded window shifted by the newline.
        let long = String(repeating: "lorem ipsum ", count: 300)
        let shifted = String((long + "\n").dropFirst(1))
        #expect(CommitClearRule.classify(preCommitWindow: long, postCommitWindow: shifted) == .stillPresent)
    }

    @Test("Enter-send closes the segment on the pre-send text: retained, not zero")
    func sendKeepsRetention() throws {
        let span = "see you tomorrow"
        let preSend = "sounds good, " + span
        var watch = PendingRetainedWatch(opportunity: accepted(span))
        try watch.observeFiveSeconds(window: preSend)
        #expect(watch.retentionAt5Seconds.retainedCharacters == span.count)
        // Return: the keyboard read `preSend`; the composer then cleared.
        #expect(CommitClearRule.classify(preCommitWindow: preSend, postCommitWindow: "") == .sentAndCleared)
        try watch.closeSegment(window: preSend)
        #expect(watch.isComplete)
        #expect(watch.retentionAtSegmentClose.retainedCharacters == span.count)
        #expect(watch.retentionAt30Seconds.missingness == .segmentClosedEarly)
        let event = try watch.finishedEvent()
        #expect(event.retentionAtSegmentClose.retainedCharacters == span.count)
        #expect(event.typingSpeedBucket == "fast")
    }

    @Test("Without the commit read, the cleared field scored the sent span as deleted")
    func clearedFieldWasTheBug() throws {
        let span = "see you tomorrow"
        var watch = PendingRetainedWatch(opportunity: accepted(span))
        try watch.observeFiveSeconds(window: "sounds good, " + span)
        try watch.closeSegment(window: "")
        #expect(watch.retentionAtSegmentClose.retainedCharacters == 0)
    }

    @Test("Backspace deletion still scores zero retained")
    func deletionStillZero() throws {
        let span = "see you tomorrow"
        var watch = PendingRetainedWatch(opportunity: accepted(span))
        try watch.observeFiveSeconds(window: "ok, " + span)
        // The writer deleted the span; no Return, so no commit read exists
        // and the segment closes on the live field.
        try watch.closeSegment(window: "ok, ")
        #expect(watch.retentionAtSegmentClose.retainedCharacters == 0)
        // A Return after the deletion: the pre-commit read no longer has the
        // span, so a send that clears the field still scores zero.
        var later = PendingRetainedWatch(opportunity: accepted(span))
        try later.observeFiveSeconds(window: "ok, ")
        #expect(CommitClearRule.classify(preCommitWindow: "ok, ", postCommitWindow: "") == .sentAndCleared)
        try later.closeSegment(window: "ok, ")
        #expect(later.retentionAtSegmentClose.retainedCharacters == 0)
    }
}

@Suite("Typing speed rides on every ledger event")
struct TypingSpeedEventTests {
    @Test("Silent and shown events carry the bucket and decode as production lines")
    func eventsCarryBucket() throws {
        let silent = try TextFreeOnlineEvent.silent(
            id: UUID(),
            occurredAt: Date(timeIntervalSince1970: 3_000),
            sessionDigestSHA256: String(repeating: "c", count: 64),
            variant: "champion",
            appCategory: "chat",
            register: "chat",
            boundary: "word-boundary",
            reason: .supersededByTyping,
            generated: false,
            deadlineMissed: true,
            generatorMilliseconds: nil,
            firstStableWordMilliseconds: nil,
            nextActionMilliseconds: 90,
            opportunityCharacters: 4,
            typingSpeedBucket: .medium
        )
        #expect(silent.typingSpeedBucket == "medium")
        let decoded = try TextFreeOnlineEvent.decodeProductionLine(TextFreeOnlineEvent.encodeJSONL(silent))
        #expect(decoded.typingSpeedBucket == "medium")

        let shown = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 3_000),
            sessionDigestSHA256: String(repeating: "c", count: 64),
            appCategory: "prose",
            register: "prose",
            boundary: "mid-word",
            typingSpeedBucket: .slow,
            safeOpportunity: true,
            candidateCharacters: 5,
            candidateWordCount: 1,
            candidateSource: .dictionary,
            opportunityCharacters: 3
        )
        #expect(try shown.eventWithoutAcceptedSpan().typingSpeedBucket == "slow")
        // Older call sites that pass nothing still write the honest default.
        let legacy = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 3_000),
            sessionDigestSHA256: String(repeating: "c", count: 64),
            appCategory: "prose",
            register: "prose",
            boundary: "mid-word",
            safeOpportunity: true,
            candidateCharacters: 5,
            candidateWordCount: 1,
            candidateSource: .dictionary,
            opportunityCharacters: 3
        )
        #expect(try legacy.eventWithoutAcceptedSpan().typingSpeedBucket == "unknown")
    }
}

enum TypingCadenceTrackerTestsSupport {
    static func tracker(intervals: [Int]) -> TypingCadenceTracker {
        var tracker = TypingCadenceTracker()
        var clock: TimeInterval = 10
        tracker.noteKeystroke(atUptime: clock)
        for interval in intervals {
            clock += Double(interval) / 1_000
            tracker.noteKeystroke(atUptime: clock)
        }
        return tracker
    }

    /// Median stride 130 ms, upper stride 140 ms.
    static func fastTracker() -> TypingCadenceTracker {
        tracker(intervals: [120, 130, 140, 125, 135])
    }
}
