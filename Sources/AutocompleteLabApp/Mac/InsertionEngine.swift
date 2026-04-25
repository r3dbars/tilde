import AppKit
import AutocompleteLabCore

struct InsertionResult: Equatable {
    let succeeded: Bool
    let mode: InsertionMode
    let message: String
}

@MainActor
final class InsertionEngine {
    private let accessibilityClient: AccessibilityClient
    private let clipboardFallbackEnabled: Bool

    init(
        accessibilityClient: AccessibilityClient,
        clipboardFallbackEnabled: Bool = false
    ) {
        self.accessibilityClient = accessibilityClient
        self.clipboardFallbackEnabled = clipboardFallbackEnabled
    }

    func insert(_ text: String, profile: CompatibilityProfile) -> InsertionResult {
        guard !text.isEmpty else {
            return InsertionResult(succeeded: false, mode: profile.insertionMode, message: "No text to insert.")
        }

        switch profile.insertionMode {
        case .axSelectedText:
            if accessibilityClient.insertText(text) {
                return InsertionResult(succeeded: true, mode: .axSelectedText, message: "Inserted via AX selected text.")
            }

            return clipboardFallback(text, profile: profile)

        case .axThenKeyEvents:
            if accessibilityClient.insertText(text) {
                return InsertionResult(succeeded: true, mode: .axSelectedText, message: "Inserted via verified AX selected text.")
            }

            if insertWithKeyEvents(text) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return clipboardFallback(text, profile: profile)

        case .keyEvents:
            if insertWithKeyEvents(text) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return clipboardFallback(text, profile: profile)

        case .clipboardFallbackOptIn:
            return clipboardFallback(text, profile: profile)

        case .disabled:
            return InsertionResult(succeeded: false, mode: .disabled, message: "Insertion is disabled for this app.")
        }
    }

    private func insertWithKeyEvents(_ text: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        var characters = Array(text.utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        characters.withUnsafeMutableBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            keyUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private func clipboardFallback(_ text: String, profile: CompatibilityProfile) -> InsertionResult {
        guard clipboardFallbackEnabled, !profile.isSensitive else {
            return InsertionResult(
                succeeded: false,
                mode: .clipboardFallbackOptIn,
                message: "AX insertion failed and clipboard fallback is disabled."
            )
        }

        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems?.map { $0.copy() as! NSPasteboardItem } ?? []
        let originalChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let pasteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)
        pasteEvent?.flags = .maskCommand
        pasteEvent?.post(tap: .cghidEventTap)
        let pasteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        pasteUpEvent?.flags = .maskCommand
        pasteUpEvent?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if pasteboard.changeCount >= originalChangeCount {
                pasteboard.clearContents()
                pasteboard.writeObjects(originalItems)
            }
        }

        return InsertionResult(
            succeeded: true,
            mode: .clipboardFallbackOptIn,
            message: "Inserted via temporary clipboard fallback."
        )
    }
}
