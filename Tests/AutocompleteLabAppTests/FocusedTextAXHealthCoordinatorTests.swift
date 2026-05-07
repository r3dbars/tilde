import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Focused text AX health coordinator")
struct FocusedTextAXHealthCoordinatorTests {
    @Test("Repeated slow reads start a cooldown")
    func repeatedSlowReadsStartCooldown() throws {
        var coordinator = FocusedTextAXHealthCoordinator(
            policy: FocusedTextAXHealthPolicy(
                slowReadDurationMilliseconds: 80,
                repeatedSlowReadCount: 2,
                cooldownMilliseconds: 500
            )
        )
        let now = Date(timeIntervalSince1970: 100)

        _ = coordinator.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now
        )
        let observation = coordinator.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 100,
            now: now.addingTimeInterval(0.1)
        )

        let cooldown = try #require(observation.cooldown)
        #expect(observation.didStartCooldown)
        #expect(cooldown.bundleIdentifier == "com.example.Editor")
        #expect(cooldown.reason == .readDuration)
        #expect(cooldown.cooldownMilliseconds == 500)
    }

    @Test("Poll decision returns active cooldown and later recovery")
    func pollDecisionReturnsCooldownAndRecovery() {
        var coordinator = FocusedTextAXHealthCoordinator(
            policy: FocusedTextAXHealthPolicy(
                slowReadDurationMilliseconds: 80,
                repeatedSlowReadCount: 2,
                cooldownMilliseconds: 500
            )
        )
        let now = Date(timeIntervalSince1970: 100)

        _ = coordinator.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now
        )
        _ = coordinator.recordRead(
            bundleIdentifier: "com.example.Editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 90,
            now: now.addingTimeInterval(0.1)
        )

        switch coordinator.pollDecision(
            for: "com.example.Editor",
            now: now.addingTimeInterval(0.2)
        ) {
        case let .coolingDown(cooldown):
            #expect(cooldown.remainingMilliseconds == 400)
        case .allowed:
            Issue.record("Expected active cooldown")
        }

        switch coordinator.pollDecision(
            for: "com.example.Editor",
            now: now.addingTimeInterval(0.7)
        ) {
        case let .allowed(recovery?):
            #expect(recovery.bundleIdentifier == "com.example.Editor")
            #expect(recovery.reason == .readDuration)
            #expect(recovery.cooldownMilliseconds == 500)
        case let decision:
            Issue.record("Expected cooldown recovery, got \(decision)")
        }
    }
}
