import AppKit
import ApplicationServices
import Foundation

let action = CommandLine.arguments.dropFirst().first ?? "assert"
let environment = ProcessInfo.processInfo.environment
let marker = environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "SteadyType Obsidian proof"
let expectedSuffix = environment["AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX"] ?? ""
let resetText = environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT"] ?? marker
let insertionText = environment["AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT"] ?? ""
let requireExpectedSuffixInEditor = environment["AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX_REQUIRES_EDITOR"] == "1"
let focusCurrentValueEnd = environment["AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_CURRENT_VALUE_END"] == "1"
let defaultProofFile = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md")
let proofFile = environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_FILE"].map(URL.init(fileURLWithPath:)) ?? defaultProofFile
let normalizedMarker = normalizedWhitespace(marker)
let compactMarker = compactWhitespace(marker)

func normalizedWhitespace(_ value: String) -> String {
    value
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

func compactWhitespace(_ value: String) -> String {
    String(value.filter { !$0.isWhitespace })
}

func containsNormalized(_ haystack: String, _ needle: String) -> Bool {
    normalizedWhitespace(haystack).range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        || compactWhitespace(haystack).range(of: compactMarker, options: [.caseInsensitive, .diacriticInsensitive]) != nil
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

func role(of element: AXUIElement) -> String? {
    copyAttribute(element, kAXRoleAttribute) as? String
}

func textValue(of element: AXUIElement) -> String {
    copyAttribute(element, kAXValueAttribute) as? String ?? ""
}

func titleValue(of element: AXUIElement) -> String {
    copyAttribute(element, kAXTitleAttribute) as? String ?? ""
}

func proofFileText() -> String {
    (try? String(contentsOf: proofFile, encoding: .utf8)) ?? ""
}

func isDisposableProofWindow(_ element: AXUIElement) -> Bool {
    let title = titleValue(of: element)
    return title.contains("ObsidianProofVault") && title.contains("placement-proof")
}

func hasDisposableProofFile() -> Bool {
    proofFile.path.contains("AutocompleteLab/ObsidianProofVault/")
        && containsNormalized(proofFileText(), normalizedMarker)
}

func isTextEntry(_ element: AXUIElement) -> Bool {
    let role = role(of: element)
    return role == kAXTextAreaRole as String
        || role == kAXTextFieldRole as String
        || role == "AXWebArea"
}

struct AXTreeSummary {
    var visitedCount = 0
    var windowCount = 0
    var textEntryCount = 0
    var roleCounts: [String: Int] = [:]
}

func collectAXTreeSummary(
    from element: AXUIElement,
    depth: Int = 0,
    maxDepth: Int = 7,
    maxNodes: Int = 400,
    summary: inout AXTreeSummary
) {
    guard depth <= maxDepth,
          summary.visitedCount < maxNodes else {
        return
    }

    AXUIElementSetMessagingTimeout(element, 0.15)
    summary.visitedCount += 1
    let elementRole = role(of: element) ?? "unknown"
    summary.roleCounts[elementRole, default: 0] += 1
    if isTextEntry(element) {
        summary.textEntryCount += 1
    }

    for child in children(of: element) {
        collectAXTreeSummary(
            from: child,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxNodes: maxNodes,
            summary: &summary
        )
    }
}

func summarizedRoles(_ counts: [String: Int]) -> String {
    counts
        .sorted {
            if $0.value == $1.value {
                return $0.key < $1.key
            }
            return $0.value > $1.value
        }
        .prefix(8)
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: ",")
}

func obsidianEditorAXSnapshot(appElement: AXUIElement) -> String {
    var summary = AXTreeSummary()
    let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
    summary.windowCount = windows.count

    if windows.isEmpty {
        collectAXTreeSummary(from: appElement, maxDepth: 4, summary: &summary)
    } else {
        for window in windows.prefix(5) {
            collectAXTreeSummary(from: window, summary: &summary)
        }
    }

    let roles = summarizedRoles(summary.roleCounts)
    return """
    Obsidian editor AX snapshot: windows=\(summary.windowCount) textEntries=\(summary.textEntryCount) visited=\(summary.visitedCount) roles=\(roles.isEmpty ? "none" : roles).
    If windows are present but textEntries=0, Obsidian may be exposing only window chrome; relaunch the proof lane with --force-renderer-accessibility or enable Electron renderer accessibility before counting support.
    """
}

func containsMarker(_ element: AXUIElement) -> Bool {
    containsNormalized(textValue(of: element), normalizedMarker)
}

func findTextEntry(
    in element: AXUIElement,
    requiringMarker: Bool,
    depth: Int = 0
) -> AXUIElement? {
    guard depth < 28 else {
        return nil
    }

    AXUIElementSetMessagingTimeout(element, 0.25)
    if isTextEntry(element),
       !requiringMarker || containsMarker(element) {
        return element
    }

    for child in children(of: element) {
        if let match = findTextEntry(in: child, requiringMarker: requiringMarker, depth: depth + 1) {
            return match
        }
    }

    return nil
}

func focusedWindow(from appElement: AXUIElement) -> AXUIElement? {
    if let focusedWindow = copyAttribute(appElement, kAXFocusedWindowAttribute) {
        return (focusedWindow as! AXUIElement)
    }

    let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
    return windows.first
}

func resolveEditor(appElement: AXUIElement, systemWide: AXUIElement) -> AXUIElement? {
    for candidate in [
        focusedElement(from: appElement),
        focusedElement(from: systemWide)
    ].compactMap({ $0 }) {
        AXUIElementSetMessagingTimeout(candidate, 0.5)
        if isTextEntry(candidate),
           marker.isEmpty || containsMarker(candidate) {
            return candidate
        }
    }

    guard let window = focusedWindow(from: appElement) else {
        return nil
    }

    if marker.isEmpty {
        return findTextEntry(in: window, requiringMarker: false)
    }

    return findTextEntry(in: window, requiringMarker: true)
        ?? (isDisposableProofWindow(window) && hasDisposableProofFile()
            ? findTextEntry(in: window, requiringMarker: false)
            : nil)
}

func focusAtEnd(_ editor: AXUIElement, text: String) -> Bool {
    AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    var endRange = CFRange(location: text.utf16.count, length: 0)
    guard let rangeValue = AXValueCreate(.cfRange, &endRange) else {
        return false
    }

    return AXUIElementSetAttributeValue(
        editor,
        kAXSelectedTextRangeAttribute as CFString,
        rangeValue
    ) == .success
}

func focusTextForDocumentEnd(currentText: String, fileText: String = proofFileText()) -> String {
    guard fileText.localizedCaseInsensitiveContains(marker) else {
        return currentText
    }

    if !expectedSuffix.isEmpty {
        let trimmedFileText = fileText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedFileText.hasSuffix(expectedSuffix) else {
            return currentText
        }
    }

    if proofFile.path.contains("AutocompleteLab/ObsidianProofVault/") {
        return fileText
    }

    guard fileText.utf16.count > currentText.utf16.count else {
        return currentText
    }

    return fileText
}

func focusSelectionTextForDocumentEnd(currentText: String, fileText: String = proofFileText()) -> String {
    guard fileText.localizedCaseInsensitiveContains(marker) else {
        return currentText
    }

    if !expectedSuffix.isEmpty {
        let trimmedFileText = fileText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedFileText.hasSuffix(expectedSuffix) else {
            return currentText
        }
    }

    if let range = currentText.range(of: fileText) {
        return String(currentText[..<range.upperBound])
    }

    let trimmedFileText = fileText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedFileText.isEmpty,
       let range = currentText.range(of: trimmedFileText) {
        return String(currentText[..<range.upperBound])
    }

    if normalizedWhitespace(currentText).hasSuffix(normalizedWhitespace(fileText)) {
        return currentText
    }

    return focusTextForDocumentEnd(currentText: currentText, fileText: fileText)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    fputs("Obsidian is not running. Open a disposable smoke note first.\n", stderr)
    exit(3)
}

app.activate(options: [.activateAllWindows])
let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

guard let editor = resolveEditor(appElement: appElement, systemWide: systemWide) else {
    fputs("Could not read the focused Obsidian editor.\n\(obsidianEditorAXSnapshot(appElement: appElement))\n", stderr)
    exit(3)
}

AXUIElementSetMessagingTimeout(editor, 1.0)
let currentText = textValue(of: editor)

switch action {
case "assert":
    let fileText = proofFileText()
    guard containsNormalized(currentText, normalizedMarker)
        || containsNormalized(fileText, normalizedMarker) else {
        fputs("Refusing to type in Obsidian because the focused note does not contain the disposable smoke marker.\n", stderr)
        exit(3)
    }

    if !expectedSuffix.isEmpty {
        let trimmedCurrentText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFileText = fileText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTextHasSuffix = trimmedCurrentText.hasSuffix(expectedSuffix)
        let fileTextHasSuffix = trimmedFileText.hasSuffix(expectedSuffix)
        guard currentTextHasSuffix
            || (!requireExpectedSuffixInEditor && fileTextHasSuffix) else {
            fputs("Refusing Obsidian proof because the focused smoke note does not end with the expected disposable text.\n", stderr)
            exit(3)
        }
    }

    let focusText = focusCurrentValueEnd
        ? currentText
        : focusSelectionTextForDocumentEnd(currentText: currentText, fileText: fileText)
    guard focusAtEnd(editor, text: focusText) else {
        fputs("Could not place the Obsidian caret at the disposable editor end.\n", stderr)
        exit(3)
    }
    print("Obsidian smoke target confirmed")

case "focus":
    guard focusAtEnd(editor, text: focusSelectionTextForDocumentEnd(currentText: currentText)) else {
        exit(3)
    }

case "reset":
    guard AXUIElementSetAttributeValue(
        editor,
        kAXValueAttribute as CFString,
        resetText as CFTypeRef
    ) == .success else {
        fputs("Could not reset the disposable Obsidian smoke note text.\n", stderr)
        exit(3)
    }

    guard focusAtEnd(editor, text: resetText) else {
        fputs("Could not place the Obsidian caret after resetting the disposable editor.\n", stderr)
        exit(3)
    }

case "insert":
    let baseText = focusTextForDocumentEnd(currentText: currentText)
    let replacementText = baseText + insertionText
    guard focusAtEnd(editor, text: baseText),
          AXUIElementSetAttributeValue(
              editor,
              kAXValueAttribute as CFString,
              replacementText as CFTypeRef
          ) == .success else {
        exit(3)
    }

    _ = focusAtEnd(
        editor,
        text: focusSelectionTextForDocumentEnd(
            currentText: textValue(of: editor),
            fileText: replacementText
        )
    )

default:
    fputs("Unknown Obsidian AX editor action: \(action)\n", stderr)
    exit(2)
}
