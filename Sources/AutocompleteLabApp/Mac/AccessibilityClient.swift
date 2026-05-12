import AppKit
import ApplicationServices
import AutocompleteLabCore
import CoreGraphics

struct RunningApplicationInfo: Equatable, Sendable {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
}

struct FocusedTextContext: Equatable, Sendable {
    let elementIdentifier: Int
    let role: String?
    let subrole: String?
    let fingerprint: FocusedElementFingerprint
    let textBeforeCursor: String
    let textAfterCursor: String
    let selectedText: String
    let selectedTextLength: Int
    let caretRect: CGRect?
    let elementRect: CGRect?
    let windowRect: CGRect?
    let windowIdentifier: Int?
    let textLineRect: CGRect?
    let textStyle: FocusedTextStyle?
    let isSecure: Bool
    let fieldClassification: AXFieldClassification
    let caretIsSynthetic: Bool
    let capabilities: FocusedTextCapabilities

    init(
        elementIdentifier: Int,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        textBeforeCursor: String,
        textAfterCursor: String,
        selectedText: String = "",
        selectedTextLength: Int,
        caretRect: CGRect?,
        elementRect: CGRect?,
        windowRect: CGRect?,
        windowIdentifier: Int?,
        textLineRect: CGRect?,
        textStyle: FocusedTextStyle?,
        isSecure: Bool,
        fieldClassification: AXFieldClassification = AXFieldClassification(kind: .unknown, reason: "unknown"),
        caretIsSynthetic: Bool,
        capabilities: FocusedTextCapabilities
    ) {
        self.elementIdentifier = elementIdentifier
        self.role = role
        self.subrole = subrole
        self.fingerprint = fingerprint
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.selectedText = selectedText
        self.selectedTextLength = selectedTextLength
        self.caretRect = caretRect
        self.elementRect = elementRect
        self.windowRect = windowRect
        self.windowIdentifier = windowIdentifier
        self.textLineRect = textLineRect
        self.textStyle = textStyle
        self.isSecure = isSecure
        self.fieldClassification = fieldClassification
        self.caretIsSynthetic = caretIsSynthetic
        self.capabilities = capabilities
    }
}

struct FocusedTextCapabilities: Equatable, Sendable {
    let canReadValue: Bool
    let canReadSelectedTextRange: Bool
    let canReadBoundsForRange: Bool
    let canReadAttributedText: Bool
    let canSetSelectedText: Bool

    var supportsInlineSuggestions: Bool {
        canReadValue && canReadSelectedTextRange && canReadBoundsForRange
    }

    var supportsAXInsertion: Bool {
        canSetSelectedText
    }
}

struct FocusedTextReadOptions: Equatable, Sendable {
    static let standard = FocusedTextReadOptions()
    static let syntheticTextAreaFastPath = FocusedTextReadOptions(
        preferDirectTextSnapshot: true,
        skipParameterizedTextGeometry: true,
        skipAttributedText: true,
        useMinimalFingerprint: true,
        skipWindowLookup: true,
        assumedCanSetSelectedText: true
    )

    let preferDirectTextSnapshot: Bool
    let skipParameterizedTextGeometry: Bool
    let skipAttributedText: Bool
    let useMinimalFingerprint: Bool
    let skipWindowLookup: Bool
    let assumedCanSetSelectedText: Bool?

    init(
        preferDirectTextSnapshot: Bool = false,
        skipParameterizedTextGeometry: Bool = false,
        skipAttributedText: Bool = false,
        useMinimalFingerprint: Bool = false,
        skipWindowLookup: Bool = false,
        assumedCanSetSelectedText: Bool? = nil
    ) {
        self.preferDirectTextSnapshot = preferDirectTextSnapshot
        self.skipParameterizedTextGeometry = skipParameterizedTextGeometry
        self.skipAttributedText = skipAttributedText
        self.useMinimalFingerprint = useMinimalFingerprint
        self.skipWindowLookup = skipWindowLookup
        self.assumedCanSetSelectedText = assumedCanSetSelectedText
    }
}

