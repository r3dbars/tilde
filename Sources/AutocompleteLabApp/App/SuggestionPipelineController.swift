import AutocompleteLabCore
import Foundation

/// Signals the polling driver needs from the host to decide whether a focused-text
/// poll should run right now. Computing these requires app-layer knowledge (frontmost
/// app, compatibility profile, suggestion visibility), so the host supplies them and the
/// controller owns the pure cadence policy that consumes them.
struct FocusPollingCadenceSignals {
    var isTrustedForAccessibility: Bool
    var hasSupportedProfile: Bool
    var hasVisibleSuggestion: Bool
    var hasPersonalCapture: Bool
    var lastFocusedTextChangeAt: Date?
}

/// The app-layer surface the focused-text polling driver delegates back to.
///
/// `SuggestionPipelineController` owns *when* and *how often* the focused text is sampled
/// (timer, cadence, in-flight guard, throttle/pause, latency/skip bookkeeping). It does not
/// own *what* a poll does — reading Accessibility, resolving the compatibility profile,
/// processing the resulting context, and hiding/preserving the visible suggestion all stay
/// in `AppDelegate` and are reached through this protocol.
@MainActor
protocol SuggestionPipelineHost: AnyObject {
    /// App-computed inputs for the cadence decision (frontmost profile, trust, visibility).
    func focusedTextPollCadenceSignals() -> FocusPollingCadenceSignals

    /// Perform one focused-text poll (Accessibility read + dispatch). Returns whether the
    /// poll completes asynchronously (the host will call `finishPoll` from its async
    /// completion handler in that case).
    func executeFocusedTextPoll(startedAt: UInt64) -> Bool

    /// Apply a throttle recommendation that may hide or preserve the visible suggestion.
    /// Pause bookkeeping is handled by the controller; this callback covers only the
    /// app-owned suggestion-visibility side effects.
    func applyFocusedTextPollingThrottle(_ recommendation: FocusedTextPollingThrottleRecommendation)
}

/// First decomposition slice carved out of the `AppDelegate` god object: the focused-text
/// **polling driver** — the head of the suggestion pipeline.
///
/// This owns the repeating poll timer, the in-flight guard, the AX-read identity used to drop
/// stale reads, the latency/skip diagnostics, the typing/insertion poll pause, and the pure
/// cadence/backoff/diagnostics policies. `AppDelegate` holds one of these and delegates the
/// timing concerns to it while retaining the execution and suggestion-presentation logic
/// behind `SuggestionPipelineHost`.
///
/// Behavior is intentionally identical to the previous in-`AppDelegate` implementation; this
/// is a pure relocation. See the file footer for the remaining pipeline stages still living in
/// `AppDelegate` (keystroke trigger scheduling, request lifecycle, display/suppression
/// dispatch) that future slices should migrate into this controller.
@MainActor
final class SuggestionPipelineController {
    private unowned let host: SuggestionPipelineHost

    // Polling cadence policies (pure, stateless value types).
    private let cadencePolicy = FocusPollingCadencePolicy()
    private let backoffPolicy = FocusedTextPollingBackoffPolicy.typingBackoff
    private let diagnosticsPolicy = FocusedTextPollDiagnosticsPolicy.typingDiagnostics

    // Polling driver state.
    private let pollInterval: TimeInterval = 0.08
    private var pollTimer: Timer?
    private var requestedPollTask: Task<Void, Never>?
    private var isPollInFlightStorage = false
    private var lastPollAttemptAt: Date?
    private var latestReadRequestID: UInt64?
    private var latencyStats = FocusedTextPollLatencyStats()
    private var skipStats = FocusedTextPollSkipStats()
    private var pollingPause = FocusedTextPollingPause()
    private var accessibilityBackoffPause = FocusedTextPollingPause()

    init(host: SuggestionPipelineHost) {
        self.host = host
    }

    // MARK: - Timer lifecycle

