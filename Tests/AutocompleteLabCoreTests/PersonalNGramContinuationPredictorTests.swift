import Testing
@testable import AutocompleteLabCore

@Suite("Personal n-gram continuation predictor")
struct PersonalNGramContinuationPredictorTests {
    private let predictor = PersonalNGramContinuationPredictor()

    @Test("Uses highest matching order and personal source metadata")
    func predictsHighestOrder() throws {
        let memory = PersonalWritingMemory(
            ngramContinuations: [
                "the launch note should": [PersonalNGramContinuation(display: "stay focused and small", weight: 2, lastSeenDay: "2026-07-15")],
                "note should": [PersonalNGramContinuation(display: "be ignored for higher order", weight: 9, lastSeenDay: "2026-07-15")]
            ],
            builtAtDay: "2026-07-15"
        )
        let selection = predictor.selection(
            for: "The launch note should",
            memory: memory,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 3
        )

        #expect(selection.suggestion?.visibleText == " stay focused and")
        #expect(selection.candidateSelectionSource == "personal-ngram")
        #expect(selection.traceMetadata["personalNGramMatch"] == "order-4")
    }

    @Test("Blocks unsupported profiles and punctuation boundaries")
    func appliesSameGatingAsDocLocal() {
        let memory = PersonalWritingMemory(
            ngramContinuations: ["launch note": [PersonalNGramContinuation(display: "stays focused", weight: 1, lastSeenDay: "2026-07-15")]],
            builtAtDay: "2026-07-15"
        )
        #expect(predictor.selection(for: "launch note", memory: memory, behaviorProfileID: .email).suppressionReason == "unsupported-profile")
        #expect(predictor.selection(for: "launch note,", memory: memory, behaviorProfileID: .notes).suppressionReason == "not-word-boundary")
    }

    @Test("AI chat requires explicit prompt app permission")
    func promptAppRequiresPermission() {
        let memory = PersonalWritingMemory(
            ngramContinuations: ["make this": [PersonalNGramContinuation(display: "clear and direct", weight: 1, lastSeenDay: "2026-07-15")]],
            builtAtDay: "2026-07-15"
        )
        #expect(predictor.selection(for: "make this", memory: memory, behaviorProfileID: .aiChat).suggestion == nil)
        #expect(predictor.selection(for: "make this", memory: memory, behaviorProfileID: .aiChat, allowsPromptAppPrediction: true).suggestion != nil)
    }
}
