import Foundation
import Testing
@testable import InlineGhostIME

@Suite("IME usage stats", .serialized)
struct GhostStatsTests {
    @Test("Forced flush persists queued aggregate before returning")
    func forcedFlushIsSynchronous() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "stats." + formatter.string(from: Date())
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer { defaults.set(original, forKey: key) }

        let before = (defaults.dictionary(forKey: key) as? [String: Int])?["wordsAccepted"] ?? 0
        GhostStats.recordAccepted("two words")
        GhostStats.flush(force: true)
        let after = (defaults.dictionary(forKey: key) as? [String: Int])?["wordsAccepted"] ?? 0

        #expect(after == before + 2)
    }
}
