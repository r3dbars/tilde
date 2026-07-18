import AutocompleteLabCore

/// Owns mutable typing-burst samples while the core policy owns thresholds.
@MainActor
final class TypingBurstStateHost {
    private let policy: TypingBurstPolicy
    private var state = TypingBurstState()

    init(policy: TypingBurstPolicy = TypingBurstPolicy()) {
        self.policy = policy
    }

    func reset() {
        state.reset()
    }

    func observe(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        nowMilliseconds: Int
    ) -> TypingBurstDecision {
        policy.observe(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor,
            nowMilliseconds: nowMilliseconds,
            state: &state
        )
    }
}
