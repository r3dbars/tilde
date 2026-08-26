import CryptoKit
import Foundation

public struct LabHistoricalReplaySummary: Equatable, Sendable {
    public let acceptedCases: Int
    public let typedInsteadCases: Int
    public let screenContextCases: Int
}

public struct LabHistoricalReplayLoad: Sendable {
    public let suite: LabScenarioSuite
    public let summary: LabHistoricalReplaySummary
}

/// Reads Tilde's owner-controlled export directly into memory. Source text is
/// never copied into a Lab report, identifier, log, or diagnostic.
public enum LabHistoricalReplayLoader {
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage")
    }

    public static func load(
        from directory: URL = defaultDirectory,
        maximumCases: Int = 2_000
    ) throws -> LabHistoricalReplayLoad {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let eventsURL = files.first(where: { $0.lastPathComponent.hasPrefix("ghost_events_") }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let screens = try screenIndex(
            files.first(where: { $0.lastPathComponent.hasPrefix("brain_samples_") })
        )
        let records = try JSONLineReader.objects(at: eventsURL)
            .compactMap(HistoricalEvent.init)
            .filter { $0.isUseful }
            .sorted { $0.timestamp < $1.timestamp }

        var identifiers = Set<String>()
        var scenarios: [LabScenario] = []
        var acceptedCount = 0
        var typedInsteadCount = 0
        var screenCount = 0
        for record in records.prefix(max(0, maximumCases)) {
            guard let rawTarget = record.target, !rawTarget.isEmpty else { continue }
            let target = String(rawTarget.prefix(12_000))
            let digest = opaqueDigest(record.identityMaterial + target)
            guard identifiers.insert(digest).inserted else { continue }
            let screen = screens[record.screenLookupKey]
            if screen != nil { screenCount += 1 }
            let source: LabScenarioSource
            if record.event == "typed_instead" {
                source = .historicalTypedInstead
                typedInsteadCount += 1
            } else {
                source = .historicalAccepted
                acceptedCount += 1
            }
            let base = LabScenario(
                id: "history-\(digest.prefix(20))",
                category: source == .historicalAccepted
                    ? "reply.history.accepted"
                    : "reply.history.typed-instead",
                partition: .development,
                tags: ["private-history", source.rawValue],
                appBundleIdentifier: record.appBundle,
                typedContext: String(record.context.suffix(24_000)),
                expectation: LabExpectation(
                    shouldSuggest: true,
                    goldenContinuation: target,
                    acceptablePrefixes: [target],
                    maximumWords: 20
                ),
                evaluation: LabEvaluationMetadata(
                    source: source,
                    checkpoint: .caret,
                    contextVariant: screen == nil ? .appMetadata : .recordedScreen,
                    temporalIntegrity: .unverifiedHistorical,
                    evidence: LabContextEvidence(recordedScreenText: screen),
                    corpusID: "private-tilde-history",
                    rootScenarioID: "history-\(digest.prefix(20))"
                )
            )
            scenarios.append(contentsOf: LabPrefixReplay.expand(
                base,
                checkpoints: [.caret, .firstWord, .twoWords]
            ))
        }
        let suite = try LabScenarioSuite(
            name: "Private Personal Replay development only",
            scenarios: scenarios
        ).validated()
        return LabHistoricalReplayLoad(
            suite: suite,
            summary: LabHistoricalReplaySummary(
                acceptedCases: acceptedCount,
                typedInsteadCases: typedInsteadCount,
                screenContextCases: screenCount
            )
        )
    }

    private static func screenIndex(_ url: URL?) throws -> [String: String] {
        guard let url else { return [:] }
        return try JSONLineReader.objects(at: url).reduce(into: [:]) { index, object in
            guard let app = object["app_bundle"] as? String,
                  let context = object["context"] as? String,
                  let suggestion = object["suggestion"] as? String,
                  let screen = object["screen"] as? String,
                  !screen.isEmpty else { return }
            index[opaqueDigest(app + "\u{0}" + context + "\u{0}" + suggestion)] = String(screen.suffix(48_000))
        }
    }

    private static func opaqueDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private struct HistoricalEvent {
        let event: String
        let timestamp: String
        let appBundle: String?
        let context: String
        let ghost: String
        let accepted: String?
        let typed: String?

        init?(_ object: [String: Any]) {
            guard let event = object["event"] as? String,
                  let timestamp = object["ts"] as? String,
                  let context = object["context"] as? String,
                  let ghost = object["ghost"] as? String else { return nil }
            self.event = event
            self.timestamp = timestamp
            appBundle = object["app_bundle"] as? String
            self.context = context
            self.ghost = ghost
            accepted = object["accepted"] as? String
            typed = object["typed"] as? String
        }

        var isUseful: Bool {
            !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (event == "accept_all" || event == "accept_word" || event == "typed_instead")
        }
        var target: String? { event == "typed_instead" ? typed : accepted }
        var identityMaterial: String {
            [timestamp, appBundle ?? "", event, context, ghost].joined(separator: "\u{0}")
        }
        var screenLookupKey: String {
            opaqueDigest((appBundle ?? "") + "\u{0}" + context + "\u{0}" + ghost)
        }
    }

    private enum JSONLineReader {
        static func objects(at url: URL) throws -> [[String: Any]] {
            try String(contentsOf: url, encoding: .utf8)
                .split(whereSeparator: \.isNewline)
                .compactMap { line in
                    try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
                }
        }
    }
}
