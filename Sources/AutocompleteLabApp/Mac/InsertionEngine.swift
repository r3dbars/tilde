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

    init(accessibilityClient: AccessibilityClient) {
        self.accessibilityClient = accessibilityClient
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

        return clipboardFallbackUnavailable()
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

    private func clipboardFallbackUnavailable() -> InsertionResult {
        return InsertionResult(
            succeeded: false,
            mode: .clipboardFallbackOptIn,
            message: "Insertion failed and clipboard fallback is disabled for beta."
        )
    }
}
