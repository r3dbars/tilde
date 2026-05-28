import AppKit
import ApplicationServices
import Foundation

struct Options {
    var action = ""
    var bundleIdentifier = ""
    var displayName = "Terminal"
    var marker = ""
    var text = ""
    var processIdentifier: pid_t?
    var discoveryTimeoutSeconds: TimeInterval = 0
    var hints: [String] = []
    var allowsMissingMarkerForEmptyText = false
}

struct Snapshot {
    let frontmostBundleIdentifier: String?
    let frontmostProcessIdentifier: pid_t?
    let targetProcessIdentifier: pid_t?
    let textCount: Int
    let titleCount: Int
    let markerWindowCount: Int
    let hasMarker: Bool
    let hasText: Bool
    let hasHint: Bool
    let expectedTokenCount: Int
    let expectedTokenMatches: Int
}

struct SearchState {
    let hasMarker: Bool
    let hasText: Bool
    let hasHint: Bool
    let expectedTokenCount: Int
    let expectedTokenMatches: Int

    var score: Int {
        (hasMarker ? 1_000 : 0)
            + (hasText ? 1_000 : 0)
            + (hasHint ? 1_000 : 0)
            + expectedTokenMatches
    }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

func usage() -> Never {
    print("Usage: swift script/terminal_prompt_ax_proof_helper.swift <wait|assert|contains-marker> --bundle BID --display NAME --marker MARKER [--pid PID] [--text TEXT] [--hint TEXT] [--discovery-timeout SECONDS] [--allow-missing-marker-for-empty-text]")
    exit(0)
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else {
        fail("missing action", code: 2)
    }
    if args[0] == "-h" || args[0] == "--help" {
        usage()
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
        case "--pid":
            let rawValue = value()
            guard let pid = Int32(rawValue), pid > 0 else {
                fail("--pid must be a positive process identifier", code: 2)
            }
            options.processIdentifier = pid_t(pid)
        case "--hint":
            options.hints.append(value())
        case "--allow-missing-marker-for-empty-text":
            options.allowsMissingMarkerForEmptyText = true
        case "--discovery-timeout":
            let rawValue = value()
            guard let timeout = TimeInterval(rawValue), timeout >= 0 else {
                fail("--discovery-timeout must be a non-negative number", code: 2)
            }
            options.discoveryTimeoutSeconds = timeout
        case "-h", "--help":
            usage()
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

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func focusedElement(in appElement: AXUIElement) -> AXUIElement? {
    guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute),
          CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
        return nil
    }
    return (focusedValue as! AXUIElement)
}

func focusedWindow(in appElement: AXUIElement) -> AXUIElement? {
    guard let focusedWindowValue = copyAttribute(appElement, kAXFocusedWindowAttribute),
          CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() else {
        return nil
    }
    return (focusedWindowValue as! AXUIElement)
}

func collectText(from element: AXUIElement, depth: Int = 0, into values: inout [String]) {
    guard depth <= 10 else {
        return
    }

    for attribute in [kAXValueAttribute as String, kAXTitleAttribute as String, kAXDescriptionAttribute as String, kAXHelpAttribute as String] {
        let value = stringAttribute(element, attribute)
        if !value.isEmpty {
            values.append(value)
        }
    }

    for child in children(of: element) {
        collectText(from: child, depth: depth + 1, into: &values)
    }
}

func collectWindowTitles(from appElement: AXUIElement) -> [String] {
    let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
    return windows
        .map { stringAttribute($0, kAXTitleAttribute) }
        .filter { !$0.isEmpty }
}

func windows(from appElement: AXUIElement) -> [AXUIElement] {
    copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
}

func frontmostBundleIdentifier() -> String? {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

func frontmostProcessIdentifier() -> pid_t? {
    NSWorkspace.shared.frontmostApplication?.processIdentifier
}

func targetRunningApplication(options: Options) -> NSRunningApplication? {
    if let processIdentifier = options.processIdentifier {
        guard let app = NSRunningApplication(processIdentifier: processIdentifier),
              app.bundleIdentifier == options.bundleIdentifier else {
            return nil
        }
        return app
    }

    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
       frontmostApplication.bundleIdentifier == options.bundleIdentifier {
        return frontmostApplication
    }

    return NSWorkspace.shared.runningApplications.first {
        $0.bundleIdentifier == options.bundleIdentifier
    }
}

func activateIfNeeded(_ app: NSRunningApplication, options: Options) {
    let frontmost = NSWorkspace.shared.frontmostApplication
    if frontmost?.processIdentifier == app.processIdentifier {
        return
    }

    app.activate(options: [.activateAllWindows])
    Thread.sleep(forTimeInterval: 0.08)
    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
        return
    }

    activateWithSystemEvents(processIdentifier: app.processIdentifier)
    Thread.sleep(forTimeInterval: 0.08)
}

func activateWithSystemEvents(processIdentifier: pid_t) {
    let script = """
    on run argv
      set targetPID to (item 1 of argv) as integer
      tell application "System Events"
        repeat with procRef in application processes
          try
            if unix id of procRef is targetPID then
              set frontmost of procRef to true
              return
            end if
          end try
        end repeat
      end tell
    end run
    """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-", String(processIdentifier)]
    let input = Pipe()
    process.standardInput = input
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        if let data = script.data(using: .utf8) {
            input.fileHandleForWriting.write(data)
        }
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()
    } catch {
        input.fileHandleForWriting.closeFile()
    }
}

