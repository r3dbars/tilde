import Testing
@testable import AutocompleteLabCore

@Suite("Common phrase continuation predictor")
struct CommonPhraseContinuationPredictorTests {
    private let predictor = CommonPhraseContinuationPredictor()

    @Test("Predicts only short generic bridge phrases")
    func predictsShortGenericBridgePhrases() {
        let cases: [(String, AutocompleteBehaviorProfileID, String, String)] = [
            ("Quick note: I just wanted to", .docsProse, " follow up", "i just wanted to"),
            ("Reply draft\nCan you please", .email, " take a look", "can you please"),
            ("Thread\nSounds good", .casualChat, " to me", "sounds good"),
            ("Daily note\nWhat I need is", .notes, " a clearer next step", "what i need is"),
            ("Planning\nNext step is", .docsProse, " to make this concrete", "next step is")
        ]

        for (context, profile, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: profile,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "canned-bridge")
            #expect(selection.traceMetadata["cannedBridgeMatch"] == match)
            #expect(selection.traceMetadata["predictivePhraseMatch"] == nil)
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Rejects removed demo proof and product complaint phrases")
    func rejectsRemovedDemoAndComplaintPhrases() {
        for context in [
            "Autocomplete Lab Obsidian proof\nSmoke proof feels",
            "The best daily driver shape is",
            "What kills trust most is",
            "This breaks trust when",
            "In Obsidian this note should capture",
            "When I hit Tab it should"
        ] {
            #expect(predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            ).suppressionReason == "no-match")
        }
    }

    @Test("Allows notes and replies while blocking unsafe profiles")
    func blocksUnsafeProfiles() {
        #expect(predictor.suggestion(
            for: "Note: we should keep this",
            behaviorProfileID: .notes
        )?.visibleText == " small")

        #expect(predictor.selection(
            for: "Prompt: we should keep this",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "Search: we should keep this",
            behaviorProfileID: .search
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "Form: we should keep this",
            behaviorProfileID: .forms
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "let we should keep this",
            behaviorProfileID: .coding
        ).suppressionReason == "unsupported-profile")
    }

    @Test("Allows explicit prompt-app proof prediction while keeping prompt apps blocked by default")
    func allowsExplicitPromptAppPrediction() {
        let blocked = predictor.selection(
            for: "Please make this",
            behaviorProfileID: .aiChat,
            maxVisibleWords: 4
        )
        let allowed = predictor.selection(
            for: "Please make this",
            behaviorProfileID: .aiChat,
            maxVisibleWords: 4,
            allowsPromptAppPrediction: true
        )

        #expect(blocked.suppressionReason == "unsupported-profile")
        #expect(allowed.suggestion?.visibleText == " clearer")
        #expect(allowed.matchedContextSuffix == "please make this")
    }

    @Test("Stays silent without a full-word bridge anchor")
    func staysSilentWithoutAnchor() {
        #expect(predictor.selection(
            for: "",
            behaviorProfileID: .docsProse
        ).suppressionReason == "empty-context")
        #expect(predictor.selection(
            for: "I just wanted t",
            behaviorProfileID: .docsProse
        ).suppressionReason == "no-match")
        #expect(predictor.selection(
            for: "I just wanted to,",
            behaviorProfileID: .docsProse
        ).suppressionReason == "not-word-boundary")
        #expect(predictor.selection(
            for: "Would be better if it",
            behaviorProfileID: .docsProse
        ).suppressionReason == "no-match")
    }

    @Test("Normalizes punctuation and chooses the longest matching bridge")
    func normalizesPunctuationAndChoosesLongestMatch() {
        let predictor = CommonPhraseContinuationPredictor(priors: [
            CommonPhraseContinuationPrior(contextSuffix: "make this", continuation: "clearer", score: 0.9),
            CommonPhraseContinuationPrior(contextSuffix: "please make this", continuation: "short and clear", score: 0.1)
        ])
        let selection = predictor.selection(
            for: "Reply: please, make this",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " short and clear")
        #expect(selection.matchedContextSuffix == "please make this")
    }

    @Test("Clamps bridge suggestions to the requested visible word count")
    func clampsVisibleWordCount() {
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
