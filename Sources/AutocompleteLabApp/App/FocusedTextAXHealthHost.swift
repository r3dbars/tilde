import AutocompleteLabCore
import Foundation

/// Owns mutable per-app AX health state while the core policy owns all thresholds.
@MainActor
final class FocusedTextAXHealthHost {
    private let policy: FocusedTextAXHealthPolicy
    private var state = FocusedTextAXHealthState()

    init(policy: FocusedTextAXHealthPolicy = .typingResponsiveness) {
        self.policy = policy
    }

    func pollDecision(
        for bundleIdentifier: String,
        now: Date
    ) -> FocusedTextAXHealthPollDecision {
        policy.pollDecision(
            for: bundleIdentifier,
            now: now,
            state: &state
        )
    }

    func recordRead(
        bundleIdentifier: String,
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int,
        hasContext: Bool,
        now: Date
    ) -> FocusedTextAXHealthObservation {
        policy.recordRead(
            bundleIdentifier: bundleIdentifier,
            queueDelayMilliseconds: queueDelayMilliseconds,
            readDurationMilliseconds: readDurationMilliseconds,
            hasContext: hasContext,
            now: now,
            state: &state
        )
    }
}
