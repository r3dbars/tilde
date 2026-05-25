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
        let smokeSelection = predictor.selection(
            for: "Autocomplete Lab Obsidian proof\nSmoke proof feels",
            behaviorProfileID: .docsProse
        )
        let secondSmokeSelection = predictor.selection(
            for: "Smoke proof feels instant and stays",
            behaviorProfileID: .docsProse
        )

        #expect(selection.suggestion?.visibleText == " follow up")
        #expect(selection.matchedContextSuffix == "i just wanted to")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
        #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        #expect(proofSelection.suggestion?.visibleText == " ready")
        #expect(proofSelection.matchedContextSuffix == "the draft is almost")
        #expect(smokeSelection.suggestion?.visibleText == " instant")
        #expect(smokeSelection.matchedContextSuffix == "smoke proof feels")
        #expect(secondSmokeSelection.suggestion?.visibleText == " instant")
        #expect(secondSmokeSelection.matchedContextSuffix == "and stays")
    }

    @Test("Predicts daily-driver writing phrases instantly")
    func predictsDailyDriverWritingPhrasesInstantly() {
        let cases: [(String, String, String)] = [
            ("Obsidian scratchpad: In Obsidian, this note should capture", " the key details clearly", "in obsidian this note should capture"),
            ("While I am typing fast, it should", " stay short and clear", "while i am typing fast it should"),
            ("The suggestion should be less timid and", " more confident about next words", "the suggestion should be less timid and"),
            ("The next suggestion should be a", " short useful phrase", "the next suggestion should be a"),
            ("The action item needs an", " owner and deadline", "the action item needs an")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount ?? 0 >= 3)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Predicts daily-driver audit phrases through punctuation and lists")
    func predictsDailyDriverAuditPhrasesThroughPunctuationAndLists() {
        let cases: [(String, String, String)] = [
            ("I want this note to feel", " light and clear", "i want this note to feel"),
            ("The draft feels calmer when it", " stays short and specific", "the draft feels calmer when it"),
            ("The review should focus on", " real user risk", "the review should focus on"),
            ("A good reply here would be", " short kind and specific", "a good reply here would be"),
            ("Before we ship, we should", " run one small check", "before we ship we should"),
            ("The local test should fail only when", " proof is missing", "the local test should fail only when"),
            ("Project notes\nKeep the app small\nMake the copy", " short and clear", "make the copy"),
            ("Decision log\nHold the risky path until", " proof exists", "hold the risky path until"),
            ("Launch checklist\nBuild the app\nRun the proof\nWrite the", " small repro", "build the app run the proof write the"),
            ("I am trying to say this in a way that feels", " natural and human", "i am trying to say this in a way that feels"),
            ("What I want is", " something fast and reliable", "what i want is"),
            ("If this works tomorrow, I will", " leave it turned on", "if this works tomorrow i will")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount ?? 0 >= 2)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Predicts daily-driver complaint phrases instantly")
    func predictsDailyDriverComplaintPhrasesInstantly() {
        let cases: [(String, String, String)] = [
            ("I want this to", " finish the sentence naturally", "i want this to"),
            ("The biggest problem is", " suggestions feel too timid", "the biggest problem is"),
            ("What kills trust most is", " wrong fields showing up", "what kills trust most is"),
            ("It should almost always", " show up while writing", "it should almost always"),
            ("This needs to feel", " fast enough to trust", "this needs to feel"),
            ("When I hit Tab it should", " accept exactly the next word", "when i hit tab it should"),
            ("The best daily driver shape is", " short phrase autocomplete", "the best daily driver shape is")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount ?? 0 >= 3)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
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
