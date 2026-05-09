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
            if let result = attempt(text, mode: mode, profile: profile) {
                return result
            }
        }

        return clipboardFallbackUnavailable()
    }

    private func attempt(_ text: String, mode: InsertionMode, profile: CompatibilityProfile) -> InsertionResult? {
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

            if insertWithKeyEvents(text, profile: profile) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return nil

        case .keyEvents:
            if insertWithKeyEvents(text, profile: profile) {
                return InsertionResult(succeeded: true, mode: .keyEvents, message: "Inserted via synthetic key events.")
            }

            return nil

        case .clipboardFallbackOptIn:
            return nil

        case .disabled:
            return nil
        }
    }

    private func insertWithKeyEvents(_ text: String, profile: CompatibilityProfile) -> Bool {
        if profile.appFamily == .chromium,
           insertWithHardwareKeyEvents(text) {
            return true
        }

        return insertWithUnicodeKeyEvents(text)
    }

    private func insertWithUnicodeKeyEvents(_ text: String) -> Bool {
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

    private func insertWithHardwareKeyEvents(_ text: String) -> Bool {
        guard let strokes = KeyboardTextEventPlan.hardwareKeyStrokes(for: text),
              let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        for stroke in strokes {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: stroke.virtualKey, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: stroke.virtualKey, keyDown: false) else {
                return false
            }

            keyDown.flags = stroke.flags
            keyUp.flags = stroke.flags
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

struct KeyboardTextKeyStroke: Equatable {
    let virtualKey: CGKeyCode
    let flags: CGEventFlags
}

enum KeyboardTextEventPlan {
    static func hardwareKeyStrokes(for text: String) -> [KeyboardTextKeyStroke]? {
        var strokes: [KeyboardTextKeyStroke] = []
        for scalar in text.unicodeScalars {
            guard let stroke = hardwareKeyStroke(for: scalar) else {
                return nil
            }
            strokes.append(stroke)
        }
        return strokes
    }

    private static func hardwareKeyStroke(for scalar: Unicode.Scalar) -> KeyboardTextKeyStroke? {
        if let letter = asciiLetterStroke(for: scalar) {
            return letter
        }

        if let plain = plainKeyMap[scalar] {
            return KeyboardTextKeyStroke(virtualKey: plain, flags: [])
        }

        if let shifted = shiftedKeyMap[scalar] {
            return KeyboardTextKeyStroke(virtualKey: shifted, flags: .maskShift)
        }

        return nil
    }

    private static func asciiLetterStroke(for scalar: Unicode.Scalar) -> KeyboardTextKeyStroke? {
        guard scalar.value <= 127 else {
            return nil
        }
        let ascii = UInt8(scalar.value)

        let lowercase: UInt8
        let flags: CGEventFlags
        if ascii >= 65 && ascii <= 90 {
            lowercase = ascii + 32
            flags = .maskShift
        } else if ascii >= 97 && ascii <= 122 {
            lowercase = ascii
            flags = []
        } else {
            return nil
        }

        guard let keyCode = letterKeyMap[lowercase] else {
            return nil
        }

        return KeyboardTextKeyStroke(virtualKey: keyCode, flags: flags)
    }

    private static let letterKeyMap: [UInt8: CGKeyCode] = [
        97: 0, 115: 1, 100: 2, 102: 3, 104: 4, 103: 5, 122: 6, 120: 7,
        99: 8, 118: 9, 98: 11, 113: 12, 119: 13, 101: 14, 114: 15,
        121: 16, 116: 17, 111: 31, 117: 32, 105: 34, 112: 35, 108: 37,
        106: 38, 107: 40, 110: 45, 109: 46
    ]

    private static let plainKeyMap: [Unicode.Scalar: CGKeyCode] = [
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24,
        "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "[": 33,
        "'": 39, ";": 41, "\\": 42, ",": 43, "/": 44, ".": 47, "`": 50,
        " ": 49, "\n": 36
    ]

    private static let shiftedKeyMap: [Unicode.Scalar: CGKeyCode] = [
        "!": 18, "@": 19, "#": 20, "$": 21, "^": 22, "%": 23, "+": 24,
        "(": 25, "&": 26, "_": 27, "*": 28, ")": 29, "}": 30, "{": 33,
        "\"": 39, ":": 41, "|": 42, "<": 43, "?": 44, ">": 47, "~": 50
    ]
}
