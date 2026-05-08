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
    let textLineRect: CGRect?
    let visibleCharacterRange: AccessibilityCharacterRange?
    let insertionPointLineNumber: Int?
    let textStyle: FocusedTextStyle?
    let isSecure: Bool
    let fieldClassification: AXFieldClassification
    let caretIsSynthetic: Bool
    let capabilities: FocusedTextCapabilities
    let axReadErrors: [AXAttributeReadError]
}

struct FocusedTextCapabilities: Equatable, Sendable {
    let canReadValue: Bool
    let canReadSelectedTextRange: Bool
    let canReadBoundsForRange: Bool
    let canReadAttributedText: Bool
    let canSetSelectedText: Bool
    let canReadVisibleCharacterRange: Bool
    let canReadInsertionPointLineNumber: Bool

    init(
        canReadValue: Bool,
        canReadSelectedTextRange: Bool,
        canReadBoundsForRange: Bool,
        canReadAttributedText: Bool,
        canSetSelectedText: Bool,
        canReadVisibleCharacterRange: Bool = false,
        canReadInsertionPointLineNumber: Bool = false
    ) {
        self.canReadValue = canReadValue
        self.canReadSelectedTextRange = canReadSelectedTextRange
        self.canReadBoundsForRange = canReadBoundsForRange
        self.canReadAttributedText = canReadAttributedText
        self.canSetSelectedText = canSetSelectedText
        self.canReadVisibleCharacterRange = canReadVisibleCharacterRange
        self.canReadInsertionPointLineNumber = canReadInsertionPointLineNumber
    }

    var supportsInlineSuggestions: Bool {
        canReadValue && canReadSelectedTextRange && canReadBoundsForRange
    }

    var supportsAXInsertion: Bool {
        canSetSelectedText
    }
}

struct FocusedTextDiagnostics: Equatable, Sendable {
    let bundleIdentifier: String?
    let localizedAppName: String?
    let role: String?
    let subrole: String?
    let isSecure: Bool
    let textBeforeCursorLength: Int
    let textAfterCursorLength: Int
    let selectedRangeDescription: String
    let caretRect: CGRect?
    let elementRect: CGRect?
    let windowRect: CGRect?
    let textLineRect: CGRect?
    let visibleCharacterRange: AccessibilityCharacterRange?
    let insertionPointLineNumber: Int?
    let capabilities: FocusedTextCapabilities
    let attributeDump: FocusedElementAttributeDump
    let axReadErrors: [AXAttributeReadError]

    var summary: String {
        """
        App: \(localizedAppName ?? "Unknown") (\(bundleIdentifier ?? "unknown bundle"))
        Role: \(role ?? "unknown")
        Subrole: \(subrole ?? "none")
        Secure: \(isSecure)
        Selected range: \(selectedRangeDescription)
        Text before cursor: \(textBeforeCursorLength) chars
        Text after cursor: \(textAfterCursorLength) chars
        Caret rect: \(caretRect.map(String.init(describing:)) ?? "missing")
        Element rect: \(elementRect.map(String.init(describing:)) ?? "missing")
        Window rect: \(windowRect.map(String.init(describing:)) ?? "missing")
        Text line rect: \(textLineRect.map(String.init(describing:)) ?? "missing")
        Visible character range: \(visibleCharacterRange.map { "location=\($0.location), length=\($0.length)" } ?? "missing")
        Insertion line: \(insertionPointLineNumber.map(String.init) ?? "missing")
        Capabilities:
          value: \(capabilities.canReadValue)
          selected range: \(capabilities.canReadSelectedTextRange)
          bounds for range: \(capabilities.canReadBoundsForRange)
          attributed text: \(capabilities.canReadAttributedText)
          selected text insertion: \(capabilities.canSetSelectedText)
          visible range: \(capabilities.canReadVisibleCharacterRange)
          insertion line: \(capabilities.canReadInsertionPointLineNumber)
        AX read errors:
        \(axReadErrorSummary)

        Attributes:
        \(attributeDump.attributeSummary)

        Parameterized attributes:
        \(attributeDump.parameterizedAttributeSummary)
        """
    }

