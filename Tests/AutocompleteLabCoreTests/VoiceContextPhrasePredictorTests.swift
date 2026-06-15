import Testing
@testable import AutocompleteLabCore

/// Spike coverage for the dictation + inline prediction loop
/// (docs/product/spikes/voice-text-loop.md). Proves a phrase that only ever
/// appeared in the recent *spoken* corpus can surface as a typed suggestion,
/// while staying opt-in, redacted, and behind the normal gates.
@Suite("Voice context phrase predictor")
struct VoiceContextPhrasePredictorTests {
    private let spokenAboutLatency = "Let's circle back on the latency budget before the beta cutoff"

    // MARK: - The core proof

    @Test("A phrase only present in the spoken corpus can surface as a prediction")
    func spokenOnlyPhraseSurfaces() {
        let predictor = VoiceContextPhrasePredictor(
            policy: RecentSpokenContextPolicy(isEnabled: true),
            provider: InMemorySpokenTranscriptProvider(entries: [spokenAboutLatency])
        )

        let selection = predictor.selection(
            for: "I think we should circle back on the",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " latency budget before the beta cutoff")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "doc-local-ngram")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-4-spoken-transcript")
    }

    @Test("The doc-local predictor reads the spoken corpus directly through its seam")
    func docLocalPredictorReadsSpokenCorpusParameter() {
        let predictor = DocLocalNGramPhrasePredictor()

        let selection = predictor.selection(
            for: "I think we should circle back on the",
            spokenContextTexts: [spokenAboutLatency],
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " latency budget before the beta cutoff")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-4-spoken-transcript")
    }

    @Test("A local fixture transcript surfaces a spoken-only continuation end to end")
    func fixtureTranscriptSurfacesPrediction() {
        let fixtureText = """
        # local fixture — no real audio
        \(spokenAboutLatency)
        """
        let predictor = VoiceContextPhrasePredictor(
            policy: RecentSpokenContextPolicy(isEnabled: true),
            provider: SpokenTranscriptFixture.provider(fromFixtureText: fixtureText)
        )

        let selection = predictor.selection(
            for: "I think we should circle back on the",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " latency budget before the beta cutoff")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-4-spoken-transcript")
    }

    // MARK: - Opt-in / privacy posture

    @Test("Disabled policy keeps the spoken corpus off and changes nothing")
    func disabledPolicyIgnoresSpokenCorpus() {
        let predictor = VoiceContextPhrasePredictor(
            policy: .disabled,
            provider: InMemorySpokenTranscriptProvider(entries: [spokenAboutLatency])
        )

        let selection = predictor.selection(
            for: "I think we should circle back on the",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == "no-local-match")
    }

    @Test("Spoken corpus never appears as raw text in trace metadata")
    func spokenCorpusStaysOutOfTraceMetadata() {
        let predictor = VoiceContextPhrasePredictor(
            policy: RecentSpokenContextPolicy(isEnabled: true),
            provider: InMemorySpokenTranscriptProvider(entries: [
                "Remember the Falcon launch budget stays private to this Mac"
            ])
        )

        let selection = predictor.selection(
            for: "Please keep the Falcon launch",
            behaviorProfileID: .notes,
            maxVisibleWords: 8
        )
        let metadataText = selection.traceMetadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")

        #expect(selection.suggestion?.visibleText == " budget stays private to this Mac")
        #expect(metadataText.contains("docLocalNGramMatch=order-3-spoken-transcript"))
        #expect(!metadataText.localizedCaseInsensitiveContains("Falcon"))
        #expect(!metadataText.localizedCaseInsensitiveContains("budget"))
    }

    @Test("Spoken corpus still obeys behavior-profile gating")
    func spokenCorpusObeysProfileGating() {
        let predictor = VoiceContextPhrasePredictor(
            policy: RecentSpokenContextPolicy(isEnabled: true),
            provider: InMemorySpokenTranscriptProvider(entries: [spokenAboutLatency])
        )

        let selection = predictor.selection(
            for: "I think we should circle back on the",
            behaviorProfileID: .search,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion == nil)
        #expect(selection.suppressionReason == "unsupported-profile")
    }

    // MARK: - Ranking

    @Test("Typed context outranks the spoken corpus on an equal-length match")
    func typedContextOutranksSpokenCorpus() {
        let predictor = VoiceContextPhrasePredictor(
            policy: RecentSpokenContextPolicy(isEnabled: true),
            provider: InMemorySpokenTranscriptProvider(entries: [
                "ship the beta and grab coffee afterwards"
            ])
        )

        let selection = predictor.selection(
            for: """
            Ship the beta to the early testers first

            Ship the beta
            """,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8
        )

        #expect(selection.suggestion?.visibleText == " to the early testers first")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-3-before-cursor")
    }

    // MARK: - Policy + fixture bounds

    @Test("Spoken context policy keeps only the most recent entries")
    func policyKeepsRecentEntries() {
        let provider = InMemorySpokenTranscriptProvider(entries: [
            "one two three", "four five six", "seven eight nine", "ten eleven twelve"
        ])
        let policy = RecentSpokenContextPolicy(isEnabled: true, maxEntries: 2)

        #expect(policy.contextTexts(from: provider) == ["seven eight nine", "ten eleven twelve"])
    }

    @Test("Spoken context policy is off by default and when there is no provider")
    func policyOffByDefault() {
        let provider = InMemorySpokenTranscriptProvider(entries: ["anything at all here"])

        #expect(RecentSpokenContextPolicy().contextTexts(from: provider) == [])
        #expect(RecentSpokenContextPolicy.disabled.contextTexts(from: provider) == [])
        #expect(RecentSpokenContextPolicy(isEnabled: true).contextTexts(from: nil) == [])
    }

    @Test("Spoken context policy caps very long entries from the tail")
    func policyCapsLongEntries() {
        let long = String(repeating: "a", count: 50) + " tail words here"
        let provider = InMemorySpokenTranscriptProvider(entries: [long])

        let texts = RecentSpokenContextPolicy(isEnabled: true, maxCharactersPerEntry: 10)
            .contextTexts(from: provider)

        #expect(texts == ["words here"])
    }

    @Test("Fixture parser ignores blank lines and comments")
    func fixtureParserIgnoresCommentsAndBlanks() {
        let fixtureText = """
        # voice-text-loop sample — local only
        Let's circle back on the latency budget

        # another comment
        The onboarding flow should feel calm
        """

        let entries = SpokenTranscriptFixture.entries(fromFixtureText: fixtureText)

        #expect(entries == [
            "Let's circle back on the latency budget",
            "The onboarding flow should feel calm"
        ])
        #expect(SpokenTranscriptFixture.provider(fromFixtureText: fixtureText).entries == entries)
    }
}
