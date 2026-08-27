import TildeCore
import Foundation

/// Headless CLI support for `script/redaction_eval.py`: runs the EXACT
/// shipped `RedactionService` pipeline (rules, then the real GLiNER
/// helper-process model layer via `GLiNERRedactionHelperHost`) over a
/// corpus file, one JSON line per input record.
///
/// Unlike `ReplayEvalCommand` — whose whole contract is "never emit a
/// scrap of text, aggregate counts only" because it runs against the
/// owner's REAL Personal History — this command's output DOES include the
/// (already redacted) text. That is intentional and safe here only
/// because its one caller, `redaction_eval.py`, feeds it a committed
/// SYNTHETIC corpus of fake planted secrets; the Python side needs the
/// redacted text to check that each planted secret string is actually
/// gone. This command must never be pointed at real captured screen text
/// or the real Personal History store — it takes an explicit corpus file
/// path for exactly that reason, never reading any store.
struct RedactionEvalCommand {
    struct InputRecord: Decodable {
        let id: String
        let text: String
    }

    struct OutputLine: Encodable {
        let id: String
        let dropped: Bool
        let redacted: String?
        let ruleFindingCount: Int?
        let modelSpanCount: Int?
    }

    enum CommandResult: Equatable {
        case output(String), failure(String)
    }

    private let corpusPath: String
    private let serviceFactory: @Sendable () -> RedactionService

    init(
        corpusPath: String,
        serviceFactory: @escaping @Sendable () -> RedactionService = {
            RedactionService(spanDetector: GLiNERRedactionHelperHost())
        }
    ) {
        self.corpusPath = corpusPath
        self.serviceFactory = serviceFactory
    }

    func execute() async -> CommandResult {
        guard let data = FileManager.default.contents(atPath: corpusPath),
              let contents = String(data: data, encoding: .utf8) else {
            return .failure(#"{"error":"corpus-unreadable"}"#)
        }

        let decoder = JSONDecoder()
        var lines: [String] = []
        let service = serviceFactory()
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let record = try? decoder.decode(InputRecord.self, from: Data(rawLine.utf8)) else {
                return .failure(#"{"error":"corpus-line-invalid"}"#)
            }
            let outcome = await service.redact(record.text)
            let output: OutputLine
            switch outcome {
            case let .redacted(result):
                output = OutputLine(
                    id: record.id,
                    dropped: false,
                    redacted: result.text,
                    ruleFindingCount: result.ruleFindings.count,
                    modelSpanCount: result.modelSpanCount
                )
            case .dropped:
                output = OutputLine(id: record.id, dropped: true, redacted: nil, ruleFindingCount: nil, modelSpanCount: nil)
            }
            guard let encoded = try? JSONEncoder().encode(output), let line = String(data: encoded, encoding: .utf8) else {
                return .failure(#"{"error":"encode-failed"}"#)
            }
            lines.append(line)
        }
        return .output(lines.joined(separator: "\n"))
    }
}
