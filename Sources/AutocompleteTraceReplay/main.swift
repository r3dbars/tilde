import AutocompleteLabCore
import Foundation

let arguments = CommandLine.arguments.dropFirst()

guard let tracePath = arguments.first, !tracePath.isEmpty else {
    FileHandle.standardError.write(
        Data("Usage: AutocompleteTraceReplay /path/to/traces.jsonl\n".utf8)
    )
    Foundation.exit(64)
}

let traceURL = URL(fileURLWithPath: tracePath)
let data = try Data(contentsOf: traceURL)
let contents = String(decoding: data, as: UTF8.self)
let decoder = JSONDecoder()
let events = try contents
    .split(whereSeparator: \.isNewline)
    .map { line in
        try decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
    }

let report = AutocompleteTraceReplay().report(for: events)
print(report.markdown)
Foundation.exit(report.passesReplayProofGate ? 0 : 1)
