import AutocompleteLabCore
import Foundation

let arguments = CommandLine.arguments.dropFirst()
var tracePath: String?
var startLine = 0
var endLine: Int?
var profile = AutocompleteTraceReplayProfile.full
var decisionDiffMode = false
var previewBrain = DisplayScoreSuppressionBrain.fromEnvironment(ProcessInfo.processInfo.environment)
var iterator = arguments.makeIterator()
let usage = "Usage: AutocompleteTraceReplay [--decision-diff] [--one-brain-preview] [--start-line N] [--end-line N] [--profile \(AutocompleteTraceReplayProfile.cliValues)] /path/to/traces.jsonl\n"

func printUsageAndExit(
    _ message: String? = nil,
    status: Int32 = 64,
    fileHandle: FileHandle = .standardError
) -> Never {
    if let message {
        fileHandle.write(Data("\(message)\n".utf8))
    }
    fileHandle.write(Data(usage.utf8))
    Foundation.exit(status)
}

func parseLine(_ value: String, flag: String) -> Int {
    guard let parsed = Int(value), parsed >= 0 else {
        printUsageAndExit("Invalid \(flag): \(value)")
    }
    return parsed
}

func parseProfile(_ value: String) -> AutocompleteTraceReplayProfile {
    guard let parsed = AutocompleteTraceReplayProfile(rawValue: value) else {
        printUsageAndExit("Invalid --profile: \(value)")
    }
    return parsed
}

while let argument = iterator.next() {
    switch argument {
    case "--start-line":
        guard let value = iterator.next() else {
            printUsageAndExit("Missing value for --start-line")
        }
        startLine = parseLine(value, flag: "--start-line")
    case "--end-line":
        guard let value = iterator.next() else {
            printUsageAndExit("Missing value for --end-line")
        }
        endLine = parseLine(value, flag: "--end-line")
    case "--profile":
        guard let value = iterator.next() else {
            printUsageAndExit("Missing value for --profile")
        }
        profile = parseProfile(value)
    case "--decision-diff":
        decisionDiffMode = true
    case "--one-brain-preview":
        previewBrain = .oneBrainPreview
    case let value where value.hasPrefix("--start-line="):
        startLine = parseLine(String(value.dropFirst("--start-line=".count)), flag: "--start-line")
    case let value where value.hasPrefix("--end-line="):
        endLine = parseLine(String(value.dropFirst("--end-line=".count)), flag: "--end-line")
    case let value where value.hasPrefix("--profile="):
        profile = parseProfile(String(value.dropFirst("--profile=".count)))
    case "-h", "--help":
        printUsageAndExit(status: 0, fileHandle: .standardOutput)
    case let value where value.hasPrefix("-"):
        printUsageAndExit("Unknown argument: \(value)")
    default:
        if tracePath != nil {
            printUsageAndExit("Only one trace path can be provided")
        }
        tracePath = argument
    }
}

guard let tracePath, !tracePath.isEmpty else {
    printUsageAndExit("Missing trace path")
}

if let endLine, endLine < startLine {
    printUsageAndExit("--end-line must be greater than or equal to --start-line")
}

let traceURL = URL(fileURLWithPath: tracePath)
let data = try Data(contentsOf: traceURL)
let contents = String(decoding: data, as: UTF8.self)
let decoder = JSONDecoder()
var events: [AutocompleteTraceEvent] = []
for (offset, line) in contents.split(whereSeparator: \.isNewline).enumerated() {
    let lineNumber = offset + 1
    guard lineNumber > startLine else {
        continue
    }

    if let endLine, lineNumber > endLine {
        break
    }

    let event = try decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
    events.append(event)
}

if decisionDiffMode {
    let report = AutocompleteTraceReplay().decisionDiffReport(
        for: events,
        previewBrain: previewBrain
    )
    print(report.markdown)
    Foundation.exit(report.passesDiffProofGate ? 0 : 1)
} else {
    let report = AutocompleteTraceReplay().report(for: events, profile: profile)
    print(report.markdown)
    Foundation.exit(report.passesReplayProofGate ? 0 : 1)
}
