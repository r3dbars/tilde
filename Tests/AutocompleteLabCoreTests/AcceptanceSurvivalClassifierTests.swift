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

    @Test("Counts kept word-completion suffixes inside the completed word")
    func countsKeptWordCompletionSuffixesInsideCompletedWord() {
        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: "ation",
            currentFullText: "I use dictation every day.",
            expectedInsertionUTF16Offset: "I use dict".utf16.count,
            checkpoint: .twoSeconds
        )

        #expect(measurement.survivalClass == .lightlyEditedKept)
        #expect(measurement.tokenRecall == 1.0)
        #expect(measurement.deletedWithinTwoSeconds == false)
    }

    @Test("Counts one-letter suffix accepts at the exact insertion offset")
    func countsOneLetterSuffixAcceptsAtExactInsertionOffset() {
        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: "d",
            currentFullText: "Autocomplete Lab Obsidian proof\nSmoke proof feed",
            expectedInsertionUTF16Offset: "Autocomplete Lab Obsidian proof\nSmoke proof fee".utf16.count,
            checkpoint: .twoSeconds
        )

        #expect(measurement.survivalClass == .lightlyEditedKept)
        #expect(measurement.tokenRecall == 1.0)
        #expect(!measurement.deletedWithinTwoSeconds)
    }

    @Test("Combines exact and suffix-kept tokens")
    func combinesExactAndSuffixKeptTokens() {
        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: "ation every",
            currentFullText: "I use dictation every day.",
            expectedInsertionUTF16Offset: "I use dict".utf16.count,
            checkpoint: .twoSeconds
        )

        #expect(measurement.survivalClass == .lightlyEditedKept)
        #expect(measurement.tokenRecall == 1.0)
    }

    @Test("Does not count tiny suffix coincidences as kept word completions")
    func doesNotCountTinySuffixCoincidencesAsKeptWordCompletions() {
        let measurement = classifier.classify(
            acceptedText: "in",
            currentTextWindow: "I changed the thing.",
            checkpoint: .twoSeconds
        )

        #expect(measurement.survivalClass == .rejectedAfterAccept)
        #expect(measurement.tokenRecall == 0)
    }

    @Test("Does not count unrelated suffixes away from the insertion point")
    func doesNotCountUnrelatedSuffixesAwayFromInsertionPoint() {
        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: "ing",
            currentFullText: "I changed the meeting.",
            expectedInsertionUTF16Offset: "I changed ".utf16.count,
            checkpoint: .twoSeconds
        )

        #expect(measurement.survivalClass == .rejectedAfterAccept)
        #expect(measurement.tokenRecall == 0)
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

    @Test("Send checkpoint finalizes accepted text separately from blur")
    func sendCheckpointFinalizesAcceptedTextSeparatelyFromBlur() {
        let measurement = classifier.classify(
            acceptedText: "send this note",
            currentTextWindow: "Please send this note.",
            checkpoint: .fieldSend,
            firstEditDelayMilliseconds: 8_000
        )

        #expect(measurement.survivalClass == .exactKept)
        #expect(measurement.isStrongAcceptedAndKept)
        #expect(measurement.isFinalAcceptedAndKept)
        #expect(measurement.traceMetadata["checkpoint"] == "fieldSend")
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
