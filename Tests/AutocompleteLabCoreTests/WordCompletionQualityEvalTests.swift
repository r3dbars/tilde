import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Word completion quality eval")
struct WordCompletionQualityEvalTests {
    @Test("Reports app surface quality and miss rates")
    func reportsAppSurfaceQualityAndMissRates() throws {
        let report = WordCompletionQualityEvaluator.evaluate()
        let total = report.totalSummary

        #expect(report.score == 9.6)
        #expect(total.caseCount == 16)
        #expect(total.shownCount == 11)
        #expect(total.candidateQualityRate == 1.0)
        #expect(total.missCount == 1)
        #expect(total.typedOverCount == 1)
        #expect(total.repeatedMissSuppressionRate == 1.0)
        #expect(total.prefixCooldownRate == 1.0)
        #expect(total.partialAcceptSuccessRate == 1.0)

        let surfaceNames = Set(report.surfaceSummaries.map(\.surfaceName))
        #expect(surfaceNames == [
            "TextEdit",
            "Notes",
            "Obsidian",
            "Chrome-like fields"
        ])

        let chrome = try #require(report.surfaceSummaries.first {
            $0.surfaceName == "Chrome-like fields"
        })
        #expect(chrome.typedOverCount == 1)
        #expect(chrome.missRate == 1.0 / 3.0)
    }

    @Test("Keeps word completion short and quiet")
    func keepsWordCompletionShortAndQuiet() {
        let report = WordCompletionQualityEvaluator.evaluate()

        #expect(report.results.allSatisfy { result in
            guard let visibleSuffix = result.visibleSuffix else {
                return true
            }
            return !visibleSuffix.contains(" ")
                && visibleSuffix.count <= 12
        })
        #expect(report.results.contains { result in
            result.evalCase.id == "textedit-two-letter-floor"
                && result.visibleSuffix == nil
                && result.candidateSuppressionReason == "invalid-fragment"
        })
        #expect(report.results.contains { result in
            result.evalCase.id == "textedit-low-value-kind"
                && result.visibleSuffix == nil
                && result.candidateSuppressionReason == "low-value-suffix"
        })
        #expect(report.results.contains { result in
            result.evalCase.id == "obsidian-code-word"
                && result.visibleSuffix == nil
        })
    }

    @Test("Report markdown includes the proof counters")
    func reportMarkdownIncludesProofCounters() {
        let markdown = WordCompletionQualityEvaluator.evaluate().markdown

        #expect(markdown.contains("Score: 9.6/10"))
        #expect(markdown.contains("Candidate quality"))
        #expect(markdown.contains("Miss rate"))
        #expect(markdown.contains("Typed-over rate"))
        #expect(markdown.contains("Repeated miss suppressed"))
        #expect(markdown.contains("Prefix cooldown blocked"))
        #expect(markdown.contains("Partial accept"))
        #expect(markdown.contains("Chrome-like fields"))
        #expect(markdown.contains("chrome-documentary-typed-over"))
        #expect(markdown.contains("not a need to make completions louder"))
    }
}
