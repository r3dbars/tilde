import ApplicationServices
import AutocompleteLabCore
import Foundation

final class KeyboardEventTap: @unchecked Sendable {
    typealias Handler = @MainActor @Sendable (AutocompleteKey, Bool, Bool) -> Bool
    typealias PassthroughKeyDownObserver = @MainActor @Sendable () -> Void
    typealias DisabledObserver = @MainActor @Sendable (_ reason: String) -> Void

    private let handler: Handler
    private let passthroughKeyDownObserver: PassthroughKeyDownObserver?
    private let disabledObserver: DisabledObserver?
    private let keyMapper = AutocompleteKeyMapper()
    private let lifecycleLock = NSLock()
    private let snapshotLock = NSLock()
    private let passthroughLock = NSLock()
    private let replayLock = NSLock()
    private let latencyLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var eventThread: Thread?
    private var isStopping = false
    private var snapshot = KeyboardEventTapSnapshot()
    private var suppressKeyUntilNanos: [AutocompleteKey: UInt64] = [:]
    private var hasObservedPassthroughKeyDown = false
    private var passthroughObservationSuppressedUntilNanos: UInt64?
    private var pendingReplayedKeyDowns: [KeyboardEventReplay: KeyboardEventReplayState] = [:]
    private var latencyStats = KeyboardEventTapLatencyStats()
    private let slowEventTapLatencyMicros = 8_000
    private let keySuppressDurationNanos: UInt64 = 250_000_000
    private let replayExpirationNanos: UInt64 = 1_000_000_000

    init(
        handler: @escaping Handler,
        passthroughKeyDownObserver: PassthroughKeyDownObserver? = nil,
        disabledObserver: DisabledObserver? = nil
    ) {
        self.handler = handler
        self.passthroughKeyDownObserver = passthroughKeyDownObserver
        self.disabledObserver = disabledObserver
    }

    deinit {
        stop()
    }

    func updateSnapshot(_ snapshot: KeyboardEventTapSnapshot) {
        snapshotLock.lock()
        self.snapshot = snapshot
        snapshotLock.unlock()
    }

    func start() -> Bool {
        lifecycleLock.lock()
        let isStartingOrRunning = eventTap != nil || eventThread != nil
        lifecycleLock.unlock()

        guard !isStartingOrRunning else {
            return true
        }

        let semaphore = DispatchSemaphore(value: 0)
        let startResult = LockedStartResult()

        lifecycleLock.lock()
        isStopping = false
        lifecycleLock.unlock()

        @Sendable func finishStart(_ result: Bool) {
            startResult.set(result)
            semaphore.signal()
        }

        let thread = Thread { [weak self] in
            guard let self else {
                finishStart(false)
                return
            }

            let runLoop = CFRunLoopGetCurrent()
            let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: keyboardEventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                self.clearThreadState()
                finishStart(false)
                return
            }

            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                self.clearThreadState()
                finishStart(false)
                return
            }

            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            self.lifecycleLock.lock()
            self.eventTap = tap
            self.runLoopSource = source
            self.eventRunLoop = runLoop
            self.lifecycleLock.unlock()

