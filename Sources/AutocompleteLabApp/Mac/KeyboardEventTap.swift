import ApplicationServices
import AutocompleteLabCore
import Carbon.HIToolbox
import Foundation

final class KeyboardEventTap: @unchecked Sendable {
    typealias Handler = @MainActor @Sendable (AutocompleteKey, Bool, Bool) -> KeyboardEventTapHandlingResult
    typealias PassthroughKeyDownObserver = @MainActor @Sendable () -> Void
    typealias PassthroughTypingMatchObserver = @MainActor @Sendable (KeyboardOptimisticTypeThroughTransition) -> Void
    typealias GeometryRefreshObserver = @MainActor @Sendable () -> Void
    typealias DisabledObserver = @MainActor @Sendable (_ reason: String) -> Void

    private let handler: Handler
    private let passthroughKeyDownObserver: PassthroughKeyDownObserver?
    private let passthroughTypingMatchObserver: PassthroughTypingMatchObserver?
    private let geometryRefreshObserver: GeometryRefreshObserver?
    private let disabledObserver: DisabledObserver?
    private let keyMapper = AutocompleteKeyMapper()
    private let consumptionPolicy = KeyboardEventTapConsumptionPolicy()
    private let repeatSuppressionPolicy = KeyboardCaptureRepeatSuppressionPolicy()
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
    private var keyDownSuggestionIDs: [AutocompleteKey: String] = [:]
    private let slowEventTapLatencyMicros = 8_000
    private let replayExpirationNanos: UInt64 = 1_000_000_000
    private var passthroughObservationAllowsAutocompleteKey = false
    let tapPlacement: KeyboardEventTapPlacement

    init(
        handler: @escaping Handler,
        passthroughKeyDownObserver: PassthroughKeyDownObserver? = nil,
        passthroughTypingMatchObserver: PassthroughTypingMatchObserver? = nil,
        geometryRefreshObserver: GeometryRefreshObserver? = nil,
        disabledObserver: DisabledObserver? = nil,
        tapPlacement: KeyboardEventTapPlacement = .fromEnvironment()
    ) {
        self.handler = handler
        self.passthroughKeyDownObserver = passthroughKeyDownObserver
        self.passthroughTypingMatchObserver = passthroughTypingMatchObserver
        self.geometryRefreshObserver = geometryRefreshObserver
        self.disabledObserver = disabledObserver
        self.tapPlacement = tapPlacement
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
                tap: self.tapPlacement.cgEventTapLocation,
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

        thread.name = "SteadyTypeKeyboardEventTap"
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
        passthroughObservationAllowsAutocompleteKey = false
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
        passthroughObservationAllowsAutocompleteKey = false
        passthroughLock.unlock()
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
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
                    "reason": type == .tapDisabledByTimeout ? "timeout" : "user-input",
                    "diagnosticLayer": "keyCapture",
                    "safetyFailure": "true"
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
        let physicalKey = AutocompletePhysicalKey(keyCode: keyCode)
        let modifiers = AutocompleteKeyModifiers(flags: event.flags)
        let key = keyMapper.key(
            physicalKey: physicalKey,
            modifiers: modifiers
        )
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let replay = KeyboardEventReplay(keyCode: keyCode, flagsRawValue: event.flags.rawValue)
        let eventMetadata = keyboardEventTapDiagnosticMetadata(event: event)

        if consumePendingReplay(replay) {
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "replay-passthrough",
                eventMetadata: eventMetadata,
                startedAt: startedAt
            )
        }

