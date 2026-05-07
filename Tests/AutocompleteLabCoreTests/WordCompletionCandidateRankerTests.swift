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

    @Test("Suppresses ambiguous two-letter static fragments unless recent")
    func suppressesAmbiguousTwoLetterStaticFragmentsUnlessRecent() {
        let ranker = WordCompletionCandidateRanker(staticWords: ["there", "their", "thing"])

        #expect(ranker.suggestion(for: "I saw th") == nil)
        #expect(ranker.suggestion(for: "I saw th", recentWords: ["therefore"])?.visibleText == "erefore")
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
        #expect(ranker.suggestion(for: "hey tr")?.visibleText == "ying")
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
        #expect(ranker.suggestion(for: "It is worki") == nil)
    }

    @Test("default words avoid lab and app vocabulary")
    func defaultWordsAvoidLabAndAppVocabulary() {
        let ranker = WordCompletionCandidateRanker()

        #expect(ranker.suggestion(for: "Try auto") == nil)
        #expect(ranker.suggestion(for: "Open code") == nil)
        #expect(ranker.suggestion(for: "Check diag") == nil)
        #expect(ranker.suggestion(for: "Review trac") == nil)
        #expect(ranker.suggestion(for: "Use trans") == nil)
    }

    @Test("default words avoid overly enthusiastic vocabulary")
    func defaultWordsAvoidOverlyEnthusiasticVocabulary() {
        let ranker = WordCompletionCandidateRanker()

        #expect(ranker.suggestion(for: "That was fant") == nil)
        #expect(ranker.suggestion(for: "This is gr") == nil)
        #expect(ranker.suggestion(for: "That sounds su") == nil)
    }

    @Test("suppresses tiny recent suffixes until the fragment is strong")
    func suppressesTinyRecentSuffixesUntilFragmentIsStrong() {
        let ranker = WordCompletionCandidateRanker(staticWords: [])

        #expect(ranker.suggestion(for: "th", recentWords: ["this"]) == nil)
        #expect(ranker.suggestion(for: "It is worki", recentWords: ["working"]) == nil)
        #expect(ranker.suggestion(for: "It is workin", recentWords: ["working"])?.visibleText == "g")
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
