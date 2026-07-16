import Foundation
import AutocompleteLabCore

final class PersonalCaptureEpisodeStore: @unchecked Sendable {
    static let shared = PersonalCaptureEpisodeStore(
        folderURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SteadyType/Personal Capture/Episodes")
    )

    private let folderURL: URL
    private let queue = DispatchQueue(label: "app.steadytype.personal-capture-episodes")
    private let calendar: Calendar
    private let now: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var records: [String: SuggestionEpisodeRecord] = [:]

    init(
        folderURL: URL,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.folderURL = folderURL
        self.calendar = calendar
        self.now = now
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    var folderPath: String {
        folderURL.path
    }

    func recordPresented(_ record: SuggestionEpisodeRecord) {
        queue.async { [self] in
            if var stored = records[record.id] {
                stored.mergePresentation(record)
                records[record.id] = stored
                persist(stored)
            } else {
                records[record.id] = record
                persist(record)
            }
        }
    }

    func recordAction(
        suggestionID: String,
        timestamp: String? = nil,
        appBundleIdentifier: String = "",
        outcome: SuggestionEpisodeOutcome,
        reason: String,
        acceptedText: String = "",
        metadata: [String: String] = [:]
    ) {
        queue.async { [self] in
            let timestamp = timestamp ?? Self.timestampString(from: now())
            guard var record = records[suggestionID] else {
                return
            }
            record.appendAction(
                outcome,
                timestamp: timestamp,
                reason: reason,
                acceptedText: acceptedText,
                metadata: metadata
            )
            records[suggestionID] = record
            persist(record)
        }
    }

    func recordSurvival(
        suggestionID: String,
        timestamp: String? = nil,
        appBundleIdentifier: String = "",
        acceptedText: String,
        checkpoint: String,
        survivalClass: String,
        tokenRecall: Double?,
        normalizedEditDistance: Double?,
        metadata: [String: String] = [:]
    ) {
        queue.async { [self] in
            let timestamp = timestamp ?? Self.timestampString(from: now())
            guard var record = records[suggestionID] else {
                return
            }
            if !acceptedText.isEmpty {
                record.acceptedText = acceptedText
            }
            record.metadata.merge(metadata) { _, new in new }
            record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
                checkpoint: checkpoint,
                survivalClass: survivalClass,
                tokenRecall: tokenRecall,
                normalizedEditDistance: normalizedEditDistance,
                timestamp: timestamp
            ))
            records[suggestionID] = record
            persist(record)
        }
    }

    func currentScorecard() -> SuggestionEpisodeScorecard {
        queue.sync {
            scorecard(for: now())
        }
    }

    func deleteAll() {
        queue.sync {
            records.removeAll()
            try? FileManager.default.removeItem(at: folderURL)
        }
    }

    func waitForPendingWrites() {
        queue.sync {}
    }

    private func persist(_ record: SuggestionEpisodeRecord) {
        do {
            // Episode records and dashboards embed verbatim typed/suggested text — keep
            // owner-only (0700 dir / 0600 file). See docs/security/threat-model.md (F2).
            SecureLocalStorage.createDirectory(at: folderURL)

            let data = try encoder.encode(record)
            guard var line = String(data: data, encoding: .utf8) else {
                return
            }
            line.append("\n")

            let writeDate = now()
            let fileURL = episodeFileURL(for: writeDate)
            SecureLocalStorage.ensureFile(at: fileURL)

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            try handle.close()

            let dashboardURL = dashboardFileURL(for: writeDate)
            let dashboard = scorecard(for: writeDate).markdown
            try dashboard.write(
                to: dashboardURL,
                atomically: true,
                encoding: .utf8
            )
            // Atomic write creates a fresh inode at the process umask; re-tighten.
            SecureLocalStorage.restrictFile(at: dashboardURL)
        } catch {
            ResearchDiagnosticsLog.shared.record(
                "personal-capture-episode-write-failed",
                metadata: ["reason": DiagnosticValueRedactor.stringSummary(length: String(describing: error).count)]
            )
        }
    }

    private func episodeFileURL(for date: Date) -> URL {
        folderURL.appendingPathComponent("\(Self.dayString(from: date, calendar: calendar)).episodes.jsonl")
    }

    private func dashboardFileURL(for date: Date) -> URL {
        folderURL.appendingPathComponent("\(Self.dayString(from: date, calendar: calendar))-dashboard.md")
    }

    private func scorecard(for date: Date) -> SuggestionEpisodeScorecard {
        SuggestionEpisodeScorecard(records: recordsFromEpisodeFile(for: date))
    }

    private func recordsFromEpisodeFile(for date: Date) -> [SuggestionEpisodeRecord] {
        let fileURL = episodeFileURL(for: date)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        var latestRecordsByID: [String: SuggestionEpisodeRecord] = [:]
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let record = try? decoder.decode(SuggestionEpisodeRecord.self, from: data) else {
                continue
            }
            latestRecordsByID[record.id] = record
        }
        return Array(latestRecordsByID.values)
    }

    static func dayString(from date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func timestampString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
