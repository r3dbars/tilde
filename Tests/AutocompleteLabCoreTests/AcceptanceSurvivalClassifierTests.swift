import Testing
@testable import AutocompleteLabCore

@Suite("Acceptance survival classifier")
struct AcceptanceSurvivalClassifierTests {
    private let classifier = AcceptanceSurvivalClassifier()

    @Test("Classifies exact kept text")
    func classifiesExactKeptText() {
        let measurement = classifier.classify(
            acceptedText: "make this easier",
            currentTextWindow: "We should make this easier tomorrow.",
            checkpoint: .tenSeconds
        )

        #expect(measurement.survivalClass == .exactKept)
        #expect(measurement.tokenRecall == 1.0)
        #expect(measurement.normalizedEditDistance == 0.0)
        #expect(measurement.isStrongAcceptedAndKept)
    }

    @Test("Treats punctuation tweaks as kept")
    func treatsPunctuationTweaksAsKept() {
        let measurement = classifier.classify(
            acceptedText: "thanks, Justin",
            currentTextWindow: "thanks Justin",
            checkpoint: .tenSeconds,
            firstEditDelayMilliseconds: 6_000
        )

        #expect(measurement.survivalClass == .exactKept)
        #expect(measurement.tokenRecall == 1.0)
        #expect(measurement.isStrongAcceptedAndKept)
    }

    @Test("Classifies partial edits")
    func classifiesPartialEdits() {
        let measurement = classifier.classify(
            acceptedText: "make this feel much calmer",
            currentTextWindow: "make this calmer",
            checkpoint: .thirtySeconds,
            firstEditDelayMilliseconds: 12_000
        )

        #expect(measurement.survivalClass == .partiallyKept)
        #expect(measurement.tokenRecall >= 0.5)
        #expect(measurement.isFinalAcceptedAndKept)
    }

    @Test("Classifies immediate deletes as rejected")
    func classifiesImmediateDeletesAsRejected() {
        let measurement = classifier.classify(
            acceptedText: "wrong direction",
            currentTextWindow: "Start again.",
            checkpoint: .twoSeconds,
            firstEditDelayMilliseconds: 900,
            deletedWithinTwoSeconds: true
        )

        #expect(measurement.survivalClass == .rejectedAfterAccept)
        #expect(!measurement.isStrongAcceptedAndKept)
        #expect(measurement.traceMetadata["deletedWithinTwoSeconds"] == "true")
    }

    @Test("Final checkpoint counts partially kept accepted text")
    func finalCheckpointCountsPartiallyKeptText() {
        let measurement = classifier.classify(
            acceptedText: "ship this version today",
            currentTextWindow: "ship this today",
            checkpoint: .fieldBlur,
            firstEditDelayMilliseconds: 20_000
        )

        #expect(measurement.survivalClass == .partiallyKept)
        #expect(measurement.isFinalAcceptedAndKept)
    }

    @Test("Matches around the expected insertion offset instead of the whole field")
    func matchesAroundExpectedInsertionOffset() {
        let acceptedText = "make this better"
        let before = String(repeating: "noise ", count: 80)
        let after = String(repeating: " other", count: 80)
        let current = before + acceptedText + after
        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: acceptedText,
            currentFullText: current,
            expectedInsertionUTF16Offset: before.utf16.count,
            checkpoint: .tenSeconds,
            radius: 24
        )
        let wrongOffset = classifier.classifyAroundExpectedInsertion(
            acceptedText: acceptedText,
            currentFullText: current,
            expectedInsertionUTF16Offset: current.utf16.count,
            checkpoint: .tenSeconds,
            radius: 24
        )

        #expect(measurement.survivalClass == .exactKept)
        #expect(wrongOffset.survivalClass == .rejectedAfterAccept)
    }
}
