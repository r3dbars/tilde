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
        #expect(total.exactPrefix3Trials == 200)
        #expect(total.exactPrefix3Count == 200)
        #expect(total.exactPrefix4Trials == 100)
        #expect(total.exactPrefix4Count == 100)
        #expect(total.noSuggestionCorrectCount == 100)
        #expect(total.unsafeDisplayFailureCount == 0)
        #expect(report.score == 100)
        #expect(report.squaredScore == 10_000)
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
        #expect(markdown.contains("Unsafe displays"))
        #expect(markdown.contains("not a claim that the live model is 100/100"))
    }
}
