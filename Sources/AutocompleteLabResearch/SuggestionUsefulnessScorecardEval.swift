import Foundation
import AutocompleteLabCore

struct SuggestionUsefulnessScorecardCase: Equatable, Sendable {
    enum Source: String, Equatable, Sendable {
        case modelCandidateRanker = "model-candidate-ranker"
        case cannedBridge = "canned-bridge"
        case docLocalNGram = "doc-local-ngram"
        case wordCompletion = "word-completion"
    }

    let id: String
    let source: Source
    let behaviorProfileID: AutocompleteBehaviorProfileID
    let textBeforeCursor: String
    let rawCandidateLines: [String]
    let localContextTexts: [String]
    let recentWords: [String]
    let expectedVisibleText: String?
    let expectedMeaningTerms: [String]
    let maxVisibleWords: Int

    init(
        id: String,
        source: Source,
        behaviorProfileID: AutocompleteBehaviorProfileID,
        textBeforeCursor: String,
        rawCandidateLines: [String] = [],
        localContextTexts: [String] = [],
        recentWords: [String] = [],
        expectedVisibleText: String?,
        expectedMeaningTerms: [String] = [],
        maxVisibleWords: Int = 4
    ) {
        self.id = id
        self.source = source
        self.behaviorProfileID = behaviorProfileID
        self.textBeforeCursor = textBeforeCursor
        self.rawCandidateLines = rawCandidateLines
        self.localContextTexts = localContextTexts
        self.recentWords = recentWords
        self.expectedVisibleText = expectedVisibleText
        self.expectedMeaningTerms = expectedMeaningTerms
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    var expectsSuggestion: Bool {
        expectedVisibleText != nil || !expectedMeaningTerms.isEmpty
    }

    var rawOutput: String {
        rawCandidateLines.joined(separator: "\n")
    }
}

struct SuggestionUsefulnessScorecardCaseResult: Equatable, Sendable {
    let evalCase: SuggestionUsefulnessScorecardCase
    let visibleText: String?
    let selectionSource: String
    let suppressionReason: String?

    var shown: Bool {
        visibleText != nil
    }

    var usefulPassed: Bool {
        guard evalCase.expectsSuggestion else {
            return visibleText == nil
        }
        guard let visibleText else {
            return false
        }
        if let expectedVisibleText = evalCase.expectedVisibleText {
            return normalizedPhrase(visibleText) == normalizedPhrase(expectedVisibleText)
        }

        let outputWords = Set(normalizedWords(visibleText))
        let requiredHits = min(2, evalCase.expectedMeaningTerms.count)
        let hits = evalCase.expectedMeaningTerms
            .map { $0.lowercased() }
            .filter { outputWords.contains($0) }
            .count
        return hits >= requiredHits
    }

    var shortPassed: Bool {
        guard evalCase.expectsSuggestion else {
            return visibleText == nil
        }
        guard let visibleText else {
            return false
        }
        if evalCase.source == .wordCompletion {
            let trimmed = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.contains(where: \.isWhitespace) && trimmed.count <= 12
        }

        let wordCount = normalizedWords(visibleText).count
        return (1...evalCase.maxVisibleWords).contains(wordCount)
    }

    var nonRepetitivePassed: Bool {
        guard evalCase.expectsSuggestion else {
            return visibleText == nil
        }
        guard let visibleText else {
            return false
        }

        let outputWords = normalizedWords(visibleText)
        guard !outputWords.isEmpty else {
            return false
        }
        if zip(outputWords, outputWords.dropFirst()).contains(where: ==) {
            return false
        }
        if evalCase.source == .wordCompletion {
            return true
        }

        let contextWords = normalizedWords(evalCase.textBeforeCursor)
        let maximumLead = min(3, outputWords.count, contextWords.count)
        guard maximumLead >= 2 else {
            return true
        }
        for leadCount in stride(from: maximumLead, through: 2, by: -1) {
            let leadPhrase = Array(outputWords.prefix(leadCount))
            if containsContiguous(leadPhrase, in: contextWords) {
                return false
            }
        }
        return contextWords.last != outputWords.first
    }

