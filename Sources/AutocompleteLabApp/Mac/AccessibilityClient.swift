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
    let textLineRect: CGRect?
    let textStyle: FocusedTextStyle?
    let isSecure: Bool
}

struct FocusedTextStyle: Equatable {
    let fontName: String
    let fontSize: CGFloat
    let foregroundColor: NSColor?

    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
}

private struct PasteboardSnapshot: Sendable {
    struct Item: Sendable {
        let values: [Value]
    }

    struct Value: Sendable {
        let type: String
        let data: Data
    }

    let items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.compactMap { item -> Item? in
            let values = item.types.compactMap { type -> Value? in
                guard let data = item.data(forType: type) else {
                    return nil
                }

                return Value(type: type.rawValue, data: data)
            }

            guard !values.isEmpty else {
                return nil
            }

            return Item(values: values)
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let pasteboardItems = items.map { item in
            let pasteboardItem = NSPasteboardItem()
            for value in item.values {
                pasteboardItem.setData(value.data, forType: NSPasteboard.PasteboardType(value.type))
            }

            return pasteboardItem
        }

        if !pasteboardItems.isEmpty {
            pasteboard.writeObjects(pasteboardItems)
        }
    }
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
        let textLineRect = selectedRange.flatMap {
            textLineBounds(for: focusedElement, textLength: text.utf16.count, textBeforeCursor: textSlice.textBeforeCursor, range: $0)
        }
        let textStyle = selectedRange.flatMap {
            focusedTextStyle(in: focusedElement, textLength: text.utf16.count, range: $0)
        }

