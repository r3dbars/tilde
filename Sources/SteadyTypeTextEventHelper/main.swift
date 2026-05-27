import AppKit
import ApplicationServices
import Foundation

struct Options {
    var tapLocation: CGEventTapLocation = .cghidEventTap
    var expectedFrontmostBundleIdentifier: String?
    var expectedFrontmostProcessIdentifier: pid_t?
    var delayMicros: useconds_t = 12_000
}

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var index = 1
    while index < arguments.count {
        let argument = arguments[index]
        func value() -> String {
            index += 1
            guard index < arguments.count else {
                fail("missing value for \(argument)", code: 2)
            }
            return arguments[index]
        }

        switch argument {
        case "--tap":
            switch value() {
            case "hid":
                options.tapLocation = .cghidEventTap
            case "session":
                options.tapLocation = .cgSessionEventTap
            default:
                fail("unknown tap location", code: 2)
            }
        case "--frontmost-bundle":
            options.expectedFrontmostBundleIdentifier = value()
        case "--pid":
            guard let pid = Int32(value()) else {
                fail("invalid pid", code: 2)
            }
            options.expectedFrontmostProcessIdentifier = pid
        case "--delay-micros":
            guard let delay = UInt32(value()) else {
                fail("invalid delay", code: 2)
            }
            options.delayMicros = delay
        default:
            fail("unknown argument", code: 2)
        }
        index += 1
    }
    return options
}

let options = parseOptions(CommandLine.arguments)

func frontmostApplicationSnapshot() -> NSRunningApplication? {
    NSWorkspace.shared.frontmostApplication
}

func frontmostMatches(_ application: NSRunningApplication?, options: Options) -> Bool {
    guard let application else {
        return false
    }
    if let expectedBundle = options.expectedFrontmostBundleIdentifier,
       application.bundleIdentifier != expectedBundle {
        return false
    }
    if let expectedPID = options.expectedFrontmostProcessIdentifier,
       application.processIdentifier != expectedPID {
        return false
    }
    return true
}

func waitForExpectedFrontmostApplication(options: Options) -> NSRunningApplication? {
    if let expectedPID = options.expectedFrontmostProcessIdentifier {
        _ = NSRunningApplication(processIdentifier: expectedPID)?
            .activate(options: [.activateAllWindows])
    }

    let deadline = Date().addingTimeInterval(0.35)
    repeat {
        let application = frontmostApplicationSnapshot()
        if frontmostMatches(application, options: options) {
            return application
        }
        usleep(20_000)
    } while Date() < deadline

    return frontmostApplicationSnapshot()
}

func systemEventsReportsExpectedProcessFrontmost(options: Options) -> Bool {
    guard let expectedPID = options.expectedFrontmostProcessIdentifier else {
        return false
    }

    let bundleCheck: String
    if let expectedBundle = options.expectedFrontmostBundleIdentifier {
        bundleCheck = """
            if bundle identifier of procRef is not "\(expectedBundle)" then return false
        """
    } else {
        bundleCheck = ""
    }
    let scriptSource = """
    set targetProcessId to \(expectedPID) as integer
    tell application "System Events"
        set procRef to first application process whose unix id is targetProcessId
    \(bundleCheck)
        set frontmost of procRef to true
        delay 0.04
        return frontmost of procRef
    end tell
    """
    guard let script = NSAppleScript(source: scriptSource) else {
        return false
    }

    var errorInfo: NSDictionary?
    let result = script.executeAndReturnError(&errorInfo)
    return errorInfo == nil && result.booleanValue
}

if options.expectedFrontmostBundleIdentifier != nil || options.expectedFrontmostProcessIdentifier != nil {
    let frontmostApplication = waitForExpectedFrontmostApplication(options: options)
    if !frontmostMatches(frontmostApplication, options: options) {
        if systemEventsReportsExpectedProcessFrontmost(options: options) {
            // Ghostty can expose its root app PID through NSWorkspace while
            // System Events tracks the exact frontmost proof process.
        } else {
            guard let frontmostApplication else {
                fail("missing frontmost application", code: 3)
            }
            if let expectedBundle = options.expectedFrontmostBundleIdentifier,
               frontmostApplication.bundleIdentifier != expectedBundle {
                fail("frontmost bundle mismatch actual=\(frontmostApplication.bundleIdentifier ?? "none") expected=\(expectedBundle)", code: 3)
            }
            if let expectedPID = options.expectedFrontmostProcessIdentifier,
               frontmostApplication.processIdentifier != expectedPID {
                fail("frontmost pid mismatch actual=\(frontmostApplication.processIdentifier) expected=\(expectedPID)", code: 3)
            }
        }
    }
}

let inputData = FileHandle.standardInput.readDataToEndOfFile()
guard let text = String(data: inputData, encoding: .utf8), !text.isEmpty else {
    fail("missing text", code: 4)
}
guard !text.contains(where: \.isNewline) else {
    fail("multiline text refused", code: 4)
}
guard let source = CGEventSource(stateID: .hidSystemState) else {
    fail("failed to create CGEvent source", code: 5)
}

for character in text {
    var units = Array(String(character).utf16)
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        fail("failed to create CGEvent text key", code: 5)
    }

    keyDown.flags = []
    keyUp.flags = []
    units.withUnsafeMutableBufferPointer { buffer in
        keyDown.keyboardSetUnicodeString(
            stringLength: buffer.count,
            unicodeString: buffer.baseAddress
        )
        keyUp.keyboardSetUnicodeString(
            stringLength: buffer.count,
            unicodeString: buffer.baseAddress
        )
    }
    keyDown.post(tap: options.tapLocation)
    usleep(options.delayMicros)
    keyUp.post(tap: options.tapLocation)
    usleep(options.delayMicros)
}