    var safePassed: Bool {
        guard let visibleText else {
            return !evalCase.expectsSuggestion
        }

        let normalized = normalizedPhrase(visibleText)
        return !Self.unsafeFragments.contains { normalized.contains($0) }
    }

    var acceptWorthy: Bool {
        usefulPassed && shortPassed && nonRepetitivePassed && safePassed
    }

    private static let unsafeFragments = [
        "api key",
        "bearer token",
        "click send",
        "credit card",
        "password",
        "press enter",
        "press return",
        "press tab",
        "private key",
        "run this command",
        "secret",
        "send the prompt",
        "submit the prompt"
    ]
}

struct SuggestionUsefulnessSourceSummary: Equatable, Sendable {
    let source: String
    let caseCount: Int
    let expectedSuggestionCount: Int
    let shownCount: Int
    let usefulPassCount: Int
    let shortPassCount: Int
    let nonRepetitivePassCount: Int
    let safePassCount: Int
    let acceptWorthyCount: Int

    var passRate: Double {
        scorecardRate(acceptWorthyCount, caseCount)
    }
}

struct SuggestionUsefulnessGateResult: Equatable, Sendable {
    let id: String
    let label: String
    let passed: Bool
}

struct SuggestionUsefulnessScorecardReport: Equatable, Sendable {
    let results: [SuggestionUsefulnessScorecardCaseResult]
    let sourceSummaries: [SuggestionUsefulnessSourceSummary]
    let totalSummary: SuggestionUsefulnessSourceSummary
    let gateResults: [SuggestionUsefulnessGateResult]

    var score: Double {
        let passed = totalSummary.acceptWorthyCount + gateResults.filter(\.passed).count
        let total = totalSummary.caseCount + gateResults.count
        return (scorecardRate(passed, total) * 100).rounded()
    }

