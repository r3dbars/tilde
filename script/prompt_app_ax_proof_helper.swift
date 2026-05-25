import AppKit
import ApplicationServices
import Foundation

struct Options {
    var action = ""
    var bundleIdentifier = ""
    var displayName = "Prompt app"
    var marker = ""
    var text = ""
    var backupPath = ""
    var clearIfNoBackup = false
    var discoveryTimeoutSeconds: TimeInterval = 0
    var promptHints: [String] = []
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else {
        fail("missing action", code: 2)
    }
    if args[0] == "-h" || args[0] == "--help" {
        print("Usage: swift script/prompt_app_ax_proof_helper.swift <seed|focus|assert|contains-marker|restore> --bundle BID --display NAME --marker MARKER [--text TEXT] [--backup PATH] [--hint TEXT] [--discovery-timeout SECONDS] [--clear-if-no-backup]")
        exit(0)
    }
    options.action = args.removeFirst()

    var index = 0
    while index < args.count {
        let arg = args[index]
        func value() -> String {
            guard index + 1 < args.count else {
                fail("\(arg) needs a value", code: 2)
            }
            index += 1
            return args[index]
        }

        switch arg {
        case "--bundle":
            options.bundleIdentifier = value()
        case "--display":
            options.displayName = value()
        case "--marker":
            options.marker = value()
        case "--text":
            options.text = value()
        case "--backup":
            options.backupPath = value()
        case "--hint":
            options.promptHints.append(value())
        case "--discovery-timeout":
            let rawValue = value()
            guard let timeout = TimeInterval(rawValue), timeout >= 0 else {
                fail("--discovery-timeout must be a non-negative number", code: 2)
            }
            options.discoveryTimeoutSeconds = timeout
        case "--clear-if-no-backup":
            options.clearIfNoBackup = true
        case "-h", "--help":
            print("Usage: swift script/prompt_app_ax_proof_helper.swift <seed|focus|assert|contains-marker|restore> --bundle BID --display NAME --marker MARKER [--text TEXT] [--backup PATH] [--hint TEXT] [--discovery-timeout SECONDS] [--clear-if-no-backup]")
            exit(0)
        default:
            fail("unknown argument: \(arg)", code: 2)
        }
        index += 1
    }

    guard !options.bundleIdentifier.isEmpty else {
        fail("--bundle is required", code: 2)
    }
    guard !options.marker.isEmpty else {
        fail("--marker is required", code: 2)
    }

    if options.promptHints.isEmpty {
        switch options.bundleIdentifier {
        case "com.anthropic.claudefordesktop":
            options.promptHints = [
                "Ask Claude",
                "Message Claude",
                "Reply to Claude",
                "How can I help"
            ]
        case "com.openai.codex":
            options.promptHints = [
                "Ask Codex anything",
                "Ask for follow-up changes",
                "Describe a task or ask a question"
            ]
        default:
            options.promptHints = []
        }
    }

    return options
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    copyAttribute(element, attribute) as? String ?? ""
}

func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
    copyAttribute(element, attribute) as? Bool ?? false
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func rect(for element: AXUIElement) -> CGRect? {
    guard let positionValue = copyAttribute(element, kAXPositionAttribute),
          let sizeValue = copyAttribute(element, kAXSizeAttribute),
          CFGetTypeID(positionValue) == AXValueGetTypeID(),
          CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
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

func setSelectedRange(_ element: AXUIElement, location: Int, length: Int) {
    var range = CFRange(location: location, length: length)
    guard let rangeValue = AXValueCreate(.cfRange, &range) else {
        return
    }
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}

enum KeyEventDestination {
    case pid
    case eventTap
}

func postCommandShortcut(
    virtualKey: CGKeyCode,
    to pid: pid_t,
    destination: KeyEventDestination
) -> Bool {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
        return false
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand

    switch destination {
    case .pid:
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    case .eventTap:
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    return true
}

func restorePasteboardItems(_ items: [NSPasteboardItem]) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if !items.isEmpty {
        pasteboard.writeObjects(items)
    }
}

func clonePasteboardItems(_ items: [NSPasteboardItem]) -> [NSPasteboardItem] {
    items.map { item in
        let clone = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                clone.setData(data, forType: type)
            } else if let string = item.string(forType: type) {
                clone.setString(string, forType: type)
            }
        }
        return clone
    }
}

func waitForExactValue(_ element: AXUIElement, text: String, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if stringAttribute(element, kAXValueAttribute) == text {
            return true
        }
        Thread.sleep(forTimeInterval: 0.05)
    } while Date() < deadline
    return stringAttribute(element, kAXValueAttribute) == text
}

