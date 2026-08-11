import Testing
@testable import AutocompleteLabApp

@Suite("Aggregate-only usage stats")
struct TildeStatsTests {
    @Test("Lifetime sums every daily aggregate")
    func lifetimeSumsDailyCounters() {
        let values: [String: Any] = [
            "stats.2026-08-09": ["wordsAccepted": 2],
            "stats.2026-08-10": ["wordsAccepted": 3],
            "stats.2026-08-11": ["wordsAccepted": 5],
        ]

        #expect(TildeStats.sumWordsAccepted(in: values) == 10)
    }

    @Test("Late writes change lifetime without a checkpoint")
    func lateWritesRemainVisible() {
        var values: [String: Any] = [
            "stats.2026-08-09": ["wordsAccepted": 2],
            "stats.2026-08-11": ["wordsAccepted": 5],
        ]
        #expect(TildeStats.sumWordsAccepted(in: values) == 7)

        values["stats.2026-08-10"] = ["wordsAccepted": 3]
        #expect(TildeStats.sumWordsAccepted(in: values) == 10)
    }

    @Test("Unrelated defaults are ignored")
    func ignoresNonStatsValues() {
        let values: [String: Any] = [
            "stats.2026-08-11": ["wordsAccepted": 4],
            "stats.2026-08-10": "invalid",
            "GhostSuggestionsEnabled": false,
        ]

        #expect(TildeStats.sumWordsAccepted(in: values) == 4)
    }
}
