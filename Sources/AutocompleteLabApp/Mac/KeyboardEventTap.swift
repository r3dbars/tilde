import ApplicationServices
import AutocompleteLabCore
import Foundation

final class KeyboardEventTap: @unchecked Sendable {
    typealias Handler = @Sendable (AutocompleteKey, Bool, Bool) -> Bool
    typealias PassthroughKeyDownObserver = @MainActor @Sendable () -> Void

    private let handler: Handler
    private let passthroughKeyDownObserver: PassthroughKeyDownObserver?
    private let keyMapper = AutocompleteKeyMapper()
    private let lifecycleLock = NSLock()
    private let passthroughLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var eventThread: Thread?
    private var isStopping = false
    private var hasObservedPassthroughKeyDown = false

    init(
        handler: @escaping Handler,
        passthroughKeyDownObserver: PassthroughKeyDownObserver? = nil
    ) {
        self.handler = handler
        self.passthroughKeyDownObserver = passthroughKeyDownObserver
    }

    deinit {
        stop()
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

    func stop() {
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
    }

    func resetPassthroughObservation() {
        passthroughLock.lock()
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

            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let key = keyMapper.key(
            physicalKey: AutocompletePhysicalKey(keyCode: keyCode),
            modifiers: AutocompleteKeyModifiers(flags: event.flags)
        )
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if key == .other {
            markPassthroughObserved()
            if let passthroughKeyDownObserver {
                Task { @MainActor in
                    passthroughKeyDownObserver()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let hadPassthroughKeyDown = consumePassthroughObservation()
        guard handler(key, isAutorepeat, hadPassthroughKeyDown) else {
            return Unmanaged.passUnretained(event)
        }

        return nil
    }

    private func markPassthroughObserved() {
        passthroughLock.lock()
        hasObservedPassthroughKeyDown = true
        passthroughLock.unlock()
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
