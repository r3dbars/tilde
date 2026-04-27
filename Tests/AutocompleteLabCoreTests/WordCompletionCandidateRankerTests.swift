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
        #expect(ranker.suggestion(for: "This sh")?.visibleText == "ould")
        #expect(ranker.suggestion(for: "he")?.visibleText == "llo")
        #expect(ranker.suggestion(for: "It seems to be de")?.visibleText == "cent")
        #expect(ranker.suggestion(for: "I wa")?.visibleText == "nt")
        #expect(ranker.suggestion(for: "This should be su")?.visibleText == "per")
        #expect(ranker.suggestion(for: "hey tr")?.visibleText == "ying")
        #expect(ranker.suggestion(for: "It is worki")?.visibleText == "ng")
    }

    @Test("suppresses low value static suffixes")
    func suppressesLowValueStaticSuffixes() {
        let ranker = WordCompletionCandidateRanker()

        #expect(ranker.suggestion(for: "This is kin") == nil)
        #expect(ranker.suggestion(for: "I nee") == nil)
        #expect(ranker.suggestion(for: "Can you tes") == nil)
        #expect(ranker.suggestion(for: "why is it so slo") == nil)
        #expect(ranker.suggestion(for: "This should be super fas") == nil)
        #expect(ranker.suggestion(for: "Can you look") == nil)
        #expect(ranker.suggestion(for: "I see thi") == nil)
    }

    @Test("allows one letter recent suffixes for long fragments")
    func allowsOneLetterRecentSuffixesForLongFragments() {
        let ranker = WordCompletionCandidateRanker(staticWords: [])

        #expect(ranker.suggestion(for: "That was fantasti", recentWords: ["fantastic"])?.visibleText == "c")
        #expect(ranker.suggestion(for: "This should be super fas", recentWords: ["fast"]) == nil)
    }

    @Test("uses newest recent words before older learned words")
    func usesNewestRecentWordsFirst() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["document"])

        let suggestion = ranker.suggestion(for: "Open doc", recentWords: ["documentary", "documentation"])

        #expect(suggestion?.visibleText == "umentation")
    }

    @Test("does not suggest phrases or completed words")
    func skipsInvalidFragments() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["dictation"])

        #expect(ranker.suggestion(for: "I use dictation") == nil)
        #expect(ranker.suggestion(for: "I use d") == nil)
        #expect(ranker.suggestion(for: "I use dic ") == nil)
    }
}