func normalizedWhitespace(_ text: String) -> String {
    text
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

func containsText(_ haystack: String, _ needle: String, caseInsensitive: Bool = false) -> Bool {
    if caseInsensitive {
        if haystack.localizedCaseInsensitiveContains(needle) {
            return true
        }
        return normalizedWhitespace(haystack).localizedCaseInsensitiveContains(
            normalizedWhitespace(needle)
        )
    }

    if haystack.contains(needle) {
        return true
    }
    return normalizedWhitespace(haystack).contains(normalizedWhitespace(needle))
}

func searchState(in searchable: [String], options: Options) -> SearchState {
    let joinedSearchable = searchable.joined(separator: "\n")
    let hasMarker = containsText(joinedSearchable, options.marker, caseInsensitive: true)
    let expectedTokens = normalizedWhitespace(options.text).split(separator: " ")
    let expectedTokenMatches = expectedTokens.filter { token in
        containsText(joinedSearchable, String(token))
    }.count
    let hasNearCompleteText = expectedTokens.count >= 4
        && expectedTokenMatches >= expectedTokens.count - 1
    let hasText = options.text.isEmpty
        || containsText(joinedSearchable, options.text)
        || hasNearCompleteText
    let hasHint = options.hints.isEmpty || options.hints.contains { hint in
        containsText(joinedSearchable, hint, caseInsensitive: true)
    }

    return SearchState(
        hasMarker: hasMarker,
        hasText: hasText,
        hasHint: hasHint,
        expectedTokenCount: expectedTokens.count,
        expectedTokenMatches: expectedTokenMatches
    )
}

func snapshot(options: Options) -> Snapshot {
    guard let app = targetRunningApplication(options: options) else {
        let frontmost = frontmostBundleIdentifier()
        return Snapshot(
            frontmostBundleIdentifier: frontmost,
            frontmostProcessIdentifier: frontmostProcessIdentifier(),
            targetProcessIdentifier: options.processIdentifier,
            textCount: 0,
            titleCount: 0,
            markerWindowCount: 0,
            hasMarker: false,
            hasText: false,
            hasHint: false,
            expectedTokenCount: 0,
            expectedTokenMatches: 0
        )
    }
    activateIfNeeded(app, options: options)

    let frontmost = frontmostBundleIdentifier()
    let frontmostPID = frontmostProcessIdentifier()
    guard frontmost == options.bundleIdentifier,
          options.processIdentifier == nil || frontmostPID == app.processIdentifier else {
        return Snapshot(
            frontmostBundleIdentifier: frontmost,
            frontmostProcessIdentifier: frontmostPID,
            targetProcessIdentifier: app.processIdentifier,
            textCount: 0,
            titleCount: 0,
            markerWindowCount: 0,
            hasMarker: false,
            hasText: false,
            hasHint: false,
            expectedTokenCount: 0,
            expectedTokenMatches: 0
        )
    }

    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.8)

    var texts: [String] = []
    var scopedSearchables: [[String]] = []
    var allWindows = windows(from: appElement)
    if let focusedWindow = focusedWindow(in: appElement) {
        allWindows.insert(focusedWindow, at: 0)
    }
    let markerWindows = allWindows.filter { window in
        containsText(stringAttribute(window, kAXTitleAttribute), options.marker, caseInsensitive: true)
    }
    let scopedWindows = markerWindows.isEmpty ? allWindows : markerWindows
    for window in scopedWindows {
        var windowTexts: [String] = []
        collectText(from: window, into: &windowTexts)
        texts.append(contentsOf: windowTexts)
        let title = stringAttribute(window, kAXTitleAttribute)
        scopedSearchables.append(windowTexts + (title.isEmpty ? [] : [title]))
    }
    if let focused = focusedElement(in: appElement) {
        var focusedTexts: [String] = []
        collectText(from: focused, into: &focusedTexts)
        texts.append(contentsOf: focusedTexts)
        if markerWindows.isEmpty {
            scopedSearchables.append(focusedTexts)
        } else {
            for window in markerWindows {
                let title = stringAttribute(window, kAXTitleAttribute)
                scopedSearchables.append(focusedTexts + (title.isEmpty ? [] : [title]))
            }
        }
    }

    if texts.isEmpty {
        var appTexts: [String] = []
        collectText(from: appElement, into: &appTexts)
        texts.append(contentsOf: appTexts)
        scopedSearchables.append(appTexts)
    }

    let titles = scopedWindows
        .map { stringAttribute($0, kAXTitleAttribute) }
        .filter { !$0.isEmpty }
    let bestState = scopedSearchables
        .map { searchState(in: $0, options: options) }
        .max { $0.score < $1.score }
        ?? searchState(in: texts + titles, options: options)

    return Snapshot(
        frontmostBundleIdentifier: frontmost,
        frontmostProcessIdentifier: frontmostPID,
        targetProcessIdentifier: app.processIdentifier,
        textCount: texts.count,
        titleCount: titles.count,
        markerWindowCount: markerWindows.count,
        hasMarker: bestState.hasMarker,
        hasText: bestState.hasText,
        hasHint: bestState.hasHint,
        expectedTokenCount: bestState.expectedTokenCount,
        expectedTokenMatches: bestState.expectedTokenMatches
    )
}

