import ApplicationServices
import AutocompleteLabCore
import Foundation

final class KeyboardEventTap {
    typealias Handler = (AutocompleteKey, Bool) -> Bool

    private let handler: Handler
    private let keyMapper = AutocompleteKeyMapper()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: keyboardEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-disabled",
                metadata: [
                    "reason": type == .tapDisabledByTimeout ? "timeout" : "user-input"
                ]
            )

            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
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

        guard key != .other else {
            return Unmanaged.passUnretained(event)
        }

        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard handler(key, isAutorepeat) else {
            return Unmanaged.passUnretained(event)
        }

        return nil
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
