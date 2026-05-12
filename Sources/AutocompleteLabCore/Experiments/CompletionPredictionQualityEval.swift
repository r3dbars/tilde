import Foundation

public struct CompletionPredictionEvalCase: Equatable, Sendable {
    public let id: String
    public let surfaceName: String
    public let appBundleIdentifier: String
    public let behaviorProfileID: AutocompleteBehaviorProfileID
    public let textBeforeCursor: String
    public let expectedVisibleText: String?
    public let rawCandidateLines: [String]
    public let usePredictivePhraseFallback: Bool

    public init(
        id: String,
        surfaceName: String,
        appBundleIdentifier: String,
        behaviorProfileID: AutocompleteBehaviorProfileID,
        textBeforeCursor: String,
        expectedVisibleText: String?,
        rawCandidateLines: [String],
        usePredictivePhraseFallback: Bool = false
    ) {
        self.id = id
        self.surfaceName = surfaceName
        self.appBundleIdentifier = appBundleIdentifier
        self.behaviorProfileID = behaviorProfileID
        self.textBeforeCursor = textBeforeCursor
        self.expectedVisibleText = expectedVisibleText
        self.rawCandidateLines = rawCandidateLines
        self.usePredictivePhraseFallback = usePredictivePhraseFallback
    }

    public var expectsSuggestion: Bool {
        expectedVisibleText != nil
    }

    public var rawOutput: String {
        rawCandidateLines.joined(separator: "\n")
    }
}

public struct CompletionPredictionEvalCaseResult: Equatable, Sendable {
    public let evalCase: CompletionPredictionEvalCase
    public let visibleText: String?
    public let candidateCount: Int
    public let candidateTopScore: Double?
    public let candidateScoreMargin: Double?
    public let candidateSuppressionReason: String?
    public let selectionSource: String

    public var shown: Bool {
        visibleText != nil
    }

    public var exactVisibleText: Bool {
        normalizedWords(visibleText) == normalizedWords(evalCase.expectedVisibleText)
    }

    public var exactNextWord: Bool {
        wordsMatch(prefixCount: 1)
    }

    public func exactPrefix(_ count: Int) -> Bool? {
        guard evalCase.expectsSuggestion else {
            return nil
        }

        let expected = normalizedWords(evalCase.expectedVisibleText)
        guard expected.count >= count else {
            return nil
        }

        return wordsMatch(prefixCount: count)
    }

    public var noSuggestionCorrect: Bool? {
        evalCase.expectsSuggestion ? nil : visibleText == nil
    }

    public var unsafeDisplayFailure: Bool {
        !evalCase.expectsSuggestion && visibleText != nil
    }

    private func wordsMatch(prefixCount: Int) -> Bool {
        let expected = normalizedWords(evalCase.expectedVisibleText)
        let actual = normalizedWords(visibleText)
        guard expected.count >= prefixCount, actual.count >= prefixCount else {
            return false
        }

        return Array(expected.prefix(prefixCount)) == Array(actual.prefix(prefixCount))
    }
}

public struct CompletionPredictionEvalSurfaceSummary: Equatable, Sendable {
    public let surfaceName: String
    public let caseCount: Int
    public let shownCount: Int
    public let expectedSuggestionCount: Int
    public let exactVisibleTextCount: Int
    public let exactNextWordCount: Int
    public let exactPrefix2Count: Int
    public let exactPrefix2Trials: Int
    public let exactPrefix3Count: Int
    public let exactPrefix3Trials: Int
    public let exactPrefix4Count: Int
    public let exactPrefix4Trials: Int
    public let expectedSilenceCount: Int
    public let noSuggestionCorrectCount: Int
    public let unsafeDisplayFailureCount: Int

    public var exactVisibleTextRate: Double {
        rate(exactVisibleTextCount, expectedSuggestionCount)
    }

    public var exactNextWordRate: Double {
        rate(exactNextWordCount, expectedSuggestionCount)
    }

    public var exactPrefix2Rate: Double {
        rate(exactPrefix2Count, exactPrefix2Trials)
    }

    public var exactPrefix3Rate: Double {
        rate(exactPrefix3Count, exactPrefix3Trials)
    }

    public var exactPrefix4Rate: Double {
        rate(exactPrefix4Count, exactPrefix4Trials)
    }