func describeFailure(_ snapshot: Snapshot, options: Options) -> String {
    let frontmost = snapshot.frontmostBundleIdentifier ?? "none"
    let frontmostPID = snapshot.frontmostProcessIdentifier.map(String.init) ?? "none"
    let targetPID = snapshot.targetProcessIdentifier.map(String.init) ?? "none"
    return "\(options.displayName) proof AX check failed; frontmost=\(frontmost), frontmostPid=\(frontmostPID), targetPid=\(targetPID), textNodes=\(snapshot.textCount), titles=\(snapshot.titleCount), markerWindows=\(snapshot.markerWindowCount), marker=\(snapshot.hasMarker), text=\(snapshot.hasText), textTokens=\(snapshot.expectedTokenMatches)/\(snapshot.expectedTokenCount), hint=\(snapshot.hasHint)"
}

let options = parseOptions()

func waitForMatch(options: Options) -> Snapshot {
    let deadline = Date().addingTimeInterval(options.discoveryTimeoutSeconds)
    var latest = snapshot(options: options)
    repeat {
        latest = snapshot(options: options)
        if snapshotSatisfiesWait(latest, options: options) {
            return latest
        }
        Thread.sleep(forTimeInterval: 0.2)
    } while Date() < deadline
    return latest
}

func snapshotSatisfiesWait(_ snapshot: Snapshot, options: Options) -> Bool {
    let markerSatisfied = snapshot.hasMarker
        || (
            options.allowsMissingMarkerForEmptyText
                && options.text.isEmpty
                && snapshot.textCount > 0
        )
    return markerSatisfied && snapshot.hasText && snapshot.hasHint
}

switch options.action {
case "wait":
    let result = waitForMatch(options: options)
    guard snapshotSatisfiesWait(result, options: options) else {
        fail(describeFailure(result, options: options))
    }
case "assert":
    let result = snapshot(options: options)
    guard result.hasMarker && result.hasText else {
        fail(describeFailure(result, options: options))
    }
case "contains-marker":
    let result = snapshot(options: options)
    guard result.hasMarker else {
        fail(describeFailure(result, options: options))
    }
default:
    fail("unknown action: \(options.action)", code: 2)
}
