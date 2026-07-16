import Foundation
import AutocompleteLabCore

public struct CompletionPredictionEvalCase: Equatable, Sendable {
    public let id: String
    public let surfaceName: String
    public let appBundleIdentifier: String
    public let behaviorProfileID: AutocompleteBehaviorProfileID
    public let textBeforeCursor: String
    public let expectedVisibleText: String?
    public let rawCandidateLines: [String]
    public let useCannedBridge: Bool

    public init(
        id: String,
        surfaceName: String,
        appBundleIdentifier: String,
        behaviorProfileID: AutocompleteBehaviorProfileID,
        textBeforeCursor: String,
        expectedVisibleText: String?,
        rawCandidateLines: [String],
        useCannedBridge: Bool = false
    ) {
        self.id = id
        self.surfaceName = surfaceName
        self.appBundleIdentifier = appBundleIdentifier
        self.behaviorProfileID = behaviorProfileID
        self.textBeforeCursor = textBeforeCursor
        self.expectedVisibleText = expectedVisibleText
        self.rawCandidateLines = rawCandidateLines
        self.useCannedBridge = useCannedBridge
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

    public var usefulSuffix: Bool? {
        guard evalCase.expectsSuggestion else {
            return nil
        }
        return visibleText != nil
            && exactNextWord
            && !overEagerChattyOutput
            && !repetitionFailure
            && !wrongTopicFailure
            && !unsafeSensitiveFailure
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

    public var overEagerChattyOutput: Bool {
        guard let visibleText else {
            return false
        }
        let normalized = visibleText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = normalizedWords(visibleText)
        if visibleText.contains("\n") || words.count > 4 {
            return true
        }
        return Self.chattyFragments.contains { normalized.contains($0) }
    }

    public var repetitionFailure: Bool {
        let outputWords = normalizedWords(visibleText)
        guard !outputWords.isEmpty else {
            return false
        }
        if outputWords.count >= 2 {
            for index in 0..<(outputWords.count - 1) where outputWords[index] == outputWords[index + 1] {
                return true
            }
        }

        let contextWords = normalizedWords(evalCase.textBeforeCursor)
        let maximumLead = min(3, outputWords.count, contextWords.count)
        if maximumLead >= 2 {
            for leadCount in stride(from: maximumLead, through: 2, by: -1) {
                if containsContiguous(Array(outputWords.prefix(leadCount)), in: contextWords) {
                    return true
                }
            }
        }

        return contextWords.last == outputWords.first
    }

    public var wrongTopicFailure: Bool {
        guard evalCase.expectsSuggestion else {
            return visibleText != nil
        }
        let expectedWords = normalizedWords(evalCase.expectedVisibleText)
        let outputWords = normalizedWords(visibleText)
        guard let expectedFirst = expectedWords.first, let outputFirst = outputWords.first else {
            return true
        }
        return expectedFirst != outputFirst
    }

    public var unsafeSensitiveFailure: Bool {
        if unsafeDisplayFailure {
            return true
        }
        guard let visibleText else {
            return false
        }
        let normalized = visibleText.lowercased()
        return Self.unsafeSensitiveFragments.contains { normalized.contains($0) }
    }

    public var userFeelGood: Bool {
        guard evalCase.expectsSuggestion else {
            return visibleText == nil
        }
        return usefulSuffix == true
    }

    private func wordsMatch(prefixCount: Int) -> Bool {
        let expected = normalizedWords(evalCase.expectedVisibleText)
        let actual = normalizedWords(visibleText)
        guard expected.count >= prefixCount, actual.count >= prefixCount else {
            return false
        }

        return Array(expected.prefix(prefixCount)) == Array(actual.prefix(prefixCount))
    }

    private static let chattyFragments = [
        "as an ai",
        "certainly",
        "i can help",
        "i would recommend",
        "i would suggest",
        "one option is",
        "the next step would",
        "you should",
        "let me know",
        "press enter",
        "submit the prompt",
        "run this command"
    ]

    private static let unsafeSensitiveFragments = [
        "api key",
        "bearer token",
        "credit card",
        "password",
        "private key",
        "secret",
        "social security",
        "ssn",
        "submit the prompt",
        "run this command",
        "press enter to send"
    ]
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
    public let usefulSuffixCount: Int
    public let usefulSuffixTrials: Int
    public let expectedSilenceCount: Int
    public let noSuggestionCorrectCount: Int
    public let unsafeDisplayFailureCount: Int
    public let overEagerChattyPassCount: Int
    public let repetitionPassCount: Int
    public let wrongTopicPassCount: Int
    public let unsafeSensitivePassCount: Int
    public let userFeelPassCount: Int

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

    public var usefulSuffixRate: Double {
        rate(usefulSuffixCount, usefulSuffixTrials)
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

    public var overEagerChattyPassRate: Double {
        rate(overEagerChattyPassCount, caseCount)
    }

    public var repetitionPassRate: Double {
        rate(repetitionPassCount, caseCount)
    }

    public var wrongTopicPassRate: Double {
        rate(wrongTopicPassCount, caseCount)
    }

    public var unsafeSensitivePassRate: Double {
        rate(unsafeSensitivePassCount, caseCount)
    }

    public var userFeelPassRate: Double {
        rate(userFeelPassCount, caseCount)
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
        let exactRows = surfaceSummaries.map { summary in
            "| \(summary.surfaceName) | \(summary.shownCount)/\(summary.caseCount) | \(percent(summary.exactNextWordRate, trials: summary.expectedSuggestionCount)) | \(percent(summary.exactPrefix2Rate, trials: summary.exactPrefix2Trials)) | \(percent(summary.exactPrefix3Rate, trials: summary.exactPrefix3Trials)) | \(percent(summary.exactPrefix4Rate, trials: summary.exactPrefix4Trials)) | \(percent(summary.noSuggestionRate, trials: summary.expectedSilenceCount)) | \(summary.unsafeDisplayFailureCount) |"
        }
        .joined(separator: "\n")
        let guardrailRows = surfaceSummaries.map { summary in
            "| \(summary.surfaceName) | \(percent(summary.usefulSuffixRate, trials: summary.usefulSuffixTrials)) | \(percent(summary.overEagerChattyPassRate)) | \(percent(summary.repetitionPassRate)) | \(percent(summary.wrongTopicPassRate)) | \(percent(summary.unsafeSensitivePassRate)) | \(percent(summary.userFeelPassRate)) |"
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
        let cannedBridgeResults = results.filter { $0.selectionSource == "canned-bridge" }
        let modelResults = results.filter { $0.selectionSource == "model-candidate-ranker" }
        let cannedBridgeExact = cannedBridgeResults.filter { $0.evalCase.expectsSuggestion && $0.exactVisibleText }.count
        let modelExact = modelResults.filter { $0.evalCase.expectsSuggestion && $0.exactVisibleText }.count

        return """
        # Completion Prediction Quality Eval - 500 Cases

        Score: \(String(format: "%.1f", score))/100
        Squared score: \(String(format: "%.1f", squaredScore))/10000

        This deterministic harness uses 500 synthetic cases. It checks whether the app's cleaner and ranker pick common next-word and 2-4 word continuations when they are available, plus a small canned-bridge source for generic transitions only. It still suppresses prompt-app, search, form, password, code-like negatives, over-eager/chatty output, repetition, wrong-topic continuations, unsafe/sensitive text, and bad user-feel.

        ## Exactness Summary

        | Surface | Shown | Next word exact | 2-word exact | 3-word exact | 4-word exact | Silence exact | Unsafe displays |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \(exactRows)
        | Total | \(totalSummary.shownCount)/\(totalSummary.caseCount) | \(percent(totalSummary.exactNextWordRate)) | \(percent(totalSummary.exactPrefix2Rate)) | \(percent(totalSummary.exactPrefix3Rate)) | \(percent(totalSummary.exactPrefix4Rate)) | \(percent(totalSummary.noSuggestionRate)) | \(totalSummary.unsafeDisplayFailureCount) |

        ## Guardrail Summary

        | Surface | Useful suffix | Over-eager/chatty ok | Repetition ok | Wrong-topic ok | Unsafe/sensitive ok | User-feel ok |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: |
        \(guardrailRows)
        | Total | \(percent(totalSummary.usefulSuffixRate)) | \(percent(totalSummary.overEagerChattyPassRate)) | \(percent(totalSummary.repetitionPassRate)) | \(percent(totalSummary.wrongTopicPassRate)) | \(percent(totalSummary.unsafeSensitivePassRate)) | \(percent(totalSummary.userFeelPassRate)) |

        ## Source Mix

        - Canned bridge exact: \(cannedBridgeExact)/\(cannedBridgeResults.count)
        - Model candidate ranker exact: \(modelExact)/\(modelResults.filter { $0.evalCase.expectsSuggestion }.count)
        - Canned-bridge positives omit the expected answer from raw model candidates.

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
        if evalCase.useCannedBridge {
            let cannedBridgeSelection = CommonPhraseContinuationPredictor().selection(
                for: evalCase.textBeforeCursor,
                behaviorProfileID: evalCase.behaviorProfileID
            )
            if let suggestion = cannedBridgeSelection.suggestion {
                return CompletionPredictionEvalCaseResult(
                    evalCase: evalCase,
                    visibleText: suggestion.visibleText,
                    candidateCount: 1,
                    candidateTopScore: cannedBridgeSelection.score,
                    candidateScoreMargin: nil,
                    candidateSuppressionReason: cannedBridgeSelection.suppressionReason,
                    selectionSource: "canned-bridge"
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
            usefulSuffixCount: results.filter { $0.usefulSuffix == true }.count,
            usefulSuffixTrials: results.filter { $0.usefulSuffix != nil }.count,
            expectedSilenceCount: results.filter { !$0.evalCase.expectsSuggestion }.count,
            noSuggestionCorrectCount: results.filter { $0.noSuggestionCorrect == true }.count,
            unsafeDisplayFailureCount: results.filter(\.unsafeDisplayFailure).count,
            overEagerChattyPassCount: results.filter { !$0.overEagerChattyOutput }.count,
            repetitionPassCount: results.filter { !$0.repetitionFailure }.count,
            wrongTopicPassCount: results.filter { !$0.wrongTopicFailure }.count,
            unsafeSensitivePassCount: results.filter { !$0.unsafeSensitiveFailure }.count,
            userFeelPassCount: results.filter(\.userFeelGood).count
        )
    }

    private static func score(for summary: CompletionPredictionEvalSurfaceSummary) -> Double {
        let weighted = (
            summary.exactNextWordRate * 0.14
                + summary.usefulSuffixRate * 0.12
                + summary.exactPrefix2Rate * 0.08
                + summary.exactPrefix3Rate * 0.06
                + summary.exactPrefix4Rate * 0.04
                + summary.exactVisibleTextRate * 0.08
                + summary.noSuggestionRate * 0.08
                + summary.overEagerChattyPassRate * 0.09
                + summary.repetitionPassRate * 0.07
                + summary.wrongTopicPassRate * 0.08
                + summary.unsafeSensitivePassRate * 0.08
                + summary.userFeelPassRate * 0.08
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
        let useCannedBridge = index.isMultiple(of: 2)
        return CompletionPredictionEvalCase(
            id: "prediction-\(String(format: "%03d", index))",
            surfaceName: surface.name,
            appBundleIdentifier: surface.appBundleIdentifier,
            behaviorProfileID: surface.behaviorProfileID,
            textBeforeCursor: "\(tone): \(template.textBeforeCursor)",
            expectedVisibleText: " \(template.expectedVisibleText)",
            rawCandidateLines: useCannedBridge
                ? orderedDistractorCandidates(
                    distractors: template.distractors,
                    offset: index
                )
                : orderedCandidates(
                    expected: template.expectedVisibleText,
                    distractors: template.distractors,
                    offset: index
                ),
            useCannedBridge: useCannedBridge
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
        EvalSurface(name: "Obsidian", appBundleIdentifier: "md.obsidian", behaviorProfileID: .notes),
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
        PositiveTemplate(textBeforeCursor: "Sounds good", expectedVisibleText: "to me", distractors: ["for now", "right away"]),
        PositiveTemplate(textBeforeCursor: "That makes sense", expectedVisibleText: "to me", distractors: ["for later", "right now"]),
        PositiveTemplate(textBeforeCursor: "I can take", expectedVisibleText: "a look", distractors: ["more time", "the whole thing"]),
        PositiveTemplate(textBeforeCursor: "Can you please", expectedVisibleText: "take a look", distractors: ["send it now", "open settings"]),
        PositiveTemplate(textBeforeCursor: "Let me know", expectedVisibleText: "what you think", distractors: ["when possible", "submit the prompt"]),
        PositiveTemplate(textBeforeCursor: "We should probably", expectedVisibleText: "keep it simple", distractors: ["make it huge", "open another app"]),
        PositiveTemplate(textBeforeCursor: "It would help to", expectedVisibleText: "make this clearer", distractors: ["add more steps", "run this command"]),
        PositiveTemplate(textBeforeCursor: "Thanks for", expectedVisibleText: "sending this over", distractors: ["checking later", "click send"]),
        PositiveTemplate(textBeforeCursor: "What I need is", expectedVisibleText: "a clearer next step", distractors: ["more noise here", "a bigger plan"]),
        PositiveTemplate(textBeforeCursor: "Next step is", expectedVisibleText: "to make this concrete", distractors: ["press Enter now", "open settings"])
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

private func containsContiguous(_ needle: [String], in haystack: [String]) -> Bool {
    guard !needle.isEmpty, haystack.count >= needle.count else {
        return false
    }

    for startIndex in 0...(haystack.count - needle.count) {
        let endIndex = startIndex + needle.count
        if Array(haystack[startIndex..<endIndex]) == needle {
            return true
        }
    }

    return false
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

private func percent(_ value: Double, trials: Int) -> String {
    trials > 0 ? percent(value) : "n/a"
}
