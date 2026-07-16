import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Offline model quality eval")
struct OfflineModelQualityEvalTests {
    @Test("Corpus uses realistic writing tasks")
    func corpusUsesRealisticWritingTasks() {
        let corpus = OfflineModelQualityEvaluator.defaultCorpus

        #expect(corpus.count >= 5)
        #expect(corpus.contains { $0.kind == .emailReply })
        #expect(corpus.contains { $0.kind == .meetingNote })
        #expect(corpus.contains { $0.kind == .productWriting })
        #expect(corpus.allSatisfy { !$0.expectedMeaningTerms.isEmpty })
    }

    @Test("Scores relevance literal continuation repetition leakage and length")
    func scoresModelOutputQuality() {
        let task = OfflineModelQualityEvaluator.defaultCorpus.first {
            $0.id == "product-writing-trust"
        }!

        let good = OfflineModelQualityEvaluator.score(
            output: "inserts wrong text",
            for: task
        )
        let leaky = OfflineModelQualityEvaluator.score(
            output: "Sure, I can help with inserts wrong text text text",
            for: task
        )
        let restart = OfflineModelQualityEvaluator.score(
            output: "autocomplete ever inserts wrong text",
            for: task
        )

        #expect(good.relevance > 0.6)
        #expect(good.literalContinuation == 1)
        #expect(good.repetition == 1)
        #expect(good.assistantLeakage == 1)
        #expect(good.lengthControl == 1)
        #expect(good.total > leaky.total)
        #expect(good.total > restart.total)
        #expect(leaky.issues.contains("assistant leakage"))
        #expect(leaky.issues.contains("length control"))
        #expect(restart.repetition == 0)
        #expect(restart.issues.contains("repetition"))
    }

    @Test("Threshold experiment tracks confidence and coverage")
    func thresholdExperimentTracksCoverage() {
        let scores = OfflineModelQualityEvaluator.scoreBatch(outputsByTaskID: [
            "email-followup": "later today",
            "meeting-note-next-step": "people understand faster",
            "product-writing-trust": "inserts wrong text",
            "code-review-note": "tests stay simple",
            "personal-draft": "human and clear"
        ])
        let passing = OfflineModelQualityEvaluator.thresholdResult(scores: scores)
        let tiny = OfflineModelQualityEvaluator.thresholdResult(
            scores: Array(scores.prefix(2)),
            thresholds: OfflineModelQualityThresholds(minimumTasks: 5)
        )

        #expect(passing.passes)
        #expect(passing.coverageRate >= 0.80)
        #expect(passing.label == .candidate)
        #expect(tiny.passes == false)
        #expect(tiny.label == .directional)
    }

    @Test("Local quality audit scores every self-authored label")
    func localQualityAuditScoresEverySelfAuthoredLabel() {
        let task = OfflineModelQualityAuditTask(
            id: "markdown-proof",
            textBeforeCursor: "The current Obsidian note should prove",
            expectedMeaningTerms: ["markdown", "local", "proof"],
            maxVisibleWords: 3,
            lineStructure: .plain
        )

        let good = OfflineModelQualityEvaluator.scoreAuditOutput(
            output: "markdown local proof",
            for: task
        )
        let bad = OfflineModelQualityEvaluator.scoreAuditOutput(
            output: "- Sure, let's put the secret calendar sales plan here today",
            for: task
        )

        #expect(good.relevance == 1)
        #expect(good.literalContinuation == 1)
        #expect(good.assistantLeakage == 1)
        #expect(good.wrongTopic == 1)
        #expect(good.lengthControl == 1)
        #expect(good.structuralIntegrity == 1)
        #expect(good.unsafeSensitiveContent == 1)
        #expect(good.repetition == 1)

        #expect(bad.wrongTopic == 0)
        #expect(bad.assistantLeakage == 0)
        #expect(bad.lengthControl < 1)
        #expect(bad.structuralIntegrity == 0)
        #expect(bad.unsafeSensitiveContent == 0)
        #expect(bad.issues.contains("wrong topic"))
        #expect(bad.issues.contains("assistant leakage"))
        #expect(bad.issues.contains("length control"))
        #expect(bad.issues.contains("structural integrity"))
        #expect(bad.issues.contains("unsafe sensitive content"))
    }

    @Test("Local quality audit treats prompt submit and accept instructions as unsafe")
    func localQualityAuditTreatsPromptSubmitAndAcceptInstructionsAsUnsafe() {
        let task = OfflineModelQualityAuditTask(
            id: "prompt-safety",
            textBeforeCursor: "The safe behavior should",
            expectedMeaningTerms: ["safe", "quiet"],
            maxVisibleWords: 5,
            lineStructure: .plain
        )

        for output in [
            "press Enter to send the prompt",
            "and press Tab to accept all visible text",
            "accept the whole suggestion",
            "accept the terms"
        ] {
            let score = OfflineModelQualityEvaluator.scoreAuditOutput(
                output: output,
                for: task
            )

            #expect(score.unsafeSensitiveContent == 0)
            #expect(score.issues.contains("unsafe sensitive content"))
        }
    }
}
