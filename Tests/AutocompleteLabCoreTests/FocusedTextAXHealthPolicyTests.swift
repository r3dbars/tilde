import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text AX health policy")
struct FocusedTextAXHealthPolicyTests {
    @Test("One slow read does not start cooldown")
    func oneSlowReadDoesNotStartCooldown() {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 2
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        let observation = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now,
            state: &state
        )

        #expect(observation.isSlow)
        #expect(observation.slowReason == .readDuration)
        #expect(observation.slowReadCount == 1)
        #expect(observation.cooldown == nil)
    }

    @Test("Repeated slow reads cooldown the same bundle")
    func repeatedSlowReadsCooldownSameBundle() throws {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 2,
            slowReadWindowMilliseconds: 1_000,
            cooldownMilliseconds: 750
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now,
            state: &state
        )
        let observation = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 100,
            now: now.addingTimeInterval(0.2),
            state: &state
        )

        let cooldown = try #require(observation.cooldown)
        #expect(cooldown.bundleIdentifier == "com.example.Editor")
        #expect(cooldown.reason == .readDuration)
        #expect(cooldown.slowReadCount == 2)
        #expect(cooldown.cooldownMilliseconds == 750)
        #expect(cooldown.remainingMilliseconds == 750)
        #expect(isSameTime(cooldown.cooldownUntil, now.addingTimeInterval(0.95)))
    }

    @Test("Slow reads are tracked per bundle")
    func slowReadsAreTrackedPerBundle() {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 2
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        _ = policy.recordRead(
            bundleIdentifier: "com.example.One",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now,
            state: &state
        )
        let observation = policy.recordRead(
            bundleIdentifier: "com.example.Two",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now.addingTimeInterval(0.1),
            state: &state
        )

        #expect(observation.isSlow)
        #expect(observation.slowReadCount == 1)
        #expect(observation.cooldown == nil)
    }

    @Test("Fast read clears slow streak")
    func fastReadClearsSlowStreak() {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 2
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now,
            state: &state
        )
        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 20,
            now: now.addingTimeInterval(0.1),
            state: &state
        )
        let observation = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now.addingTimeInterval(0.2),
            state: &state
        )

        #expect(observation.slowReadCount == 1)
        #expect(observation.cooldown == nil)
    }

    @Test("Poll decision suppresses cooling bundle and recovers")
    func pollDecisionSuppressesCoolingBundleAndRecovers() throws {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 2,
            cooldownMilliseconds: 500
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now,
            state: &state
        )
        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now.addingTimeInterval(0.1),
            state: &state
        )

        switch policy.pollDecision(
            for: "com.example.Editor",
            now: now.addingTimeInterval(0.2),
            state: &state
        ) {
        case let .coolingDown(cooldown):
            #expect(cooldown.remainingMilliseconds == 400)
        case .allowed:
            Issue.record("Expected active cooldown")
        }

        switch policy.pollDecision(
            for: "com.example.Other",
            now: now.addingTimeInterval(0.2),
            state: &state
        ) {
        case .allowed(nil):
            break
        case let decision:
            Issue.record("Expected other bundle to stay allowed, got \(decision)")
        }

        switch policy.pollDecision(
            for: "com.example.Editor",
            now: now.addingTimeInterval(0.7),
            state: &state
        ) {
        case let .allowed(recovery?):
            #expect(recovery.bundleIdentifier == "com.example.Editor")
            #expect(recovery.reason == .readDuration)
            #expect(recovery.cooldownMilliseconds == 500)
        case let decision:
            Issue.record("Expected cooldown recovery, got \(decision)")
        }
    }

    @Test("Queue delay can start cooldown")
    func queueDelayCanStartCooldown() throws {
        let policy = FocusedTextAXHealthPolicy(
            slowQueueDelayMilliseconds: 80,
            slowReadDurationMilliseconds: 1_000,
            repeatedSlowReadCount: 2
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        _ = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 90,
            readDurationMilliseconds: 10,
            now: now,
            state: &state
        )
        let observation = policy.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 120,
            readDurationMilliseconds: 10,
            now: now.addingTimeInterval(0.1),
            state: &state
        )

        let cooldown = try #require(observation.cooldown)
        #expect(cooldown.reason == .queueDelay)
    }

    @Test("Slow reads without focused text context cooldown immediately")
    func slowReadsWithoutFocusedTextContextCooldownImmediately() throws {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            repeatedSlowReadCount: 3,
            missingContextSlowReadCount: 1,
            cooldownMilliseconds: 750
        )
        var state = FocusedTextAXHealthState()
        let now = Date(timeIntervalSince1970: 100)

        let observation = policy.recordRead(
            bundleIdentifier: "com.apple.Notes",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 145,
            hasContext: false,
            now: now,
            state: &state
        )

        let cooldown = try #require(observation.cooldown)
        #expect(observation.didStartCooldown)
        #expect(cooldown.bundleIdentifier == "com.apple.Notes")
        #expect(cooldown.reason == .readDuration)
        #expect(cooldown.slowReadCount == 1)
        #expect(cooldown.remainingMilliseconds == 750)
    }

    @Test("Fast missing context read does not cooldown")
    func fastMissingContextReadDoesNotCooldown() {
        let policy = FocusedTextAXHealthPolicy(
            slowReadDurationMilliseconds: 80,
            missingContextSlowReadCount: 1
        )
        var state = FocusedTextAXHealthState()

        let observation = policy.recordRead(
            bundleIdentifier: "com.apple.Notes",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 20,
            hasContext: false,
            now: Date(timeIntervalSince1970: 100),
            state: &state
        )

        #expect(!observation.isSlow)
        #expect(!observation.didStartCooldown)
        #expect(observation.cooldown == nil)
    }

    private func isSameTime(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 0.000_001
    }
}
