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
    private let clipboardFallbackPolicy = ClipboardFallbackPolicy()
    private let clipboardFallbackRestorePolicy = ClipboardFallbackRestorePolicy()

    init(
        accessibilityClient: AccessibilityClient,
        clipboardFallbackEnabled: Bool = false
    ) {
        self.accessibilityClient = accessibilityClient
        self.clipboardFallbackEnabled = clipboardFallbackEnabled
    }

    func insert(
        _ text: String,
        profile: CompatibilityProfile,
        skipping skippedModes: Set<InsertionMode> = []
    ) -> InsertionResult {
        guard !text.isEmpty else {
            return InsertionResult(succeeded: false, mode: profile.insertionMode, message: "No text to insert.")
        }

        for mode in InsertionModePlan.modes(for: profile, skipping: skippedModes) {
            if let result = attempt(text, mode: mode) {
                return result
            }
        }

        return clipboardFallback(text, profile: profile)
    }

    private func attempt(_ text: String, mode: InsertionMode) -> InsertionResult? {
        switch mode {
        case .axSelectedText:
            if accessibilityClient.insertText(text) {
                return InsertionResult(succeeded: true, mode: .axSelectedText, message: "Inserted via AX selected text.")
            }

            return nil

        case .axValueReplacement:
            if accessibilityClient.replaceSelectedTextBySettingValue(text) {
                return InsertionResult(succeeded: true, mode: .axValueReplacement, message: "Inserted via AX value replacement.")
            }

            return nil

        case .axThenKeyEvents:
            if accessibilityClient.insertText(text) {
                return InsertionResult(succeeded: true, mode: .axSelectedText, message: "Inserted via verified AX selected text.")
            }

            if insertWithKeyEvents(text) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return nil

        case .keyEvents:
            if insertWithKeyEvents(text) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return nil

        case .clipboardFallbackOptIn:
            return nil

        case .disabled:
            return nil
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
        let fallbackDecision = clipboardFallbackPolicy.decision(
            profile: profile,
            runtimeEnabled: clipboardFallbackEnabled
        )
        guard fallbackDecision == .allowed else {
            return InsertionResult(
                succeeded: false,
                mode: .clipboardFallbackOptIn,
                message: fallbackDecision.message
            )
        }

        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems?.map { $0.copy() as! NSPasteboardItem } ?? []
        let restorePolicy = clipboardFallbackRestorePolicy

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let fallbackChangeCount = pasteboard.changeCount

        let pasteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)
        pasteEvent?.flags = .maskCommand
        pasteEvent?.post(tap: .cghidEventTap)
        let pasteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        pasteUpEvent?.flags = .maskCommand
        pasteUpEvent?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let restoreDecision = restorePolicy.decision(
                insertedText: text,
                currentString: pasteboard.string(forType: .string),
                fallbackChangeCount: fallbackChangeCount,
                currentChangeCount: pasteboard.changeCount
            )
            if restoreDecision == .restoreOriginalPasteboard {
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