        return FocusedTextContext(
            textBeforeCursor: textSlice.textBeforeCursor,
            textAfterCursor: textSlice.textAfterCursor,
            caretRect: caretRect,
            textLineRect: textLineRect,
            textStyle: textStyle,
            isSecure: isSecure
        )
    }

    func insertText(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return true
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = focusedElement(for: app.processIdentifier) else {
            return false
        }

        guard !isSecureTextElement(focusedElement) else {
            return false
        }

        let originalValue = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        let originalRange = selectedTextRange(in: focusedElement)
        let expectedValue = expectedTextValue(
            afterInserting: text,
            into: originalValue,
            selectedRange: originalRange
        )

        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if result == .success {
            if directInsertionChangedValue(
                in: focusedElement,
                originalValue: originalValue,
                expectedValue: expectedValue
            ) {
                return true
            }

            return pasteTextThroughClipboard(text)
        }

        return pasteTextThroughClipboard(text)
    }

    private func expectedTextValue(
        afterInserting text: String,
        into originalValue: String?,
        selectedRange: CFRange?
    ) -> String? {
        guard let originalValue,
              let selectedRange,
              selectedRange.location >= 0,
              selectedRange.length >= 0 else {
            return nil
        }

        let startOffset = min(selectedRange.location, originalValue.utf16.count)
        let endOffset = min(startOffset + selectedRange.length, originalValue.utf16.count)
        let prefix = CursorTextSplitter.split(originalValue, utf16Offset: startOffset).textBeforeCursor
        let suffix = CursorTextSplitter.split(originalValue, utf16Offset: endOffset).textAfterCursor

        return prefix + text + suffix
    }

    private func directInsertionChangedValue(
        in focusedElement: AXUIElement,
        originalValue: String?,
        expectedValue: String?
    ) -> Bool {
        guard let expectedValue else {
            return true
        }

        if copiedTextValue(in: focusedElement) == expectedValue {
            return true
        }

        Thread.sleep(forTimeInterval: 0.02)
        let updatedValue = copiedTextValue(in: focusedElement)
        if updatedValue == expectedValue {
            return true
        }

        guard let updatedValue else {
            return false
        }

        return updatedValue != originalValue
    }

    private func copiedTextValue(in focusedElement: AXUIElement) -> String? {
        copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
    }

    private func pasteTextThroughClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(to: pasteboard)
            return false
        }

        let temporaryChangeCount = pasteboard.changeCount
        guard postCommandV() else {
            snapshot.restore(to: pasteboard)
            return false
        }

        restorePasteboard(snapshot, ifChangeCountIs: temporaryChangeCount)
        return true
    }

    private func postCommandV() -> Bool {
        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(9), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(9), keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, ifChangeCountIs temporaryChangeCount: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))

            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount == temporaryChangeCount else {
                return
            }

            snapshot.restore(to: pasteboard)
        }
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
        let caretRange = CFRange(location: range.location, length: 0)
        return bounds(for: element, range: caretRange)
    }

    private func textLineBounds(
        for element: AXUIElement,
        textLength: Int,
        textBeforeCursor: String,
        range: CFRange
    ) -> CGRect? {
        if let lastCharacter = textBeforeCursor.last, !lastCharacter.isNewline, range.location > 0 {
            let previousCharacterRange = CFRange(location: range.location - 1, length: 1)
            return bounds(for: element, range: previousCharacterRange)
        }

        if range.location < textLength {
            let nextCharacterRange = CFRange(location: range.location, length: 1)
            return bounds(for: element, range: nextCharacterRange)
        }

        let caretRange = CFRange(location: range.location, length: 0)
        return bounds(for: element, range: caretRange)
    }

    private func bounds(for element: AXUIElement, range: CFRange) -> CGRect? {
        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
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

    private func focusedTextStyle(in element: AXUIElement, textLength: Int, range: CFRange) -> FocusedTextStyle? {
        let location: Int
        let length: Int

        if range.location > 0 {
            location = range.location - 1
            length = 1
        } else if textLength > 0 {
            location = 0
            length = 1
        } else {
            return nil
        }

        var sampleRange = CFRange(location: location, length: length)
        guard let rangeValue = AXValueCreate(.cfRange, &sampleRange) else {
            return nil
        }

        var attributedValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &attributedValue
        )

        guard result == .success,
              let attributedString = attributedValue as? NSAttributedString,
              attributedString.length > 0 else {
            return nil
        }

        let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
        let font = accessibilityFont(from: attributes) ?? NSFont.systemFont(ofSize: 13)

        return FocusedTextStyle(
            fontName: font.fontName,
            fontSize: font.pointSize,
            foregroundColor: accessibilityForegroundColor(from: attributes)
        )
    }

    private func accessibilityFont(from attributes: [NSAttributedString.Key: Any]) -> NSFont? {
        if let font = attributes[.font] as? NSFont {
            return font
        }

        let fontKey = NSAttributedString.Key("AXFont")
        guard let fontDictionary = attributes[fontKey] as? [String: Any] else {
            return nil
        }

        let fontSize = (fontDictionary["AXFontSize"] as? NSNumber)?.doubleValue ?? 13
        let fontName = fontDictionary["AXFontName"] as? String
            ?? fontDictionary["AXVisibleName"] as? String
            ?? fontDictionary["AXFontFamily"] as? String

        guard let fontName else {
            return NSFont.systemFont(ofSize: CGFloat(fontSize))
        }

        return NSFont(name: fontName, size: CGFloat(fontSize))
            ?? NSFont.systemFont(ofSize: CGFloat(fontSize))
    }

    private func accessibilityForegroundColor(from attributes: [NSAttributedString.Key: Any]) -> NSColor? {
        if let color = attributes[.foregroundColor] as? NSColor {
            return color
        }

        let colorKey = NSAttributedString.Key("AXForegroundColor")
        if let color = attributes[colorKey] as? NSColor {
            return color
        }

        if let value = attributes[colorKey] {
            let cfValue = value as CFTypeRef
            if CFGetTypeID(cfValue) == CGColor.typeID {
                return NSColor(cgColor: value as! CGColor)
            }
        }

        return nil
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