    private var axReadErrorSummary: String {
        guard !axReadErrors.isEmpty else {
            return "  none"
        }

        return axReadErrors
            .map { "  \($0.attribute): \($0.code)" }
            .joined(separator: "\n")
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

struct AXAttributeReadError: Equatable, Sendable {
    let attribute: String
    let code: String
    let isTimeoutOrCannotComplete: Bool
}

private final class AXAttributeReadRecorder {
    private(set) var errors: [AXAttributeReadError] = []

    func record(attribute: String, result: AXError) {
        guard result != .success else {
            return
        }

        let code = Self.traceSafeCode(for: result)
        errors.append(AXAttributeReadError(
            attribute: attribute,
            code: code,
            isTimeoutOrCannotComplete: result == .cannotComplete
        ))
    }

    private static func traceSafeCode(for result: AXError) -> String {
        switch result {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .illegalArgument:
            return "illegalArgument"
        case .invalidUIElement:
            return "invalidUIElement"
        case .invalidUIElementObserver:
            return "invalidUIElementObserver"
        case .cannotComplete:
            return "cannotComplete"
        case .attributeUnsupported:
            return "attributeUnsupported"
        case .actionUnsupported:
            return "actionUnsupported"
        case .notificationUnsupported:
            return "notificationUnsupported"
        case .notImplemented:
            return "notImplemented"
        case .notificationAlreadyRegistered:
            return "notificationAlreadyRegistered"
        case .notificationNotRegistered:
            return "notificationNotRegistered"
        case .apiDisabled:
            return "apiDisabled"
        case .noValue:
            return "noValue"
        case .parameterizedAttributeUnsupported:
            return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision:
            return "notEnoughPrecision"
        @unknown default:
            return "unknown"
        }
    }
}

final class AccessibilityClient: @unchecked Sendable {
    private let sensitiveTextFieldPolicy = SensitiveTextFieldPolicy()
    private let fieldClassifier = AXFieldClassifier()

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
            allowDescendantTextFallback: allowDescendantTextFallback
        )
    }

