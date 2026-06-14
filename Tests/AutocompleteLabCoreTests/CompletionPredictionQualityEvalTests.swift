import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Completion prediction quality eval")
struct CompletionPredictionQualityEvalTests {
    @Test("Default corpus runs 500 deterministic prediction cases")
    func defaultCorpusRuns500DeterministicPredictionCases() {
        let report = CompletionPredictionQualityEvaluator.evaluate()
        let total = report.totalSummary

        #expect(report.results.count == 500)
        #expect(total.caseCount == 500)
        #expect(total.expectedSuggestionCount == 400)
        #expect(total.expectedSilenceCount == 100)
        #expect(total.shownCount == 400)
        #expect(total.exactVisibleTextCount == 400)
        #expect(total.exactNextWordCount == 400)
        #expect(total.exactPrefix2Trials == 300)
        #expect(total.exactPrefix2Count == 300)
        #expect(total.exactPrefix3Trials == 175)
        #expect(total.exactPrefix3Count == 175)
        #expect(total.exactPrefix4Trials == 50)
        #expect(total.exactPrefix4Count == 50)
        #expect(total.usefulSuffixTrials == 400)
        #expect(total.usefulSuffixCount == 400)
        #expect(total.noSuggestionCorrectCount == 100)
        #expect(total.unsafeDisplayFailureCount == 0)
        #expect(total.overEagerChattyPassCount == 500)
        #expect(total.repetitionPassCount == 500)
        #expect(total.wrongTopicPassCount == 500)
        #expect(total.unsafeSensitivePassCount == 500)
        #expect(total.userFeelPassCount == 500)
        #expect(report.score == 100)
        #expect(report.squaredScore == 10_000)
        #expect(report.results.filter { $0.selectionSource == "canned-bridge" }.count == 200)
        #expect(report.results.filter { $0.selectionSource == "model-candidate-ranker" && $0.evalCase.expectsSuggestion }.count == 200)
        #expect(report.results.filter { $0.evalCase.useCannedBridge }.allSatisfy { result in
            !result.evalCase.rawCandidateLines.contains(result.evalCase.expectedVisibleText?.trimmingCharacters(in: .whitespaces) ?? "")
        })
    }

    @Test("Corpus covers real target surfaces and blocked negative fields")
    func corpusCoversSurfacesAndBlockedNegativeFields() {
        let report = CompletionPredictionQualityEvaluator.evaluate()
        let names = Set(report.surfaceSummaries.map(\.surfaceName))

        #expect(names.contains("TextEdit"))
        #expect(names.contains("Notes"))
        #expect(names.contains("Obsidian"))
        #expect(names.contains("Chrome textarea"))
        #expect(names.contains("Chrome contenteditable"))
        #expect(names.contains("Codex prompt negative"))
        #expect(names.contains("Search field negative"))
        #expect(names.contains("Form field negative"))
        #expect(names.contains("Password field negative"))
        #expect(names.contains("Code field negative"))

        let obsidianCases = report.results.filter { $0.evalCase.surfaceName == "Obsidian" }
        #expect(obsidianCases.count == 80)
        #expect(obsidianCases.allSatisfy { $0.evalCase.behaviorProfileID == .notes })

        let negativeSummaries = report.surfaceSummaries.filter { $0.surfaceName.contains("negative") }
        #expect(negativeSummaries.allSatisfy { $0.expectedSilenceCount == 20 })
        #expect(negativeSummaries.allSatisfy { $0.noSuggestionCorrectCount == 20 })
        #expect(negativeSummaries.allSatisfy { $0.unsafeDisplayFailureCount == 0 })
    }

    @Test("Markdown report names the 500-case score and squared score")
    func markdownReportNamesScoreAndSquaredScore() {
        let markdown = CompletionPredictionQualityEvaluator.evaluate().markdown

        #expect(markdown.contains("Completion Prediction Quality Eval - 500 Cases"))
        #expect(markdown.contains("Score: 100.0/100"))
        #expect(markdown.contains("Squared score: 10000.0/10000"))
        #expect(markdown.contains("Next word exact"))
        #expect(markdown.contains("4-word exact"))
        #expect(markdown.contains("Useful suffix"))
        #expect(markdown.contains("Over-eager/chatty ok"))
        #expect(markdown.contains("Repetition ok"))
        #expect(markdown.contains("Wrong-topic ok"))
        #expect(markdown.contains("Unsafe/sensitive ok"))
        #expect(markdown.contains("User-feel ok"))
        #expect(markdown.contains("Unsafe displays"))
        #expect(markdown.contains("| Code field negative | 0/20 | n/a | n/a | n/a | n/a | 100% | 0 |"))
        #expect(markdown.contains("| Code field negative | n/a | 100% | 100% | 100% | 100% | 100% |"))
        #expect(markdown.contains("Source Mix"))
        #expect(markdown.contains("Canned bridge exact: 200/200"))
        #expect(markdown.contains("Canned-bridge positives omit the expected answer"))
        #expect(markdown.contains("not a claim that the live model is 100/100"))
    }

    @Test("Checked-in report exposes generated guardrail summary")
    func checkedInReportExposesGeneratedGuardrailSummary() throws {
        let reportPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evals/completion-prediction-quality-500-2026-05-11.md")
        let checkedInReport = try String(contentsOf: reportPath, encoding: .utf8)
        let generatedMarkdown = CompletionPredictionQualityEvaluator.evaluate().markdown

        for required in [
            "Score: 100.0/100",
            "Squared score: 10000.0/10000",
            "| Total | 400/500 | 100% | 100% | 100% | 100% | 100% | 0 |",
            "| Total | 100% | 100% | 100% | 100% | 100% | 100% |",
            "| Code field negative | 0/20 | n/a | n/a | n/a | n/a | 100% | 0 |",
            "| Code field negative | n/a | 100% | 100% | 100% | 100% | 100% |",
            "Canned-bridge positives omit the expected answer",
            "not a claim that the live model is 100/100"
        ] {
            #expect(generatedMarkdown.contains(required))
            #expect(checkedInReport.contains(required))
        }
    }

    @Test("Daily-driver phrase corpus scores accept-worthy writing suggestions")
    func dailyDriverPhraseCorpusScoresAcceptWorthyWritingSuggestions() {
        let report = DailyDriverPhraseQualityEvaluator.evaluate()
        let total = report.totalSummary

        #expect(report.results.count == 30)
        #expect(total.caseCount == 30)
        #expect(total.displayEligibleCount == 24)
        #expect(total.expectedSilenceCount == 6)
        #expect(total.shownCount == 24)
        #expect(total.phraseLengthPassCount == 24)
        #expect(total.relevancePassCount == 24)
        #expect(total.suffixNoiseFailureCount == 0)
        #expect(total.expectedSilencePassCount == 6)
        #expect(total.acceptWorthyCount == 30)
        #expect(report.score == 100)
        #expect(Set(report.surfaceSummaries.map(\.surfaceName)) == ["TextEdit", "Notes", "Obsidian"])
        #expect(report.results.contains { $0.selectionSource == "canned-bridge" })
        #expect(report.results.contains { $0.selectionSource == "model-candidate-ranker" })
    }

    @Test("Daily-driver phrase report names acceptability and suffix-noise guardrails")
    func dailyDriverPhraseReportNamesAcceptabilityAndSuffixNoiseGuardrails() throws {
        let markdown = DailyDriverPhraseQualityEvaluator.evaluate().markdown
        let reportPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evals/daily-driver-phrase-quality-2026-06-12.md")
        let checkedInReport = try String(contentsOf: reportPath, encoding: .utf8)

        for required in [
            "Daily Driver Phrase Quality Eval - 30 Real Writing Cases",
            "Score: 100/100",
            "Rows scored: 30",
            "Display-eligible rows: 24",
            "Suppressed/no-suggestion rows: 6",
            "Accept-worthy rows: 30/30",
            "3-8 word phrase rate: 100%",
            "Suffix-noise failures: 0",
            "| Total | 24/24 | 100% | 100% | 0 | 6/6 | 100% |",
            "short generic continuations would be worth accepting",
            "not private dogfood"
        ] {
            #expect(markdown.contains(required))
            #expect(checkedInReport.contains(required))
        }
    }
}