struct FocusedTextDiagnostics: Equatable, Sendable {
    let bundleIdentifier: String?
    let localizedAppName: String?
    let role: String?
    let subrole: String?
    let fingerprint: FocusedElementFingerprint
    let isSecure: Bool
    let textBeforeCursorLength: Int
    let textAfterCursorLength: Int
    let selectedRangeDescription: String
    let caretRect: CGRect?
    let elementRect: CGRect?
    let windowRect: CGRect?
    let windowIdentifier: Int?
    let textLineRect: CGRect?
    let capabilities: FocusedTextCapabilities
    let attributeDump: FocusedElementAttributeDump

    var summary: String {
        """
        App: \(localizedAppName ?? "Unknown") (\(bundleIdentifier ?? "unknown bundle"))
        Role: \(role ?? "unknown")
        Subrole: \(subrole ?? "none")
        Window title: \(fingerprint.windowTitle.map { DiagnosticValueRedactor.stringSummary(length: $0.count) } ?? "missing")
        Secure: \(isSecure)
        Selected range: \(selectedRangeDescription)
        Text before cursor: \(textBeforeCursorLength) chars
        Text after cursor: \(textAfterCursorLength) chars
        Caret rect: \(caretRect.map(String.init(describing:)) ?? "missing")
        Element rect: \(elementRect.map(String.init(describing:)) ?? "missing")
        Window rect: \(windowRect.map(String.init(describing:)) ?? "missing")
        Window identifier: \(windowIdentifier.map(String.init) ?? "missing")
        Text line rect: \(textLineRect.map(String.init(describing:)) ?? "missing")
        Capabilities:
          value: \(capabilities.canReadValue)
          selected range: \(capabilities.canReadSelectedTextRange)
          bounds for range: \(capabilities.canReadBoundsForRange)
          attributed text: \(capabilities.canReadAttributedText)
          selected text insertion: \(capabilities.canSetSelectedText)

        Attributes:
        \(attributeDump.attributeSummary)

        Parameterized attributes:
        \(attributeDump.parameterizedAttributeSummary)
        """
    }
}

struct FocusedElementAttributeDump: Equatable, Sendable {
    let attributes: [FocusedElementAttributeSummary]
    let parameterizedAttributes: [String]

    var attributeSummary: String {
        guard !attributes.isEmpty else {
            return "  unavailable"
        }

        return attributes
            .map { "  \($0.name): \($0.valueSummary) | settable=\($0.isSettable)" }
            .joined(separator: "\n")
    }

    var parameterizedAttributeSummary: String {
        guard !parameterizedAttributes.isEmpty else {
            return "  none"
        }

        return parameterizedAttributes
            .map { "  \($0)" }
            .joined(separator: "\n")
    }
}

struct FocusedElementAttributeSummary: Equatable, Sendable {
    let name: String
    let valueSummary: String
    let isSettable: Bool
}

struct FocusedTextStyle: Equatable, @unchecked Sendable {
    let fontName: String
    let fontSize: CGFloat
    let foregroundColor: NSColor?

    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
}

private struct EditableTextSnapshot {
    let slice: CursorTextSlice
    let utf16Length: Int
    let canReadValue: Bool
}

final class AccessibilityClient: @unchecked Sendable {
    private let sensitiveTextFieldPolicy = SensitiveTextFieldPolicy()
    private let descendantTextFallbackPolicy = DescendantTextFallbackPolicy()
    private let focusedContextBeforeUTF16Limit = 2_000
    private let focusedContextAfterUTF16Limit = 500

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

    func focusedTextContext(allowDescendantTextFallback: Bool = false) -> FocusedTextContext? {
        guard let app = frontmostApplication() else {
            return nil
        }

        return focusedTextContext(
            for: app,
            allowDescendantTextFallback: allowDescendantTextFallback,
            options: .standard
        )
    }

