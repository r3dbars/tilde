import Foundation

/// The zero-protocol stats bridge: the keyboard flushes privacy-clean COUNTS
/// (never text) into its own defaults domain; this reader aggregates them for
/// the Tilde window and menu. Lifetime totals accumulate in the app's domain
/// and never reset — the odometer only goes up.
enum TildeStats {

    private static let imeDomain = "bar.r3d.inputmethod.InlineGhost"
    private static let lifetimeKey = "tilde.lifetimeWordsAccepted"
    private static let countedKey = "tilde.countedThroughDay"

    struct Today {
        let wordsAccepted: Int
        let wordsTyped: Int
        let activeSeconds: Int

        var shareOfTyping: Int {
            let total = wordsAccepted + wordsTyped
            return total > 0 ? Int((Double(wordsAccepted) / Double(total) * 100).rounded()) : 0
        }
        /// Effective pace: all words (typed + written for you) per active minute.
        var wordsPerMinute: Int {
            guard activeSeconds >= 30 else { return 0 }
            return Int((Double(wordsAccepted + wordsTyped) / (Double(activeSeconds) / 60)).rounded())
        }
        /// Your fingers alone: only self-typed words per active minute — the
        /// honest "without Tilde" counterfactual (you'd have typed the rest).
        var fingersPerMinute: Int {
            guard activeSeconds >= 30 else { return 0 }
            return Int((Double(wordsTyped) / (Double(activeSeconds) / 60)).rounded())
        }
    }

    private static func dayDict(_ key: String) -> [String: Int] {
        UserDefaults(suiteName: imeDomain)?.dictionary(forKey: "stats.\(key)") as? [String: Int] ?? [:]
    }

    private static var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func today() -> Today {
        let d = dayDict(todayKey)
        return Today(wordsAccepted: d["wordsAccepted"] ?? 0,
                     wordsTyped: d["wordsTyped"] ?? 0,
                     activeSeconds: d["activeSeconds"] ?? 0)
    }

    /// Lifetime = accumulated closed days + today's running count. Each past
    /// day is folded in exactly once (tracked by countedThroughDay).
    static func lifetimeWordsAccepted() -> Int {
        let defaults = UserDefaults.standard
        var lifetime = defaults.integer(forKey: lifetimeKey)
        let countedThrough = defaults.string(forKey: countedKey) ?? ""
        let todayK = todayKey
        if let suite = UserDefaults(suiteName: imeDomain) {
            for (key, value) in suite.dictionaryRepresentation() {
                guard key.hasPrefix("stats."), let day = key.split(separator: ".").last.map(String.init),
                      day < todayK, day > countedThrough,
                      let d = value as? [String: Int] else { continue }
                lifetime += d["wordsAccepted"] ?? 0
            }
            let closedDays = suite.dictionaryRepresentation().keys
                .compactMap { $0.hasPrefix("stats.") ? String($0.dropFirst(6)) : nil }
                .filter { $0 < todayK }
            if let newest = closedDays.max(), newest > countedThrough {
                defaults.set(lifetime, forKey: lifetimeKey)
                defaults.set(newest, forKey: countedKey)
            }
        }
        return lifetime + today().wordsAccepted
    }
}