    func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedTextIfIdle()
            }
        }
        timer.tolerance = pollInterval / 2
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        requestedPollTask?.cancel()
        requestedPollTask = nil
    }

    /// Coalesces passthrough typing into a near-immediate focused-text read. This bypasses
    /// only the repeating timer cadence; the host still applies every normal AX, privacy,
    /// focus identity, activation, placement, and freshness guard.
    func requestPollSoon(afterMilliseconds delayMilliseconds: Int) {
        requestedPollTask?.cancel()
        // A keystroke makes the normal typing pause obsolete, but it must not
        // erase a backoff installed after a slow Accessibility read.
        pollingPause = FocusedTextPollingPause()

        requestedPollTask = Task { @MainActor [weak self] in
            guard delayMilliseconds > 0 else {
                self?.requestedPollTask = nil
                self?.pollFocusedTextIfIdle(bypassingCadence: true)
                return
            }

            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else {
                return
            }

            self?.requestedPollTask = nil
            self?.pollFocusedTextIfIdle(bypassingCadence: true)
        }
    }

    // MARK: - In-flight guard (shared with the host's manual-suggestion path)

    var isPollInFlight: Bool {
        isPollInFlightStorage
    }

    func notePollAttempt(at now: Date) {
        lastPollAttemptAt = now
    }

    func beginInFlightPoll() {
        isPollInFlightStorage = true
    }

    /// AX-read identity bookkeeping used to drop stale reads.
    func noteReadStarted(requestID: UInt64) {
        latestReadRequestID = requestID
    }

    func isCurrentRead(_ requestID: UInt64) -> Bool {
        latestReadRequestID == requestID
    }

    // MARK: - Cadence-gated idle poll (timer entry point)

    private func pollFocusedTextIfIdle(bypassingCadence: Bool = false) {
        let now = Date()
        guard !accessibilityBackoffPause.isPaused(now: now) else {
            return
        }

        if bypassingCadence {
            let signals = host.focusedTextPollCadenceSignals()
            guard signals.isTrustedForAccessibility,
                  signals.hasSupportedProfile || signals.hasPersonalCapture else {
                return
            }
        } else {
            guard shouldRunFocusedTextPoll(now: now) else {
                return
            }
        }

        guard !isPollInFlightStorage else {
            guard backoffPolicy.shouldRecordInFlightSkip(
                lastPollAttemptAt: lastPollAttemptAt,
                now: now
            ) else {
                return
            }

            lastPollAttemptAt = now
            if let notice = skipStats.recordSkippedInFlight(now: now) {
                DiagnosticsLog.shared.record(
                    "focused-text-poll-skipped",
                    metadata: [
                        "reason": "in-flight",
                        "count": String(notice.count)
                    ]
                )
            }
            return
        }

        lastPollAttemptAt = now
        isPollInFlightStorage = true
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let completesAsync = host.executeFocusedTextPoll(startedAt: startedAt)
        if !completesAsync {
            finishPoll(startedAt: startedAt)
        }
    }

    private func shouldRunFocusedTextPoll(now: Date) -> Bool {
        let signals = host.focusedTextPollCadenceSignals()
        let hasRecentTextChange = cadencePolicy.hasRecentTextChange(
            lastTextChangeAt: signals.lastFocusedTextChangeAt,
            now: now
        )

        return cadencePolicy.shouldPoll(
            now: now,
            lastPollAt: lastPollAttemptAt,
            isTrustedForAccessibility: signals.isTrustedForAccessibility,
            hasSupportedProfile: signals.hasSupportedProfile || signals.hasPersonalCapture,
            hasVisibleSuggestion: signals.hasVisibleSuggestion,
            hasRecentTextChange: hasRecentTextChange
        )
    }

    // MARK: - Poll completion bookkeeping

    /// Closes out a poll: records latency/skip diagnostics and clears the in-flight guard.
    /// Called from the controller's own synchronous path and from the host's async read
    /// completion handlers.
    func finishPoll(
        startedAt: UInt64,
        latencySummarySuppressionReason: String? = nil
    ) {
        let endedAt = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Int((endedAt - startedAt) / 1_000_000)
        isPollInFlightStorage = false
        latestReadRequestID = nil
        recordPollLatency(
            durationMilliseconds,
            summarySuppressionReason: latencySummarySuppressionReason
        )
        recordPollSkipSummaryIfNeeded()
    }

    private func recordPollLatency(
        _ durationMilliseconds: Int,
        summarySuppressionReason: String? = nil
    ) {
        if diagnosticsPolicy.shouldRecordSlowPollMarker(
            durationMilliseconds: durationMilliseconds
        ) {
            DiagnosticsLog.shared.record(
                "focused-text-poll-latency-slow",
                metadata: [
                    "durationMilliseconds": String(durationMilliseconds)
                ]
            )
        }

        if let summarySuppressionReason {
            DiagnosticsLog.shared.record(
                "focused-text-poll-latency-summary-suppressed",
                metadata: [
                    "durationMilliseconds": String(durationMilliseconds),
                    "reason": summarySuppressionReason
                ]
            )
            return
        }

        if let summary = latencyStats.record(durationMilliseconds) {
            DiagnosticsLog.shared.record(
                "focused-text-poll-latency-summary",
                metadata: [
                    "count": String(summary.count),
                    "p50Milliseconds": String(summary.p50Milliseconds),
                    "p90Milliseconds": String(summary.p90Milliseconds),
                    "p95Milliseconds": String(summary.p95Milliseconds),
                    "p99Milliseconds": String(summary.p99Milliseconds),
                    "maxMilliseconds": String(summary.maxMilliseconds)
                ]
            )
            host.applyFocusedTextPollingThrottle(
                backoffPolicy.throttleRecommendation(
                    latencySummary: summary,
                    skipSummary: nil
                )
            )
        }
    }

    private func recordPollSkipSummaryIfNeeded() {
        guard let summary = skipStats.drain(now: Date()) else {
            return
        }

        DiagnosticsLog.shared.record(
            "focused-text-poll-skip-summary",
            metadata: [
                "reason": "in-flight",
                "count": String(summary.count),
                "durationMilliseconds": String(summary.durationMilliseconds)
            ]
        )
        host.applyFocusedTextPollingThrottle(
            backoffPolicy.throttleRecommendation(
                latencySummary: nil,
                skipSummary: summary
            )
        )
    }

    // MARK: - Throttle / pause coordination

    /// Pause after the current AX read has been processed (pure cadence side effect; no
    /// suggestion visibility changes).
    func pauseAfterProcessingCurrentAXRead(
        _ recommendation: FocusedTextPollingThrottleRecommendation
    ) {
        guard recommendation.shouldThrottle,
              let reason = recommendation.reason,
              recommendation.pauseMilliseconds > 0 else {
            return
        }

        accessibilityBackoffPause.pause(
            now: Date(),
            durationMilliseconds: recommendation.pauseMilliseconds,
            policy: backoffPolicy
        )
        DiagnosticsLog.shared.record(
            "focused-text-poll-throttled",
            metadata: [
                "reason": reason.rawValue,
                "pauseMilliseconds": String(recommendation.pauseMilliseconds),
                "currentRead": "processed"
            ]
        )
    }

    // MARK: - Pause state (typing / insertion / throttle / manual reset)

    func pausePolling(now: Date, durationMilliseconds: Int) {
        requestedPollTask?.cancel()
        requestedPollTask = nil
        pollingPause.pause(now: now, durationMilliseconds: durationMilliseconds)
    }

    func pausePollingWithBackoff(now: Date, durationMilliseconds: Int) {
        accessibilityBackoffPause.pause(
            now: now,
            durationMilliseconds: durationMilliseconds,
            policy: backoffPolicy
        )
    }

    func isPollingPaused(now: Date) -> Bool {
        pollingPause.isPaused(now: now) || accessibilityBackoffPause.isPaused(now: now)
    }

    func resetPollingPause() {
        pollingPause = FocusedTextPollingPause()
        accessibilityBackoffPause = FocusedTextPollingPause()
    }

    // MARK: - Thin policy pass-throughs for the host's async completion path

    func throttleRecommendation(
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int
    ) -> FocusedTextPollingThrottleRecommendation {
        backoffPolicy.throttleRecommendation(
            queueDelayMilliseconds: queueDelayMilliseconds,
            readDurationMilliseconds: readDurationMilliseconds
        )
    }

    func shouldProcessCurrentAXReadBeforeThrottle(hasContext: Bool) -> Bool {
        backoffPolicy.shouldProcessCurrentAXReadBeforeThrottle(hasContext: hasContext)
    }

    func shouldRecordSlowAXReadMarker(
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int
    ) -> Bool {
        diagnosticsPolicy.shouldRecordSlowAXReadMarker(
            queueDelayMilliseconds: queueDelayMilliseconds,
            readDurationMilliseconds: readDurationMilliseconds
        )
    }
}

