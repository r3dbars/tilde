@testable import AutocompleteLabApp
import AutocompleteLabCore
import Foundation
import Testing

@Suite("Focused text AX health host")
@MainActor
struct FocusedTextAXHealthHostTests {
    @Test("keeps policy state between reads and poll decisions")
    func keepsPolicyStateBetweenReadsAndPollDecisions() {
        let host = FocusedTextAXHealthHost(
            policy: FocusedTextAXHealthPolicy(
                slowReadDurationMilliseconds: 10,
                missingContextSlowReadCount: 1,
                cooldownMilliseconds: 500
            )
        )
        let now = Date()

        let observation = host.recordRead(
            bundleIdentifier: "com.example.editor",
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 20,
            hasContext: false,
            now: now
        )

        #expect(observation.didStartCooldown)
        if case let .coolingDown(cooldown) = host.pollDecision(
            for: "com.example.editor",
            now: now
        ) {
            #expect(cooldown.bundleIdentifier == "com.example.editor")
        } else {
            Issue.record("Expected the host to retain the policy cooldown state")
        }
    }

    @Test("returns an allowed decision for an untracked app")
    func returnsAllowedDecisionForAnUntrackedApp() {
        let host = FocusedTextAXHealthHost()

        #expect(host.pollDecision(for: "com.example.editor", now: Date()) == .allowed(recovery: nil))
    }
}
