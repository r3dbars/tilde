import Testing
@testable import AutocompleteLabCore

@Suite("Word completion candidate ranker")
struct WordCompletionCandidateRankerTests {
    @Test("returns suffix only for a known word")
    func returnsSuffixOnly() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["dictation"])

        let suggestion = ranker.suggestion(for: "I use dic")

        #expect(suggestion?.visibleText == "tation")
    }

    @Test("uses recent words before static words")
    func usesRecentWords() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["document"])

        let suggestion = ranker.suggestion(for: "Open doc", recentWords: ["documentary"])

        #expect(suggestion?.visibleText == "umentary")
    }

    @Test("common fragments complete without waiting for the model")
    func commonFragmentsComplete() {
        let ranker = WordCompletionCandidateRanker()

        #expect(ranker.suggestion(for: "Hey wh")?.visibleText == "at")
        #expect(ranker.suggestion(for: "Can we ma")?.visibleText == "ke")
        #expect(ranker.suggestion(for: "I see thi")?.visibleText == "s")
        #expect(ranker.suggestion(for: "It is worki")?.visibleText == "ng")
    }

    @Test("does not suggest phrases or completed words")
    func skipsInvalidFragments() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["dictation"])

        #expect(ranker.suggestion(for: "I use dictation") == nil)
        #expect(ranker.suggestion(for: "I use d") == nil)
        #expect(ranker.suggestion(for: "I use dic ") == nil)
    }
}
