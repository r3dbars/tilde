import Foundation

public struct DailyDriverPhraseQualityEvalCase: Equatable, Sendable {
    public let id: String
    public let surfaceName: String
    public let behaviorProfileID: AutocompleteBehaviorProfileID
    public let textBeforeCursor: String
    public let expectedMeaningTerms: [String]
    public let rawCandidateLines: [String]
    public let useCannedBridge: Bool
    public let expectedNoSuggestion: Bool

    public init(
        id: String,
        surfaceName: String,
        behaviorProfileID: AutocompleteBehaviorProfileID,
        textBeforeCursor: String,
        expectedMeaningTerms: [String],
        rawCandidateLines: [String],
        useCannedBridge: Bool = false,
        expectedNoSuggestion: Bool = false
    ) {
        self.id = id
        self.surfaceName = surfaceName
        self.behaviorProfileID = behaviorProfileID
        self.textBeforeCursor = textBeforeCursor
        self.expectedMeaningTerms = expectedMeaningTerms
        self.rawCandidateLines = rawCandidateLines
        self.useCannedBridge = useCannedBridge
        self.expectedNoSuggestion = expectedNoSuggestion
    }

    public var expectsSuggestion: Bool {
        !expectedNoSuggestion
    }

    public var rawOutput: String {
        rawCandidateLines.joined(separator: "\n")
    }
}

public struct DailyDriverPhraseQualityEvalCaseResult: Equatable, Sendable {
    public let evalCase: DailyDriverPhraseQualityEvalCase
    public let visibleText: String?
    public let selectionSource: String
    public let suppressionReason: String?

    public var shown: Bool {
        visibleText != nil
    }

    public var visibleWordCount: Int {
        phraseWords(visibleText).count
    }

    public var phraseLengthAcceptable: Bool? {
        guard evalCase.expectsSuggestion else {
            return nil
        }
        return (3...8).contains(visibleWordCount)
    }

    public var relevanceAcceptable: Bool? {
        guard evalCase.expectsSuggestion else {
            return nil
        }
        let outputWords = Set(phraseWords(visibleText))
        guard !outputWords.isEmpty else {
            return false
        }
        let requiredHits = min(2, evalCase.expectedMeaningTerms.count)
        let hits = evalCase.expectedMeaningTerms
            .map { $0.lowercased() }
            .filter { outputWords.contains($0) }
            .count
        return hits >= requiredHits
    }

    public var suffixNoiseFailure: Bool {
        evalCase.expectsSuggestion && shown && visibleWordCount < 3
    }

    public var repetitionFailure: Bool {
        let outputWords = phraseWords(visibleText)
        guard !outputWords.isEmpty else {
            return evalCase.expectsSuggestion
        }
        if zip(outputWords, outputWords.dropFirst()).contains(where: ==) {
            return true
        }

        let contextWords = phraseWords(evalCase.textBeforeCursor)
        let maximumLead = min(3, outputWords.count, contextWords.count)
        guard maximumLead >= 2 else {
            return false
        }

        for leadCount in stride(from: maximumLead, through: 2, by: -1) {
            if phraseContainsContiguous(Array(outputWords.prefix(leadCount)), in: contextWords) {
                return true
            }
        }
        return false
    }

    public var unsafeOrAssistantFailure: Bool {
        guard let visibleText else {
            return false
        }
        let normalized = visibleText.lowercased()
        return Self.blockedFragments.contains { normalized.contains($0) }
    }

    public var expectedSilencePassed: Bool? {
        evalCase.expectedNoSuggestion ? visibleText == nil : nil
    }

    public var acceptWorthy: Bool {
        if evalCase.expectedNoSuggestion {
            return visibleText == nil
        }

        return shown
            && phraseLengthAcceptable == true
            && relevanceAcceptable == true
            && !suffixNoiseFailure
            && !repetitionFailure
            && !unsafeOrAssistantFailure
    }

