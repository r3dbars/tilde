import Foundation

enum ResearchCLIError: Error, LocalizedError {
    case usage(String)
    case invalidValue(String)
    case missingArtifact(String)
    case budgetExpired
    case noComparableReports
    case noPromotableCandidate
    case protectedEvidenceRequired
    case rawTelemetryKey(String)
    case regressionFailed(armID: String, failedCases: Int, gates: [String])

    var errorDescription: String? {
        switch self {
        case let .usage(message): message
        case let .invalidValue(label): "Invalid value for \(label)."
        case let .missingArtifact(label): "Required research artifact is missing: \(label)."
        case .budgetExpired: "The campaign's cumulative active-time budget is exhausted."
        case .noComparableReports: "No complete, exactly paired baseline/candidate reports are available."
        case .noPromotableCandidate: "No candidate passed the pre-registered paired promotion rule."
        case .protectedEvidenceRequired:
            "Protected work requires a passing frozen comparison from the immediately preceding phase."
        case let .rawTelemetryKey(key):
            "The online event input contains forbidden raw-data key \(key)."
        case let .regressionFailed(armID, failedCases, gates):
            "Regression candidate \(armID) failed \(failedCases) cases; gates: \(gates.isEmpty ? "none" : gates.joined(separator: ", "))."
        }
    }
}

struct CLIArguments {
    let command: String?
    let positionals: [String]
    private let options: [String: String]
    private let flags: Set<String>

    init(_ values: [String]) throws {
        command = values.first
        var positionals: [String] = []
        var options: [String: String] = [:]
        var flags = Set<String>()
        let knownFlags: Set<String> = [
            "help", "resume", "no-cache", "allow-battery", "experimental-model",
            "confirm-consume", "json",
        ]
        var index = command == nil ? 0 : 1
        while index < values.count {
            let token = values[index]
            guard token.hasPrefix("--") else {
                positionals.append(token)
                index += 1
                continue
            }
            let body = String(token.dropFirst(2))
            guard !body.isEmpty else { throw ResearchCLIError.usage(Self.usage) }
            if let separator = body.firstIndex(of: "=") {
                let key = String(body[..<separator])
                let value = String(body[body.index(after: separator)...])
                guard !key.isEmpty, !value.isEmpty,
                      options.updateValue(value, forKey: key) == nil,
                      !flags.contains(key) else {
                    throw ResearchCLIError.usage("Duplicate or empty option --\(key).")
                }
            } else if knownFlags.contains(body) {
                guard flags.insert(body).inserted, options[body] == nil else {
                    throw ResearchCLIError.usage("Duplicate flag --\(body).")
                }
            } else {
                guard index + 1 < values.count, !values[index + 1].hasPrefix("--") else {
                    throw ResearchCLIError.usage("Option --\(body) needs a value.")
                }
                guard options.updateValue(values[index + 1], forKey: body) == nil,
                      !flags.contains(body) else {
                    throw ResearchCLIError.usage("Duplicate option --\(body).")
                }
                index += 1
            }
            index += 1
        }
        self.positionals = positionals
        self.options = options
        self.flags = flags
    }

    func value(_ name: String) -> String? { options[name] }
    func hasFlag(_ name: String) -> Bool { flags.contains(name) }

    func requiredValue(_ name: String) throws -> String {
        guard let value = options[name], !value.isEmpty else {
            throw ResearchCLIError.usage("Missing required option --\(name).")
        }
        return value
    }

    func integer(_ name: String, default fallback: Int) throws -> Int {
        guard let value = options[name] else { return fallback }
        guard let result = Int(value) else { throw ResearchCLIError.invalidValue("--\(name)") }
        return result
    }

    func double(_ name: String, default fallback: Double) throws -> Double {
        guard let value = options[name] else { return fallback }
        guard let result = Double(value), result.isFinite else {
            throw ResearchCLIError.invalidValue("--\(name)")
        }
        return result
    }

    func assertAllowed(
        options allowedOptions: Set<String>,
        flags allowedFlags: Set<String> = []
    ) throws {
        let unknownOptions = Set(options.keys).subtracting(allowedOptions)
        let unknownFlags = flags.subtracting(allowedFlags.union(["help"]))
        if let unknown = unknownOptions.union(unknownFlags).sorted().first {
            throw ResearchCLIError.usage("Unknown option --\(unknown) for \(command ?? "command").")
        }
    }

    static let usage = """
    Usage: tilde-research <command> [arguments]

      init                     create an owner-only discovery campaign
      validate CAMPAIGN       validate schema, phase firewall, suite, and budget
      run CAMPAIGN            run or resume durable interleaved work
      status CAMPAIGN         show durable work, reports, cache, and time budget
      compare                 paired-bootstrap every candidate against the baseline
      risk-coverage           replay confidence thresholds without new inference
      personalization-replay chronological local history evaluation; aggregate output only
      advance-search          create a balanced-halving or adaptive child campaign
      nominate                freeze up to three passing validation candidates
      validate-candidates PLAN
                               run a frozen validation plan (requires --campaign)
      holdout                 freeze, consume once, and run one holdout candidate
      freeze-regression       bind a failure digest and immutable regression suite
      regression              run a frozen permanent regression plan
      shadow                  create a no-display local shadow plan
      dogfood                 create a sticky controlled local dogfood plan
      soak                    create a bounded four-hour/overnight stability plan
      ingest-events           ingest strict text-free JSONL online events
      online-report           summarize acceptance, edit harm, latency, and attention tax
      confidence-report       fit chronological text-free acceptance calibration
      soak-report             enforce duration, reliability, insertion, egress, and p99 gates
      interaction-report      verify complete text-free real-host interaction evidence
      delete-telemetry        delete every event for a campaign
      cache-clear             delete the synthetic-only raw candidate cache
      agent-evidence          export bounded aggregate-only evidence for an agent
      agent-validate          validate a bounded aggregate-only agent proposal

    Run `tilde-research <command> --help` for command-specific options.
    """
}

extension String {
    var expandedResearchPath: String {
        (self as NSString).expandingTildeInPath
    }

    var researchSlug: String {
        let lowered = lowercased()
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "tilde-campaign" : String(collapsed.prefix(80))
    }
}
