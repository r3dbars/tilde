import Foundation

/// Reads the keyboard's aggregate-only daily counters. No typed text, prompts,
/// completions, app names, fields, or document identifiers cross this bridge.
enum TildeStats {
    private static func dayDict(_ key: String) -> [String: Int] {
        UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
            .dictionary(forKey: "stats.\(key)") as? [String: Int] ?? [:]
    }

    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func todayWordsAccepted() -> Int {
        dayDict(todayKey)["wordsAccepted"] ?? 0
    }

    static func lifetimeWordsAccepted() -> Int {
        guard let suite = UserDefaults(suiteName: TildeSettings.keyboardSuiteName) else { return 0 }
        return sumWordsAccepted(in: suite.dictionaryRepresentation())
    }

    static func sumWordsAccepted(in values: [String: Any]) -> Int {
        values.reduce(into: 0) { total, entry in
            guard entry.key.hasPrefix("stats."),
                  let counters = entry.value as? [String: Int]
            else { return }
            total += counters["wordsAccepted"] ?? 0
        }
    }
}
