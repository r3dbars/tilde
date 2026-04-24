import AppKit
import ApplicationServices
import AutocompleteLabCore
import CoreGraphics

struct RunningApplicationInfo: Equatable {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
}

struct FocusedTextContext: Equatable {
    let textBeforeCursor: String
    let textAfterCursor: String
    let caretRect: CGRect?
    let isSecure: Bool
}

final class AccessibilityClient {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestPermissionIfNeeded() {
        guard !isTrusted else {
            return
        }

        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        AXIsProcessTrustedWithOptions(options)
    }

    func frontmostApplication() -> RunningApplicationInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier else {
            return nil
        }

        return RunningApplicationInfo(
            bundleIdentifier: bundleIdentifier,
            localizedName: app.localizedName ?? bundleIdentifier,
            processIdentifier: app.processIdentifier
        )
    }

    func focusedTextContext() -> FocusedTextContext? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard let focusedElement = focusedElement(for: app.processIdentifier) else {
            return nil
        }

        let isSecure = isSecureTextElement(focusedElement)

        guard let text = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String else {
            return nil
        }

        let selectedRange = selectedTextRange(in: focusedElement)
        let textSlice = CursorTextSplitter.split(
            text,
            utf16Offset: selectedRange?.location ?? text.utf16.count
        )
        let caretRect = selectedRange.flatMap { caretBounds(for: focusedElement, range: $0) }

        return FocusedTextContext(
            textBeforeCursor: textSlice.textBeforeCursor,
            textAfterCursor: textSlice.textAfterCursor,
            caretRect: caretRect,
            isSecure: isSecure
        )
    }

    func insertText(_ text: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = focusedElement(for: app.processIdentifier) else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    private func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        guard let focusedElementValue = copyAttribute(appElement, attribute: kAXFocusedUIElementAttribute) else {
            return nil
        }

        return (focusedElementValue as! AXUIElement)
    }

    private func copyAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        guard let rangeValue = copyAttribute(element, attribute: kAXSelectedTextRangeAttribute) else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func caretBounds(for element: AXUIElement, range: CFRange) -> CGRect? {
        var caretRange = CFRange(location: range.location, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &caretRange) else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard result == .success, let boundsValue else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else {
            return nil
        }

        return rect
    }

    private func isSecureTextElement(_ element: AXUIElement) -> Bool {
        if let subrole = copyAttribute(element, attribute: kAXSubroleAttribute) as? String,
           subrole == "AXSecureTextField" {
            return true
        }

        if let protected = copyAttribute(element, attribute: "AXProtectedContent") as? Bool {
            return protected
        }

        return false
    }
}