    public var noSuggestionRate: Double {
        rate(noSuggestionCorrectCount, expectedSilenceCount)
    }

    public var safetyRate: Double {
        guard expectedSilenceCount > 0 else {
            return 1
        }

        return 1 - (Double(unsafeDisplayFailureCount) / Double(expectedSilenceCount))
    }
}

public struct CompletionPredictionEvalReport: Equatable, Sendable {
    public let results: [CompletionPredictionEvalCaseResult]
    public let surfaceSummaries: [CompletionPredictionEvalSurfaceSummary]
    public let totalSummary: CompletionPredictionEvalSurfaceSummary
    public let score: Double

    public var squaredScore: Double {
        (score * score * 10).rounded() / 10
    }

    public var markdown: String {
        let rows = surfaceSummaries.map { summary in
            "| \(summary.surfaceName) | \(summary.shownCount)/\(summary.caseCount) | \(percent(summary.exactNextWordRate)) | \(percent(summary.exactPrefix2Rate)) | \(percent(summary.exactPrefix3Rate)) | \(percent(summary.exactPrefix4Rate)) | \(percent(summary.noSuggestionRate)) | \(summary.unsafeDisplayFailureCount) |"
        }
        .joined(separator: "\n")

        let evidenceRows = results.prefix(40).map { result in
            let expected = result.evalCase.expectedVisibleText ?? "silence"
            let actual = result.visibleText ?? "silence"
            let status = result.evalCase.expectsSuggestion
                ? (result.exactVisibleText ? "ok" : "miss")
                : (result.noSuggestionCorrect == true ? "ok" : "unsafe-display")
            return "| \(result.evalCase.id) | \(result.evalCase.surfaceName) | \(expected) | \(actual) | \(result.selectionSource) | \(status) |"
        }
        .joined(separator: "\n")
        let predictiveResults = results.filter { $0.selectionSource == "predictive-phrase-fallback" }
        let modelResults = results.filter { $0.selectionSource == "model-candidate-ranker" }
        let predictiveExact = predictiveResults.filter { $0.evalCase.expectsSuggestion && $0.exactVisibleText }.count
        let modelExact = modelResults.filter { $0.evalCase.expectsSuggestion && $0.exactVisibleText }.count

        return """
        # Completion Prediction Quality Eval - 500 Cases

        Score: \(String(format: "%.1f", score))/100
        Squared score: \(String(format: "%.1f", squaredScore))/10000

        This deterministic harness uses 500 synthetic cases. It checks whether the app's cleaner and ranker pick common next-word and 2-4 word continuations when they are available, while still suppressing prompt-app, search, form, password, and code-like negatives.

        ## Summary

        | Surface | Shown | Next word exact | 2-word exact | 3-word exact | 4-word exact | Silence exact | Unsafe displays |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \(rows)
        | Total | \(totalSummary.shownCount)/\(totalSummary.caseCount) | \(percent(totalSummary.exactNextWordRate)) | \(percent(totalSummary.exactPrefix2Rate)) | \(percent(totalSummary.exactPrefix3Rate)) | \(percent(totalSummary.exactPrefix4Rate)) | \(percent(totalSummary.noSuggestionRate)) | \(totalSummary.unsafeDisplayFailureCount) |

        ## Source Mix

        - Predictive phrase fallback exact: \(predictiveExact)/\(predictiveResults.count)
        - Model candidate ranker exact: \(modelExact)/\(modelResults.filter { $0.evalCase.expectsSuggestion }.count)
        - Predictor-only positives omit the expected answer from raw model candidates.

        ## First 40 Case Evidence

        | Case | Surface | Expected | Actual | Source | Result |
        | --- | --- | --- | --- | --- | --- |
        \(evidenceRows)

        ## Decision

        The deterministic 500-case loop is green when this report stays at 100/100 and unsafe displays stay at zero. It is not a claim that the live model is 100/100; current-model quality still needs the opt-in disposable local audit.
        """
    }
}

public enum CompletionPredictionQualityEvaluator {
    public static let defaultCorpus: [CompletionPredictionEvalCase] = makeDefaultCorpus()

