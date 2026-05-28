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

    @Test("Predicts Claude Code proof setting phrase instantly")
    func predictsClaudeCodeProofSettingPhraseInstantly() {
        let selection = predictor.selection(
            for: "Make this setting the feature",
            behaviorProfileID: .aiChat,
            maxVisibleWords: 4,
            allowsPromptAppPrediction: true
        )

        #expect(selection.suggestion?.visibleText == " configurable")
        #expect(selection.matchedContextSuffix == "make this setting the feature")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
        #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
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

    @Test("Predicts finish-my-thought writing phrases instantly")
    func predictsFinishMyThoughtWritingPhrasesInstantly() {
        let cases: [(String, String, String)] = [
            ("I think what matters is", " that it feels effortless", "i think what matters is"),
            ("What I am trying to say is", " this should feel natural", "what i am trying to say is"),
            ("The next thing I want to", " write is the thought", "the next thing i want to"),
            ("This would be better if it", " predicted the next phrase", "this would be better if it"),
            ("The way I would say it is", " keep it very simple", "the way i would say it is"),
            ("What makes this useful is", " getting the words right", "what makes this useful is"),
            ("When this feels magical it", " knows the next phrase", "when this feels magical it"),
            ("If I am writing fast I", " want help finishing thoughts", "if i am writing fast i")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount == 4)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Predicts first-person daily-driver trust and feeling shapes")
    func predictsFirstPersonDailyDriverTrustAndFeelingShapes() {
        let cases: [(String, String, String)] = [
            ("This app feels wrong", " when placement breaks trust", "intent-daily-driver-feels-wrong"),
            ("The suggestions fall short", " when suggestions feel generic", "intent-daily-driver-falls-short"),
            ("SteadyType is not quite there", " because trust still breaks", "intent-daily-driver-not-there-yet"),
            ("I would use this every day", " if it predicts my next thought", "intent-daily-driver-use-every-day"),
            ("What would make me use this", " is trusting the next phrase", "intent-daily-driver-make-me-use-this"),
            ("I keep reaching for it when", " it predicts my next thought", "intent-daily-driver-reach-for-it-when"),
            ("As a daily driver", " it has to feel effortless", "intent-daily-driver-as-daily-driver"),
            ("The typing flow feels heavy", " enough to break flow", "intent-daily-driver-feels-slow")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount ?? 0 >= 4)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Predicts reusable writing intent patterns instantly")
    func predictsReusableWritingIntentPatternsInstantly() {
        let cases: [(String, String, String)] = [
            ("Quick thought: what I mean is", " this should feel natural", "intent-what-i-mean-is"),
            ("My point is", " this should feel clear", "intent-point-is"),
            ("The app would be better if it", " predicted the next phrase", "intent-better-if-it"),
            ("For tomorrow, we need to", " make this feel simpler", "intent-we-need-to"),
            ("I need to", " say this more clearly", "intent-i-need-to"),
            ("Next step is", " to make this concrete", "intent-next-step-is"),
            ("The goal is", " to make writing faster", "intent-the-goal-is"),
            ("Can you", " take a look at", "intent-can-you")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount == 4)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }
    }

    @Test("Predicts daily-driver connector thoughts instantly")
    func predictsDailyDriverConnectorThoughtsInstantly() {
        let cases: [(String, String, String)] = [
            ("I want SteadyType because", " it saves real time", "intent-daily-driver-because"),
            ("This typing app needs to work so that", " writing keeps moving forward", "intent-daily-driver-so-that"),
            ("The suggestion shows up late which means", " it loses trust quickly", "intent-daily-driver-which-means-trust"),
            ("For SteadyType, the reason is", " it feels genuinely useful", "intent-daily-driver-reason-is"),
            ("The autocomplete fix is", " to make it predictable", "intent-daily-driver-fix-is"),
            ("For phrase suggestions, we should prove", " it works while writing", "intent-daily-driver-prove")
        ]

        for (context, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: .docsProse,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount == 4)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }

        #expect(predictor.selection(
            for: "Can you submit because",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
    }

    @Test("Predicts Obsidian markdown note labels instantly")
    func predictsObsidianMarkdownNoteLabelsInstantly() {
        let cases: [(String, AutocompleteBehaviorProfileID, String, String)] = [
            ("## Next:", .docsProse, " write the smallest concrete action", "intent-markdown-next"),
            ("- [ ] TODO:", .bullets, " make the next step concrete", "intent-markdown-action-items"),
            ("1. [ ] TODO:", .bullets, " make the next step concrete", "intent-markdown-action-items"),
            ("# Open questions:", .docsProse, " capture what still feels unclear", "intent-markdown-open-questions"),
            ("Meeting notes\nDecisions:", .docsProse, " capture what changed today", "intent-markdown-decisions"),
            ("Daily note\n## Focus", .docsProse, " the next useful writing pass", "intent-markdown-focus"),
            ("Daily note\nToday:", .notes, " focus on the highest leverage fix", "intent-markdown-daily-note"),
            ("Project notes\n- Waiting on", .bullets, " the response before moving forward", "intent-markdown-waiting-on"),
            ("Project notes\n- Blocked:", .bullets, " by the missing proof", "intent-markdown-blocked"),
            ("Launch notes\nRisks", .docsProse, " the part that could break trust", "intent-markdown-risks"),
            ("Daily note\nDone:", .docsProse, " capture what actually shipped today", "intent-markdown-done"),
            ("Scratchpad\nIdea", .notes, " turn this into a small test", "intent-markdown-ideas"),
            ("Reflection\nNote to self:", .docsProse, " keep the next step visible", "intent-markdown-note-to-self"),
            ("What matters today", .notes, " is the next clear step", "intent-markdown-what-matters-today"),
            ("Quick capture\nBefore I forget", .docsProse, " capture the important detail", "intent-markdown-before-i-forget"),
            ("- Follow up on", .bullets, " the open thread today", "intent-markdown-follow-up-on")
        ]

        for (context, profile, expected, match) in cases {
            let selection = predictor.selection(
                for: context,
                behaviorProfileID: profile,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion?.visibleText == expected)
            #expect(selection.suggestion?.visibleWordCount ?? 0 >= 4)
            #expect(selection.matchedContextSuffix == match)
            #expect(selection.traceMetadata["candidateSelectionSource"] == "predictive-phrase-fallback")
            #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
        }

        #expect(predictor.selection(
            for: "Prompt\nNext:",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "Email\nNext:",
            behaviorProfileID: .email
        ).suppressionReason == "not-word-boundary")
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
        #expect(predictor.selection(
            for: "Can you",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "This app feels wrong",
            behaviorProfileID: .aiChat
        ).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(
            for: "The suggestions fall short",
            behaviorProfileID: .search
        ).suppressionReason == "unsupported-profile")
    }

    @Test("Allows explicit prompt-app proof prediction while keeping prompt apps blocked by default")
    func allowsExplicitPromptAppProofPrediction() {
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
        #expect(predictor.selection(
            for: "Would be better if it",
            behaviorProfileID: .docsProse
        ).suppressionReason == "no-match")
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
