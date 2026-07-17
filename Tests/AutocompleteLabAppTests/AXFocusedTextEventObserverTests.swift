import ApplicationServices
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("AX focused text event coalescer")
struct AXFocusedTextEventObserverTests {
    @Test("Stop invalidates an activation captured by the old lifecycle")
    func stopInvalidatesPendingActivation() {
        var lifecycle = AXFocusedTextObserverLifecycle()
        let pendingActivationGeneration = lifecycle.start()

        lifecycle.stop()

        #expect(!lifecycle.isStarted)
        #expect(!lifecycle.accepts(generation: pendingActivationGeneration))
    }

    @Test("Restart accepts only the new observer generation")
    func restartRejectsStaleLifecycle() {
        var lifecycle = AXFocusedTextObserverLifecycle()
        let staleGeneration = lifecycle.start()
        lifecycle.stop()
        let currentGeneration = lifecycle.start()

        #expect(currentGeneration != staleGeneration)
        #expect(!lifecycle.accepts(generation: staleGeneration))
        #expect(lifecycle.accepts(generation: currentGeneration))
    }

    @Test("App switches invalidate setup retries from the old target")
    func appSwitchInvalidatesSetupRetry() {
        var target = AXFocusedTextObservationTarget()
        let staleGeneration = target.begin(processIdentifier: 41)
        let currentGeneration = target.begin(processIdentifier: 42)

        #expect(!target.accepts(processIdentifier: 41, generation: staleGeneration))
        #expect(target.accepts(processIdentifier: 42, generation: currentGeneration))

        target.cancel()

        #expect(!target.accepts(processIdentifier: 42, generation: currentGeneration))
    }