    func focusedTextContext(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool = false,
        options: FocusedTextReadOptions = .standard
    ) -> FocusedTextContext? {
        guard let focusedElement = focusedElement(
            for: app,
            allowWindowDescendantFallback: allowDescendantTextFallback
        ) else {
            return nil
        }

        configureMessagingTimeout(for: focusedElement)

        let role = copyAttribute(focusedElement, attribute: kAXRoleAttribute) as? String
        let subrole = copyAttribute(focusedElement, attribute: kAXSubroleAttribute) as? String
        let fingerprint = options.useMinimalFingerprint
            ? FocusedElementFingerprint()
            : focusedElementFingerprint(
                for: focusedElement,
                processIdentifier: app.processIdentifier
            )
        let isSecure = isSensitiveTextElement(
            focusedElement,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint
        )

        guard !isSecure else {
            return secureTextContext(
                element: focusedElement,
                role: role,
                subrole: subrole,
                fingerprint: fingerprint,
                processIdentifier: app.processIdentifier
            )
        }

        let selectedRange = selectedTextRange(in: focusedElement)
        guard let textSnapshot = editableTextSnapshot(
            in: focusedElement,
            role: role,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            windowTitle: fingerprint.windowTitle,
            allowDescendantTextFallback: allowDescendantTextFallback,
            selectedRange: selectedRange,
            options: options
        ) else {
            return nil
        }

        let elementRect = elementBounds(for: focusedElement)
        let windowIdentifier = options.skipWindowLookup
            ? nil
            : containingWindowIdentifier(for: focusedElement, processIdentifier: app.processIdentifier)
        let windowRect = options.skipWindowLookup
            ? nil
            : containingWindowBounds(for: focusedElement, processIdentifier: app.processIdentifier)
        let selectedTextLength = max(0, selectedRange?.length ?? 0)
        let caretRect = options.skipParameterizedTextGeometry ? nil : selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(
                caretBounds(for: focusedElement, range: $0),
                elementRect: elementRect,
                windowRect: windowRect
            )
        }
        let textLineRect = options.skipParameterizedTextGeometry ? nil : selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(
                textLineBounds(
                    for: focusedElement,
                    textLength: textSnapshot.utf16Length,
                    textBeforeCursor: textSnapshot.slice.textBeforeCursor,
                    range: $0
                ),
                elementRect: elementRect,
                windowRect: windowRect
            )
        }
        let textStyle = options.skipAttributedText ? nil : selectedRange.flatMap {
            focusedTextStyle(in: focusedElement, textLength: textSnapshot.utf16Length, range: $0)
        }
        let capabilities = textCapabilities(
            for: focusedElement,
            selectedRange: selectedRange,
            caretRect: caretRect,
            textStyle: textStyle,
            canReadValue: textSnapshot.canReadValue,
            canReadBoundsForRange: options.skipParameterizedTextGeometry ? false : nil,
            canReadAttributedText: options.skipAttributedText ? false : nil,
            canSetSelectedText: options.assumedCanSetSelectedText
        )

        return FocusedTextContext(
            elementIdentifier: Int(CFHash(focusedElement)),
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            textBeforeCursor: textSnapshot.slice.textBeforeCursor,
            textAfterCursor: textSnapshot.slice.textAfterCursor,
            selectedTextLength: selectedTextLength,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            windowIdentifier: windowIdentifier,
            textLineRect: textLineRect,
            textStyle: textStyle,
            isSecure: isSecure,
            caretIsSynthetic: false,
            capabilities: capabilities
        )
    }

    private func secureTextContext(
        element: AXUIElement,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        processIdentifier: pid_t
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: Int(CFHash(element)),
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            textBeforeCursor: "",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: elementBounds(for: element),
            windowRect: containingWindowBounds(for: element, processIdentifier: processIdentifier),
            windowIdentifier: containingWindowIdentifier(for: element, processIdentifier: processIdentifier),
            textLineRect: nil,
            textStyle: nil,
            isSecure: true,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: false,
                canReadSelectedTextRange: false,
                canReadBoundsForRange: false,
                canReadAttributedText: false,
                canSetSelectedText: false
            )
        )
    }

    func insertText(_ text: String, allowDescendantTextFallback: Bool = false) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let focusedElement = focusedElement(
                  for: RunningApplicationInfo(
                      bundleIdentifier: bundleIdentifier,
                      localizedName: app.localizedName ?? bundleIdentifier,
                      processIdentifier: app.processIdentifier
                  ),
                  allowWindowDescendantFallback: allowDescendantTextFallback
              ) else {
            return false
        }

        let textBeforeInsert = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        guard result == .success else {
            return false
        }

        guard let textBeforeInsert else {
            return true
        }

        let textAfterInsert = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        return textAfterInsert != textBeforeInsert
    }

    func replaceSelectedTextBySettingValue(_ text: String, allowDescendantTextFallback: Bool = false) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let focusedElement = focusedElement(
                  for: RunningApplicationInfo(
                      bundleIdentifier: bundleIdentifier,
                      localizedName: app.localizedName ?? bundleIdentifier,
                      processIdentifier: app.processIdentifier
                  ),
                  allowWindowDescendantFallback: allowDescendantTextFallback
              ),
              let textBeforeInsert = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String,
              let selectedRange = selectedTextRange(in: focusedElement),
              let replacement = SelectedTextRangeReplacer.replacingSelectedRange(
                  in: textBeforeInsert,
                  utf16Location: selectedRange.location,
                  utf16Length: selectedRange.length,
                  with: text
              ) else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            replacement.text as CFTypeRef
        )

        guard result == .success else {
            return false
        }

        var cursorRange = CFRange(location: replacement.cursorUTF16Offset, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &cursorRange) {
            _ = AXUIElementSetAttributeValue(
                focusedElement,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }

        if replacement.cursorUTF16Offset == replacement.text.utf16.count,
           !cursorMatches(cursorRange, in: focusedElement) {
            moveInsertionPointToLineEnd()
        }

        let textAfterInsert = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        return textAfterInsert == replacement.text
    }

    func restoreFocusedTextValue(_ text: String, cursorUTF16Offset: Int) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = focusedElement(for: app.processIdentifier) else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        guard result == .success else {
            return false
        }

        let boundedOffset = min(max(0, cursorUTF16Offset), text.utf16.count)
        var cursorRange = CFRange(location: boundedOffset, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &cursorRange) {
            _ = AXUIElementSetAttributeValue(
                focusedElement,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }

        let restoredText = copyAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        return restoredText == text
    }

    private func cursorMatches(_ expectedRange: CFRange, in element: AXUIElement) -> Bool {
        guard let currentRange = selectedTextRange(in: element) else {
            return false
        }

        return currentRange.location == expectedRange.location
            && currentRange.length == expectedRange.length
    }

    private func moveInsertionPointToLineEnd() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    func focusedTextDiagnostics(allowDescendantTextFallback: Bool = false) -> FocusedTextDiagnostics? {
        guard let app = frontmostApplication() else {
            return nil
        }

        return focusedTextDiagnostics(for: app, allowDescendantTextFallback: allowDescendantTextFallback)
    }

    func focusedTextDiagnostics(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool = false
    ) -> FocusedTextDiagnostics? {
        guard let focusedElement = focusedElement(
            for: app,
            allowWindowDescendantFallback: allowDescendantTextFallback
        ) else {
            return nil
        }

        configureMessagingTimeout(for: focusedElement)

        let role = copyAttribute(focusedElement, attribute: kAXRoleAttribute) as? String
        let subrole = copyAttribute(focusedElement, attribute: kAXSubroleAttribute) as? String
        let fingerprint = focusedElementFingerprint(
            for: focusedElement,
            processIdentifier: app.processIdentifier
        )
        let text = editableText(
            in: focusedElement,
            role: role,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            windowTitle: fingerprint.windowTitle,
            allowDescendantTextFallback: allowDescendantTextFallback
        )
        let selectedRange = selectedTextRange(in: focusedElement)
        let textSlice = text.map {
            CursorTextSplitter.split($0, utf16Offset: selectedRange?.location ?? $0.utf16.count)
        }
        let elementRect = elementBounds(for: focusedElement)
        let windowIdentifier = containingWindowIdentifier(for: focusedElement, processIdentifier: app.processIdentifier)
        let windowRect = containingWindowBounds(for: focusedElement, processIdentifier: app.processIdentifier)
        let caretRect = selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(
                caretBounds(for: focusedElement, range: $0),
                elementRect: elementRect,
                windowRect: windowRect
            )
        }
        let textLineRect = selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(
                textLineBounds(
                    for: focusedElement,
                    textLength: text?.utf16.count ?? 0,
                    textBeforeCursor: textSlice?.textBeforeCursor ?? "",
                    range: $0
                ),
                elementRect: elementRect,
                windowRect: windowRect
            )
        }
        let textStyle = selectedRange.flatMap {
            focusedTextStyle(in: focusedElement, textLength: text?.utf16.count ?? 0, range: $0)
        }
        let capabilities = textCapabilities(
            for: focusedElement,
            selectedRange: selectedRange,
            caretRect: caretRect,
            textStyle: textStyle
        )
        let attributeDump = focusedElementAttributeDump(for: focusedElement)

        return FocusedTextDiagnostics(
            bundleIdentifier: app.bundleIdentifier,
            localizedAppName: app.localizedName,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            isSecure: isSensitiveTextElement(
                focusedElement,
                role: role,
                subrole: subrole,
                fingerprint: fingerprint
            ),
            textBeforeCursorLength: textSlice?.textBeforeCursor.count ?? 0,
            textAfterCursorLength: textSlice?.textAfterCursor.count ?? 0,
            selectedRangeDescription: selectedRange.map { "location=\($0.location), length=\($0.length)" } ?? "missing",
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            windowIdentifier: windowIdentifier,
            textLineRect: textLineRect,
            capabilities: capabilities,
            attributeDump: attributeDump
        )
    }

    private func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)
        guard let focusedElementValue = copyAttribute(appElement, attribute: kAXFocusedUIElementAttribute) else {
            return nil
        }

        return (focusedElementValue as! AXUIElement)
    }

    private func focusedElement(
        for app: RunningApplicationInfo,
        allowWindowDescendantFallback: Bool
    ) -> AXUIElement? {
        if let focusedElement = focusedElement(for: app.processIdentifier) {
            return focusedElement
        }

        guard allowWindowDescendantFallback,
              app.bundleIdentifier == "com.google.Chrome",
              let focusedWindow = focusedWindow(for: app.processIdentifier),
              let windowTitle = copyAttribute(focusedWindow, attribute: kAXTitleAttribute) as? String,
              descendantTextFallbackPolicy.allowsFallback(
                  bundleIdentifier: app.bundleIdentifier,
                  role: "AXWebArea",
                  directText: nil,
                  windowTitle: windowTitle
              ) else {
            return nil
        }

        return bestEditableDescendant(in: focusedWindow)
    }

    private func focusedWindow(for processIdentifier: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)
        guard let windowValue = copyAttribute(appElement, attribute: kAXFocusedWindowAttribute) else {
            return nil
        }

        return (windowValue as! AXUIElement)
    }

    private func bestEditableDescendant(in element: AXUIElement) -> AXUIElement? {
        let result = editableDescendantSearchResult(in: element)
        return result.focused ?? result.first
    }

    private func editableDescendantSearchResult(
        in element: AXUIElement,
        depth: Int = 0
    ) -> (focused: AXUIElement?, first: AXUIElement?) {
        guard depth < 8 else {
            return (focused: nil, first: nil)
        }

        configureMessagingTimeout(for: element)
        let role = copyAttribute(element, attribute: kAXRoleAttribute) as? String
        if ["AXTextArea", "AXTextField", "AXWebArea"].contains(role ?? "") {
            let isFocused = (copyAttribute(element, attribute: kAXFocusedAttribute) as? Bool) == true
            return (focused: isFocused ? element : nil, first: element)
        }

        let children = copyAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] ?? []
        var first: AXUIElement?
        for child in children {
            let result = editableDescendantSearchResult(in: child, depth: depth + 1)
            if let focused = result.focused {
                return (focused: focused, first: first ?? result.first)
            }
            first = first ?? result.first
        }

        return (focused: nil, first: first)
    }

    private func copyAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func focusedElementAttributeDump(for element: AXUIElement) -> FocusedElementAttributeDump {
        let attributes = attributeNames(for: element).map { attribute in
            FocusedElementAttributeSummary(
                name: attribute,
                valueSummary: diagnosticValueSummary(copyAttribute(element, attribute: attribute)),
                isSettable: canSetAttribute(element, attribute: attribute)
            )
        }

        return FocusedElementAttributeDump(
            attributes: attributes,
            parameterizedAttributes: parameterizedAttributeNames(for: element)
        )
    }

    private func attributeNames(for element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &names)

        guard result == .success,
              let names = names as? [String] else {
            return []
        }

        return names.sorted()
    }

    private func parameterizedAttributeNames(for element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyParameterizedAttributeNames(element, &names)

        guard result == .success,
              let names = names as? [String] else {
            return []
        }

        return names.sorted()
    }

    private func diagnosticValueSummary(_ value: CFTypeRef?) -> String {
        guard let value else {
            return "unavailable"
        }

        if let string = value as? String {
            return DiagnosticValueRedactor.stringSummary(length: string.count)
        }

        if let attributedString = value as? NSAttributedString {
            return DiagnosticValueRedactor.attributedStringSummary(length: attributedString.length)
        }

        if let array = value as? [Any] {
            return DiagnosticValueRedactor.arraySummary(count: array.count)
        }

        if let bool = value as? Bool {
            return String(bool)
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        let cfTypeID = CFGetTypeID(value)

        if cfTypeID == AXUIElementGetTypeID() {
            return "AXUIElement"
        }

        if cfTypeID == AXValueGetTypeID(),
           let summary = axValueSummary(value as! AXValue) {
            return summary
        }

        return DiagnosticValueRedactor.unknownSummary(typeName: String(describing: type(of: value)))
    }

    private func axValueSummary(_ value: AXValue) -> String? {
        switch AXValueGetType(value) {
        case .cfRange:
            var range = CFRange()
            guard AXValueGetValue(value, .cfRange, &range) else {
                return nil
            }

            return "Range(location=\(range.location), length=\(range.length))"

        case .cgPoint:
            var point = CGPoint.zero
            guard AXValueGetValue(value, .cgPoint, &point) else {
                return nil
            }

            return "Point(x=\(Int(point.x)), y=\(Int(point.y)))"

        case .cgSize:
            var size = CGSize.zero
            guard AXValueGetValue(value, .cgSize, &size) else {
                return nil
            }

            return "Size(width=\(Int(size.width)), height=\(Int(size.height)))"

        case .cgRect:
            var rect = CGRect.zero
            guard AXValueGetValue(value, .cgRect, &rect) else {
                return nil
            }

            return "Rect(x=\(Int(rect.origin.x)), y=\(Int(rect.origin.y)), width=\(Int(rect.width)), height=\(Int(rect.height)))"

        default:
            return "AXValue(\(AXValueGetType(value).rawValue))"
        }
    }

    private func editableTextSnapshot(
        in element: AXUIElement,
        role: String?,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        windowTitle: String?,
        allowDescendantTextFallback: Bool,
        selectedRange: CFRange?,
        options: FocusedTextReadOptions = .standard
    ) -> EditableTextSnapshot? {
        if options.preferDirectTextSnapshot,
           let directSnapshot = directEditableTextSnapshot(
               in: element,
               role: role,
               bundleIdentifier: bundleIdentifier,
               processIdentifier: processIdentifier,
               windowTitle: windowTitle,
               allowDescendantTextFallback: allowDescendantTextFallback,
               selectedRange: selectedRange
           ) {
            return directSnapshot
        }

        if let selectedRange,
           let boundedSnapshot = boundedEditableTextSnapshot(
               in: element,
               selectedRange: selectedRange
           ) {
            return boundedSnapshot
        }

        guard let text = editableText(
            in: element,
            role: role,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            windowTitle: windowTitle,
            allowDescendantTextFallback: allowDescendantTextFallback
        ) else {
            return nil
        }

        return EditableTextSnapshot(
            slice: CursorTextSplitter.split(
                text,
                utf16Offset: selectedRange?.location ?? text.utf16.count
            ),
            utf16Length: text.utf16.count,
            canReadValue: true
        )
    }

    private func directEditableTextSnapshot(
        in element: AXUIElement,
        role: String?,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        windowTitle: String?,
        allowDescendantTextFallback: Bool,
        selectedRange: CFRange?
    ) -> EditableTextSnapshot? {
        guard let text = editableText(
            in: element,
            role: role,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            windowTitle: windowTitle,
            allowDescendantTextFallback: allowDescendantTextFallback
        ) else {
            return nil
        }

        return EditableTextSnapshot(
            slice: CursorTextSplitter.split(
                text,
                utf16Offset: selectedRange?.location ?? text.utf16.count
            ),
            utf16Length: text.utf16.count,
            canReadValue: true
        )
    }

    private func boundedEditableTextSnapshot(
        in element: AXUIElement,
        selectedRange: CFRange
    ) -> EditableTextSnapshot? {
        guard selectedRange.location >= 0,
              selectedRange.length >= 0,
              let textLength = editableTextUTF16Length(in: element) else {
            return nil
        }

        let cursorLocation = min(selectedRange.location, textLength)
        let beforeStart = max(0, cursorLocation - focusedContextBeforeUTF16Limit)
        let beforeLength = cursorLocation - beforeStart
        let afterLength = min(
            focusedContextAfterUTF16Limit,
            max(0, textLength - cursorLocation)
        )

        guard let before = stringForRange(
            in: element,
            range: CFRange(location: beforeStart, length: beforeLength)
        ),
            let after = stringForRange(
                in: element,
                range: CFRange(location: cursorLocation, length: afterLength)
            ) else {
            return nil
        }

        return EditableTextSnapshot(
            slice: CursorTextSlice(textBeforeCursor: before, textAfterCursor: after),
            utf16Length: textLength,
            canReadValue: true
        )
    }

    private func editableTextUTF16Length(in element: AXUIElement) -> Int? {
        if let number = copyAttribute(element, attribute: "AXNumberOfCharacters") as? NSNumber {
            return max(0, number.intValue)
        }

        if let string = copyAttribute(element, attribute: kAXValueAttribute) as? String {
            return string.utf16.count
        }

        return nil
    }

    private func stringForRange(in element: AXUIElement, range: CFRange) -> String? {
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }

        guard range.length > 0 else {
            return ""
        }

        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            return nil
        }

        var stringValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXStringForRange" as CFString,
            rangeValue,
            &stringValue
        )

        guard result == .success else {
            return nil
        }

        return stringValue as? String
    }

    private func editableText(
        in element: AXUIElement,
        role: String?,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        windowTitle: String?,
        allowDescendantTextFallback: Bool
    ) -> String? {
        let directText = copyAttribute(element, attribute: kAXValueAttribute) as? String
        guard allowDescendantTextFallback,
              descendantTextFallbackPolicy.allowsFallback(
                  bundleIdentifier: bundleIdentifier,
                  role: role,
                  directText: directText,
                  windowTitle: windowTitle ?? containingWindowTitle(
                      for: element,
                      processIdentifier: processIdentifier
                  )
              ) else {
            return directText
        }

        let descendantText = descendantText(in: element)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !descendantText.isEmpty else {
            return directText
        }

        return descendantText
    }

    private func containingWindowTitle(for element: AXUIElement, processIdentifier: pid_t) -> String? {
        if let windowValue = copyAttribute(element, attribute: kAXWindowAttribute),
           let title = copyAttribute((windowValue as! AXUIElement), attribute: kAXTitleAttribute) as? String {
            return title
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        guard let windowValue = copyAttribute(appElement, attribute: kAXFocusedWindowAttribute) else {
            return nil
        }

        return copyAttribute((windowValue as! AXUIElement), attribute: kAXTitleAttribute) as? String
    }

    private func focusedElementFingerprint(
        for element: AXUIElement,
        processIdentifier: pid_t
    ) -> FocusedElementFingerprint {
        FocusedElementFingerprint(
            identifier: compactAttributeText(copyAttribute(element, attribute: "AXIdentifier") as? String),
            title: compactAttributeText(copyAttribute(element, attribute: kAXTitleAttribute) as? String),
            description: compactAttributeText(copyAttribute(element, attribute: kAXDescriptionAttribute) as? String),
            help: compactAttributeText(copyAttribute(element, attribute: kAXHelpAttribute) as? String),
            placeholder: compactAttributeText(copyAttribute(element, attribute: "AXPlaceholderValue") as? String),
            windowTitle: compactAttributeText(containingWindowTitle(for: element, processIdentifier: processIdentifier))
        )
    }

    private func compactAttributeText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let compact = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else {
            return nil
        }

        return String(compact.prefix(120))
    }

    private func descendantText(in element: AXUIElement, depth: Int = 0) -> String {
        guard depth < 6 else {
            return ""
        }

        let children = copyAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] ?? []
        var parts: [String] = []

        for child in children {
            configureMessagingTimeout(for: child)

            if let value = copyAttribute(child, attribute: kAXValueAttribute) as? String,
               !value.isEmpty {
                parts.append(value)
            }

            let nestedText = descendantText(in: child, depth: depth + 1)
            if !nestedText.isEmpty {
                parts.append(nestedText)
            }
        }

        return parts.joined(separator: "\n")
    }

    private func configureMessagingTimeout(for element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, 0.12)
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

    private func elementBounds(for element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAttribute(element, attribute: kAXPositionAttribute),
              let sizeValue = copyAttribute(element, attribute: kAXSizeAttribute) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func containingWindowBounds(for element: AXUIElement, processIdentifier: pid_t) -> CGRect? {
        guard let window = containingWindowElement(for: element, processIdentifier: processIdentifier) else {
            return nil
        }

        return elementBounds(for: window)
    }

    private func containingWindowIdentifier(for element: AXUIElement, processIdentifier: pid_t) -> Int? {
        containingWindowElement(for: element, processIdentifier: processIdentifier)
            .map { Int(CFHash($0)) }
    }

    private func containingWindowElement(for element: AXUIElement, processIdentifier: pid_t) -> AXUIElement? {
        if let windowValue = copyAttribute(element, attribute: kAXWindowAttribute) {
            return (windowValue as! AXUIElement)
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        guard let windowValue = copyAttribute(appElement, attribute: kAXFocusedWindowAttribute) else {
            return nil
        }

        return (windowValue as! AXUIElement)
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

    private func canSetAttribute(_ element: AXUIElement, attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private func textCapabilities(
        for element: AXUIElement,
        selectedRange: CFRange?,
        caretRect: CGRect?,
        textStyle: FocusedTextStyle?,
        canReadValue: Bool? = nil,
        canReadBoundsForRange: Bool? = nil,
        canReadAttributedText: Bool? = nil,
        canSetSelectedText: Bool? = nil
    ) -> FocusedTextCapabilities {
        FocusedTextCapabilities(
            canReadValue: canReadValue ?? (copyAttribute(element, attribute: kAXValueAttribute) is String),
            canReadSelectedTextRange: selectedRange != nil,
            canReadBoundsForRange: canReadBoundsForRange ?? (caretRect != nil),
            canReadAttributedText: canReadAttributedText ?? (textStyle != nil),
            canSetSelectedText: canSetSelectedText ?? canSetAttribute(element, attribute: kAXSelectedTextAttribute)
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

    private func isSensitiveTextElement(
        _ element: AXUIElement,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint
    ) -> Bool {
        if subrole == "AXSecureTextField" {
            return true
        }

        if let protected = copyAttribute(element, attribute: "AXProtectedContent") as? Bool {
            return protected
        }

        return sensitiveTextFieldPolicy.isSensitive(
            role: role,
            subrole: subrole,
            fingerprint: fingerprint
        )
    }
}