    private static let blockedFragments = [
        "as an ai",
        "click send",
        "i can help",
        "press enter",
        "press return",
        "run this command",
        "secret",
        "submit the prompt",
        "you should"
    ]
}

public struct DailyDriverPhraseQualitySurfaceSummary: Equatable, Sendable {
    public let surfaceName: String
    public let caseCount: Int
    public let displayEligibleCount: Int
    public let shownCount: Int
    public let acceptWorthyCount: Int
    public let phraseLengthPassCount: Int
    public let relevancePassCount: Int
    public let suffixNoiseFailureCount: Int
    public let expectedSilenceCount: Int
    public let expectedSilencePassCount: Int

    public var acceptWorthyRate: Double {
        phraseRate(acceptWorthyCount, caseCount)
    }

    public var phraseLengthRate: Double {
        phraseRate(phraseLengthPassCount, displayEligibleCount)
    }

    public var relevanceRate: Double {
        phraseRate(relevancePassCount, displayEligibleCount)
    }

    public var expectedSilenceRate: Double {
        phraseRate(expectedSilencePassCount, expectedSilenceCount)
    }
}

public struct DailyDriverPhraseQualityEvalReport: Equatable, Sendable {
    public let results: [DailyDriverPhraseQualityEvalCaseResult]
    public let surfaceSummaries: [DailyDriverPhraseQualitySurfaceSummary]
    public let totalSummary: DailyDriverPhraseQualitySurfaceSummary
    public let score: Double

    public var markdown: String {
        let rows = surfaceSummaries.map { summary in
            "| \(summary.surfaceName) | \(summary.shownCount)/\(summary.displayEligibleCount) | \(phrasePercent(summary.phraseLengthRate, trials: summary.displayEligibleCount)) | \(phrasePercent(summary.relevanceRate, trials: summary.displayEligibleCount)) | \(summary.suffixNoiseFailureCount) | \(summary.expectedSilencePassCount)/\(summary.expectedSilenceCount) | \(phrasePercent(summary.acceptWorthyRate)) |"
        }
        .joined(separator: "\n")

        let evidenceRows = results.map { result in
            let actual = result.visibleText ?? "silence"
            let status = result.acceptWorthy ? "accept" : "miss"
            return "| \(result.evalCase.id) | \(result.evalCase.surfaceName) | \(actual) | \(result.visibleWordCount) | \(result.selectionSource) | \(status) |"
        }
        .joined(separator: "\n")

        return """
        # Daily Driver Phrase Quality Eval - 30 Real Writing Cases

        Score: \(String(format: "%.0f", score))/100

        This deterministic harness uses synthetic, disposable writing situations for TextEdit, Notes, and Obsidian. It asks whether short generic continuations would be worth accepting without relying on private dogfood text or product-specific canned phrases.

        ## Acceptance Bar

        A displayed phrase passes only when it is 3-8 words, matches the expected meaning terms, avoids assistant/action/sensitive text, and does not restart recent context. One- or two-word phrase nubs count as suffix-noise failures in this eval.

        ## Summary

        - Rows scored: \(totalSummary.caseCount).
        - Display-eligible rows: \(totalSummary.displayEligibleCount).
        - Suppressed/no-suggestion rows: \(totalSummary.expectedSilenceCount).
        - Accept-worthy rows: \(totalSummary.acceptWorthyCount)/\(totalSummary.caseCount).
        - 3-8 word phrase rate: \(phrasePercent(totalSummary.phraseLengthRate, trials: totalSummary.displayEligibleCount)).
        - Relevance score: \(phrasePercent(totalSummary.relevanceRate, trials: totalSummary.displayEligibleCount)).
        - Suffix-noise failures: \(totalSummary.suffixNoiseFailureCount).
        - Expected suppressions passed: \(totalSummary.expectedSilencePassCount)/\(totalSummary.expectedSilenceCount).

        | Surface | Shown | 3-8 words | Relevant | Suffix-noise failures | Silence exact | Would accept |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: |
        \(rows)
        | Total | \(totalSummary.shownCount)/\(totalSummary.displayEligibleCount) | \(phrasePercent(totalSummary.phraseLengthRate, trials: totalSummary.displayEligibleCount)) | \(phrasePercent(totalSummary.relevanceRate, trials: totalSummary.displayEligibleCount)) | \(totalSummary.suffixNoiseFailureCount) | \(totalSummary.expectedSilencePassCount)/\(totalSummary.expectedSilenceCount) | \(phrasePercent(totalSummary.acceptWorthyRate)) |

        ## Case Evidence

        | Case | Surface | Actual | Words | Source | Result |
        | --- | --- | --- | ---: | --- | --- |
        \(evidenceRows)

        ## Decision

        This harness is green when score stays at 100/100, suffix-noise failures stay at zero, and expected suppressions keep passing. It is deterministic phrase-quality proof, not private dogfood.
        """
    }
}