// MARK: - Decomposition follow-ups
//
// This controller currently owns only the *focused-text polling driver* — the first of the
// four suggestion-pipeline stages called out for decomposition. The remaining stages are
// still implemented in `AppDelegate` because they are vertically fused to its shared
// "current suggestion" / `SuggestionSession` / compatibility-profile state, which has no
// zero-coupling seam. They should migrate into this controller incrementally, each behind a
// narrowed `SuggestionPipelineHost`, as that shared state is itself untangled:
//
//   1. Keystroke trigger scheduling — `observePassthroughTypingKeyDown`, the keyboard event
//      tap lifecycle, and the debounce that turns typing into a `scheduleSuggestion` call.
//   2. Request lifecycle — `scheduleSuggestion` / `presentSuggestion`, the debounce task,
//      and `invalidatePendingSuggestionRequest` / `cancelPendingSuggestionTask`.
//   3. Display / suppression dispatch — `refreshVisibleSuggestion`, `hideSuggestion`,
//      `suppressField`, and the presentation/annoyance gates.
//
// The poll *execution* itself (`pollFocusedText` / `completeFocusedTextPoll` and the
// personal-capture variants) and the suggestion-hiding throttle application
// (`applyFocusedTextPollingThrottleIfNeeded`) deliberately stay in `AppDelegate` for now and
// are reached via `SuggestionPipelineHost`; moving them depends on stages 2 and 3 above.