        if key == .other, isModifierOnlyMacVirtualKeyCode(keyCode) {
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-modifier",
                eventMetadata: eventMetadata,
                startedAt: startedAt
            )
        }

        if key == .other {
            guard shouldTreatOtherKeyAsTypingPassthrough(
                physicalKey: physicalKey,
                modifiers: modifiers
            ) else {
                DiagnosticsLog.shared.record(
                    "keyboard-event-tap-non-typing-chord",
                    metadata: [
                        "keyCode": "\(keyCode)",
                        "physicalKey": physicalKey.diagnosticName,
                        "modifiers": modifiers.diagnosticName,
                        "flagsRawValue": "\(event.flags.rawValue)"
                    ]
                )
                return finish(
                    Unmanaged.passUnretained(event),
                    key: key,
                    decision: "passthrough-non-typing-chord",
                    eventMetadata: eventMetadata,
                    startedAt: startedAt
                )
            }

            if shouldSuppressPassthroughObservation() {
                return finish(
                    Unmanaged.passUnretained(event),
                    key: key,
                    decision: "passthrough-synthetic-insert",
                    eventMetadata: eventMetadata,
                    startedAt: startedAt
                )
            }

            let snapshot = currentSnapshot()
            markPassthroughObserved(
                allowingAutocompleteKey: snapshot.allowsAutocompleteKeyAfterPassthroughObservation
            )
            if let transition = optimisticTypeThroughTransition(
                event: event,
                keyCode: keyCode
            ) {
                if let passthroughTypingMatchObserver {
                    Task { @MainActor in
                        passthroughTypingMatchObserver(transition)
                    }
                }
                if let geometryRefreshObserver {
                    Task { @MainActor in geometryRefreshObserver() }
                }
                return finish(
                    Unmanaged.passUnretained(event),
                    key: key,
                    decision: "passthrough-type-through-match",
                    eventMetadata: eventMetadata,
                    startedAt: startedAt
                )
            }
            markSnapshotInvalidatedByTyping()
            if let passthroughKeyDownObserver {
                Task { @MainActor in
                    passthroughKeyDownObserver()
                }
            }
            if isReturnMacVirtualKeyCode(keyCode), let geometryRefreshObserver {
                Task { @MainActor in geometryRefreshObserver() }
            }
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-other",
                eventMetadata: eventMetadata,
                startedAt: startedAt
            )
        }

        let passthroughObservation = consumePassthroughObservation()
        if passthroughObservation.observed {
            if shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
                snapshot: currentSnapshot(),
                passthroughObservationAllowsAutocompleteKey: passthroughObservation.allowsAutocompleteKey
            ) {
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
                    eventMetadata: eventMetadata,
                    startedAt: startedAt
                )
            }
        }

        guard shouldConsume(key, isAutorepeat: isAutorepeat) else {
            return finish(
                Unmanaged.passUnretained(event),
                key: key,
                decision: "passthrough-unsupported",
                eventMetadata: eventMetadata,
                startedAt: startedAt
            )
        }

        Task { @MainActor in
            let result = handler(key, isAutorepeat, passthroughObservation.observed)
            switch result {
            case .handled:
                break
            case let .replayOriginalKey(reason):
                DiagnosticsLog.shared.record(
                    "keyboard-event-tap-replayed-captured-key",
                    metadata: [
                        "key": key.diagnosticName,
                        "reason": reason.rawValue,
                        "diagnosticLayer": "keyCapture",
                        "safetyFailure": "false"
                    ]
                )
                replayKey(replay)
            case let .dropOriginalKey(reason):
                DiagnosticsLog.shared.record(
                    "keyboard-event-tap-unhandled-consumed-key-dropped",
                    metadata: [
                        "key": key.diagnosticName,
                        "reason": reason.rawValue,
                        "diagnosticLayer": "keyCapture",
                        "safetyFailure": "true"
                    ]
                )
            }
        }
        return finish(nil, key: key, decision: "consume", eventMetadata: eventMetadata, startedAt: startedAt)
    }

    private func finish(
        _ result: Unmanaged<CGEvent>?,
        key: AutocompleteKey,
        decision: String,
        eventMetadata: [String: String],
        startedAt: UInt64
    ) -> Unmanaged<CGEvent>? {
        recordEventTapLatency(
            key: key,
            decision: decision,
            eventMetadata: eventMetadata,
            startedAt: startedAt
        )
        return result
    }

    private func recordEventTapLatency(
        key: AutocompleteKey,
        decision: String,
        eventMetadata: [String: String],
        startedAt: UInt64
    ) {
        let elapsedMicros = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000)
        latencyLock.lock()
        let summary = latencyStats.record(elapsedMicros)
        latencyLock.unlock()

        var metadata = eventMetadata
        metadata["key"] = key.diagnosticName
        metadata["decision"] = decision
        metadata["durationMicros"] = String(elapsedMicros)
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-latency",
            metadata: metadata
        )

        if elapsedMicros >= slowEventTapLatencyMicros {
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-latency-slow",
                metadata: metadata
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
                "p90Micros": String(summary.p90Micros),
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

        if key == .commandZ,
           snapshot.hasPendingAcceptedInsertionUndo,
           !snapshot.isInvalidatedByUserTyping {
            snapshotLock.unlock()
            return true
        }

        guard snapshot.hasVisibleSuggestion,
              !snapshot.isInvalidatedByUserTyping else {
            suppressKeyUntilNanos.removeAll(keepingCapacity: true)
            keyDownSuggestionIDs.removeAll(keepingCapacity: true)
            snapshotLock.unlock()
            return false
        }

        let keyDownSuggestionID = isAutorepeat ? keyDownSuggestionIDs[key] : snapshot.visibleSuggestionID
        if repeatSuppressionPolicy.shouldSuppressAutorepeat(
            key: key,
            isAutorepeat: isAutorepeat,
            suppressedUntilNanos: suppressKeyUntilNanos[key],
            nowNanos: nowNanos
        ) {
            snapshotLock.unlock()
            return true
        }
        suppressKeyUntilNanos[key] = nil

        let shouldConsume = consumptionPolicy.shouldConsume(KeyboardEventTapConsumptionInput(
            key: key,
            hasVisibleSuggestion: snapshot.hasVisibleSuggestion,
            supportsOneWordAcceptance: snapshot.supportsOneWordAcceptance,
            supportsFullAcceptance: snapshot.supportsFullAcceptance,
            isInvalidatedByUserTyping: snapshot.isInvalidatedByUserTyping,
            hasPendingAcceptedInsertionUndo: snapshot.hasPendingAcceptedInsertionUndo,
            acceptAllShortcut: snapshot.acceptAllShortcut,
            isAutorepeat: isAutorepeat,
            visibleSuggestionID: snapshot.visibleSuggestionID,
            keyDownSuggestionID: keyDownSuggestionID
        ))

        if isAutorepeat {
            if !shouldConsume {
                keyDownSuggestionIDs[key] = nil
            }
        } else if shouldConsume, let visibleSuggestionID = snapshot.visibleSuggestionID {
            keyDownSuggestionIDs[key] = visibleSuggestionID
        } else {
            keyDownSuggestionIDs[key] = nil
        }

        if let deadline = repeatSuppressionPolicy.suppressionDeadline(
            shouldConsume: shouldConsume,
            isAutorepeat: isAutorepeat,
            nowNanos: nowNanos
        ) {
            suppressKeyUntilNanos[key] = deadline
        }
        snapshotLock.unlock()
        return shouldConsume
    }

    private func currentSnapshot() -> KeyboardEventTapSnapshot {
        snapshotLock.lock()
        let snapshot = self.snapshot
        snapshotLock.unlock()
        return snapshot
    }

    private func markSnapshotInvalidatedByTyping() {
        snapshotLock.lock()
        snapshot.isInvalidatedByUserTyping = true
        suppressKeyUntilNanos.removeAll(keepingCapacity: true)
        snapshotLock.unlock()
    }

    private func optimisticTypeThroughTransition(
        event: CGEvent,
        keyCode: Int64
    ) -> KeyboardOptimisticTypeThroughTransition? {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }

        guard snapshot.allowsOptimisticTypeThrough,
              !snapshot.isInvalidatedByUserTyping else { return nil }

        let transition: KeyboardOptimisticTypeThroughTransition?
        if isBackspaceMacVirtualKeyCode(keyCode) {
            transition = snapshot.retreatOptimisticTypeThrough()
        } else if let typedCharacter = keyboardEventTapTypedCharacter(event: event) {
            transition = snapshot.advanceOptimisticTypeThrough(typedCharacter: typedCharacter)
        } else {
            transition = nil
        }
        return transition
    }

    private func markPassthroughObserved(allowingAutocompleteKey: Bool) {
        passthroughLock.lock()
        hasObservedPassthroughKeyDown = true
        passthroughObservationAllowsAutocompleteKey = passthroughObservationAllowsAutocompleteKey
            || allowingAutocompleteKey
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

    private func consumePassthroughObservation() -> (
        observed: Bool,
        allowsAutocompleteKey: Bool
    ) {
        passthroughLock.lock()
        let value = (
            observed: hasObservedPassthroughKeyDown,
            allowsAutocompleteKey: passthroughObservationAllowsAutocompleteKey
        )
        hasObservedPassthroughKeyDown = false
        passthroughObservationAllowsAutocompleteKey = false
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

enum KeyboardEventTapPlacement: String, Sendable {
    static let environmentKey = "AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION"

    case session
    case hid

    var cgEventTapLocation: CGEventTapLocation {
        switch self {
        case .session:
            return .cgSessionEventTap
        case .hid:
            return .cghidEventTap
        }
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        guard let rawValue = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return .session
        }

        switch rawValue.lowercased() {
        case "session", "cgsession", "cgsessioneventtap":
            return .session
        case "hid", "cghid", "cghideventtap":
            return .hid
        default:
            return .session
        }
    }
}

struct KeyboardEventTapSnapshot: Equatable, Sendable {
    var hasVisibleSuggestion: Bool
    var supportsOneWordAcceptance: Bool
    var supportsFullAcceptance: Bool
    var isInvalidatedByUserTyping: Bool
    var allowsAutocompleteKeyAfterPassthroughObservation: Bool
    var hasPendingAcceptedInsertionUndo: Bool
    var acceptAllShortcut: AcceptAllShortcut
    var visibleSuggestionID: String?
    var visibleSuggestionRemainingText: String?
    var visibleSuggestionOriginalText: String?
    var optimisticTypedPrefix: String
    var allowsOptimisticTypeThrough: Bool

    init(
        hasVisibleSuggestion: Bool = false,
        supportsOneWordAcceptance: Bool = false,
        supportsFullAcceptance: Bool = false,
        isInvalidatedByUserTyping: Bool = false,
        allowsAutocompleteKeyAfterPassthroughObservation: Bool = false,
        hasPendingAcceptedInsertionUndo: Bool = false,
        acceptAllShortcut: AcceptAllShortcut = .shiftTab,
        visibleSuggestionID: String? = nil,
        visibleSuggestionRemainingText: String? = nil,
        visibleSuggestionOriginalText: String? = nil,
        optimisticTypedPrefix: String = "",
        allowsOptimisticTypeThrough: Bool = true
    ) {
        self.hasVisibleSuggestion = hasVisibleSuggestion
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.isInvalidatedByUserTyping = isInvalidatedByUserTyping
        self.allowsAutocompleteKeyAfterPassthroughObservation = allowsAutocompleteKeyAfterPassthroughObservation
        self.hasPendingAcceptedInsertionUndo = hasPendingAcceptedInsertionUndo
        self.acceptAllShortcut = acceptAllShortcut
        self.visibleSuggestionID = visibleSuggestionID
        self.visibleSuggestionRemainingText = visibleSuggestionRemainingText
        self.visibleSuggestionOriginalText = visibleSuggestionOriginalText ?? visibleSuggestionRemainingText
        self.optimisticTypedPrefix = optimisticTypedPrefix
        self.allowsOptimisticTypeThrough = allowsOptimisticTypeThrough
    }

    mutating func advanceOptimisticTypeThrough(
        typedCharacter: Character,
        matcher: OptimisticTypeThroughMatcher = OptimisticTypeThroughMatcher()
    ) -> KeyboardOptimisticTypeThroughTransition? {
        guard hasVisibleSuggestion,
              let remaining = visibleSuggestionRemainingText else {
            return nil
        }
        let nextPrefix = optimisticTypedPrefix + String(typedCharacter)
        switch matcher.advance(typedCharacter: typedCharacter, remaining: remaining) {
        case let .matched(newRemaining):
            optimisticTypedPrefix = nextPrefix
            visibleSuggestionRemainingText = newRemaining
            return .matched(typedCharacter: typedCharacter, typedPrefix: nextPrefix, remainingText: newRemaining)
        case .exhausted:
            optimisticTypedPrefix = nextPrefix
            visibleSuggestionRemainingText = ""
            return .matched(typedCharacter: typedCharacter, typedPrefix: nextPrefix, remainingText: "")
        case .mismatch:
            return nil
        }
    }

    mutating func retreatOptimisticTypeThrough(
        matcher: OptimisticTypeThroughMatcher = OptimisticTypeThroughMatcher()
    ) -> KeyboardOptimisticTypeThroughTransition? {
        guard hasVisibleSuggestion,
              !optimisticTypedPrefix.isEmpty,
              let original = visibleSuggestionOriginalText else {
            return nil
        }
        let nextPrefix = String(optimisticTypedPrefix.dropLast())
        switch matcher.retreat(typedPrefix: optimisticTypedPrefix, originalRemaining: original) {
        case let .matched(newRemaining):
            optimisticTypedPrefix = nextPrefix
            visibleSuggestionRemainingText = newRemaining
            return .retreated(typedPrefix: nextPrefix, remainingText: newRemaining)
        case .exhausted:
            optimisticTypedPrefix = nextPrefix
            visibleSuggestionRemainingText = ""
            return .retreated(typedPrefix: nextPrefix, remainingText: "")
        case .mismatch:
            return nil
        }
    }
}

enum KeyboardOptimisticTypeThroughTransition: Equatable, Sendable {
    case matched(typedCharacter: Character, typedPrefix: String, remainingText: String)
    case retreated(typedPrefix: String, remainingText: String)

    var typedPrefix: String {
        switch self {
        case let .matched(_, typedPrefix, _), let .retreated(typedPrefix, _): typedPrefix
        }
    }

    var remainingText: String {
        switch self {
        case let .matched(_, _, remainingText), let .retreated(_, remainingText): remainingText
        }
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
            p90Micros: percentile(0.90, in: sorted),
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
    let p90Micros: Int
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

func autocompletePhysicalKey(forMacVirtualKeyCode keyCode: Int64) -> AutocompletePhysicalKey {
    switch keyCode {
    case 6:
        .z
    case 48:
        .tab
    case 50:
        .backtick
    case 53:
        .escape
    default:
        .other
    }
}

func isModifierOnlyMacVirtualKeyCode(_ keyCode: Int64) -> Bool {
    switch keyCode {
    case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63:
        true
    default:
        false
    }
}

func isBackspaceMacVirtualKeyCode(_ keyCode: Int64) -> Bool {
    keyCode == 51 || keyCode == 117
}

func keyboardEventTapTypedCharacter(event: CGEvent) -> Character? {
    var actualLength = 0
    var utf16 = [UniChar](repeating: 0, count: 8)
    event.keyboardGetUnicodeString(
        maxStringLength: utf16.count,
        actualStringLength: &actualLength,
        unicodeString: &utf16
    )
    guard actualLength > 0 else { return nil }
    let text = String(decoding: utf16.prefix(actualLength), as: UTF16.self)
    guard text.count == 1 else { return nil }
    return text.first
}

func currentKeyboardInputSourceAllowsOptimisticTypeThrough() -> Bool {
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let rawType = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else {
        return false
    }
    let type = unsafeBitCast(rawType, to: CFString.self) as String
    return keyboardInputSourceTypeAllowsOptimisticTypeThrough(type)
}

func keyboardInputSourceTypeAllowsOptimisticTypeThrough(_ type: String) -> Bool {
    type == (kTISTypeKeyboardLayout as String)
}

func shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
    snapshot: KeyboardEventTapSnapshot,
    passthroughObservationAllowsAutocompleteKey: Bool = false
) -> Bool {
    snapshot.isInvalidatedByUserTyping
        && !snapshot.allowsAutocompleteKeyAfterPassthroughObservation
        && !passthroughObservationAllowsAutocompleteKey
}

func shouldTreatOtherKeyAsTypingPassthrough(
    physicalKey: AutocompletePhysicalKey,
    modifiers: AutocompleteKeyModifiers
) -> Bool {
    if modifiers.contains(.command)
        || modifiers.contains(.control)
        || modifiers.contains(.option)
        || modifiers.contains(.function) {
        return false
    }

    switch physicalKey {
    case .tab, .escape:
        return false
    case .backtick, .z, .other:
        return true
    }
}

func isReturnMacVirtualKeyCode(_ keyCode: Int64) -> Bool {
    keyCode == 36 || keyCode == 76
}

func keyboardEventTapDiagnosticMetadata(event: CGEvent) -> [String: String] {
    var metadata: [String: String] = [:]
    let eventSourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
    let eventTargetPID = event.getIntegerValueField(.eventTargetUnixProcessID)

    if eventSourcePID > 0 {
        metadata["eventSourcePID"] = String(eventSourcePID)
    }
    if eventTargetPID > 0 {
        metadata["eventTargetPID"] = String(eventTargetPID)
    }

    return metadata
}

private extension AutocompletePhysicalKey {
    init(keyCode: Int64) {
        self = autocompletePhysicalKey(forMacVirtualKeyCode: keyCode)
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

    var diagnosticName: String {
        var names: [String] = []
        if contains(.shift) {
            names.append("shift")
        }
        if contains(.control) {
            names.append("control")
        }
        if contains(.option) {
            names.append("option")
        }
        if contains(.command) {
            names.append("command")
        }
        if contains(.function) {
            names.append("function")
        }
        return names.isEmpty ? "none" : names.joined(separator: "+")
    }
}

private extension AutocompletePhysicalKey {
    var diagnosticName: String {
        switch self {
        case .tab:
            "tab"
        case .backtick:
            "backtick"
        case .z:
            "z"
        case .escape:
            "escape"
        case .other:
            "other"
        }
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