public enum DailyDriverPhraseQualityEvaluator {
    public static let defaultCorpus: [DailyDriverPhraseQualityEvalCase] = makeDefaultCorpus()

    public static func evaluate(
        corpus: [DailyDriverPhraseQualityEvalCase] = defaultCorpus,
        cleaner: CompletionOutputCleaner = CompletionOutputCleaner(maxVisibleWords: 8),
        ranker: CompletionCandidateRanker = CompletionCandidateRanker(),
        predictor: CommonPhraseContinuationPredictor = CommonPhraseContinuationPredictor()
    ) -> DailyDriverPhraseQualityEvalReport {
        let results = corpus.map { evalCase in
            result(for: evalCase, cleaner: cleaner, ranker: ranker, predictor: predictor)
        }
        let summaries = surfaceSummaries(for: results)
        let total = summary(surfaceName: "Total", results: results)
        return DailyDriverPhraseQualityEvalReport(
            results: results,
            surfaceSummaries: summaries,
            totalSummary: total,
            score: score(for: total)
        )
    }

    private static func result(
        for evalCase: DailyDriverPhraseQualityEvalCase,
        cleaner: CompletionOutputCleaner,
        ranker: CompletionCandidateRanker,
        predictor: CommonPhraseContinuationPredictor
    ) -> DailyDriverPhraseQualityEvalCaseResult {
        if evalCase.useCannedBridge {
            let selection = predictor.selection(
                for: evalCase.textBeforeCursor,
                behaviorProfileID: evalCase.behaviorProfileID,
                maxVisibleWords: 8
            )
            return DailyDriverPhraseQualityEvalCaseResult(
                evalCase: evalCase,
                visibleText: selection.suggestion?.visibleText,
                selectionSource: "canned-bridge",
                suppressionReason: selection.suppressionReason
            )
        }

        let selection = cleaner.cleanBestCandidate(
            evalCase.rawOutput,
            after: evalCase.textBeforeCursor,
            mode: .phraseContinuation,
            behaviorProfileID: evalCase.behaviorProfileID,
            ranker: ranker
        )
        return DailyDriverPhraseQualityEvalCaseResult(
            evalCase: evalCase,
            visibleText: selection.suggestion?.visibleText,
            selectionSource: "model-candidate-ranker",
            suppressionReason: selection.suppressionReason?.rawValue
        )
    }

    private static func surfaceSummaries(
        for results: [DailyDriverPhraseQualityEvalCaseResult]
    ) -> [DailyDriverPhraseQualitySurfaceSummary] {
        let grouped = Dictionary(grouping: results) { $0.evalCase.surfaceName }
        return grouped.keys.sorted().compactMap { surfaceName in
            guard let surfaceResults = grouped[surfaceName] else {
                return nil
            }
            return summary(surfaceName: surfaceName, results: surfaceResults)
        }
    }

