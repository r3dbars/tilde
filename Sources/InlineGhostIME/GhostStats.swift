import Foundation

/// Aggregate-only keyboard counters. Typed text and suggestion text are never persisted.
enum GhostStats {
    private static let persistenceQueue = DispatchQueue(label: "com.tilde.ghostStats", qos: .utility)
    private static var wordsAccepted = 0
    private static var wordsTyped = 0
    private static var activeSeconds = 0.0
    private static var lastKeystroke: Date?
    private static var lastFlush = Date.distantPast

    static func touchActive() {
        let now = Date()
        if let lastKeystroke {
            let gap = now.timeIntervalSince(lastKeystroke)
            if gap < 5 { activeSeconds += gap }
        }
        lastKeystroke = now
    }

    static func recordTypedWord() {
        wordsTyped += 1
        flush()
    }

    static func recordAccepted(_ text: String) {
        wordsAccepted += text.split(whereSeparator: \Character.isWhitespace).count
        flush()
    }

    static func flush(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastFlush) > 20 else { return }
        lastFlush = now
        let snapshot = [
            "wordsAccepted": wordsAccepted,
            "wordsTyped": wordsTyped,
            "activeSeconds": Int(activeSeconds),
        ]
        wordsAccepted = 0
        wordsTyped = 0
        activeSeconds = 0

        persistenceQueue.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = "stats." + formatter.string(from: now)
            let defaults = UserDefaults.standard
            var day = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
            for (metric, value) in snapshot { day[metric, default: 0] += value }
            defaults.set(day, forKey: key)
        }
    }
}