            finishStart(true)
            CFRunLoopRun()
        }

        thread.name = "AutocompleteLabKeyboardEventTap"
        lifecycleLock.lock()
        eventThread = thread
        lifecycleLock.unlock()
        thread.start()

        guard semaphore.wait(timeout: .now() + 1) == .success else {
            stop()
            return false
        }

        return startResult.value
    }

    func stop(reason: String = "stop") {
        lifecycleLock.lock()
        let tap = eventTap
        let source = runLoopSource
        let runLoop = eventRunLoop
        isStopping = true
        eventTap = nil
        runLoopSource = nil
        eventRunLoop = nil
        eventThread = nil
        lifecycleLock.unlock()

        resetPassthroughObservation()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        guard let runLoop else {
            flushLatencySummary(reason: reason)
            return
        }

        let stopped = DispatchSemaphore(value: 0)
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            if let source {
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
            CFRunLoopStop(runLoop)
            stopped.signal()
        }
        CFRunLoopWakeUp(runLoop)
        _ = stopped.wait(timeout: .now() + 1)
        flushLatencySummary(reason: reason)
    }

    func resetPassthroughObservation() {
        passthroughLock.lock()
        hasObservedPassthroughKeyDown = false
        passthroughObservationSuppressedUntilNanos = nil
        passthroughLock.unlock()
    }

    func suppressPassthroughObservation(until date: Date) {
        suppressPassthroughObservation(for: max(0, date.timeIntervalSinceNow))
    }

    func suppressPassthroughObservation(for seconds: TimeInterval) {
        let durationNanos = UInt64(max(0, seconds) * 1_000_000_000)
        let untilNanos = DispatchTime.now().uptimeNanoseconds + durationNanos
        passthroughLock.lock()
        passthroughObservationSuppressedUntilNanos = max(
            passthroughObservationSuppressedUntilNanos ?? untilNanos,
            untilNanos
        )
        hasObservedPassthroughKeyDown = false
        passthroughLock.unlock()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lifecycleLock.lock()
            let shouldIgnoreDisabledCallback = isStopping || eventTap == nil
            let tap = eventTap
            lifecycleLock.unlock()

            guard !shouldIgnoreDisabledCallback else {
                return Unmanaged.passUnretained(event)
            }

            DiagnosticsLog.shared.record(
                "keyboard-event-tap-disabled",
                metadata: [
                    "reason": type == .tapDisabledByTimeout ? "timeout" : "user-input"
                ]
            )

            let reason = type == .tapDisabledByTimeout ? "timeout" : "user-input"
            if let disabledObserver {
                Task { @MainActor in
                    disabledObserver(reason)
                }
            } else if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let startedAt = DispatchTime.now().uptimeNanoseconds
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let key = keyMapper.key(
            physicalKey: AutocompletePhysicalKey(keyCode: keyCode),
            modifiers: AutocompleteKeyModifiers(flags: event.flags)
        )
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let replay = KeyboardEventReplay(keyCode: keyCode, flagsRawValue: event.flags.rawValue)

        if consumePendingReplay(replay) {
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "replay-passthrough",
                startedAt: startedAt
            )
        }

        if key == .other {
            if shouldSuppressPassthroughObservation() {
                return finish(
                    Unmanaged.passUnretained(event),
                    key: key,
                    decision: "passthrough-synthetic-insert",
                    startedAt: startedAt
                )
            }

            markPassthroughObserved()
            markSnapshotInvalidatedByTyping()
            if let passthroughKeyDownObserver {
                Task { @MainActor in
                    passthroughKeyDownObserver()
                }
            }
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-other",
                startedAt: startedAt
            )
        }

        let hadPassthroughKeyDown = consumePassthroughObservation()
        if hadPassthroughKeyDown {
            markSnapshotInvalidatedByTyping()
            if let passthroughKeyDownObserver {
                Task { @MainActor in
                    passthroughKeyDownObserver()
                }
            }
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-after-typing",
                startedAt: startedAt
            )
        }

        guard shouldConsume(key, isAutorepeat: isAutorepeat) else {
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-unsupported",
                startedAt: startedAt
            )
        }

        Task { @MainActor in
            let handled = handler(key, isAutorepeat, hadPassthroughKeyDown)
            if !handled {
                replayKey(replay)
            }
        }
        return finish(nil, key: key, decision: "consume", startedAt: startedAt)
    }

    private func finish(
        _ result: Unmanaged<CGEvent>?,
        key: AutocompleteKey,
        decision: String,
        startedAt: UInt64
    ) -> Unmanaged<CGEvent>? {
        recordEventTapLatency(key: key, decision: decision, startedAt: startedAt)
        return result
    }

    private func recordEventTapLatency(
        key: AutocompleteKey,
        decision: String,
        startedAt: UInt64
    ) {
        let elapsedMicros = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000)
        latencyLock.lock()
        let summary = latencyStats.record(elapsedMicros)
        latencyLock.unlock()

        if key != .other {
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-latency",
                metadata: [
                    "key": key.diagnosticName,
                    "decision": decision,
                    "durationMicros": String(elapsedMicros)
                ]
            )
        }

        if elapsedMicros >= slowEventTapLatencyMicros {
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-latency-slow",
                metadata: [
                    "key": key.diagnosticName,
                    "decision": decision,
                    "durationMicros": String(elapsedMicros)
                ]
            )
        }

        if let summary {
            recordLatencySummary(summary, reason: "sample-window")
        }
    }

    private func flushLatencySummary(reason: String) {
        latencyLock.lock()
        let summary = latencyStats.drain()
        latencyLock.unlock()

        if let summary {
            recordLatencySummary(summary, reason: reason)
        }
    }

    private func recordLatencySummary(
        _ summary: KeyboardEventTapLatencySummary,
        reason: String
    ) {
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-latency-summary",
            metadata: [
                "reason": reason,
                "count": String(summary.count),
                "p50Micros": String(summary.p50Micros),
                "p95Micros": String(summary.p95Micros),
                "p99Micros": String(summary.p99Micros),
                "maxMicros": String(summary.maxMicros)
            ]
        )
    }

    private func shouldConsume(_ key: AutocompleteKey, isAutorepeat: Bool) -> Bool {
        let nowNanos = DispatchTime.now().uptimeNanoseconds
        snapshotLock.lock()
        let snapshot = self.snapshot

        let canHandleUndo = key == .commandZ && snapshot.hasPendingAcceptedInsertionUndo
        guard snapshot.hasVisibleSuggestion || canHandleUndo,
              !snapshot.isInvalidatedByUserTyping else {
            suppressKeyUntilNanos.removeAll(keepingCapacity: true)
            snapshotLock.unlock()
            return false
        }

        if isAutorepeat,
           let suppressUntil = suppressKeyUntilNanos[key],
           suppressUntil > nowNanos {
            snapshotLock.unlock()
            return true
        }
        suppressKeyUntilNanos[key] = nil

        let shouldConsume: Bool
        switch key {
        case .tab:
            shouldConsume = snapshot.supportsOneWordAcceptance
        case .backtick:
            shouldConsume = snapshot.supportsFullAcceptance && snapshot.acceptAllShortcut == .backtick
        case .commandZ:
            shouldConsume = snapshot.hasPendingAcceptedInsertionUndo
        case .escape:
            shouldConsume = true
        case .optionTab:
            shouldConsume = snapshot.supportsFullAcceptance && snapshot.acceptAllShortcut == .optionTab
        case .other:
            shouldConsume = false
        }

        if shouldConsume, !isAutorepeat {
            suppressKeyUntilNanos[key] = nowNanos + keySuppressDurationNanos
        }
        snapshotLock.unlock()
        return shouldConsume
    }

    private func markSnapshotInvalidatedByTyping() {
        snapshotLock.lock()
        snapshot.isInvalidatedByUserTyping = true
        suppressKeyUntilNanos.removeAll(keepingCapacity: true)
        snapshotLock.unlock()
    }

    private func markPassthroughObserved() {
        passthroughLock.lock()
        hasObservedPassthroughKeyDown = true
        passthroughLock.unlock()
    }

    private func shouldSuppressPassthroughObservation(nowNanos: UInt64 = DispatchTime.now().uptimeNanoseconds) -> Bool {
        passthroughLock.lock()
        defer { passthroughLock.unlock() }

        guard let suppressedUntil = passthroughObservationSuppressedUntilNanos else {
            return false
        }

        if suppressedUntil > nowNanos {
            return true
        }

        passthroughObservationSuppressedUntilNanos = nil
        return false
    }

    private func consumePassthroughObservation() -> Bool {
        passthroughLock.lock()
        let value = hasObservedPassthroughKeyDown
        hasObservedPassthroughKeyDown = false
        passthroughLock.unlock()
        return value
    }

    private func clearThreadState() {
        lifecycleLock.lock()
        eventTap = nil
        runLoopSource = nil
        eventRunLoop = nil
        eventThread = nil
        isStopping = false
        lifecycleLock.unlock()
    }

    private func consumePendingReplay(_ replay: KeyboardEventReplay) -> Bool {
        replayLock.lock()
        if !pendingReplayedKeyDowns.isEmpty {
            let nowNanos = DispatchTime.now().uptimeNanoseconds
            pendingReplayedKeyDowns = pendingReplayedKeyDowns.filter { $0.value.expiresAtNanos > nowNanos }
        }
        guard var state = pendingReplayedKeyDowns[replay],
              state.count > 0 else {
            replayLock.unlock()
            return false
        }

        state.count -= 1
        if state.count == 0 {
            pendingReplayedKeyDowns[replay] = nil
        } else {
            pendingReplayedKeyDowns[replay] = state
        }
        replayLock.unlock()
        return true
    }

    @MainActor
    private func replayKey(_ replay: KeyboardEventReplay) {
        guard let virtualKey = replay.virtualKeyCode else {
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let flags = CGEventFlags(rawValue: replay.flagsRawValue)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return
        }

        markPendingReplay(replay)
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.flags = flags
        keyUp.post(tap: .cghidEventTap)
    }

    private func markPendingReplay(_ replay: KeyboardEventReplay) {
        let nowNanos = DispatchTime.now().uptimeNanoseconds
        replayLock.lock()
        pendingReplayedKeyDowns[replay] = KeyboardEventReplayState(
            count: (pendingReplayedKeyDowns[replay]?.count ?? 0) + 1,
            expiresAtNanos: nowNanos + replayExpirationNanos
        )
        replayLock.unlock()
    }
}