    private static func summary(
        surfaceName: String,
        results: [DailyDriverPhraseQualityEvalCaseResult]
    ) -> DailyDriverPhraseQualitySurfaceSummary {
        DailyDriverPhraseQualitySurfaceSummary(
            surfaceName: surfaceName,
            caseCount: results.count,
            displayEligibleCount: results.filter { $0.evalCase.expectsSuggestion }.count,
            shownCount: results.filter { $0.evalCase.expectsSuggestion && $0.shown }.count,
            acceptWorthyCount: results.filter(\.acceptWorthy).count,
            phraseLengthPassCount: results.filter { $0.phraseLengthAcceptable == true }.count,
            relevancePassCount: results.filter { $0.relevanceAcceptable == true }.count,
            suffixNoiseFailureCount: results.filter(\.suffixNoiseFailure).count,
            expectedSilenceCount: results.filter { $0.evalCase.expectedNoSuggestion }.count,
            expectedSilencePassCount: results.filter { $0.expectedSilencePassed == true }.count
        )
    }

    private static func score(for summary: DailyDriverPhraseQualitySurfaceSummary) -> Double {
        guard summary.caseCount > 0 else {
            return 0
        }
        let raw = (Double(summary.acceptWorthyCount) / Double(summary.caseCount)) * 100
        return raw.rounded()
    }

    private static func makeDefaultCorpus() -> [DailyDriverPhraseQualityEvalCase] {
        var cases: [DailyDriverPhraseQualityEvalCase] = []
        var index = 0
        for surface in surfaces {
            for template in positiveTemplates {
                index += 1
                let useCannedBridge = index.isMultiple(of: 2)
                cases.append(DailyDriverPhraseQualityEvalCase(
                    id: "\(surface.id)-phrase-\(String(format: "%02d", index))",
                    surfaceName: surface.name,
                    behaviorProfileID: surface.behaviorProfileID,
                    textBeforeCursor: "\(surface.contextPrefix): \(template.textBeforeCursor)",
                    expectedMeaningTerms: template.expectedMeaningTerms,
                    rawCandidateLines: useCannedBridge
                        ? template.distractors
                        : [template.expectedVisibleText] + template.distractors,
                    useCannedBridge: useCannedBridge
                ))
            }
        }

        cases.append(contentsOf: negativeTemplates.enumerated().map { offset, template in
            DailyDriverPhraseQualityEvalCase(
                id: "suppress-\(String(format: "%02d", offset + 1))",
                surfaceName: template.surfaceName,
                behaviorProfileID: template.behaviorProfileID,
                textBeforeCursor: template.textBeforeCursor,
                expectedMeaningTerms: [],
                rawCandidateLines: template.rawCandidateLines,
                expectedNoSuggestion: true
            )
        })
        return cases
    }

    private struct Surface {
        let id: String
        let name: String
        let contextPrefix: String
        let behaviorProfileID: AutocompleteBehaviorProfileID
    }

    private struct PositiveTemplate {
        let textBeforeCursor: String
        let expectedVisibleText: String
        let expectedMeaningTerms: [String]
        let distractors: [String]
    }

    private struct NegativeTemplate {
        let surfaceName: String
        let behaviorProfileID: AutocompleteBehaviorProfileID
        let textBeforeCursor: String
        let rawCandidateLines: [String]
    }

    private static let surfaces = [
        Surface(id: "textedit", name: "TextEdit", contextPrefix: "Scratch draft", behaviorProfileID: .docsProse),
        Surface(id: "notes", name: "Notes", contextPrefix: "Daily note", behaviorProfileID: .notes),
        Surface(id: "obsidian", name: "Obsidian", contextPrefix: "Obsidian note", behaviorProfileID: .docsProse)
    ]