func selectCurrentText(_ element: AXUIElement, pid: pid_t, destination: KeyEventDestination? = nil) {
    AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    setSelectedRange(element, location: 0, length: stringAttribute(element, kAXValueAttribute).utf16.count)
    if let destination {
        _ = postCommandShortcut(virtualKey: 0, to: pid, destination: destination)
        Thread.sleep(forTimeInterval: 0.08)
    }
}

func seedWithSelectedTextFallback(_ element: AXUIElement, text: String, pid: pid_t) -> Bool {
    selectCurrentText(element, pid: pid)
    let result = AXUIElementSetAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,
        text as CFTypeRef
    )
    return result == .success && waitForExactValue(element, text: text, timeout: 1.0)
}

func seedWithPasteFallback(_ element: AXUIElement, text: String, pid: pid_t) -> Bool {
    let pasteboard = NSPasteboard.general
    let originalItems = clonePasteboardItems(pasteboard.pasteboardItems ?? [])
    defer {
        restorePasteboardItems(originalItems)
    }

    pasteboard.clearContents()
    guard pasteboard.setString(text, forType: .string) else {
        return false
    }

    for destination in [KeyEventDestination.pid, .eventTap] {
        selectCurrentText(element, pid: pid, destination: destination)
        guard postCommandShortcut(virtualKey: 9, to: pid, destination: destination) else {
            continue
        }
        if waitForExactValue(element, text: text, timeout: 1.2) {
            return true
        }
    }

    return false
}

func selectedRangeMatches(_ element: AXUIElement, location: Int, length: Int) -> Bool {
    guard let rangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute),
          CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
        return false
    }

    var range = CFRange()
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return false
    }
    return range.location == location && range.length == length
}

func rangeDescription(_ element: AXUIElement) -> String {
    guard let rangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute),
          CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
        return "missing"
    }

    var range = CFRange()
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return "unreadable"
    }
    return "location=\(range.location),length=\(range.length)"
}

func postCommandRight(to pid: pid_t) {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
        return
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.postToPid(pid)
    keyUp.postToPid(pid)
}

func clickInside(_ frame: CGRect) {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        return
    }

    let x = min(frame.maxX - 16, max(frame.minX + 16, frame.midX))
    let point = CGPoint(x: x, y: frame.midY)
    guard let mouseDown = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    ),
    let mouseUp = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        return
    }

    mouseDown.post(tap: .cghidEventTap)
    mouseUp.post(tap: .cghidEventTap)
}

func focusedElement(in appElement: AXUIElement) -> AXUIElement? {
    guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute),
          CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
        return nil
    }
    return (focusedValue as! AXUIElement)
}

func axElementContains(_ element: AXUIElement, targetIdentifier: Int, depth: Int = 0) -> Bool {
    guard depth <= 12 else {
        return false
    }

    if Int(CFHash(element)) == targetIdentifier {
        return true
    }

    return children(of: element).contains { child in
        axElementContains(child, targetIdentifier: targetIdentifier, depth: depth + 1)
    }
}

func isTextInput(_ element: AXUIElement) -> Bool {
    let role = stringAttribute(element, kAXRoleAttribute)
    return role == kAXTextAreaRole as String || role == "AXTextField"
}

func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

func textLooksLikePromptChrome(_ element: AXUIElement, hints: [String]) -> Bool {
    let fields = [
        stringAttribute(element, "AXPlaceholderValue"),
        stringAttribute(element, kAXDescriptionAttribute),
        stringAttribute(element, kAXTitleAttribute),
        stringAttribute(element, kAXHelpAttribute)
    ].map(normalized)

    return hints.contains { hint in
        let lowerHint = normalized(hint)
        return fields.contains { field in field.contains(lowerHint) }
    }
}

struct Candidate {
    let element: AXUIElement
    let value: String
    let frame: CGRect
    let focused: Bool
    let hasMarker: Bool
    let looksDisposable: Bool
    let focusedDraftCanBeRestored: Bool
    let score: Double
}