struct KeyboardEventTapSnapshot: Equatable, Sendable {
    var hasVisibleSuggestion: Bool
    var supportsOneWordAcceptance: Bool
    var supportsFullAcceptance: Bool
    var isInvalidatedByUserTyping: Bool
    var hasPendingAcceptedInsertionUndo: Bool
    var acceptAllShortcut: AcceptAllShortcut

    init(
        hasVisibleSuggestion: Bool = false,
        supportsOneWordAcceptance: Bool = false,
        supportsFullAcceptance: Bool = false,
        isInvalidatedByUserTyping: Bool = false,
        hasPendingAcceptedInsertionUndo: Bool = false,
        acceptAllShortcut: AcceptAllShortcut = .backtick
    ) {
        self.hasVisibleSuggestion = hasVisibleSuggestion
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.isInvalidatedByUserTyping = isInvalidatedByUserTyping
        self.hasPendingAcceptedInsertionUndo = hasPendingAcceptedInsertionUndo
        self.acceptAllShortcut = acceptAllShortcut
    }
}

private struct KeyboardEventReplay: Hashable, Sendable {
    let keyCode: Int64
    let flagsRawValue: UInt64

    var virtualKeyCode: CGKeyCode? {
        guard keyCode >= 0,
              keyCode <= Int64(UInt16.max) else {
            return nil
        }

        return CGKeyCode(keyCode)
    }
}

