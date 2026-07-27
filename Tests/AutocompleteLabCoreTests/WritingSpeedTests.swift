import Testing
@testable import AutocompleteLabCore

@Suite struct WritingSpeedTests {

    @Test func rawWordsPerMinute() {
        // 60 words over 60s of active typing = 60 wpm.
        #expect(WritingSpeed.wordsPerMinute(words: 60, activeTypingMilliseconds: 60_000) == 60)
        // 34 words over 30s = 68 wpm.
        #expect(WritingSpeed.wordsPerMinute(words: 34, activeTypingMilliseconds: 30_000) == 68)
    }

    @Test func tooLittleActivityShowsNothing() {
        #expect(WritingSpeed.wordsPerMinute(words: 100, activeTypingMilliseconds: 29_999) == nil)
        #expect(WritingSpeed.wordsPerMinute(words: 0, activeTypingMilliseconds: 120_000) == nil)
    }

    @Test func speedupIsWholePercentAndOnlyClaimsRealGains() {
        #expect(WritingSpeed.speedupPercent(raw: 68, assisted: 84) == 24)
        #expect(WritingSpeed.speedupPercent(raw: 68, assisted: 68) == nil)
        #expect(WritingSpeed.speedupPercent(raw: 68, assisted: 60) == nil)
        #expect(WritingSpeed.speedupPercent(raw: 0, assisted: 10) == nil)
    }

    @Test func hoursSavedFromOwnMeasuredRate() {
        // Writer types 3,000 chars in 10 min active -> 5 chars/s. 9,000 ghost
        // chars at that rate = 1,800s = 0.5h.
        let hours = WritingSpeed.hoursSaved(
            charactersAccepted: 9_000,
            typedCharacters: 3_000,
            activeTypingMilliseconds: 600_000
        )
        #expect(hours == 0.5)
        #expect(WritingSpeed.hoursSaved(charactersAccepted: 0, typedCharacters: 3_000, activeTypingMilliseconds: 600_000) == nil)
        #expect(WritingSpeed.hoursSaved(charactersAccepted: 9_000, typedCharacters: 0, activeTypingMilliseconds: 600_000) == nil)
    }
}
