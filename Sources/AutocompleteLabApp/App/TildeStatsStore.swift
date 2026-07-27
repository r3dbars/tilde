import AutocompleteLabCore
import Foundation

/// App-side aggregate of the keyboard's usage counters — the data the Tilde
/// window displays. Counts and durations only, never text (privacy rule).
///
/// The keyboard's counters live in the IME process; they reach this store over
/// the brain socket as periodic `{"stats": {...}}` reports (Phase 0 bridge —
/// `ingest(report:)` is that contract). Until the bridge lands, everything
/// reads zero and the window shows its cold-start state.
///
/// Lifetime totals NEVER reset — the odometer only goes up.
@MainActor
final class TildeStatsStore: ObservableObject {

    static let shared = TildeStatsStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let lifetimeWordsAccepted = "tilde.stats.lifetimeWordsAccepted"
        static let lifetimeCharactersAccepted = "tilde.stats.lifetimeCharactersAccepted"
        static let lastSeenOdometer = "tilde.stats.lastSeenOdometer"
        static func day(_ key: String) -> String { "tilde.stats.day.\(key)" }
    }

    /// Fields a stats report may carry. All deltas since the previous report.
    enum ReportField: String, CaseIterable {
        case wordsAccepted
        case charactersAccepted
        case wordsTyped
        case typedCharacters
        case activeTypingMs
        case keystrokes
    }

    @Published private(set) var revision = 0

    // MARK: - Ingest (called when a keyboard stats report arrives)

    func ingest(report: [String: Int]) {
        guard report.values.contains(where: { $0 > 0 }) else { return }
        let accepted = report[ReportField.wordsAccepted.rawValue] ?? 0
        let acceptedCharacters = report[ReportField.charactersAccepted.rawValue] ?? 0
        defaults.set(lifetimeWords + accepted, forKey: Key.lifetimeWordsAccepted)
        defaults.set(
            defaults.integer(forKey: Key.lifetimeCharactersAccepted) + acceptedCharacters,
            forKey: Key.lifetimeCharactersAccepted
        )
        var day = defaults.dictionary(forKey: Key.day(Self.dayKey())) as? [String: Int] ?? [:]
        for field in ReportField.allCases {
            if let delta = report[field.rawValue], delta > 0 {
                day[field.rawValue, default: 0] += delta
            }
        }
        defaults.set(day, forKey: Key.day(Self.dayKey()))
        revision += 1
    }

    // MARK: - Reads

    var lifetimeWords: Int { defaults.integer(forKey: Key.lifetimeWordsAccepted) }

    /// Where the odometer animates FROM on window-open; call `markSeen()` after
    /// presenting so the next open starts where this one ended.
    var lastSeenOdometer: Int { defaults.integer(forKey: Key.lastSeenOdometer) }

    func markSeen() { defaults.set(lifetimeWords, forKey: Key.lastSeenOdometer) }

    var todayWordsAccepted: Int { todayField(.wordsAccepted) }

    var rawWordsPerMinute: Double? {
        WritingSpeed.wordsPerMinute(words: recentField(.wordsTyped), activeTypingMilliseconds: recentField(.activeTypingMs))
    }

    var assistedWordsPerMinute: Double? {
        WritingSpeed.wordsPerMinute(
            words: recentField(.wordsTyped) + recentField(.wordsAccepted),
            activeTypingMilliseconds: recentField(.activeTypingMs)
        )
    }

    var speedupPercent: Int? {
        guard let raw = rawWordsPerMinute, let assisted = assistedWordsPerMinute else { return nil }
        return WritingSpeed.speedupPercent(raw: raw, assisted: assisted)
    }

    var hoursSavedThisMonth: Double? {
        var accepted = 0, typed = 0, activeMs = 0
        for key in monthDayKeys() {
            let day = defaults.dictionary(forKey: Key.day(key)) as? [String: Int] ?? [:]
            accepted += day[ReportField.charactersAccepted.rawValue] ?? 0
            typed += day[ReportField.typedCharacters.rawValue] ?? 0
            activeMs += day[ReportField.activeTypingMs.rawValue] ?? 0
        }
        return WritingSpeed.hoursSaved(
            charactersAccepted: accepted,
            typedCharacters: typed,
            activeTypingMilliseconds: activeMs
        )
    }

    // MARK: - Helpers

    private func todayField(_ field: ReportField) -> Int {
        (defaults.dictionary(forKey: Key.day(Self.dayKey())) as? [String: Int])?[field.rawValue] ?? 0
    }

    /// Last 7 days — recent enough to reflect the current model, big enough to
    /// clear the WritingSpeed minimum-activity floor.
    private func recentField(_ field: ReportField) -> Int {
        var total = 0
        for offset in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let day = defaults.dictionary(forKey: Key.day(Self.dayKey(for: date))) as? [String: Int] ?? [:]
            total += day[field.rawValue] ?? 0
        }
        return total
    }

    private func monthDayKeys() -> [String] {
        (0..<31).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date()).map(Self.dayKey(for:))
        }
    }

    private static func dayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