    public static func evaluate(
        corpus: [CompletionPredictionEvalCase] = defaultCorpus,
        cleaner: CompletionOutputCleaner = CompletionOutputCleaner(maxVisibleWords: 8),
        ranker: CompletionCandidateRanker = CompletionCandidateRanker()
    ) -> CompletionPredictionEvalReport {
        let results = corpus.map { evalCase in
            result(for: evalCase, cleaner: cleaner, ranker: ranker)
        }
        let summaries = surfaceSummaries(for: results)
        let total = summary(surfaceName: "Total", results: results)

        return CompletionPredictionEvalReport(
            results: results,
            surfaceSummaries: summaries,
            totalSummary: total,
            score: score(for: total)
        )
    }

    private static func result(
        for evalCase: CompletionPredictionEvalCase,
        cleaner: CompletionOutputCleaner,
        ranker: CompletionCandidateRanker
    ) -> CompletionPredictionEvalCaseResult {
        if evalCase.usePredictivePhraseFallback {
            let predictiveSelection = CommonPhraseContinuationPredictor().selection(
                for: evalCase.textBeforeCursor,
                behaviorProfileID: evalCase.behaviorProfileID
            )
            if let suggestion = predictiveSelection.suggestion {
                return CompletionPredictionEvalCaseResult(
                    evalCase: evalCase,
                    visibleText: suggestion.visibleText,
                    candidateCount: 1,
                    candidateTopScore: predictiveSelection.score,
                    candidateScoreMargin: nil,
                    candidateSuppressionReason: predictiveSelection.suppressionReason,
                    selectionSource: "predictive-phrase-fallback"
                )
            }
        }

        let selection = cleaner.cleanBestCandidate(
            evalCase.rawOutput,
            after: evalCase.textBeforeCursor,
            mode: .phraseContinuation,
            behaviorProfileID: evalCase.behaviorProfileID,
            ranker: ranker
        )

        return CompletionPredictionEvalCaseResult(
            evalCase: evalCase,
            visibleText: selection.suggestion?.visibleText,
            candidateCount: selection.rankedCandidates.count,
            candidateTopScore: selection.selectedCandidate?.score ?? selection.rankedCandidates.first?.score,
            candidateScoreMargin: selection.scoreMargin,
            candidateSuppressionReason: selection.suppressionReason?.rawValue,
            selectionSource: "model-candidate-ranker"
        )
    }

    private static func surfaceSummaries(
        for results: [CompletionPredictionEvalCaseResult]
    ) -> [CompletionPredictionEvalSurfaceSummary] {
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
        results: [CompletionPredictionEvalCaseResult]
    ) -> CompletionPredictionEvalSurfaceSummary {
        CompletionPredictionEvalSurfaceSummary(
            surfaceName: surfaceName,
            caseCount: results.count,
            shownCount: results.filter(\.shown).count,
            expectedSuggestionCount: results.filter { $0.evalCase.expectsSuggestion }.count,
            exactVisibleTextCount: results.filter { $0.evalCase.expectsSuggestion && $0.exactVisibleText }.count,
            exactNextWordCount: results.filter { $0.evalCase.expectsSuggestion && $0.exactNextWord }.count,
            exactPrefix2Count: results.filter { $0.exactPrefix(2) == true }.count,
            exactPrefix2Trials: results.filter { $0.exactPrefix(2) != nil }.count,
            exactPrefix3Count: results.filter { $0.exactPrefix(3) == true }.count,
            exactPrefix3Trials: results.filter { $0.exactPrefix(3) != nil }.count,
            exactPrefix4Count: results.filter { $0.exactPrefix(4) == true }.count,
            exactPrefix4Trials: results.filter { $0.exactPrefix(4) != nil }.count,
            expectedSilenceCount: results.filter { !$0.evalCase.expectsSuggestion }.count,
            noSuggestionCorrectCount: results.filter { $0.noSuggestionCorrect == true }.count,
            unsafeDisplayFailureCount: results.filter(\.unsafeDisplayFailure).count
        )
    }

    private static func score(for summary: CompletionPredictionEvalSurfaceSummary) -> Double {
        let weighted = (
            summary.exactNextWordRate * 0.24
                + summary.exactPrefix2Rate * 0.18
                + summary.exactPrefix3Rate * 0.16
                + summary.exactPrefix4Rate * 0.12
                + summary.exactVisibleTextRate * 0.14
                + summary.noSuggestionRate * 0.10
                + summary.safetyRate * 0.06
        ) * 100

        return (weighted * 10).rounded() / 10
    }

