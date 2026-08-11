import Foundation

/// Aggregate-only keyboard counters. Typed text and suggestion text are never persisted.
enum GhostStats {
    private static let persistenceQueue = DispatchQueue(label: "com.tilde.ghostStats", qos: .utility)
    private static var wordsAccepted = 0
    private static var lastFlush = Date.distantPast

    static func recordAccepted(_ text: String) {
        let count = text.split(whereSeparator: \Character.isWhitespace).count
        guard count > 0 else { return }
        let now = Date()
        persistenceQueue.async {
            wordsAccepted += count
            persist(now: now, force: false)
        }
    }

    static func flush(force: Bool = false) {
        let now = Date()
        if force {
            persistenceQueue.sync { persist(now: now, force: true) }
        } else {
            persistenceQueue.async { persist(now: now, force: false) }
        }
    }

    private static func persist(now: Date, force: Bool) {
        guard force || now.timeIntervalSince(lastFlush) > 20 else { return }
        lastFlush = now
        let accepted = wordsAccepted
        wordsAccepted = 0
        guard accepted > 0 else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "stats." + formatter.string(from: now)
        let defaults = UserDefaults.standard
        var day = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        day["wordsAccepted", default: 0] += accepted
        defaults.set(day, forKey: key)
    }
}
