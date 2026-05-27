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

if options.expectedFrontmostBundleIdentifier != nil || options.expectedFrontmostProcessIdentifier != nil {
    guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
        fail("missing frontmost application", code: 3)
    }
    if let expectedBundle = options.expectedFrontmostBundleIdentifier,
       frontmostApplication.bundleIdentifier != expectedBundle {
        fail("frontmost bundle mismatch", code: 3)
    }
    if let expectedPID = options.expectedFrontmostProcessIdentifier,
       frontmostApplication.processIdentifier != expectedPID {
        fail("frontmost pid mismatch", code: 3)
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