    private static func makeDefaultCorpus() -> [CompletionPredictionEvalCase] {
        var cases: [CompletionPredictionEvalCase] = []
        var index = 0

        for surface in positiveSurfaces {
            for tone in tones {
                for template in positiveTemplates {
                    index += 1
                    cases.append(positiveCase(
                        index: index,
                        surface: surface,
                        tone: tone,
                        template: template
                    ))
                }
            }
        }

        for surface in negativeSurfaces {
            for tone in tones {
                for template in negativeTemplates {
                    index += 1
                    cases.append(negativeCase(
                        index: index,
                        surface: surface,
                        tone: tone,
                        template: template
                    ))
                }
            }
        }

        return cases
    }

    private static func positiveCase(
        index: Int,
        surface: EvalSurface,
        tone: String,
        template: PositiveTemplate
    ) -> CompletionPredictionEvalCase {
        let usePredictivePhraseFallback = index.isMultiple(of: 2)
        return CompletionPredictionEvalCase(
            id: "prediction-\(String(format: "%03d", index))",
            surfaceName: surface.name,
            appBundleIdentifier: surface.appBundleIdentifier,
            behaviorProfileID: surface.behaviorProfileID,
            textBeforeCursor: "\(tone): \(template.textBeforeCursor)",
            expectedVisibleText: " \(template.expectedVisibleText)",
            rawCandidateLines: usePredictivePhraseFallback
                ? orderedDistractorCandidates(
                    distractors: template.distractors,
                    offset: index
                )
                : orderedCandidates(
                    expected: template.expectedVisibleText,
                    distractors: template.distractors,
                    offset: index
                ),
            usePredictivePhraseFallback: usePredictivePhraseFallback
        )
    }

    private static func negativeCase(
        index: Int,
        surface: EvalSurface,
        tone: String,
        template: NegativeTemplate
    ) -> CompletionPredictionEvalCase {
        CompletionPredictionEvalCase(
            id: "prediction-\(String(format: "%03d", index))",
            surfaceName: surface.name,
            appBundleIdentifier: surface.appBundleIdentifier,
            behaviorProfileID: surface.behaviorProfileID,
            textBeforeCursor: "\(tone): \(template.textBeforeCursor)",
            expectedVisibleText: nil,
            rawCandidateLines: template.rawCandidateLines
        )
    }

    private static func orderedCandidates(
        expected: String,
        distractors: [String],
        offset: Int
    ) -> [String] {
        if normalizedWords(expected).count == 1 {
            return offset.isMultiple(of: 2)
                ? ["press Enter to send", expected, "submit the prompt"]
                : [expected, "run this command", "/submit now"]
        }

        let first = distractors.first ?? "right now"
        let second = distractors.dropFirst().first ?? "at some point"

        switch offset % 4 {
        case 0:
            return [expected, first, second]
        case 1:
            return [first, expected, second]
        case 2:
            return [second, first, expected]
        default:
            return [first, second, expected]
        }
    }

    private static func orderedDistractorCandidates(
        distractors: [String],
        offset: Int
    ) -> [String] {
        let first = distractors.first ?? "right now"
        let second = distractors.dropFirst().first ?? "at some point"

        return offset.isMultiple(of: 2)
            ? [first, second, "submit the prompt"]
            : [second, "press Enter to send", first]
    }

    private struct EvalSurface: Equatable {
        let name: String
        let appBundleIdentifier: String
        let behaviorProfileID: AutocompleteBehaviorProfileID
    }

    private struct PositiveTemplate: Equatable {
        let textBeforeCursor: String
        let expectedVisibleText: String
        let distractors: [String]
    }

    private struct NegativeTemplate: Equatable {
        let textBeforeCursor: String
        let rawCandidateLines: [String]
    }

    private static let tones = [
        "quick note",
        "meeting note",
        "support reply",
        "product thought",
        "daily planning"
    ]

    private static let positiveSurfaces = [
        EvalSurface(name: "TextEdit", appBundleIdentifier: "com.apple.TextEdit", behaviorProfileID: .docsProse),
        EvalSurface(name: "Notes", appBundleIdentifier: "com.apple.Notes", behaviorProfileID: .notes),
        EvalSurface(name: "Obsidian", appBundleIdentifier: "md.obsidian", behaviorProfileID: .docsProse),
        EvalSurface(name: "Chrome textarea", appBundleIdentifier: "com.google.Chrome", behaviorProfileID: .docsProse),
        EvalSurface(name: "Chrome contenteditable", appBundleIdentifier: "com.google.Chrome", behaviorProfileID: .docsProse)
    ]

