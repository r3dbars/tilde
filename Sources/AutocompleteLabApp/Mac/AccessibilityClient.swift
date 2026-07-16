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

private extension AXError {
    var diagnosticName: String {
        switch self {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .illegalArgument:
            return "illegal-argument"
        case .invalidUIElement:
            return "invalid-ui-element"
        case .invalidUIElementObserver:
            return "invalid-ui-element-observer"
        case .cannotComplete:
            return "cannot-complete"
        case .attributeUnsupported:
            return "attribute-unsupported"
        case .actionUnsupported:
            return "action-unsupported"
        case .notificationUnsupported:
            return "notification-unsupported"
        case .notImplemented:
            return "not-implemented"
        case .notificationAlreadyRegistered:
            return "notification-already-registered"
        case .notificationNotRegistered:
            return "notification-not-registered"
        case .apiDisabled:
            return "api-disabled"
        case .noValue:
            return "no-value"
        case .parameterizedAttributeUnsupported:
            return "parameterized-attribute-unsupported"
        case .notEnoughPrecision:
            return "not-enough-precision"
        @unknown default:
            return "unknown-\(rawValue)"
        }
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

struct FocusedTextWindowReadPlan: Equatable, Sendable {
    let readsIdentifier: Bool
    let allowsFocusedWindowFallback: Bool
    let readsBounds: Bool
}

enum FocusedTextWindowReadMode: Equatable, Sendable {
    case none
    case identifierOnly
    case full

    var plan: FocusedTextWindowReadPlan {
        switch self {
        case .none:
            FocusedTextWindowReadPlan(
                readsIdentifier: false,
                allowsFocusedWindowFallback: false,
                readsBounds: false
            )
        case .identifierOnly:
            FocusedTextWindowReadPlan(
                readsIdentifier: true,
                allowsFocusedWindowFallback: false,
                readsBounds: false
            )
        case .full:
            FocusedTextWindowReadPlan(
                readsIdentifier: true,
                allowsFocusedWindowFallback: true,
                readsBounds: true
            )
        }
    }
}

struct FocusedTextReadOptions: Equatable, Sendable {
    static let standard = FocusedTextReadOptions()
    static let syntheticTextAreaFastPath = FocusedTextReadOptions(
        preferDirectTextSnapshot: true,
        skipParameterizedTextGeometry: true,
        skipAttributedText: true,
        useMinimalFingerprint: true,
        // One direct AXWindow token keeps prompt identity without restoring the
        // expensive window-title/bounds path on every Codex poll.
        windowReadMode: .identifierOnly,
        assumedCanSetSelectedText: true,
        manualAccessibilityWakeAppFamily: nil
    )

    let preferDirectTextSnapshot: Bool
    let skipParameterizedTextGeometry: Bool
    let skipAttributedText: Bool
    let useMinimalFingerprint: Bool
    let windowReadMode: FocusedTextWindowReadMode
    let assumedCanSetSelectedText: Bool?
    let manualAccessibilityWakeAppFamily: CompatibilityAppFamily?

    init(
        preferDirectTextSnapshot: Bool = false,
        skipParameterizedTextGeometry: Bool = false,
        skipAttributedText: Bool = false,
        useMinimalFingerprint: Bool = false,
        windowReadMode: FocusedTextWindowReadMode = .full,
        assumedCanSetSelectedText: Bool? = nil,
        manualAccessibilityWakeAppFamily: CompatibilityAppFamily? = nil
    ) {
        self.preferDirectTextSnapshot = preferDirectTextSnapshot
        self.skipParameterizedTextGeometry = skipParameterizedTextGeometry
        self.skipAttributedText = skipAttributedText
        self.useMinimalFingerprint = useMinimalFingerprint
        self.windowReadMode = windowReadMode
        self.assumedCanSetSelectedText = assumedCanSetSelectedText
        self.manualAccessibilityWakeAppFamily = manualAccessibilityWakeAppFamily
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
    private static let accessibilityTextNodeRoles: Set<String> = [
        "AXStaticText",
        "AXText",
        "AXTextArea",
        "AXTextField"
    ]

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
        if let context = focusedTextContextWithoutManualAccessibilityWake(
            for: app,
            allowDescendantTextFallback: allowDescendantTextFallback,
            options: options
        ) {
            return context
        }

        guard let appFamily = options.manualAccessibilityWakeAppFamily else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        configureMessagingTimeout(for: appElement)
        let treeHasTextNodes = accessibilityTreeHasTextNodes(in: appElement)
        let decision = AXManualAccessibilityWakePolicy.decision(
            appFamily: appFamily,
            focusedReadReturnedContext: false,
            treeHasTextNodes: treeHasTextNodes
        )

        guard decision.shouldWake else {
            return nil
        }

        let result = AXUIElementSetAttributeValue(
            appElement,
            AXManualAccessibilityWakePolicy.attributeName as CFString,
            kCFBooleanTrue
        )
        DiagnosticsLog.shared.record(
            "ax-manual-accessibility-wake",
            metadata: [
                "app": app.bundleIdentifier,
                "result": result.diagnosticName,
                "reason": decision.reason?.rawValue ?? "none"
            ]
        )

        guard result == .success else {
            return nil
        }

        return focusedTextContextWithoutManualAccessibilityWake(
            for: app,
            allowDescendantTextFallback: allowDescendantTextFallback,
            options: options
        )
    }

    private func focusedTextContextWithoutManualAccessibilityWake(
        for app: RunningApplicationInfo,
        allowDescendantTextFallback: Bool,
        options: FocusedTextReadOptions
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
        let windowReadPlan = options.windowReadMode.plan
        let windowElement: AXUIElement?
        if windowReadPlan.readsIdentifier {
            windowElement = windowReadPlan.allowsFocusedWindowFallback
                ? containingWindowElement(for: focusedElement, processIdentifier: app.processIdentifier)
                : copyElementAttribute(focusedElement, attribute: kAXWindowAttribute)
        } else {
            windowElement = nil
        }
        let windowIdentifier = windowElement.map { Int(CFHash($0)) }
        let windowRect = windowReadPlan.readsBounds
            ? windowElement.flatMap { elementBounds(for: $0) }
            : nil
        let selectedTextLength = max(0, selectedRange?.length ?? 0)
        let selectedTextValue = selectedRange.flatMap {
            selectedText(in: focusedElement, selectedRange: $0)
        } ?? ""
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
            selectedText: selectedTextValue,
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

    private func accessibilityTreeHasTextNodes(
        in element: AXUIElement,
        depth: Int = 0
    ) -> Bool {
        guard depth <= 12 else {
            return false
        }

        configureMessagingTimeout(for: element)
        let role = copyAttribute(element, attribute: kAXRoleAttribute) as? String
        if Self.accessibilityTextNodeRoles.contains(role ?? "") {
            return true
        }

        let children = copyAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] ?? []
        for child in children where accessibilityTreeHasTextNodes(in: child, depth: depth + 1) {
            return true
        }

        return false
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

    func insertText(
        _ text: String,
        expectedFieldIdentity: FocusedFieldIdentity? = nil,
        allowDescendantTextFallback: Bool = false
    ) -> Bool {
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

        guard insertionTargetIsBound(
            expectedFieldIdentity: expectedFieldIdentity,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: app.processIdentifier,
            focusedElement: focusedElement,
            allowDescendantTextFallback: allowDescendantTextFallback
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

    func replaceSelectedTextBySettingValue(
        _ text: String,
        expectedFieldIdentity: FocusedFieldIdentity? = nil,
        allowDescendantTextFallback: Bool = false
    ) -> Bool {
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

        guard insertionTargetIsBound(
            expectedFieldIdentity: expectedFieldIdentity,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: app.processIdentifier,
            focusedElement: focusedElement,
            allowDescendantTextFallback: allowDescendantTextFallback
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

    /// Bind an Accessibility write to the field identity the acceptance pipeline validated.
    ///
    /// `insertText` / `replaceSelectedTextBySettingValue` re-resolve the frontmost app and the
    /// focused element fresh at write time, so focus stolen since acceptance was validated would
    /// otherwise let the user's accepted text land in a different app/field (a TOCTOU race —
    /// docs/security/threat-model.md F1). When an `expectedFieldIdentity` is supplied we refuse
    /// the write on drift. Element identity is the same `CFHash`-based value the focused-text
    /// reader records, so it matches what the acceptance guard compared. With descendant-text
    /// fallback the written element legitimately differs from the read element, so only the
    /// application identity (bundle id + pid) is enforced there; cross-app drift is always refused.
    private func insertionTargetIsBound(
        expectedFieldIdentity: FocusedFieldIdentity?,
        bundleIdentifier: String,
        processIdentifier: pid_t,
        focusedElement: AXUIElement,
        allowDescendantTextFallback: Bool
    ) -> Bool {
        guard let expectedFieldIdentity else {
            return true
        }

        let current = FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            elementIdentifier: Int(CFHash(focusedElement))
        )
        let decision = InsertionTargetIdentityGuard().decision(
            expected: expectedFieldIdentity,
            current: current,
            requireElementMatch: !allowDescendantTextFallback
        )
        guard let reason = decision.blockReason else {
            return true
        }

        DiagnosticsLog.shared.record(
            "insert-target-identity-mismatch",
            metadata: [
                "reason": reason.rawValue,
                "allowDescendantTextFallback": String(allowDescendantTextFallback)
            ]
        )
        return false
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
        let isSecure = isSensitiveTextElement(
            focusedElement,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint
        )
        let text = isSecure ? nil : editableText(
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
            isSecure: isSecure,
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
        return copyElementAttribute(appElement, attribute: kAXFocusedUIElementAttribute)
    }

    private func focusedElement(
        for app: RunningApplicationInfo,
        allowWindowDescendantFallback: Bool
    ) -> AXUIElement? {
        if let focusedElement = focusedElement(for: app.processIdentifier) {
            return focusedElement
        }

        guard allowWindowDescendantFallback,
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
        return copyElementAttribute(appElement, attribute: kAXFocusedWindowAttribute)
    }

    func focusedWindowText(
        for app: RunningApplicationInfo,
        maximumCharacters: Int = 4_000
    ) -> String? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        configureMessagingTimeout(for: appElement)
        var values: [String] = []
        if let focusedElement = copyElementAttribute(appElement, attribute: kAXFocusedUIElementAttribute) {
            collectAccessibleText(
                from: focusedElement,
                depth: 0,
                maximumCharacters: maximumCharacters,
                into: &values
            )
        }
        if let focusedWindow = focusedWindow(for: app.processIdentifier) {
            collectAccessibleText(
                from: focusedWindow,
                depth: 0,
                maximumCharacters: maximumCharacters,
                into: &values
            )
        }
        let windows = copyAttribute(appElement, attribute: kAXWindowsAttribute) as? [AXUIElement] ?? []
        for window in windows {
            collectAccessibleText(
                from: window,
                depth: 0,
                maximumCharacters: maximumCharacters,
                into: &values
            )
        }
        let text = values
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func collectAccessibleText(
        from element: AXUIElement,
        depth: Int,
        maximumCharacters: Int,
        into values: inout [String]
    ) {
        guard depth <= 12,
              values.joined(separator: "\n").count < maximumCharacters else {
            return
        }

        configureMessagingTimeout(for: element)
        for attribute in [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXHelpAttribute as String
        ] {
            guard let value = copyAttribute(element, attribute: attribute) as? String,
                  !value.isEmpty else {
                continue
            }
            values.append(value)
        }

        let children = copyAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] ?? []
        for child in children {
            collectAccessibleText(
                from: child,
                depth: depth + 1,
                maximumCharacters: maximumCharacters,
                into: &values
            )
        }
    }

    private func bestEditableDescendant(in element: AXUIElement) -> AXUIElement? {
        let result = editableDescendantSearchResult(in: element)
        return result.focusedTextEntry ?? result.firstTextEntry ?? result.focusedWebArea ?? result.firstWebArea
    }

    private func editableDescendantSearchResult(
        in element: AXUIElement,
        depth: Int = 0
    ) -> (
        focusedTextEntry: AXUIElement?,
        firstTextEntry: AXUIElement?,
        focusedWebArea: AXUIElement?,
        firstWebArea: AXUIElement?
    ) {
        guard depth < 24 else {
            return (
                focusedTextEntry: nil,
                firstTextEntry: nil,
                focusedWebArea: nil,
                firstWebArea: nil
            )
        }

        configureMessagingTimeout(for: element)
        let role = copyAttribute(element, attribute: kAXRoleAttribute) as? String
        let isFocused = (copyAttribute(element, attribute: kAXFocusedAttribute) as? Bool) == true
        if ["AXTextArea", "AXTextField"].contains(role ?? "") {
            return (
                focusedTextEntry: isFocused ? element : nil,
                firstTextEntry: element,
                focusedWebArea: nil,
                firstWebArea: nil
            )
        }

        if role == "AXWebArea" {
            var result = editableDescendantChildrenSearchResult(in: element, depth: depth)
            if result.focusedWebArea == nil, isFocused {
                result.focusedWebArea = element
            }
            if result.firstWebArea == nil {
                result.firstWebArea = element
            }
            return result
        }

        return editableDescendantChildrenSearchResult(in: element, depth: depth)
    }

    private func editableDescendantChildrenSearchResult(
        in element: AXUIElement,
        depth: Int
    ) -> (
        focusedTextEntry: AXUIElement?,
        firstTextEntry: AXUIElement?,
        focusedWebArea: AXUIElement?,
        firstWebArea: AXUIElement?
    ) {
        let children = copyAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] ?? []
        var firstTextEntry: AXUIElement?
        var focusedWebArea: AXUIElement?
        var firstWebArea: AXUIElement?
        for child in children {
            let result = editableDescendantSearchResult(in: child, depth: depth + 1)
            if let focusedTextEntry = result.focusedTextEntry {
                return (
                    focusedTextEntry: focusedTextEntry,
                    firstTextEntry: firstTextEntry ?? result.firstTextEntry,
                    focusedWebArea: focusedWebArea ?? result.focusedWebArea,
                    firstWebArea: firstWebArea ?? result.firstWebArea
                )
            }
            firstTextEntry = firstTextEntry ?? result.firstTextEntry
            focusedWebArea = focusedWebArea ?? result.focusedWebArea
            firstWebArea = firstWebArea ?? result.firstWebArea
        }

        return (
            focusedTextEntry: nil,
            firstTextEntry: firstTextEntry,
            focusedWebArea: focusedWebArea,
            firstWebArea: firstWebArea
        )
    }

    private func copyAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    /// Reads an attribute expected to be an `AXUIElement`, returning nil when the target app
    /// hands back a different CF type. The call sites historically force-cast the raw
    /// `CFTypeRef`, which crashes the whole menu-bar process if an app violates the AX
    /// contract; degrading to nil instead just means "no suggestion" for that read.
    private func copyElementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute: attribute) else {
            return nil
        }

        return Self.axUIElement(from: value)
    }

    /// Bridges a raw attribute value to `AXValue` only when it really is one. Same crash-safety
    /// rationale as `copyElementAttribute`.
    private func axValue(_ value: CFTypeRef) -> AXValue? {
        Self.axValue(from: value)
    }

    /// Pure crash-safety guard: returns the value typed as `AXUIElement` only when its CF type
    /// id matches, otherwise nil. Exposed (internal) so the degradation contract is unit
    /// testable without a live accessibility tree. `AXUIElement` is a CoreFoundation type, so
    /// the checked force-cast is the canonical bridge — `as?` does not runtime-check CF types.
    static func axUIElement(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    /// Pure crash-safety guard for `AXValue`; see `axUIElement(from:)`.
    static func axValue(from value: CFTypeRef) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
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
           let directSnapshot = valueEditableTextSnapshot(
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

        return valueEditableTextSnapshot(
            in: element,
            role: role,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            windowTitle: windowTitle,
            allowDescendantTextFallback: allowDescendantTextFallback,
            selectedRange: selectedRange
        )
    }

    private func valueEditableTextSnapshot(
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
        if let windowValue = copyElementAttribute(element, attribute: kAXWindowAttribute),
           let title = copyAttribute(windowValue, attribute: kAXTitleAttribute) as? String {
            return title
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        guard let windowValue = copyElementAttribute(appElement, attribute: kAXFocusedWindowAttribute) else {
            return nil
        }

        return copyAttribute(windowValue, attribute: kAXTitleAttribute) as? String
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
        guard let rangeValue = copyAttribute(element, attribute: kAXSelectedTextRangeAttribute),
              let axRange = axValue(rangeValue) else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axRange, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func selectedText(in element: AXUIElement, selectedRange: CFRange) -> String {
        if let selectedText = copyAttribute(element, attribute: kAXSelectedTextAttribute) as? String {
            return selectedText
        }

        guard selectedRange.length > 0,
              let selectedText = stringForRange(in: element, range: selectedRange) else {
            return ""
        }

        return selectedText
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

        guard result == .success, let boundsValue, let axBounds = axValue(boundsValue) else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axBounds, .cgRect, &rect) else {
            return nil
        }

        return rect
    }

    private func elementBounds(for element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAttribute(element, attribute: kAXPositionAttribute),
              let sizeValue = copyAttribute(element, attribute: kAXSizeAttribute),
              let axPosition = axValue(positionValue),
              let axSize = axValue(sizeValue) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(axPosition, .cgPoint, &position),
              AXValueGetValue(axSize, .cgSize, &size) else {
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
        if let windowValue = copyElementAttribute(element, attribute: kAXWindowAttribute) {
            return windowValue
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        configureMessagingTimeout(for: appElement)

        return copyElementAttribute(appElement, attribute: kAXFocusedWindowAttribute)
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