func collectTextInputs(
    in element: AXUIElement,
    focusedRoot: AXUIElement?,
    options: Options,
    depth: Int = 0,
    candidates: inout [Candidate]
) {
    guard depth <= 32 else {
        return
    }

    if isTextInput(element),
       let frame = rect(for: element),
       frame.width >= 220,
       frame.height >= 18,
       frame.height <= 360 {
        let value = stringAttribute(element, kAXValueAttribute)
        let hasMarker = value.contains(options.marker)
        let valueLooksDisposable = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || hasMarker
            || options.promptHints.contains { normalized(value).contains(normalized($0)) }
            || textLooksLikePromptChrome(element, hints: options.promptHints)
        let focused = boolAttribute(element, kAXFocusedAttribute)
            || focusedRoot.map { root in
                axElementContains(root, targetIdentifier: Int(CFHash(element)))
            } ?? false
        let focusedDraftCanBeRestored = focused
            && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasMarker
            && value.utf16.count <= 4_000

        if valueLooksDisposable || focusedDraftCanBeRestored {
            var score = Double(frame.width)
            score += Double(frame.maxY) / 8.0
            if focused {
                score += 1_000
            }
            if focusedDraftCanBeRestored {
                score += 650
            }
            if hasMarker {
                score += 800
            }
            if valueLooksDisposable {
                score += 500
            }
            candidates.append(Candidate(
                element: element,
                value: value,
                frame: frame,
                focused: focused,
                hasMarker: hasMarker,
                looksDisposable: valueLooksDisposable,
                focusedDraftCanBeRestored: focusedDraftCanBeRestored,
                score: score
            ))
        }
    }

    for child in children(of: element) {
        collectTextInputs(
            in: child,
            focusedRoot: focusedRoot,
            options: options,
            depth: depth + 1,
            candidates: &candidates
        )
    }
}

func runningApp(for options: Options, activate: Bool) -> NSRunningApplication {
    guard let app = NSRunningApplication.runningApplications(
        withBundleIdentifier: options.bundleIdentifier
    ).first else {
        fail("\(options.displayName) is not running.")
    }

    if activate {
        app.activate(options: [.activateAllWindows])
        Thread.sleep(forTimeInterval: 0.25)
    }
    return app
}

func appElement(for app: NSRunningApplication) -> AXUIElement {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.75)
    return element
}

func bestCandidate(in appElement: AXUIElement, options: Options) -> Candidate? {
    var candidates: [Candidate] = []
    collectTextInputs(
        in: appElement,
        focusedRoot: focusedElement(in: appElement),
        options: options,
        candidates: &candidates
    )

    return candidates.sorted { lhs, rhs in
        if lhs.hasMarker != rhs.hasMarker {
            return lhs.hasMarker
        }
        if lhs.focusedDraftCanBeRestored != rhs.focusedDraftCanBeRestored {
            return lhs.focusedDraftCanBeRestored
        }
        if lhs.focused != rhs.focused {
            return lhs.focused
        }
        if lhs.looksDisposable != rhs.looksDisposable {
            return lhs.looksDisposable
        }
        if lhs.score == rhs.score {
            return lhs.frame.maxY > rhs.frame.maxY
        }
        return lhs.score > rhs.score
    }.first
}

func pressPromptCreationButton(in element: AXUIElement, options: Options, depth: Int = 0) -> Bool {
    guard depth <= 32 else {
        return false
    }

    if options.bundleIdentifier == "com.anthropic.claudefordesktop",
       stringAttribute(element, kAXRoleAttribute) == "AXButton" {
        let buttonFields = [
            stringAttribute(element, kAXTitleAttribute),
            stringAttribute(element, kAXDescriptionAttribute),
            stringAttribute(element, kAXHelpAttribute)
        ].map(normalized)
        let acceptedLabels = ["new chat"]
        if acceptedLabels.contains(where: { label in
            buttonFields.contains { field in field == label }
        }) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
            print("Pressed \(options.displayName) \(buttonFields.first { !$0.isEmpty } ?? "new prompt") button before composer discovery.")
            return true
        }
    }

    for child in children(of: element) {
        if pressPromptCreationButton(in: child, options: options, depth: depth + 1) {
            return true
        }
    }

    return false
}

func discoverBestCandidate(in element: AXUIElement, options: Options) -> Candidate? {
    let discoveryDeadline = Date().addingTimeInterval(options.discoveryTimeoutSeconds)
    var discoveredCandidate: Candidate?
    repeat {
        discoveredCandidate = bestCandidate(in: element, options: options)
        if discoveredCandidate != nil || Date() >= discoveryDeadline {
            break
        }
        Thread.sleep(forTimeInterval: 0.25)
    } while true

    return discoveredCandidate
}

func collectMarkedInputs(
    in element: AXUIElement,
    marker: String,
    depth: Int = 0,
    results: inout [AXUIElement]
) {
    guard depth <= 32 else {
        return
    }

    if isTextInput(element),
       stringAttribute(element, kAXValueAttribute).contains(marker) {
        results.append(element)
    }

    for child in children(of: element) {
        collectMarkedInputs(in: child, marker: marker, depth: depth + 1, results: &results)
    }
}