    func focusedTextContext(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool = false
    ) -> FocusedTextContext? {
        let recorder = AXAttributeReadRecorder()
        guard let focusedElement = focusedElement(for: app.processIdentifier) else {
            return nil
        }

        configureMessagingTimeout(for: focusedElement)

        let role = copyAttribute(
            focusedElement,
            attribute: kAXRoleAttribute,
            recorder: recorder
        ) as? String
        let subrole = copyAttribute(
            focusedElement,
            attribute: kAXSubroleAttribute,
            recorder: recorder
        ) as? String
        let fingerprint = focusedElementFingerprint(
            for: focusedElement,
            processIdentifier: app.processIdentifier,
            recorder: recorder
        )
        let isSecure = isSensitiveTextElement(
            focusedElement,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            recorder: recorder
        )

        guard !isSecure else {
            return secureTextContext(
                element: focusedElement,
                role: role,
                subrole: subrole,
                fingerprint: fingerprint,
                processIdentifier: app.processIdentifier,
                recorder: recorder
            )
        }

        guard let text = editableText(
            in: focusedElement,
            role: role,
            processIdentifier: app.processIdentifier,
            allowDescendantTextFallback: allowDescendantTextFallback,
            recorder: recorder
        ) else {
            return nil
        }

        let selectedRange = selectedTextRange(in: focusedElement, recorder: recorder)
        let selectedTextRange = selectedRange.map(accessibilityTextRange)
        let visibleCharacterRange = visibleCharacterRange(in: focusedElement, recorder: recorder)
        let insertionPointLineNumber = insertionPointLineNumber(in: focusedElement, recorder: recorder)
        let selectedTextLength = max(0, selectedRange?.length ?? 0)
        let textSlice = CursorTextSplitter.split(
            text,
            utf16Offset: selectedRange?.location ?? text.utf16.count
        )
        let selectedText = selectedText(in: focusedElement, fullText: text, selectedRange: selectedRange)
        let caretRect = selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(caretBounds(for: focusedElement, range: $0))
        }
        let elementIdentifier = Int(CFHash(focusedElement))
        let elementRect = elementBounds(for: focusedElement, recorder: recorder)
        let windowRect = containingWindowBounds(
            for: focusedElement,
            processIdentifier: app.processIdentifier,
            recorder: recorder
        )
        let rawTextLineRect = selectedRange.flatMap {
            textLineBounds(
                for: focusedElement,
                textLength: text.utf16.count,
                textBeforeCursor: textSlice.textBeforeCursor,
                range: $0,
                recorder: recorder
            )
        }
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            elementIdentifier: elementIdentifier
        )
        let geometryValidation = validateGeometrySample(AccessibilityGeometrySample(
            fieldIdentity: fieldIdentity,
            textState: AccessibilityGeometryTextState(
                textBeforeCursorUTF16Length: textSlice.textBeforeCursor.utf16.count,
                textAfterCursorUTF16Length: textSlice.textAfterCursor.utf16.count,
                selectedRange: selectedTextRange,
                visibleCharacterRange: visibleCharacterRange
            ),
            caretRect: rawCaretRect,
            textLineRect: rawTextLineRect,
            elementRect: elementRect,
            windowRect: windowRect,
            insertionPointLineNumber: insertionPointLineNumber
        ))
        let caretRect = geometryValidation.caretRect
        let textLineRect = geometryValidation.textLineRect
        let textStyle = selectedRange.flatMap {
            focusedTextStyle(
                in: focusedElement,
                textLength: text.utf16.count,
                range: $0,
                recorder: recorder
            )
        }
        let fieldClassification = fieldClassification(
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            isSecure: isSecure,
            textBeforeCursorLength: textSlice.textBeforeCursor.count,
            textAfterCursorLength: textSlice.textAfterCursor.count,
            selectedTextLength: selectedTextLength,
            lineCount: lineCount(in: text)
        )
        let capabilities = textCapabilities(
            for: focusedElement,
            selectedRange: selectedRange,
            boundsForRangeSucceeded: rawCaretRect != nil,
            textStyle: textStyle,
            visibleCharacterRange: visibleCharacterRange,
            insertionPointLineNumber: insertionPointLineNumber,
            recorder: recorder
        )

        return FocusedTextContext(
            elementIdentifier: elementIdentifier,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            textBeforeCursor: textSlice.textBeforeCursor,
            textAfterCursor: textSlice.textAfterCursor,
            selectedText: selectedText,
            selectedTextLength: selectedTextLength,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            textLineRect: textLineRect,
            visibleCharacterRange: visibleCharacterRange,
            insertionPointLineNumber: insertionPointLineNumber,
            textStyle: textStyle,
            isSecure: isSecure,
            fieldClassification: fieldClassification,
            caretIsSynthetic: false,
            capabilities: capabilities,
            axReadErrors: recorder.errors
        )
    }

    private func secureTextContext(
        element: AXUIElement,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        processIdentifier: pid_t,
        recorder: AXAttributeReadRecorder
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: Int(CFHash(element)),
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            textBeforeCursor: "",
            textAfterCursor: "",
            selectedText: "",
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: elementBounds(for: element, recorder: recorder),
            windowRect: containingWindowBounds(
                for: element,
                processIdentifier: processIdentifier,
                recorder: recorder
            ),
            textLineRect: nil,
            visibleCharacterRange: nil,
            insertionPointLineNumber: nil,
            textStyle: nil,
            isSecure: true,
            fieldClassification: fieldClassification(
                role: role,
                subrole: subrole,
                fingerprint: fingerprint,
                isSecure: true,
                textBeforeCursorLength: 0,
                textAfterCursorLength: 0,
                selectedTextLength: 0,
                lineCount: 0
            ),
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: false,
                canReadSelectedTextRange: false,
                canReadBoundsForRange: false,
                canReadAttributedText: false,
                canSetSelectedText: false
            ),
            axReadErrors: recorder.errors
        )
    }

    func insertText(_ text: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = focusedElement(for: app.processIdentifier) else {
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

    func replaceSelectedTextBySettingValue(_ text: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = focusedElement(for: app.processIdentifier),
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
        let recorder = AXAttributeReadRecorder()
        guard let focusedElement = focusedElement(for: app.processIdentifier) else {
            return nil
        }

        configureMessagingTimeout(for: focusedElement)

        let role = copyAttribute(
            focusedElement,
            attribute: kAXRoleAttribute,
            recorder: recorder
        ) as? String
        let subrole = copyAttribute(
            focusedElement,
            attribute: kAXSubroleAttribute,
            recorder: recorder
        ) as? String
        let fingerprint = focusedElementFingerprint(
            for: focusedElement,
            processIdentifier: app.processIdentifier,
            recorder: recorder
        )
        let text = editableText(
            in: focusedElement,
            role: role,
            processIdentifier: app.processIdentifier,
            allowDescendantTextFallback: allowDescendantTextFallback,
            recorder: recorder
        )
        let selectedRange = selectedTextRange(in: focusedElement, recorder: recorder)
        let selectedTextRange = selectedRange.map(accessibilityTextRange)
        let visibleCharacterRange = visibleCharacterRange(in: focusedElement, recorder: recorder)
        let insertionPointLineNumber = insertionPointLineNumber(in: focusedElement, recorder: recorder)
        let textSlice = text.map {
            CursorTextSplitter.split($0, utf16Offset: selectedRange?.location ?? $0.utf16.count)
        }
        let rawCaretRect = selectedRange.flatMap {
            caretBounds(for: focusedElement, range: $0, recorder: recorder)
        }
        let caretRect = AccessibilityTextBoundsPolicy.usableTextBounds(
            rawCaretRect,
            selectedRange: selectedTextRange,
            visibleCharacterRange: visibleCharacterRange
        )
        let elementRect = elementBounds(for: focusedElement, recorder: recorder)
        let windowRect = containingWindowBounds(
            for: focusedElement,
            processIdentifier: app.processIdentifier,
            recorder: recorder
        )
        let textLineRect = selectedRange.flatMap {
            AccessibilityTextBoundsPolicy.usableTextBounds(
                textLineBounds(
                    for: focusedElement,
                    textLength: text?.utf16.count ?? 0,
                    textBeforeCursor: textSlice?.textBeforeCursor ?? "",
                    range: $0,
                    recorder: recorder
                ),
                selectedRange: selectedTextRange,
                visibleCharacterRange: visibleCharacterRange
            )
        }
        let textStyle = selectedRange.flatMap {
            focusedTextStyle(
                in: focusedElement,
                textLength: text?.utf16.count ?? 0,
                range: $0,
                recorder: recorder
            )
        }
        let capabilities = textCapabilities(
            for: focusedElement,
            selectedRange: selectedRange,
            boundsForRangeSucceeded: rawCaretRect != nil,
            textStyle: textStyle,
            visibleCharacterRange: visibleCharacterRange,
            insertionPointLineNumber: insertionPointLineNumber,
            recorder: recorder
        )
        let attributeDump = focusedElementAttributeDump(for: focusedElement, recorder: recorder)

        return FocusedTextDiagnostics(
            bundleIdentifier: app.bundleIdentifier,
            localizedAppName: app.localizedName,
            role: role,
            subrole: subrole,
            isSecure: isSensitiveTextElement(
                focusedElement,
                role: role,
                subrole: subrole,
                fingerprint: fingerprint,
                recorder: recorder
            ),
            textBeforeCursorLength: textSlice?.textBeforeCursor.count ?? 0,
            textAfterCursorLength: textSlice?.textAfterCursor.count ?? 0,
            selectedRangeDescription: selectedRange.map { "location=\($0.location), length=\($0.length)" } ?? "missing",
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            textLineRect: textLineRect,
            visibleCharacterRange: visibleCharacterRange,
            insertionPointLineNumber: insertionPointLineNumber,
            capabilities: capabilities,
            attributeDump: attributeDump,
            axReadErrors: recorder.errors
        )
    }

    func focusedElementForObserver(for processIdentifier: pid_t) -> AXUIElement? {
        focusedElement(for: processIdentifier)
    }

    func focusedWindowForObserver(for processIdentifier: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)
        guard let windowValue = copyAttribute(appElement, attribute: kAXFocusedWindowAttribute) else {
            return nil
        }

        return (windowValue as! AXUIElement)
    }

    private func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)
        guard let focusedElementValue = copyAttribute(appElement, attribute: kAXFocusedUIElementAttribute) else {
            return nil
        }

        return (focusedElementValue as! AXUIElement)
    }

    private func copyAttribute(
        _ element: AXUIElement,
        attribute: String,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        recorder?.record(attribute: attribute, result: result)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func focusedElementAttributeDump(
        for element: AXUIElement,
        recorder: AXAttributeReadRecorder? = nil
    ) -> FocusedElementAttributeDump {
        let attributes = attributeNames(for: element).map { attribute in
            FocusedElementAttributeSummary(
                name: attribute,
                valueSummary: diagnosticValueSummary(copyAttribute(
                    element,
                    attribute: attribute,
                    recorder: recorder
                )),
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

    private func editableText(
        in element: AXUIElement,
        role: String?,
        processIdentifier: pid_t,
        allowDescendantTextFallback: Bool,
        recorder: AXAttributeReadRecorder? = nil
    ) -> String? {
        let directText = copyAttribute(
            element,
            attribute: kAXValueAttribute,
            recorder: recorder
        ) as? String
        guard allowDescendantTextFallback,
              role == "AXWebArea",
              directText?.isEmpty != false,
              containingWindowTitle(
                for: element,
                processIdentifier: processIdentifier,
                recorder: recorder
              ) == "New Message" else {
            return directText
        }

        let descendantText = descendantText(in: element, recorder: recorder)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !descendantText.isEmpty else {
            return directText
        }

        return descendantText
    }

    private func containingWindowTitle(
        for element: AXUIElement,
        processIdentifier: pid_t,
        recorder: AXAttributeReadRecorder? = nil
    ) -> String? {
        if let windowValue = copyAttribute(element, attribute: kAXWindowAttribute, recorder: recorder),
           let title = copyAttribute(
            (windowValue as! AXUIElement),
            attribute: kAXTitleAttribute,
            recorder: recorder
           ) as? String {
            return title
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        guard let windowValue = copyAttribute(
            appElement,
            attribute: kAXFocusedWindowAttribute,
            recorder: recorder
        ) else {
            return nil
        }

        return copyAttribute(
            (windowValue as! AXUIElement),
            attribute: kAXTitleAttribute,
            recorder: recorder
        ) as? String
    }

    private func focusedElementFingerprint(
        for element: AXUIElement,
        processIdentifier: pid_t,
        recorder: AXAttributeReadRecorder? = nil
    ) -> FocusedElementFingerprint {
        FocusedElementFingerprint(
            identifier: compactAttributeText(copyAttribute(
                element,
                attribute: "AXIdentifier",
                recorder: recorder
            ) as? String),
            title: compactAttributeText(copyAttribute(
                element,
                attribute: kAXTitleAttribute,
                recorder: recorder
            ) as? String),
            description: compactAttributeText(copyAttribute(
                element,
                attribute: kAXDescriptionAttribute,
                recorder: recorder
            ) as? String),
            help: compactAttributeText(copyAttribute(
                element,
                attribute: kAXHelpAttribute,
                recorder: recorder
            ) as? String),
            placeholder: compactAttributeText(copyAttribute(
                element,
                attribute: "AXPlaceholderValue",
                recorder: recorder
            ) as? String),
            windowTitle: compactAttributeText(containingWindowTitle(
                for: element,
                processIdentifier: processIdentifier,
                recorder: recorder
            ))
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

    private func descendantText(
        in element: AXUIElement,
        depth: Int = 0,
        recorder: AXAttributeReadRecorder? = nil
    ) -> String {
        guard depth < 6 else {
            return ""
        }

        let children = copyAttribute(
            element,
            attribute: kAXChildrenAttribute,
            recorder: recorder
        ) as? [AXUIElement] ?? []
        var parts: [String] = []

        for child in children {
            configureMessagingTimeout(for: child)

            if let value = copyAttribute(child, attribute: kAXValueAttribute, recorder: recorder) as? String,
               !value.isEmpty {
                parts.append(value)
            }

            let nestedText = descendantText(in: child, depth: depth + 1, recorder: recorder)
            if !nestedText.isEmpty {
                parts.append(nestedText)
            }
        }

        return parts.joined(separator: "\n")
    }

    private func configureMessagingTimeout(for element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, 0.12)
    }

    private func selectedTextRange(
        in element: AXUIElement,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CFRange? {
        guard let rangeValue = copyAttribute(
            element,
            attribute: kAXSelectedTextRangeAttribute,
            recorder: recorder
        ) else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func selectedText(in element: AXUIElement, fullText: String, selectedRange: CFRange?) -> String {
        if let selectedText = copyAttribute(element, attribute: kAXSelectedTextAttribute) as? String,
           !selectedText.isEmpty {
            return selectedText
        }

        guard let selectedRange, selectedRange.length > 0 else {
            return ""
        }

        let startOffset = max(0, min(selectedRange.location, fullText.utf16.count))
        let endOffset = max(startOffset, min(startOffset + selectedRange.length, fullText.utf16.count))
        let startIndex = String.Index(utf16Offset: startOffset, in: fullText)
        let endIndex = String.Index(utf16Offset: endOffset, in: fullText)
        return String(fullText[startIndex..<endIndex])
    }

    private func caretBounds(for element: AXUIElement, range: CFRange) -> CGRect? {
        let caretRange = CFRange(location: range.location, length: 0)
        return bounds(for: element, range: caretRange, recorder: recorder)
    }

    private func textLineBounds(
        for element: AXUIElement,
        textLength: Int,
        textBeforeCursor: String,
        range: CFRange,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CGRect? {
        if let lastCharacter = textBeforeCursor.last, !lastCharacter.isNewline, range.location > 0 {
            let previousCharacterRange = CFRange(location: range.location - 1, length: 1)
            return bounds(for: element, range: previousCharacterRange, recorder: recorder)
        }

        if range.location < textLength {
            let nextCharacterRange = CFRange(location: range.location, length: 1)
            return bounds(for: element, range: nextCharacterRange, recorder: recorder)
        }

        let caretRange = CFRange(location: range.location, length: 0)
        return bounds(for: element, range: caretRange, recorder: recorder)
    }

    private func bounds(
        for element: AXUIElement,
        range: CFRange,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CGRect? {
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
        recorder?.record(attribute: kAXBoundsForRangeParameterizedAttribute, result: result)

        guard result == .success, let boundsValue else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else {
            return nil
        }

        return rect
    }

    private func elementBounds(
        for element: AXUIElement,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CGRect? {
        guard let positionValue = copyAttribute(
            element,
            attribute: kAXPositionAttribute,
            recorder: recorder
        ),
              let sizeValue = copyAttribute(
                element,
                attribute: kAXSizeAttribute,
                recorder: recorder
              ) else {
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

    private func containingWindowBounds(
        for element: AXUIElement,
        processIdentifier: pid_t,
        recorder: AXAttributeReadRecorder? = nil
    ) -> CGRect? {
        if let windowValue = copyAttribute(element, attribute: kAXWindowAttribute, recorder: recorder) {
            return elementBounds(for: (windowValue as! AXUIElement), recorder: recorder)
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        guard let windowValue = copyAttribute(
            appElement,
            attribute: kAXFocusedWindowAttribute,
            recorder: recorder
        ) else {
            return nil
        }

        return elementBounds(for: (windowValue as! AXUIElement), recorder: recorder)
    }

    private func focusedTextStyle(
        in element: AXUIElement,
        textLength: Int,
        range: CFRange,
        recorder: AXAttributeReadRecorder? = nil
    ) -> FocusedTextStyle? {
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
        recorder?.record(attribute: kAXAttributedStringForRangeParameterizedAttribute, result: result)

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
        boundsForRangeSucceeded: Bool,
        textStyle: FocusedTextStyle?,
        visibleCharacterRange: AccessibilityCharacterRange?,
        insertionPointLineNumber: Int?,
        recorder: AXAttributeReadRecorder? = nil
    ) -> FocusedTextCapabilities {
        FocusedTextCapabilities(
            canReadValue: copyAttribute(
                element,
                attribute: kAXValueAttribute,
                recorder: recorder
            ) is String,
            canReadSelectedTextRange: selectedRange != nil,
            canReadBoundsForRange: boundsForRangeSucceeded,
            canReadAttributedText: textStyle != nil,
            canSetSelectedText: canSetAttribute(element, attribute: kAXSelectedTextAttribute),
            canReadVisibleCharacterRange: visibleCharacterRange != nil,
            canReadInsertionPointLineNumber: insertionPointLineNumber != nil
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
        fingerprint: FocusedElementFingerprint,
        recorder: AXAttributeReadRecorder? = nil
    ) -> Bool {
        if subrole == "AXSecureTextField" {
            return true
        }

        if let protected = copyAttribute(
            element,
            attribute: "AXProtectedContent",
            recorder: recorder
        ) as? Bool {
            return protected
        }

        return sensitiveTextFieldPolicy.isSensitive(
            role: role,
            subrole: subrole,
            fingerprint: fingerprint
        )
    }

    private func fieldClassification(
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        isSecure: Bool,
        textBeforeCursorLength: Int,
        textAfterCursorLength: Int,
        selectedTextLength: Int,
        lineCount: Int
    ) -> AXFieldClassification {
        fieldClassifier.classification(
            for: AXFieldClassifierInput(
                role: role,
                subrole: subrole,
                title: fingerprint.title,
                placeholder: fingerprint.placeholder,
                windowTitle: fingerprint.windowTitle,
                isSecure: isSecure,
                textBeforeCursorLength: textBeforeCursorLength,
                textAfterCursorLength: textAfterCursorLength,
                selectedTextLength: selectedTextLength,
                lineCount: lineCount
            )
        )
    }

    private func lineCount(in text: String) -> Int {
        guard !text.isEmpty else {
            return 0
        }

        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}