    private static let positiveTemplates = [
        PositiveTemplate(
            textBeforeCursor: "Can you please",
            expectedVisibleText: "take a look",
            expectedMeaningTerms: ["take", "look"],
            distractors: ["send it now", "open settings", "press Enter to send"]
        ),
        PositiveTemplate(
            textBeforeCursor: "We should probably",
            expectedVisibleText: "keep it simple",
            expectedMeaningTerms: ["keep", "simple"],
            distractors: ["works", "submit the prompt", "kind of"]
        ),
        PositiveTemplate(
            textBeforeCursor: "It would help to",
            expectedVisibleText: "make this clearer",
            expectedMeaningTerms: ["make", "clearer"],
            distractors: ["ship", "open settings", "do more"]
        ),
        PositiveTemplate(
            textBeforeCursor: "Let me know",
            expectedVisibleText: "what you think",
            expectedMeaningTerms: ["what", "think"],
            distractors: ["summary", "calendar invite", "whole plan"]
        ),
        PositiveTemplate(
            textBeforeCursor: "What I need is",
            expectedVisibleText: "a clearer next step",
            expectedMeaningTerms: ["clearer", "next", "step"],
            distractors: ["everything", "the note", "send it"]
        ),
        PositiveTemplate(
            textBeforeCursor: "Next step is",
            expectedVisibleText: "to make this concrete",
            expectedMeaningTerms: ["make", "concrete"],
            distractors: ["work", "big plans", "more"]
        ),
        PositiveTemplate(
            textBeforeCursor: "Before we move on",
            expectedVisibleText: "capture the next step",
            expectedMeaningTerms: ["capture", "next", "step"],
            distractors: ["owner", "meeting tomorrow", "attachment"]
        ),
        PositiveTemplate(
            textBeforeCursor: "The main thing is",
            expectedVisibleText: "to keep this clear",
            expectedMeaningTerms: ["keep", "clear"],
            distractors: ["more", "something", "you should"]
        )
    ]

    private static let negativeTemplates = [
        NegativeTemplate(
            surfaceName: "TextEdit",
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Password:",
            rawCandidateLines: ["press Enter to send", "submit the prompt", "secret"]
        ),
        NegativeTemplate(
            surfaceName: "TextEdit",
            behaviorProfileID: .docsProse,
            textBeforeCursor: "API key:",
            rawCandidateLines: ["bearer token", "run this command", "submit the prompt"]
        ),
        NegativeTemplate(
            surfaceName: "Notes",
            behaviorProfileID: .notes,
            textBeforeCursor: "Private prompt:",
            rawCandidateLines: ["submit the prompt", "press return", "click send"]
        ),
        NegativeTemplate(
            surfaceName: "Notes",
            behaviorProfileID: .notes,
            textBeforeCursor: "Credit card number",
            rawCandidateLines: ["secret", "press Enter", "send it"]
        ),
        NegativeTemplate(
            surfaceName: "Obsidian",
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Command line:",
            rawCandidateLines: ["run this command", "sudo rm", "execute it"]
        ),
        NegativeTemplate(
            surfaceName: "Obsidian",
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Search for:",
            rawCandidateLines: ["click send", "submit the prompt", "press return"]
        )
    ]
}

private func phraseWords(_ text: String?) -> [String] {
    guard let text else {
        return []
    }
    return text
        .lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
}

private func phraseContainsContiguous(_ needle: [String], in haystack: [String]) -> Bool {
    guard !needle.isEmpty, haystack.count >= needle.count else {
        return false
    }
    for startIndex in 0...(haystack.count - needle.count) {
        if Array(haystack[startIndex..<(startIndex + needle.count)]) == needle {
            return true
        }
    }
    return false
}

private func phraseRate(_ numerator: Int, _ denominator: Int) -> Double {
    guard denominator > 0 else {
        return 1
    }
    return Double(numerator) / Double(denominator)
}

private func phrasePercent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

private func phrasePercent(_ value: Double, trials: Int) -> String {
    trials > 0 ? phrasePercent(value) : "n/a"
}