func focusedMarkedInput(in element: AXUIElement, marker: String, cursorOffset: Int, depth: Int = 0) -> Bool {
    guard depth <= 12 else {
        return false
    }

    if isTextInput(element),
       stringAttribute(element, kAXValueAttribute).contains(marker),
       selectedRangeMatches(element, location: cursorOffset, length: 0) {
        return true
    }

    return children(of: element).contains { child in
        focusedMarkedInput(in: child, marker: marker, cursorOffset: cursorOffset, depth: depth + 1)
    }
}

func exactFocusedInput(in element: AXUIElement, text: String, marker: String, cursorOffset: Int, depth: Int = 0) -> Bool {
    guard depth <= 12 else {
        return false
    }

    if isTextInput(element) {
        let value = stringAttribute(element, kAXValueAttribute)
        if value == text,
           value.contains(marker),
           selectedRangeMatches(element, location: cursorOffset, length: 0) {
            return true
        }
    }

    return children(of: element).contains { child in
        exactFocusedInput(in: child, text: text, marker: marker, cursorOffset: cursorOffset, depth: depth + 1)
    }
}

func seed(options: Options) {
    guard !options.text.isEmpty else {
        fail("--text is required for seed", code: 2)
    }
    guard options.text.contains(options.marker) else {
        fail("\(options.displayName) proof text must include \(options.marker).", code: 2)
    }
    guard !options.text.contains("\n") && !options.text.contains("\r") else {
        fail("\(options.displayName) proof text must be a single line.", code: 2)
    }

    let app = runningApp(for: options, activate: true)
    let element = appElement(for: app)
    var discoveredCandidate = discoverBestCandidate(in: element, options: options)
    if discoveredCandidate == nil,
       pressPromptCreationButton(in: element, options: options) {
        Thread.sleep(forTimeInterval: 0.8)
        discoveredCandidate = discoverBestCandidate(in: element, options: options)
    }

    guard let candidate = discoveredCandidate else {
        fail("Could not find a safe \(options.displayName) composer. Clear the prompt, open a new chat, or keep focus in the draft prompt so it can be backed up and restored.")
    }

    let shouldRestoreDraft = !candidate.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !candidate.value.contains(options.marker)
    if shouldRestoreDraft {
        guard !options.backupPath.isEmpty else {
            fail("\(options.displayName) proof refused to replace an existing focused draft without --backup.", code: 2)
        }
        do {
            try candidate.value.write(toFile: options.backupPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: options.backupPath
            )
        } catch {
            fail("Could not back up the existing \(options.displayName) draft before proof seeding: \(error.localizedDescription)")
        }
    }

    AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    let result = AXUIElementSetAttributeValue(
        candidate.element,
        kAXValueAttribute as CFString,
        options.text as CFTypeRef
    )
    var usedFallback = false
    if result != .success || stringAttribute(candidate.element, kAXValueAttribute) != options.text {
        usedFallback = true
        if !seedWithSelectedTextFallback(candidate.element, text: options.text, pid: app.processIdentifier),
           !seedWithPasteFallback(candidate.element, text: options.text, pid: app.processIdentifier) {
            fail("Could not seed the \(options.displayName) proof composer through Accessibility or guarded paste fallback (AX result \(result.rawValue)).")
        }
    }

    let cursorOffset = options.text.utf16.count
    for _ in 0..<4 {
        AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        setSelectedRange(candidate.element, location: cursorOffset, length: 0)
        postCommandRight(to: app.processIdentifier)
        Thread.sleep(forTimeInterval: 0.12)
        if selectedRangeMatches(candidate.element, location: cursorOffset, length: 0) {
            break
        }
    }

    guard stringAttribute(candidate.element, kAXValueAttribute) == options.text else {
        fail("\(options.displayName) proof composer did not retain the disposable marker text after seeding.")
    }
    guard selectedRangeMatches(candidate.element, location: cursorOffset, length: 0) else {
        fail("\(options.displayName) proof composer did not place the cursor at the end of the disposable marker text.")
    }

    if let focused = focusedElement(in: element) {
        let focusedText = stringAttribute(focused, kAXValueAttribute)
        let focusedCursorAtEnd = focusedText == options.text
            && selectedRangeMatches(focused, location: cursorOffset, length: 0)
        if !focusedCursorAtEnd {
            let focusedRole = stringAttribute(focused, kAXRoleAttribute)
            fputs("\(options.displayName) proof composer was seeded, but focused AX verification is deferred to the click/refocus step (focusedRole=\(focusedRole.isEmpty ? "unknown" : focusedRole), focusedChars=\(focusedText.count), focusedHasMarker=\(focusedText.contains(options.marker)), focusedRange=\(rangeDescription(focused))).\n", stderr)
        }
    } else {
        fputs("\(options.displayName) proof composer was seeded, but no focused AX element was exposed; deferring to the click/refocus step.\n", stderr)
    }

    print("Seeded \(options.displayName) proof composer: chars=\(options.text.count) rect=x=\(Int(candidate.frame.minX)),y=\(Int(candidate.frame.minY)),w=\(Int(candidate.frame.width)),h=\(Int(candidate.frame.height))")
    if usedFallback {
        print("Seeded \(options.displayName) proof composer with guarded selected-text/paste fallback.")
    }
    if shouldRestoreDraft {
        print("Backed up existing \(options.displayName) draft for restoration after proof.")
    }
}

