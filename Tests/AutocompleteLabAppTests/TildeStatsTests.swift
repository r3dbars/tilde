import Testing
@testable import AutocompleteLabApp

@Suite("Tilde stats")
struct TildeStatsTests {
    @Test("Accepted share uses accepted and typed words")
    func acceptedShare() {
        let today = TildeStats.Today(wordsAccepted: 25, wordsTyped: 75, activeSeconds: 60)
        #expect(today.shareOfTyping == 25)
    }

    @Test("Writing pace includes typed and accepted words")
    func assistedWritingPace() {
        let today = TildeStats.Today(wordsAccepted: 20, wordsTyped: 40, activeSeconds: 60)
        #expect(today.wordsPerMinute == 60)
    }

    @Test("Writing pace waits for a meaningful activity window")
    func shortActivityWindow() {
        let today = TildeStats.Today(wordsAccepted: 20, wordsTyped: 40, activeSeconds: 29)
        #expect(today.wordsPerMinute == 0)
    }
}
