import AutocompleteLabCore
import Foundation

struct FocusedTextAXHealthCoordinator: Equatable {
    var policy: FocusedTextAXHealthPolicy
    private var state: FocusedTextAXHealthState

    init(
        policy: FocusedTextAXHealthPolicy = .typingResponsiveness,
        state: FocusedTextAXHealthState = FocusedTextAXHealthState()
    ) {
        self.policy = policy
        self.state = state
    }

    mutating func pollDecision(
        for bundleIdentifier: String,
        now: Date = Date()
    ) -> FocusedTextAXHealthPollDecision {
        policy.pollDecision(
            for: bundleIdentifier,
            now: now,
            state: &state
        )
    }

    mutating func recordRead(
        bundleIdentifier: String,
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int,
        now: Date = Date()
    ) -> FocusedTextAXHealthObservation {
        policy.recordRead(
            bundleIdentifier: bundleIdentifier,
            queueDelayMilliseconds: queueDelayMilliseconds,
            readDurationMilliseconds: readDurationMilliseconds,
            now: now,
            state: &state
        )
    }
}