func focus(options: Options) {
    let app = runningApp(for: options, activate: true)
    let element = appElement(for: app)
    var marked: [AXUIElement] = []
    collectMarkedInputs(in: element, marker: options.marker, results: &marked)
    guard let target = marked.first else {
        fail("Could not refocus \(options.displayName) proof prompt: marker text input not found.")
    }

    let text = stringAttribute(target, kAXValueAttribute)
    let cursorOffset = text.utf16.count
    if let frame = rect(for: target) {
        clickInside(frame)
        Thread.sleep(forTimeInterval: 0.12)
    }
    for _ in 0..<4 {
        AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        setSelectedRange(target, location: cursorOffset, length: 0)
        postCommandRight(to: app.processIdentifier)
        Thread.sleep(forTimeInterval: 0.08)
        if selectedRangeMatches(target, location: cursorOffset, length: 0) {
            break
        }
    }

    guard let focused = focusedElement(in: element),
          focusedMarkedInput(
              in: focused,
              marker: options.marker,
              cursorOffset: cursorOffset
          ) else {
        fail("Could not keep \(options.displayName) proof prompt focused at the end before proof typing.")
    }

    print("Focused \(options.displayName) proof composer: chars=\(text.count)")
}

func assertReady(options: Options) {
    guard !options.text.isEmpty else {
        fail("--text is required for assert", code: 2)
    }
    let app = runningApp(for: options, activate: false)
    let element = appElement(for: app)
    let cursorOffset = options.text.utf16.count
    guard let focused = focusedElement(in: element),
          exactFocusedInput(
              in: focused,
              text: options.text,
              marker: options.marker,
              cursorOffset: cursorOffset
          ) else {
        fail("\(options.displayName) proof prompt is not the focused exact marker text before proof typing.")
    }
    print("Verified \(options.displayName) proof composer: chars=\(options.text.count)")
}

func containsMarker(options: Options) {
    let app = runningApp(for: options, activate: false)
    let element = appElement(for: app)
    var marked: [AXUIElement] = []
    collectMarkedInputs(in: element, marker: options.marker, results: &marked)
    guard !marked.isEmpty else {
        fail("\(options.displayName) proof marker is no longer present in a composer; refusing to claim no-submit proof.")
    }
    print("\(options.displayName) proof marker still present.")
}

func restore(options: Options) {
    let restoreText: String
    if !options.backupPath.isEmpty,
       let backupText = try? String(contentsOfFile: options.backupPath, encoding: .utf8),
       !backupText.isEmpty {
        restoreText = backupText
    } else if options.clearIfNoBackup {
        restoreText = ""
    } else {
        return
    }

    guard let app = NSRunningApplication.runningApplications(
        withBundleIdentifier: options.bundleIdentifier
    ).first else {
        return
    }
    let element = appElement(for: app)
    var marked: [AXUIElement] = []
    collectMarkedInputs(in: element, marker: options.marker, results: &marked)
    guard let target = marked.first else {
        fputs("\(options.displayName) draft restore skipped: proof marker is no longer present.\n", stderr)
        return
    }

    AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    let result = AXUIElementSetAttributeValue(
        target,
        kAXValueAttribute as CFString,
        restoreText as CFTypeRef
    )
    if result == .success {
        setSelectedRange(target, location: restoreText.utf16.count, length: 0)
        print("Restored \(options.displayName) proof composer: chars=\(restoreText.count)")
    } else {
        fputs("\(options.displayName) draft restore failed (AX result \(result.rawValue)).\n", stderr)
    }
}

let options = parseOptions()
switch options.action {
case "seed":
    seed(options: options)
case "focus":
    focus(options: options)
case "assert":
    assertReady(options: options)
case "contains-marker":
    containsMarker(options: options)
case "restore":
    restore(options: options)
default:
    fail("unknown action: \(options.action)", code: 2)
}
