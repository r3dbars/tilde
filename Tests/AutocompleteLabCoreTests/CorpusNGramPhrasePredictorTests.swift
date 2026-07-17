import Testing
@testable import AutocompleteLabCore

@Suite("Corpus n-gram phrase predictor")
struct CorpusNGramPhrasePredictorTests {
    @Test("Provides a broader always-on phrase floor")
    func predictsCommonCorpusPhrase() {
        let selection = CorpusNGramPhrasePredictor().selection(
            for: "Please let me know",
            behaviorProfileID: .email
        )

        #expect(selection.suggestion?.visibleText == " if that works")
        #expect(CorpusNGramPhrasePredictor.defaultPriors.count > 18)
    }

    @Test("Keeps unsafe behavior profiles closed")
    func blocksForms() {
        let selection = CorpusNGramPhrasePredictor().selection(
            for: "Please let me know",
            behaviorProfileID: .forms
        )

        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == "unsupported-profile")
    }
}