    var markdown: String {
        let sourceRows = sourceSummaries.map { summary in
            "| \(summary.source) | \(summary.acceptWorthyCount)/\(summary.caseCount) | \(summary.shownCount)/\(summary.expectedSuggestionCount) | \(summary.usefulPassCount)/\(summary.caseCount) | \(summary.shortPassCount)/\(summary.caseCount) | \(summary.nonRepetitivePassCount)/\(summary.caseCount) | \(summary.safePassCount)/\(summary.caseCount) |"
        }
        .joined(separator: "\n")
        let caseRows = results.map { result in
            let actual = result.visibleText ?? "silence"
            let status = result.acceptWorthy ? "pass" : "miss"
            return "| \(result.evalCase.id) | \(result.selectionSource) | \(actual) | \(result.usefulPassed ? "yes" : "no") | \(result.shortPassed ? "yes" : "no") | \(result.nonRepetitivePassed ? "yes" : "no") | \(result.safePassed ? "yes" : "no") | \(status) |"
        }
        .joined(separator: "\n")
        let gateRows = gateResults.map { result in
            "| \(result.id) | \(result.label) | \(result.passed ? "pass" : "fail") |"
        }
        .joined(separator: "\n")

        return """
        # Suggestion Usefulness Scorecard - 20 Synthetic Cases

        Score: \(String(format: "%.0f", score))/100

        This deterministic harness uses synthetic, disposable writing situations only. It asks whether the current local suggestion stack produces text that is useful, short, non-repetitive, safe, and quiet enough to avoid obvious annoyance.

        ## Summary

        - Candidate rows scored: \(totalSummary.caseCount).
        - Display-eligible rows: \(totalSummary.expectedSuggestionCount).
        - Shown suggestions: \(totalSummary.shownCount)/\(totalSummary.expectedSuggestionCount).
        - Useful suggestions: \(totalSummary.usefulPassCount)/\(totalSummary.caseCount).
        - Short suggestions: \(totalSummary.shortPassCount)/\(totalSummary.caseCount).
        - Non-repetitive suggestions: \(totalSummary.nonRepetitivePassCount)/\(totalSummary.caseCount).
        - Safe or suppressed rows: \(totalSummary.safePassCount)/\(totalSummary.caseCount).
        - Non-annoyance gates: \(gateResults.filter(\.passed).count)/\(gateResults.count).

        | Source | Accept-worthy | Shown | Useful | Short | Non-repetitive | Safe |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: |
        \(sourceRows)
        | Total | \(totalSummary.acceptWorthyCount)/\(totalSummary.caseCount) | \(totalSummary.shownCount)/\(totalSummary.expectedSuggestionCount) | \(totalSummary.usefulPassCount)/\(totalSummary.caseCount) | \(totalSummary.shortPassCount)/\(totalSummary.caseCount) | \(totalSummary.nonRepetitivePassCount)/\(totalSummary.caseCount) | \(totalSummary.safePassCount)/\(totalSummary.caseCount) |

        ## Case Evidence

        | Case | Source | Actual | Useful | Short | Non-repetitive | Safe | Result |
        | --- | --- | --- | --- | --- | --- | --- | --- |
        \(caseRows)

        ## Non-Annoyance Gates

        | Gate | What it proves | Result |
        | --- | --- | --- |
        \(gateRows)

        ## Decision

        This scorecard is green when the score stays at 100/100, every source remains accept-worthy, expected suppressions stay silent, and all non-annoyance gates pass. It is deterministic harness proof, not private dogfood or live model telemetry.
        """
    }
}

enum SuggestionUsefulnessScorecardEvaluator {
    static let defaultCorpus: [SuggestionUsefulnessScorecardCase] = [
        SuggestionUsefulnessScorecardCase(
            id: "model-meeting-next-step",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The meeting notes need a",
            rawCandidateLines: ["clear next step", "press Enter to send", "robust impressive plan"],
            expectedVisibleText: " clear next step",
            expectedMeaningTerms: ["clear", "next", "step"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-review-risk",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The review should focus on",
            rawCandidateLines: ["real user risk", "kind of", "submit the prompt"],
            expectedVisibleText: " real user risk",
            expectedMeaningTerms: ["real", "user", "risk"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-simple-moves-forward",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The draft says simple simple, so the next words should",
            rawCandidateLines: ["move it forward", "simple simple again", "you should rewrite this"],
            expectedVisibleText: " move it forward",
            expectedMeaningTerms: ["move", "forward"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-small-check",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Before we ship, we should",
            rawCandidateLines: ["run one small check", "run this command", "press Enter"],
            expectedVisibleText: " run one small check",
            expectedMeaningTerms: ["run", "small", "check"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-product-change",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The product update should mention",
            rawCandidateLines: ["one clear change", "key features and benefits", "click send"],
            expectedVisibleText: " one clear change",
            expectedMeaningTerms: ["one", "clear", "change"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-open-questions",
            source: .modelCandidateRanker,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "After the demo, capture the",
            rawCandidateLines: ["open questions quickly", "calendar invite", "submit it"],
            expectedVisibleText: " open questions quickly",
            expectedMeaningTerms: ["open", "questions", "quickly"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-password-silence",
            source: .modelCandidateRanker,
            behaviorProfileID: .forms,
            textBeforeCursor: "Password:",
            rawCandidateLines: ["secret", "press Enter", "api key"],
            expectedVisibleText: nil
        ),
        SuggestionUsefulnessScorecardCase(
            id: "model-search-silence",
            source: .modelCandidateRanker,
            behaviorProfileID: .search,
            textBeforeCursor: "Search for:",
            rawCandidateLines: ["nearby pizza", "click send", "submit the prompt"],
            expectedVisibleText: nil
        ),
        SuggestionUsefulnessScorecardCase(
            id: "bridge-take-look",
            source: .cannedBridge,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Can you please",
            expectedVisibleText: " take a look",
            expectedMeaningTerms: ["take", "look"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "bridge-keep-simple",
            source: .cannedBridge,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "We should probably",
            expectedVisibleText: " keep it simple",
            expectedMeaningTerms: ["keep", "simple"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "bridge-what-think",
            source: .cannedBridge,
            behaviorProfileID: .notes,
            textBeforeCursor: "Let me know",
            expectedVisibleText: " what you think",
            expectedMeaningTerms: ["what", "think"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "bridge-follow-up",
            source: .cannedBridge,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "I just wanted to",
            expectedVisibleText: " follow up",
            expectedMeaningTerms: ["follow", "up"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "doc-local-release-note",
            source: .docLocalNGram,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Release note should",
            localContextTexts: ["Release note should name one clear change before launch"],
            expectedVisibleText: " name one clear change",
            expectedMeaningTerms: ["name", "clear", "change"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "doc-local-trust-section",
            source: .docLocalNGram,
            behaviorProfileID: .notes,
            textBeforeCursor: "The trust section should",
            localContextTexts: ["The trust section should stay short and honest"],
            expectedVisibleText: " stay short and honest",
            expectedMeaningTerms: ["stay", "short", "honest"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "doc-local-demo",
            source: .docLocalNGram,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "After the demo capture",
            localContextTexts: ["After the demo capture open questions quickly"],
            expectedVisibleText: " open questions quickly",
            expectedMeaningTerms: ["open", "questions", "quickly"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "doc-local-proof-row",
            source: .docLocalNGram,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The proof row should",
            localContextTexts: ["The proof row should include source and result"],
            expectedVisibleText: " include source and result",
            expectedMeaningTerms: ["include", "source", "result"]
        ),
        SuggestionUsefulnessScorecardCase(
            id: "word-transcripted",
            source: .wordCompletion,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Use Transcrip",
            recentWords: ["Transcripted"],
            expectedVisibleText: "ted"
        ),
        SuggestionUsefulnessScorecardCase(
            id: "word-permission",
            source: .wordCompletion,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Screen permis",
            recentWords: ["permission"],
            expectedVisibleText: "sion"
        ),
        SuggestionUsefulnessScorecardCase(
            id: "word-reliable",
            source: .wordCompletion,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "The overlay should feel reliab",
            recentWords: ["reliable"],
            expectedVisibleText: "le"
        ),
        SuggestionUsefulnessScorecardCase(
            id: "word-instant",
            source: .wordCompletion,
            behaviorProfileID: .docsProse,
            textBeforeCursor: "Writing feels inst",
            recentWords: ["instant"],
            expectedVisibleText: "ant"
        )
    ]

    static func evaluate(
        corpus: [SuggestionUsefulnessScorecardCase] = defaultCorpus,
        cleaner: CompletionOutputCleaner = CompletionOutputCleaner(maxVisibleWords: 8),
        ranker: CompletionCandidateRanker = CompletionCandidateRanker(),
        bridgePredictor: CommonPhraseContinuationPredictor = CommonPhraseContinuationPredictor(),
        ngramPredictor: DocLocalNGramPhrasePredictor = DocLocalNGramPhrasePredictor(),
        wordRanker: WordCompletionCandidateRanker = WordCompletionCandidateRanker()
    ) -> SuggestionUsefulnessScorecardReport {
        let results = corpus.map { evalCase in
            result(
                for: evalCase,
                cleaner: cleaner,
                ranker: ranker,
                bridgePredictor: bridgePredictor,
                ngramPredictor: ngramPredictor,
                wordRanker: wordRanker
            )
        }
        let sourceSummaries = sourceSummaries(for: results)
        return SuggestionUsefulnessScorecardReport(
            results: results,
            sourceSummaries: sourceSummaries,
            totalSummary: summary(source: "Total", results: results),
            gateResults: gateResults()
        )
    }

    private static func result(
        for evalCase: SuggestionUsefulnessScorecardCase,
        cleaner: CompletionOutputCleaner,
        ranker: CompletionCandidateRanker,
        bridgePredictor: CommonPhraseContinuationPredictor,
        ngramPredictor: DocLocalNGramPhrasePredictor,
        wordRanker: WordCompletionCandidateRanker
    ) -> SuggestionUsefulnessScorecardCaseResult {
        switch evalCase.source {
        case .modelCandidateRanker:
            let selection = cleaner.cleanBestCandidate(
                evalCase.rawOutput,
                after: evalCase.textBeforeCursor,
                mode: .phraseContinuation,
                behaviorProfileID: evalCase.behaviorProfileID,
                ranker: ranker
            )
            return SuggestionUsefulnessScorecardCaseResult(
                evalCase: evalCase,
                visibleText: selection.suggestion?.visibleText,
                selectionSource: evalCase.source.rawValue,
                suppressionReason: selection.suppressionReason?.rawValue
            )
        case .cannedBridge:
            let selection = bridgePredictor.selection(
                for: evalCase.textBeforeCursor,
                behaviorProfileID: evalCase.behaviorProfileID,
                maxVisibleWords: evalCase.maxVisibleWords
            )
            return SuggestionUsefulnessScorecardCaseResult(
                evalCase: evalCase,
                visibleText: selection.suggestion?.visibleText,
                selectionSource: selection.candidateSelectionSource,
                suppressionReason: selection.suppressionReason
            )
        case .docLocalNGram:
            let selection = ngramPredictor.selection(
                for: evalCase.textBeforeCursor,
                localContextTexts: evalCase.localContextTexts,
                behaviorProfileID: evalCase.behaviorProfileID,
                maxVisibleWords: evalCase.maxVisibleWords
            )
            return SuggestionUsefulnessScorecardCaseResult(
                evalCase: evalCase,
                visibleText: selection.suggestion?.visibleText,
                selectionSource: selection.candidateSelectionSource,
                suppressionReason: selection.suppressionReason
            )
        case .wordCompletion:
            let researchRanker = WordCompletionCandidateRanker(
                staticWords: evalCase.recentWords + wordRanker.staticWords
            )
            let selection = researchRanker.selection(for: evalCase.textBeforeCursor)
            return SuggestionUsefulnessScorecardCaseResult(
                evalCase: evalCase,
                visibleText: selection.suggestion?.visibleText,
                selectionSource: selection.selectionSource,
                suppressionReason: selection.suppressionReason
            )
        }
    }

    private static func sourceSummaries(
        for results: [SuggestionUsefulnessScorecardCaseResult]
    ) -> [SuggestionUsefulnessSourceSummary] {
        let grouped = Dictionary(grouping: results) { $0.evalCase.source.rawValue }
        return grouped.keys.sorted().compactMap { source in
            guard let sourceResults = grouped[source] else {
                return nil
            }
            return summary(source: source, results: sourceResults)
        }
    }

    private static func summary(
        source: String,
        results: [SuggestionUsefulnessScorecardCaseResult]
    ) -> SuggestionUsefulnessSourceSummary {
        SuggestionUsefulnessSourceSummary(
            source: source,
            caseCount: results.count,
            expectedSuggestionCount: results.filter { $0.evalCase.expectsSuggestion }.count,
            shownCount: results.filter { $0.evalCase.expectsSuggestion && $0.shown }.count,
            usefulPassCount: results.filter(\.usefulPassed).count,
            shortPassCount: results.filter(\.shortPassed).count,
            nonRepetitivePassCount: results.filter(\.nonRepetitivePassed).count,
            safePassCount: results.filter(\.safePassed).count,
            acceptWorthyCount: results.filter(\.acceptWorthy).count
        )
    }

    private static func gateResults() -> [SuggestionUsefulnessGateResult] {
        var results: [SuggestionUsefulnessGateResult] = []
        let policy = DisplayScorePolicy()
        let riskyDecision = policy.decision(
            for: DisplayScore(
                utility: 1.00,
                styleFit: 1.00,
                contextFit: 1.00,
                userAffinity: 1.00,
                risk: 0.90,
                repetition: 0.00,
                instability: 0.00
            ),
            mode: .phraseContinuation
        )
        results.append(SuggestionUsefulnessGateResult(
            id: "display-high-risk",
            label: "high risk is suppressed before display",
            passed: !riskyDecision.shouldDisplay
                && riskyDecision.metadata["displayScoreSuppressionReason"] == "high-risk"
        ))

        let oneBrainRiskDecision = policy.decision(
            for: DisplayScore(
                utility: 1.00,
                styleFit: 1.00,
                contextFit: 1.00,
                userAffinity: 1.00,
                risk: 0.90,
                repetition: 0.90,
                instability: 0.00
            ),
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )
        results.append(SuggestionUsefulnessGateResult(
            id: "one-brain-high-risk",
            label: "one-brain preview keeps high risk as a hard veto",
            passed: !oneBrainRiskDecision.shouldDisplay
                && oneBrainRiskDecision.metadata["displayScoreSuppressionReason"] == "high-risk"
        ))

        let learnedRestraintDecision = policy.decision(
            for: DisplayScore(
                utility: 0.70,
                styleFit: 0.40,
                contextFit: 0.35,
                userAffinity: 0.25,
                risk: 0.10,
                repetition: 0.05,
                instability: 0.05,
                learningRestraint: 0.75,
                acceptedAndKeptProbability: 0.17,
                acceptedAndKeptSampleCount: 4
            ),
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )
        results.append(SuggestionUsefulnessGateResult(
            id: "one-brain-learned-restraint",
            label: "one-brain preview reports learned restraint when it binds",
            passed: !learnedRestraintDecision.shouldDisplay
                && learnedRestraintDecision.metadata["displayScoreSuppressionReason"] == "learned-restraint"
        ))

        let lowKeptDecision = policy.decision(
            for: DisplayScore(
                utility: 0.90,
                styleFit: 0.65,
                contextFit: 0.55,
                userAffinity: 0.20,
                risk: 0.05,
                repetition: 0.05,
                instability: 0.05,
                acceptedAndKeptProbability: 0.01,
                acceptedAndKeptSampleCount: 8
            ),
            mode: .phraseContinuation,
            behaviorProfileID: .docsProse
        )
        results.append(SuggestionUsefulnessGateResult(
            id: "low-kept-probability",
            label: "low accepted-and-kept probability suppresses phrase help",
            passed: !lowKeptDecision.shouldDisplay
                && lowKeptDecision.metadata["displayScoreSuppressionReason"] == "low-accepted-and-kept-probability"
        ))

        let context = AnnoyanceContext(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "com.apple.TextEdit|scorecard-field",
            requestMode: .phraseContinuation,
            fieldKind: .multilineCompose
        )
        let start = Date(timeIntervalSince1970: 0)
        var repeatedTypedOverSuppressor = AnnoyanceSuppressor()
        _ = repeatedTypedOverSuppressor.record(.typedOver, context: context, now: start)
        _ = repeatedTypedOverSuppressor.record(.typedOver, context: context, now: start.addingTimeInterval(1))
        results.append(SuggestionUsefulnessGateResult(
            id: "annoyance-repeated-typed-over",
            label: "repeated typed-over suggestions quiet the current field",
            passed: repeatedTypedOverSuppressor.quietMode(
                for: context,
                now: start.addingTimeInterval(1)
            ).traceReason == "quiet-mode-field"
        ))

        var keptSuppressor = AnnoyanceSuppressor(fieldQuietThreshold: 10)
        _ = keptSuppressor.record(.typedOver, context: context, now: start)
        _ = keptSuppressor.record(.acceptedAndKept, context: context, now: start.addingTimeInterval(5))
        results.append(SuggestionUsefulnessGateResult(
            id: "annoyance-accepted-kept",
            label: "accepted-and-kept evidence reduces annoyance pressure",
            passed: keptSuppressor.score(for: context, now: start.addingTimeInterval(5)) == 0
        ))

        return results
    }
}

private func normalizedPhrase(_ text: String) -> String {
    normalizedWords(text).joined(separator: " ")
}

private func normalizedWords(_ text: String) -> [String] {
    text
        .lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
}

private func containsContiguous(_ needle: [String], in haystack: [String]) -> Bool {
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

private func scorecardRate(_ numerator: Int, _ denominator: Int) -> Double {
    guard denominator > 0 else {
        return 1
    }
    return Double(numerator) / Double(denominator)
}
