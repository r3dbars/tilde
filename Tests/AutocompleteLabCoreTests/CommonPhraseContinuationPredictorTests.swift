import Testing
@testable import AutocompleteLabCore

@Suite("Common phrase continuation predictor")
struct CommonPhraseContinuationPredictorTests {
    private let predictor = CommonPhraseContinuationPredictor()

    @Test("Predicts common next phrases from anchored writing context")
    func predictsCommonNextPhrases() {
        let selection = predictor.selection(
            for: "Quick note: I just wanted to",
            behaviorProfileID: .docsProse
        )
        let proofSelection = predictor.selection(
            for: "Smoke proof feels instant and the draft is almost",
            behaviorProfileID: .docsProse
        )

        #expect(selection.suggestion?.visibleText == " follow up")
        #expect(selection.matchedContextSuffix == "i just wanted to")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
        #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        #expect(proofSelection.suggestion?.visibleText == " ready")
        #expect(proofSelection.matchedContextSuffix == "the draft is almost")
    }

    @Test("Allows Notes and casual writing but blocks prompt, search, form, and code profiles")
    func blocksUnsafeProfiles() {
        #expect(predictor.suggestion(
            for: "Note: the app should",
            behaviorProfileID: .notes
        )?.visibleText == " stay quiet")

        #expect(predictor.selection(
            for: "Prompt: the app should",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "Search: the app should",
            behaviorProfileID: .search
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "Form: the app should",
            behaviorProfileID: .forms
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "let app should",
            behaviorProfileID: .coding
        ).suppressionReason == "unsupported-profile")
    }

    @Test("Stays silent without a full-word phrase anchor")
    func staysSilentWithoutAnchor() {
        #expect(predictor.selection(
            for: "I just wanted t",
            behaviorProfileID: .docsProse
        ).suppressionReason == "no-match")
        #expect(predictor.selection(
            for: "I just wanted to,",
            behaviorProfileID: .docsProse
        ).suppressionReason == "not-word-boundary")
    }

    @Test("Clamps phrase suggestions to the requested visible word count")
    func clampsVisibleWordCount() {
        let selection = predictor.selection(
            for: "This sentence should continue",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 2
        )

        #expect(selection.suggestion?.visibleText == " without sounding")
    }

    @Test("Allows longer fallback phrases when the word slider is high")
    func allowsLongerFallbackPhrasesWhenWordSliderIsHigh() {
        let predictor = CommonPhraseContinuationPredictor(priors: [
            CommonPhraseContinuationPrior(
                contextSuffix: "this should",
                continuation: "show five six seven eight nine words",
                score: 1
            )
        ])
        let selection = predictor.selection(
            for: "this should",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 7
        )

        #expect(selection.suggestion?.visibleText == " show five six seven eight nine words")
        #expect(selection.suggestion?.visibleWordCount == 7)
    }
}
