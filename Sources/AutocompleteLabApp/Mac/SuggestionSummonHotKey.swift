import Carbon
import Foundation

struct SuggestionSummonHotKeyDescriptor: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
    let diagnosticName: String

    static let controlBacktick = SuggestionSummonHotKeyDescriptor(
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(controlKey),
        displayName: "Control-Backtick",
        diagnosticName: "control-backtick"
    )
}

@MainActor
final class SuggestionSummonHotKey {
    typealias Handler = @MainActor @Sendable () -> Void

    let descriptor: SuggestionSummonHotKeyDescriptor

    private let handler: Handler
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(
        descriptor: SuggestionSummonHotKeyDescriptor = .controlBacktick,
        handler: @escaping Handler
    ) {
        self.descriptor = descriptor
        self.handler = handler
    }

    @discardableResult
    func start() -> Bool {
        guard hotKeyRef == nil else {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            suggestionSummonHotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            eventHandlerRef = nil
            return false
        }

        var hotKeyID = EventHotKeyID(signature: OSType(0x53545950), id: 1) // STYP
        let registerStatus = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            stop()
            return false
        }

        return true
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func invoke() {
        handler()
    }
}

private func suggestionSummonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else {
        return noErr
    }

    let hotKey = Unmanaged<SuggestionSummonHotKey>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        hotKey.invoke()
    }
    return noErr
}