private struct KeyboardEventReplayState: Sendable {
    var count: Int
    var expiresAtNanos: UInt64
}

private struct KeyboardEventTapLatencyStats: Sendable {
    private var samples: [Int] = []
    private let flushCount = 100

    mutating func record(_ durationMicros: Int) -> KeyboardEventTapLatencySummary? {
        samples.append(durationMicros)
        guard samples.count >= flushCount else {
            return nil
        }

        return drain()
    }

    mutating func drain() -> KeyboardEventTapLatencySummary? {
        guard !samples.isEmpty else {
            return nil
        }

        let sorted = samples.sorted()
        let summary = KeyboardEventTapLatencySummary(
            count: sorted.count,
            p50Micros: percentile(0.50, in: sorted),
            p95Micros: percentile(0.95, in: sorted),
            p99Micros: percentile(0.99, in: sorted),
            maxMicros: sorted.last ?? 0
        )
        samples.removeAll(keepingCapacity: true)
        return summary
    }

    private func percentile(_ fraction: Double, in sorted: [Int]) -> Int {
        guard !sorted.isEmpty else {
            return 0
        }

        let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * fraction).rounded()))
        return sorted[index]
    }
}

private struct KeyboardEventTapLatencySummary: Sendable {
    let count: Int
    let p50Micros: Int
    let p95Micros: Int
    let p99Micros: Int
    let maxMicros: Int
}

private func keyboardEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<KeyboardEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return eventTap.handle(type: type, event: event)
}

private extension AutocompletePhysicalKey {
    init(keyCode: Int64) {
        switch keyCode {
        case 48:
            self = .tab
        case 50:
            self = .backtick
        case 6:
            self = .z
        case 53:
            self = .escape
        default:
            self = .other
        }
    }
}

private extension AutocompleteKeyModifiers {
    init(flags: CGEventFlags) {
        var modifiers: AutocompleteKeyModifiers = []

        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }

        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }

        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }

        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }

        if flags.contains(.maskSecondaryFn) {
            modifiers.insert(.function)
        }

        self = modifiers
    }
}

private final class LockedStartResult: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        lock.lock()
        let result = storedValue
        lock.unlock()
        return result
    }

    func set(_ value: Bool) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}
