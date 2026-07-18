import AutocompleteLabCore
import Foundation

struct KeyboardEventCaptureIdleState: Sendable {
    let hasVisibleSuggestion: Bool
    let isSuggestionPanelVisible: Bool
    let hasPendingAcceptedInsertionUndo: Bool
}

/// Owns the native keyboard event-tap lifecycle.
///
/// AppDelegate supplies the current snapshot and behavior callbacks; this
/// host keeps the global event tap, idle shutdown, and native diagnostics out
/// of the suggestion coordinator.
@MainActor
final class KeyboardEventCaptureHost {
    private let keyboardEventTapPolicy = KeyboardEventTapConsumptionPolicy()
    private let keyboardEventTapIdleStopDelayMilliseconds: Int
    private let handler: KeyboardEventTap.Handler
    private let passthroughKeyDownObserver: KeyboardEventTap.PassthroughKeyDownObserver
    private let passthroughTypingMatchObserver: KeyboardEventTap.PassthroughTypingMatchObserver
    private let disabledObserver: KeyboardEventTap.DisabledObserver
    private let idleStateProvider: @MainActor @Sendable () -> KeyboardEventCaptureIdleState

    private var keyboardEventTap: KeyboardEventTap?
    private var keyboardEventTapStopTask: Task<Void, Never>?

    init(
        keyboardEventTapIdleStopDelayMilliseconds: Int = 700,
        handler: @escaping KeyboardEventTap.Handler,
        passthroughKeyDownObserver: @escaping KeyboardEventTap.PassthroughKeyDownObserver,
        passthroughTypingMatchObserver: @escaping KeyboardEventTap.PassthroughTypingMatchObserver,
        disabledObserver: @escaping KeyboardEventTap.DisabledObserver,
        idleStateProvider: @escaping @MainActor @Sendable () -> KeyboardEventCaptureIdleState
    ) {
        self.keyboardEventTapIdleStopDelayMilliseconds = keyboardEventTapIdleStopDelayMilliseconds
        self.handler = handler
        self.passthroughKeyDownObserver = passthroughKeyDownObserver
        self.passthroughTypingMatchObserver = passthroughTypingMatchObserver
        self.disabledObserver = disabledObserver
        self.idleStateProvider = idleStateProvider
    }

    @discardableResult
    func startIfPossible(
        isTrustedForAccessibility: Bool,
        hasVisibleSuggestion: Bool,
        controlState: SuggestionControlState,
        snapshot: KeyboardEventTapSnapshot
    ) -> Bool {
        cancelIdleStop()

        guard keyboardEventTap == nil else {
            return true
        }

        guard keyboardEventTapPolicy.shouldCaptureKeys(
            isTrustedForAccessibility: isTrustedForAccessibility,
            hasVisibleSuggestion: hasVisibleSuggestion,
            controlState: controlState
        ) else {
            return false
        }

        let eventTap = KeyboardEventTap(
            handler: handler,
            passthroughKeyDownObserver: passthroughKeyDownObserver,
            passthroughTypingMatchObserver: passthroughTypingMatchObserver,
            disabledObserver: disabledObserver
        )
        eventTap.updateSnapshot(snapshot)

        if eventTap.start() {
            keyboardEventTap = eventTap
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-started",
                metadata: [
                    "diagnosticLayer": "keyCapture",
                    "tapLocation": eventTap.tapPlacement.rawValue
                ]
            )
            return true
        }

        DiagnosticsLog.shared.record(
            "keyboard-event-tap-start-failed",
            metadata: [
                "diagnosticLayer": "keyCapture",
                "safetyFailure": "true"
            ]
        )
        return false
    }

    func updateSnapshot(_ snapshot: KeyboardEventTapSnapshot) {
        keyboardEventTap?.updateSnapshot(snapshot)
    }

    @discardableResult
    func activateForSuggestionPresentation(
        isTrustedForAccessibility: Bool,
        hasVisibleSuggestion: Bool,
        controlState: SuggestionControlState,
        snapshot: KeyboardEventTapSnapshot
    ) -> Bool {
        resetPassthroughObservation()
        updateSnapshot(snapshot)
        guard startIfPossible(
            isTrustedForAccessibility: isTrustedForAccessibility,
            hasVisibleSuggestion: hasVisibleSuggestion,
            controlState: controlState,
            snapshot: snapshot
        ) else {
            return false
        }

        suppressPassthroughObservation(for: 0.35)
        return true
    }

    func resetPassthroughObservation() {
        keyboardEventTap?.resetPassthroughObservation()
    }

    func suppressPassthroughObservation(for seconds: TimeInterval) {
        keyboardEventTap?.suppressPassthroughObservation(for: seconds)
    }

    func suppressPassthroughObservation(until date: Date) {
        keyboardEventTap?.suppressPassthroughObservation(until: date)
    }

    func scheduleStopIfIdle() {
        guard keyboardEventTap != nil else {
            return
        }

        keyboardEventTapStopTask?.cancel()
        let idleStopDelayMilliseconds = keyboardEventTapIdleStopDelayMilliseconds
        keyboardEventTapStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(idleStopDelayMilliseconds))
            guard !Task.isCancelled, let self else {
                return
            }

            let idleState = self.idleStateProvider()
            guard self.keyboardEventTapPolicy.shouldStopKeyboardCapture(
                hasVisibleSuggestion: idleState.hasVisibleSuggestion,
                isSuggestionPanelVisible: idleState.isSuggestionPanelVisible,
                hasPendingAcceptedInsertionUndo: idleState.hasPendingAcceptedInsertionUndo
            ) else {
                return
            }

            self.stopNow(reason: "idle")
        }
    }

    func cancelIdleStop() {
        keyboardEventTapStopTask?.cancel()
        keyboardEventTapStopTask = nil
    }

    func stopNow(reason: String) {
        cancelIdleStop()

        guard let keyboardEventTap else {
            return
        }

        keyboardEventTap.stop(reason: reason)
        self.keyboardEventTap = nil
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-stopped",
            metadata: [
                "reason": reason
            ]
        )
    }
}
