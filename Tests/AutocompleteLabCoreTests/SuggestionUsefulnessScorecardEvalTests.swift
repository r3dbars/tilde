import Foundation
import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Suggestion usefulness scorecard eval")
struct SuggestionUsefulnessScorecardEvalTests {
    @Test("Default corpus measures useful short non-repetitive safe suggestions")
    func defaultCorpusMeasuresUsefulShortNonRepetitiveSafeSuggestions() {
        let report = SuggestionUsefulnessScorecardEvaluator.evaluate()
        let total = report.totalSummary

        #expect(report.results.count == 20)
        #expect(total.caseCount == 20)
        #expect(total.expectedSuggestionCount == 18)
        #expect(total.shownCount == 18)
        #expect(total.usefulPassCount == 20)
        #expect(total.shortPassCount == 20)
        #expect(total.nonRepetitivePassCount == 20)
        #expect(total.safePassCount == 20)
        #expect(total.acceptWorthyCount == 20)
        #expect(report.gateResults.count == 6)
        #expect(report.gateResults.allSatisfy { $0.passed })
        #expect(report.score == 100)

        let sources = Set(report.sourceSummaries.map(\.source))
        #expect(sources == [
            "canned-bridge",
            "doc-local-ngram",
            "model-candidate-ranker",
            "word-completion"
        ])
    }

    @Test("Scorecard keeps sensitive and unsafe rows silent")
    func scorecardKeepsSensitiveAndUnsafeRowsSilent() throws {
        let report = SuggestionUsefulnessScorecardEvaluator.evaluate()
        let password = try #require(report.results.first {
            $0.evalCase.id == "model-password-silence"
        })
        let search = try #require(report.results.first {
            $0.evalCase.id == "model-search-silence"
        })

        #expect(password.visibleText == nil)
        #expect(password.acceptWorthy)
        #expect(search.visibleText == nil)
        #expect(search.acceptWorthy)
    }

    @Test("Scorecard names non-annoyance gates")
    func scorecardNamesNonAnnoyanceGates() {
        let gateIDs = Set(SuggestionUsefulnessScorecardEvaluator.evaluate().gateResults.map(\.id))

        #expect(gateIDs.contains("display-high-risk"))
        #expect(gateIDs.contains("one-brain-high-risk"))
        #expect(gateIDs.contains("one-brain-learned-restraint"))
        #expect(gateIDs.contains("low-kept-probability"))
        #expect(gateIDs.contains("annoyance-repeated-typed-over"))
        #expect(gateIDs.contains("annoyance-accepted-kept"))
    }

    @Test("Markdown report is checked in and names the scorecard guardrails")
    func markdownReportIsCheckedInAndNamesTheScorecardGuardrails() throws {
        let generatedMarkdown = SuggestionUsefulnessScorecardEvaluator.evaluate().markdown
        let reportPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evals/suggestion-usefulness-scorecard-2026-06-14.md")
        let checkedInReport = try String(contentsOf: reportPath, encoding: .utf8)

        for required in [
            "Suggestion Usefulness Scorecard - 20 Synthetic Cases",
            "Score: 100/100",
            "Candidate rows scored: 20",
            "Display-eligible rows: 18",
            "Useful suggestions: 20/20",
            "Short suggestions: 20/20",
            "Non-repetitive suggestions: 20/20",
            "Safe or suppressed rows: 20/20",
            "Non-annoyance gates: 6/6",
            "| Total | 20/20 | 18/18 | 20/20 | 20/20 | 20/20 | 20/20 |",
            "one-brain preview keeps high risk as a hard veto",
            "not private dogfood or live model telemetry"
        ] {
            #expect(generatedMarkdown.contains(required))
            #expect(checkedInReport.contains(required))
        }
    }
}