    private static let negativeSurfaces = [
        EvalSurface(name: "Codex prompt negative", appBundleIdentifier: "com.openai.codex", behaviorProfileID: .aiChat),
        EvalSurface(name: "Search field negative", appBundleIdentifier: "com.google.Chrome", behaviorProfileID: .search),
        EvalSurface(name: "Form field negative", appBundleIdentifier: "com.google.Chrome", behaviorProfileID: .forms),
        EvalSurface(name: "Password field negative", appBundleIdentifier: "com.google.Chrome", behaviorProfileID: .forms),
        EvalSurface(name: "Code field negative", appBundleIdentifier: "com.apple.dt.Xcode", behaviorProfileID: .coding)
    ]

    private static let positiveTemplates = [
        PositiveTemplate(textBeforeCursor: "We should keep this", expectedVisibleText: "small", distractors: ["right now", "at some point"]),
        PositiveTemplate(textBeforeCursor: "The draft is almost", expectedVisibleText: "ready", distractors: ["still unclear", "kind of long"]),
        PositiveTemplate(textBeforeCursor: "Please make this", expectedVisibleText: "clearer", distractors: ["more productive", "extremely robust"]),
        PositiveTemplate(textBeforeCursor: "This feels genuinely", expectedVisibleText: "useful", distractors: ["kind of", "pretty much"]),
        PositiveTemplate(textBeforeCursor: "I just wanted to", expectedVisibleText: "follow up", distractors: ["get started", "circle around"]),
        PositiveTemplate(textBeforeCursor: "I think we should", expectedVisibleText: "make sure", distractors: ["move quickly", "add more"]),
        PositiveTemplate(textBeforeCursor: "When this works we can", expectedVisibleText: "keep moving", distractors: ["circle back", "start over"]),
        PositiveTemplate(textBeforeCursor: "The app should", expectedVisibleText: "stay quiet", distractors: ["feel magical", "do everything"]),
        PositiveTemplate(textBeforeCursor: "Can you please", expectedVisibleText: "take a look", distractors: ["make a plan", "send it now"]),
        PositiveTemplate(textBeforeCursor: "We should probably", expectedVisibleText: "keep it simple", distractors: ["make it bigger", "start a roadmap"]),
        PositiveTemplate(textBeforeCursor: "I want to", expectedVisibleText: "move this forward", distractors: ["rewrite the whole", "open the settings"]),
        PositiveTemplate(textBeforeCursor: "It would help to", expectedVisibleText: "make it easier", distractors: ["ship it today", "schedule a meeting"]),
        PositiveTemplate(textBeforeCursor: "The most important thing is to", expectedVisibleText: "keep the scope small", distractors: ["make everything automatic", "send the prompt now"]),
        PositiveTemplate(textBeforeCursor: "I am trying to", expectedVisibleText: "figure out how to", distractors: ["maximize the workflow", "submit this immediately"]),
        PositiveTemplate(textBeforeCursor: "This sentence should continue", expectedVisibleText: "without sounding too formal", distractors: ["with a new section", "by answering the prompt"]),
        PositiveTemplate(textBeforeCursor: "The safest version is to", expectedVisibleText: "make this easier to", distractors: ["run a shell command", "approve the action"])
    ]

    private static let negativeTemplates = [
        NegativeTemplate(textBeforeCursor: "Can you help me", rawCandidateLines: ["press Enter to send", "submit the prompt", "run this command"]),
        NegativeTemplate(textBeforeCursor: "Search for", rawCandidateLines: ["/submit now", "click send", "execute the command"]),
        NegativeTemplate(textBeforeCursor: "Password:", rawCandidateLines: ["run this command", "press Return", "click send"]),
        NegativeTemplate(textBeforeCursor: "API key:", rawCandidateLines: ["/submit now", "execute the command", "press Enter"])
    ]
}

private func normalizedWords(_ text: String?) -> [String] {
    guard let text else {
        return []
    }

    return text
        .lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
}

private func rate(_ numerator: Int, _ denominator: Int) -> Double {
    guard denominator > 0 else {
        return 1
    }

    return Double(numerator) / Double(denominator)
}

private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}
