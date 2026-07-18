import AutocompleteLabCore
import Foundation

/// Owns global suggestion pause state, persistence, and timed-expiration scheduling.
/// User-facing cleanup, diagnostics, and menu updates remain in AppDelegate.
@MainActor
final class SuggestionPauseStateHost {
    private static let pausedDefaultsKey = "SuggestionsPaused"
    private static let pausedUntilDefaultsKey = "SuggestionsPausedUntil"

    private let controlPolicy: SuggestionControlPolicy
    private let schedulePolicy: SuggestionPauseSchedulePolicy
    private let defaults: UserDefaults
    private let onTimedPauseEnded: @MainActor () -> Void
    private var expirationTask: Task<Void, Never>?
    private(set) var state = SuggestionPauseScheduleState(isPaused: false, pausedUntil: nil)

    init(
        controlPolicy: SuggestionControlPolicy = SuggestionControlPolicy(),
        schedulePolicy: SuggestionPauseSchedulePolicy = SuggestionPauseSchedulePolicy(),
        defaults: UserDefaults = .standard,
        onTimedPauseEnded: @escaping @MainActor () -> Void = {}
    ) {
        self.controlPolicy = controlPolicy
        self.schedulePolicy = schedulePolicy
        self.defaults = defaults
        self.onTimedPauseEnded = onTimedPauseEnded
    }

    var isPaused: Bool {
        state.isPaused
    }

    var pausedUntil: Date? {
        state.pausedUntil
    }

    var controlState: SuggestionControlState {
        expireTimedPauseIfNeeded(now: Date())
        return controlPolicy.state(isPaused: state.isPaused)
    }

    func load(now: Date = Date()) {
        let pausedUntilValue = defaults.double(forKey: Self.pausedUntilDefaultsKey)
        let pausedUntil = pausedUntilValue > 0 ? Date(timeIntervalSince1970: pausedUntilValue) : nil
        let persistedIsPaused = defaults.object(forKey: Self.pausedDefaultsKey) as? Bool
        let startupState = controlPolicy.startupState(persistedIsPaused: persistedIsPaused)
        state = schedulePolicy.normalizedState(
            isPaused: startupState.isPaused,
            pausedUntil: pausedUntil,
            now: now
        )
        persist()
        scheduleExpiration()
    }

    func toggle() -> SuggestionControlTransition {
        expireTimedPauseIfNeeded(now: Date())
        let transition = controlPolicy.toggle(controlPolicy.state(isPaused: state.isPaused))
        state = SuggestionPauseScheduleState(
            isPaused: transition.nextState.isPaused,
            pausedUntil: nil
        )
        persist()
        cancelExpiration()
        return transition
    }

    func applyScheduledPause(_ nextState: SuggestionPauseScheduleState) {
        state = nextState
        persist()
        scheduleExpiration()
    }

    func expireTimedPauseIfNeeded(now: Date) {
        let normalizedState = schedulePolicy.normalizedState(
            isPaused: state.isPaused,
            pausedUntil: state.pausedUntil,
            now: now
        )
        guard normalizedState != state else {
            return
        }

        state = normalizedState
        persist()
        if !state.isPaused {
            cancelExpiration()
            onTimedPauseEnded()
        }
    }

    func stop() {
        cancelExpiration()
    }

    private func persist() {
        defaults.set(state.isPaused, forKey: Self.pausedDefaultsKey)
        if let pausedUntil = state.pausedUntil {
            defaults.set(pausedUntil.timeIntervalSince1970, forKey: Self.pausedUntilDefaultsKey)
        } else {
            defaults.removeObject(forKey: Self.pausedUntilDefaultsKey)
        }
    }

    private func scheduleExpiration() {
        cancelExpiration()

        guard state.isPaused, let pausedUntil = state.pausedUntil else {
            return
        }

        let delay = max(0, pausedUntil.timeIntervalSinceNow)
        expirationTask = Task { @MainActor [weak self, pausedUntil] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.expireTimedPauseIfNeeded(now: pausedUntil)
        }
    }

    private func cancelExpiration() {
        expirationTask?.cancel()
        expirationTask = nil
    }
}
