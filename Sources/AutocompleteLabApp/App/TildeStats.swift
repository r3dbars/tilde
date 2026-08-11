import Foundation

/// Reads the keyboard's aggregate-only daily counters. No typed text, prompts,
/// completions, app names, fields, or document identifiers cross this bridge.
enum TildeStats {
    private static let imeDomain = "bar.r3d.inputmethod.InlineGhost"
    private static let lifetimeKey = "tilde.lifetimeWordsAccepted"
    private static let countedKey = "tilde.countedThroughDay"

    private static func dayDict(_ key: String) -> [String: Int] {
        UserDefaults(suiteName: imeDomain)?.dictionary(forKey: "stats.\(key)") as? [String: Int] ?? [:]
    }

    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func todayWordsAccepted() -> Int {
        dayDict(todayKey)["wordsAccepted"] ?? 0
    }

    /// Closed days are folded into a persistent aggregate exactly once; today's
    /// running count is added live so the menu stays current.
    static func lifetimeWordsAccepted() -> Int {
        let defaults = UserDefaults.standard
        var lifetime = defaults.integer(forKey: lifetimeKey)
        let countedThrough = defaults.string(forKey: countedKey) ?? ""
        let today = todayKey

        if let suite = UserDefaults(suiteName: imeDomain) {
            for (key, value) in suite.dictionaryRepresentation() {
                guard key.hasPrefix("stats."),
                      let day = key.split(separator: ".").last.map(String.init),
                      day < today,
                      day > countedThrough,
                      let counters = value as? [String: Int]
                else { continue }
                lifetime += counters["wordsAccepted"] ?? 0
            }

            let closedDays = suite.dictionaryRepresentation().keys
                .compactMap { $0.hasPrefix("stats.") ? String($0.dropFirst(6)) : nil }
                .filter { $0 < today }
            if let newest = closedDays.max(), newest > countedThrough {
                defaults.set(lifetime, forKey: lifetimeKey)
                defaults.set(newest, forKey: countedKey)
            }
        }

        return lifetime + todayWordsAccepted()
    }
}