    @Test("Setup retries are transient-only and bounded")
    func setupRetriesAreTransientOnlyAndBounded() {
        let policy = AXFocusedTextSetupRetryPolicy(
            maximumRetryAttempts: 2,
            delayMilliseconds: 25
        )

        #expect(policy.next(after: .cannotComplete, failedAttempt: 0) == .init(
            attempt: 1,
            delayMilliseconds: 25
        ))
        #expect(policy.next(after: .noValue, failedAttempt: 1) == .init(
            attempt: 2,
            delayMilliseconds: 25
        ))
        #expect(policy.next(after: .cannotComplete, failedAttempt: 2) == nil)
        #expect(policy.next(after: .apiDisabled, failedAttempt: 0) == nil)
        #expect(policy.firstRetryableError(in: [.success, .cannotComplete]) == .cannotComplete)
        #expect(policy.firstRetryableError(in: [.success, .notificationUnsupported]) == nil)
    }

    @Test("AX messaging uses the same bounded timeout as focused-text reads")
    func axMessagingTimeoutIsBounded() {
        let recorder = AXMessagingTimeoutRecorder()
        let configurator = AXFocusedTextMessagingTimeoutConfigurator { _, timeout in
            recorder.record(timeout)
            return .success
        }

        let result = configurator.configure(AXUIElementCreateSystemWide())

        #expect(result == .success)
        #expect(recorder.timeouts == [0.12])
    }

    @Test("Coalesces an AX notification burst into one delivery")
    func coalescesBurst() {
        let recorder = AXEventBurstRecorder()
        let delivered = DispatchSemaphore(value: 0)
        let coalescer = AXFocusedTextEventCoalescer(interval: 0.01) { burst in
            recorder.append(burst)
            delivered.signal()
        }

        coalescer.submit(processIdentifier: 42, notification: .valueChanged)
        coalescer.submit(processIdentifier: 42, notification: .selectedTextChanged)
        coalescer.submit(processIdentifier: 42, notification: .valueChanged)

        #expect(delivered.wait(timeout: .now() + 1) == .success)
        Thread.sleep(forTimeInterval: 0.03)
        #expect(recorder.bursts == [
            AXFocusedTextEventBurst(
                processIdentifier: 42,
                notifications: [.valueChanged, .selectedTextChanged]
            )
        ])
    }

    @Test("Delivers separate bursts outside the coalescing window")
    func deliversSeparateBursts() {
        let recorder = AXEventBurstRecorder()
        let delivered = DispatchSemaphore(value: 0)
        let coalescer = AXFocusedTextEventCoalescer(interval: 0.01) { burst in
            recorder.append(burst)
            delivered.signal()
        }

        coalescer.submit(processIdentifier: 42, notification: .valueChanged)
        #expect(delivered.wait(timeout: .now() + 1) == .success)
        coalescer.submit(processIdentifier: 42, notification: .selectedTextChanged)
        #expect(delivered.wait(timeout: .now() + 1) == .success)

        #expect(recorder.bursts.count == 2)
        #expect(recorder.bursts[0].notifications == [.valueChanged])
        #expect(recorder.bursts[1].notifications == [.selectedTextChanged])
    }

    @Test("Switching apps drops the stale pending burst")
    func switchingAppsDropsStaleBurst() {
        let recorder = AXEventBurstRecorder()
        let delivered = DispatchSemaphore(value: 0)
        let coalescer = AXFocusedTextEventCoalescer(interval: 0.02) { burst in
            recorder.append(burst)
            delivered.signal()
        }

        coalescer.submit(processIdentifier: 41, notification: .valueChanged)
        coalescer.submit(processIdentifier: 42, notification: .focusedUIElementChanged)

        #expect(delivered.wait(timeout: .now() + 1) == .success)
        Thread.sleep(forTimeInterval: 0.03)
        #expect(recorder.bursts == [
            AXFocusedTextEventBurst(
                processIdentifier: 42,
                notifications: [.focusedUIElementChanged]
            )
        ])
    }

    @Test("Cancellation prevents a pending delivery")
    func cancellationPreventsDelivery() {
        let recorder = AXEventBurstRecorder()
        let delivered = DispatchSemaphore(value: 0)
        let coalescer = AXFocusedTextEventCoalescer(interval: 0.02) { burst in
            recorder.append(burst)
            delivered.signal()
        }

        coalescer.submit(processIdentifier: 42, notification: .valueChanged)
        coalescer.cancelPending()

        #expect(delivered.wait(timeout: .now() + 0.08) == .timedOut)
        #expect(recorder.bursts.isEmpty)
    }

    @Test("Cancellation waits for an in-flight delivery handoff")
    func cancellationWaitsForInFlightDelivery() {
        let deliveryStarted = DispatchSemaphore(value: 0)
        let releaseDelivery = DispatchSemaphore(value: 0)
        let cancellationStarted = DispatchSemaphore(value: 0)
        let cancellationReturned = DispatchSemaphore(value: 0)
        let coalescer = AXFocusedTextEventCoalescer(interval: 0.01) { _ in
            deliveryStarted.signal()
            _ = releaseDelivery.wait(timeout: .now() + 1)
        }

        coalescer.submit(processIdentifier: 42, notification: .valueChanged)
        #expect(deliveryStarted.wait(timeout: .now() + 1) == .success)

        DispatchQueue.global().async {
            cancellationStarted.signal()
            coalescer.cancelPending()
            cancellationReturned.signal()
        }

        #expect(cancellationStarted.wait(timeout: .now() + 1) == .success)
        let returnedBeforeDeliveryFinished = cancellationReturned.wait(timeout: .now() + 0.08)
        releaseDelivery.signal()

        if returnedBeforeDeliveryFinished == .timedOut {
            #expect(cancellationReturned.wait(timeout: .now() + 1) == .success)
        }
        #expect(returnedBeforeDeliveryFinished == .timedOut)
    }
}

private final class AXEventBurstRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AXFocusedTextEventBurst] = []

    var bursts: [AXFocusedTextEventBurst] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ burst: AXFocusedTextEventBurst) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(burst)
    }
}

private final class AXMessagingTimeoutRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float] = []

    var timeouts: [Float] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ timeout: Float) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(timeout)
    }
}
