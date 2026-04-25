import ApplicationServices
import AutocompleteLabCore
import Foundation

final class KeyboardEventTap {
    typealias Handler = (AutocompleteKey) -> Bool

    private let handler: Handler
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
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let key = AutocompleteKey(keyCode: keyCode, flags: event.flags)

        guard handler(key) else {
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

private extension AutocompleteKey {
    init(keyCode: Int64, flags: CGEventFlags) {
        switch keyCode {
        case 48:
            self = flags.contains(.maskAlternate) ? .optionTab : .tab
        case 50:
            self = .backtick
        case 53:
            self = .escape
        default:
            self = .other
        }
    }
}
