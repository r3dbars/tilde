import Testing
@testable import AutocompleteLabCore

@Suite("Doc-local n-gram phrase predictor")
struct DocLocalNGramPhrasePredictorTests {
    private let predictor = DocLocalNGramPhrasePredictor()

    @Test("Predicts repeated local document continuations without canned priors")
    func predictsRepeatedLocalDocumentContinuations() {
        let selection = predictor.selection(
            for: """
            Launch note
            The onboarding screen should make permission feel clear before setup

            Draft
            The onboarding screen should make
            """,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " permission feel clear before setup")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "doc-local-ngram")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-5-before-cursor")
        #expect(selection.traceMetadata["predictivePhraseMatch"] == nil)
    }

    @Test("Uses explicitly supplied local context when the active line is not repeated in the field")
    func usesExplicitLocalContext() {
        let selection = predictor.selection(
            for: "The migration note should",
            localContextTexts: ["The migration note should explain the fallback plan clearly"],
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " explain the fallback plan clearly")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "doc-local-ngram")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-4-local-context")
    }

    @Test("Stays inside local in-memory text and does not emit raw match text in metadata")
    func keepsTraceMetadataRedacted() {
        let selection = predictor.selection(
            for: """
            Private Alpha Project should keep launch details local only

            Private Alpha Project should
            """,
            behaviorProfileID: .notes,
            maxVisibleWords: 8
        )
        let metadataText = selection.traceMetadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")

        #expect(selection.suggestion?.visibleText == " keep launch details local only")
        #expect(!metadataText.localizedCaseInsensitiveContains("Private Alpha"))
        #expect(!metadataText.localizedCaseInsensitiveContains("launch details"))
        #expect(metadataText.contains("docLocalNGramMatch=order-4-before-cursor"))
    }

    @Test("Blocks prompt search form code and email profiles by default")
    func blocksUnsupportedProfiles() {
        for profile in [
            AutocompleteBehaviorProfileID.aiChat,
            .search,
            .forms,
            .coding,
            .email,
            .casualChat
        ] {
            let selection = predictor.selection(
                for: """
                The local context should produce a useful continuation
                The local context should
                """,
                behaviorProfileID: profile,
                maxVisibleWords: 8
            )

            #expect(selection.suggestion == nil)
            #expect(selection.suppressionReason == "unsupported-profile")
        }
    }

    @Test("Handles punctuation list and heading contexts")
    func handlesPunctuationListsAndHeadings() {
        let punctuation = predictor.selection(
            for: """
            Before we ship, we should run the focused local proof

            Before we ship we should
            """,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )
        let list = predictor.selection(
            for: """
            - [ ] The release note needs one clear owner
            - [ ] The release note needs
            """,
            behaviorProfileID: .bullets,
            maxVisibleWords: 8
        )
        let heading = predictor.selection(
            for: """
            ## Risk review
            The fragile placement path needs proof before rollout

            ## Risk review
            The fragile placement path needs
            """,
            behaviorProfileID: .notes,
            maxVisibleWords: 8
        )

        #expect(punctuation.suggestion?.visibleText == " run the focused local proof")
        #expect(list.suggestion?.visibleText == " one clear owner")
        #expect(heading.suggestion?.visibleText == " proof before rollout")
    }

    @Test("Requires a real previous local match")
    func requiresPreviousLocalMatch() {
        let selection = predictor.selection(
            for: "This new line has no earlier continuation",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == "no-local-match")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "doc-local-ngram")
    }
}
