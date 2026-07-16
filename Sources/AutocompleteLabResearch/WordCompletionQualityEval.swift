import Foundation
import AutocompleteLabCore

public enum WordCompletionEvalAction: String, Equatable, Sendable {
    case accepted
    case typedThrough
    case typedOver
    case expectedSilence
}

public struct WordCompletionEvalCase: Equatable, Sendable {
    public let id: String
    public let surfaceName: String
    public let appBundleIdentifier: String
    public let fieldKind: String
    public let textBeforeCursor: String
    public let recentWords: [String]
    public let expectedVisibleSuffix: String?
    public let action: WordCompletionEvalAction
    public let partialTypedPrefix: String?

    public init(
        id: String,
        surfaceName: String,
        appBundleIdentifier: String,
        fieldKind: String,
        textBeforeCursor: String,
        recentWords: [String] = [],
        expectedVisibleSuffix: String?,
        action: WordCompletionEvalAction,
        partialTypedPrefix: String? = nil
    ) {
        self.id = id
        self.surfaceName = surfaceName
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldKind = fieldKind
        self.textBeforeCursor = textBeforeCursor
        self.recentWords = recentWords
        self.expectedVisibleSuffix = expectedVisibleSuffix
        self.action = action
        self.partialTypedPrefix = partialTypedPrefix
    }
}

public struct WordCompletionEvalCaseResult: Equatable, Sendable {
    public let evalCase: WordCompletionEvalCase
    public let visibleSuffix: String?
    public let candidateCount: Int
    public let candidateTopScore: Double?
    public let candidateScoreMargin: Double?
    public let candidateSuppressionReason: String?
    public let candidateQualityPassed: Bool
    public let repeatedMissSuppressed: Bool?
    public let prefixFamilyCooldownBlocked: Bool?
    public let prefixFamilyCooldownEscalated: Bool?
    public let partialAcceptSucceeded: Bool?

    public var shown: Bool {
        visibleSuffix != nil
    }

    public var expectedCandidate: Bool {
        evalCase.expectedVisibleSuffix != nil
    }

    public var missed: Bool {
        guard shown else {
            return false
        }

        return !candidateQualityPassed || evalCase.action == .typedOver
    }

    public var typedOver: Bool {
        shown && evalCase.action == .typedOver
    }
}

public struct WordCompletionEvalSurfaceSummary: Equatable, Sendable {
    public let surfaceName: String
    public let appBundleIdentifier: String
    public let caseCount: Int
    public let shownCount: Int
    public let expectedCandidateCount: Int
    public let correctCandidateCount: Int
    public let missCount: Int
    public let typedOverCount: Int
    public let repeatedMissSuppressionTrials: Int
    public let repeatedMissSuppressedCount: Int
    public let prefixCooldownTrials: Int
    public let prefixCooldownBlockedCount: Int
    public let partialAcceptTrials: Int
    public let partialAcceptSuccessCount: Int

    public var candidateQualityRate: Double {
        rate(correctCandidateCount, expectedCandidateCount)
    }

    public var missRate: Double {
        rate(missCount, shownCount)
    }

    public var typedOverRate: Double {
        rate(typedOverCount, shownCount)
    }

    public var repeatedMissSuppressionRate: Double {
        rate(repeatedMissSuppressedCount, repeatedMissSuppressionTrials)
    }

    public var prefixCooldownRate: Double {
        rate(prefixCooldownBlockedCount, prefixCooldownTrials)
    }

    public var partialAcceptSuccessRate: Double {
        rate(partialAcceptSuccessCount, partialAcceptTrials)
    }
}

public struct WordCompletionEvalReport: Equatable, Sendable {
    public let results: [WordCompletionEvalCaseResult]
    public let surfaceSummaries: [WordCompletionEvalSurfaceSummary]
    public let totalSummary: WordCompletionEvalSurfaceSummary
    public let score: Double

    public var markdown: String {
        let rows = surfaceSummaries.map { summary in
            "| \(summary.surfaceName) | \(summary.shownCount)/\(summary.caseCount) | \(percent(summary.candidateQualityRate)) | \(percent(summary.missRate)) | \(percent(summary.typedOverRate)) | \(summary.repeatedMissSuppressedCount)/\(summary.repeatedMissSuppressionTrials) | \(summary.prefixCooldownBlockedCount)/\(summary.prefixCooldownTrials) | \(summary.partialAcceptSuccessCount)/\(summary.partialAcceptTrials) |"
        }
        .joined(separator: "\n")

        let caseRows = results.map { result in
            let expected = result.evalCase.expectedVisibleSuffix ?? "silence"
            let actual = result.visibleSuffix ?? "silence"
            let miss = result.missed ? "miss" : "ok"
            let partial = result.partialAcceptSucceeded.map { $0 ? "ok" : "miss" } ?? "n/a"
            return "| \(result.evalCase.id) | \(result.evalCase.surfaceName) | \(expected) | \(actual) | \(result.evalCase.action.rawValue) | \(miss) | \(partial) |"
        }
        .joined(separator: "\n")

        return """
        # Word Completion Quality Eval

        Score: \(String(format: "%.1f", score))/10

        This deterministic report uses app-surface-shaped cases for TextEdit, Notes, Obsidian, and Chrome-like fields. It checks that word completion stays one-word, quiet, and app-scoped while measuring miss behavior.

        ## Summary

        | Surface | Shown | Candidate quality | Miss rate | Typed-over rate | Repeated miss suppressed | Prefix cooldown blocked | Partial accept |
        | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \(rows)
        | Total | \(totalSummary.shownCount)/\(totalSummary.caseCount) | \(percent(totalSummary.candidateQualityRate)) | \(percent(totalSummary.missRate)) | \(percent(totalSummary.typedOverRate)) | \(totalSummary.repeatedMissSuppressedCount)/\(totalSummary.repeatedMissSuppressionTrials) | \(totalSummary.prefixCooldownBlockedCount)/\(totalSummary.prefixCooldownTrials) | \(totalSummary.partialAcceptSuccessCount)/\(totalSummary.partialAcceptTrials) |

        ## Case Evidence

        | Case | Surface | Expected | Actual | Action | Result | Partial accept |
        | --- | --- | --- | --- | --- | --- | --- |
        \(caseRows)

        ## Decision

        Word completion reaches \(String(format: "%.1f", score))/10 in this harness. The remaining gap to 10/10 is live dogfood volume, not a need to make completions louder.
        """
    }
}

public enum WordCompletionQualityEvaluator {
    public static let defaultCorpus: [WordCompletionEvalCase] = [
        WordCompletionEvalCase(
            id: "textedit-dictation",
            surfaceName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: "multilineCompose",
            textBeforeCursor: "I use dic",
            expectedVisibleSuffix: "tation",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "textedit-instant-partial",
            surfaceName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Writing feels inst",
            recentWords: ["instant"],
            expectedVisibleSuffix: "ant",
            action: .typedThrough,
            partialTypedPrefix: "a"
        ),
        WordCompletionEvalCase(
            id: "textedit-low-value-kind",
            surfaceName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: "multilineCompose",
            textBeforeCursor: "This is kin",
            expectedVisibleSuffix: nil,
            action: .expectedSilence
        ),
        WordCompletionEvalCase(
            id: "textedit-two-letter-floor",
            surfaceName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: "multilineCompose",
            textBeforeCursor: "I saw th",
            expectedVisibleSuffix: nil,
            action: .expectedSilence
        ),
        WordCompletionEvalCase(
            id: "notes-follow",
            surfaceName: "Notes",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Action item: fol",
            recentWords: ["follow"],
            expectedVisibleSuffix: "low",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "notes-important-partial",
            surfaceName: "Notes",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: "checklist",
            textBeforeCursor: "Checklist item: impor",
            recentWords: ["important"],
            expectedVisibleSuffix: "tant",
            action: .typedThrough,
            partialTypedPrefix: "t"
        ),
        WordCompletionEvalCase(
            id: "notes-action",
            surfaceName: "Notes",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: "title",
            textBeforeCursor: "Next act",
            recentWords: ["action"],
            expectedVisibleSuffix: "ion",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "notes-short-fragment",
            surfaceName: "Notes",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: "title",
            textBeforeCursor: "Call li",
            expectedVisibleSuffix: nil,
            action: .expectedSilence
        ),
        WordCompletionEvalCase(
            id: "obsidian-name",
            surfaceName: "Obsidian",
            appBundleIdentifier: "md.obsidian",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Write about Obsid",
            recentWords: ["Obsidian"],
            expectedVisibleSuffix: "ian",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "obsidian-product-partial",
            surfaceName: "Obsidian",
            appBundleIdentifier: "md.obsidian",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Use Transcrip",
            recentWords: ["Transcripted"],
            expectedVisibleSuffix: "ted",
            action: .typedThrough,
            partialTypedPrefix: "t"
        ),
        WordCompletionEvalCase(
            id: "obsidian-permission",
            surfaceName: "Obsidian",
            appBundleIdentifier: "md.obsidian",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Screen permis",
            recentWords: ["permission"],
            expectedVisibleSuffix: "sion",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "obsidian-code-word",
            surfaceName: "Obsidian",
            appBundleIdentifier: "md.obsidian",
            fieldKind: "multilineCompose",
            textBeforeCursor: "Open code",
            expectedVisibleSuffix: nil,
            action: .expectedSilence
        ),
        WordCompletionEvalCase(
            id: "chrome-confirm",
            surfaceName: "Chrome-like fields",
            appBundleIdentifier: "com.google.Chrome",
            fieldKind: "textarea",
            textBeforeCursor: "Please conf",
            recentWords: ["confirm"],
            expectedVisibleSuffix: "irm",
            action: .accepted
        ),
        WordCompletionEvalCase(
            id: "chrome-submit",
            surfaceName: "Chrome-like fields",
            appBundleIdentifier: "com.google.Chrome",
            fieldKind: "contenteditable",
            textBeforeCursor: "The form field needs submi",
            recentWords: ["submitted"],
            expectedVisibleSuffix: "tted",
            action: .typedThrough,
            partialTypedPrefix: "t"
        ),
        WordCompletionEvalCase(
            id: "chrome-documentary-typed-over",
            surfaceName: "Chrome-like fields",
            appBundleIdentifier: "com.google.Chrome",
            fieldKind: "textarea",
            textBeforeCursor: "Open doc",
            recentWords: ["documentary"],
            expectedVisibleSuffix: "umentary",
            action: .typedOver
        ),
        WordCompletionEvalCase(
            id: "chrome-low-value-this",
            surfaceName: "Chrome-like fields",
            appBundleIdentifier: "com.google.Chrome",
            fieldKind: "contenteditable",
            textBeforeCursor: "Open thi",
            expectedVisibleSuffix: nil,
            action: .expectedSilence
        )
    ]

    public static func evaluate(
        corpus: [WordCompletionEvalCase] = defaultCorpus,
        ranker: WordCompletionCandidateRanker = WordCompletionCandidateRanker()
    ) -> WordCompletionEvalReport {
        let results = corpus.enumerated().map { index, evalCase in
            result(for: evalCase, ranker: ranker, offset: index)
        }
        let summaries = surfaceSummaries(for: results)
        let total = summary(
            surfaceName: "Total",
            appBundleIdentifier: "all",
            results: results
        )
        return WordCompletionEvalReport(
            results: results,
            surfaceSummaries: summaries,
            totalSummary: total,
            score: score(for: total)
        )
    }

    private static func result(
        for evalCase: WordCompletionEvalCase,
        ranker: WordCompletionCandidateRanker,
        offset: Int
    ) -> WordCompletionEvalCaseResult {
        let researchRanker = WordCompletionCandidateRanker(
            staticWords: evalCase.recentWords + ranker.staticWords
        )
        let selection = researchRanker.selection(for: evalCase.textBeforeCursor)
        let visibleSuffix = selection.suggestion?.visibleText
        let candidateQualityPassed = visibleSuffix == evalCase.expectedVisibleSuffix

        var repeatedMissSuppressed: Bool?
        var prefixFamilyCooldownBlocked: Bool?
        var prefixFamilyCooldownEscalated: Bool?
        var partialAcceptSucceeded: Bool?

        if let visibleSuffix, evalCase.action == .typedOver {
            let now = Date(timeIntervalSince1970: Double(1_000 + offset))
            var suppressor = SuggestionRepetitionSuppressor(missThreshold: 2, missHalfLifeSeconds: 600)
            suppressor.recordMiss(
                visibleSuffix,
                mode: .wordCompletion,
                scope: evalCase.appBundleIdentifier,
                now: now
            )
            suppressor.recordMiss(
                visibleSuffix,
                mode: .wordCompletion,
                scope: evalCase.appBundleIdentifier,
                now: now.addingTimeInterval(1)
            )
            repeatedMissSuppressed = suppressor.shouldSuppress(
                visibleSuffix,
                mode: .wordCompletion,
                scope: evalCase.appBundleIdentifier,
                now: now.addingTimeInterval(1)
            )

            var cooldown = PrefixFamilyCooldownPolicy(
                typedOverCooldownMilliseconds: 5_000,
                repeatedTypedOverCooldownMilliseconds: 30_000
            )
            let input = PrefixFamilyCooldownInput(
                appBundleIdentifier: evalCase.appBundleIdentifier,
                fieldIdentifier: evalCase.fieldKind,
                requestMode: .wordCompletion,
                textBeforeCursor: evalCase.textBeforeCursor
            )
            _ = cooldown.record(.typedOver, input: input, now: now)
            let repeatedCooldown = cooldown.record(
                .typedOver,
                input: input,
                now: now.addingTimeInterval(1)
            )
            prefixFamilyCooldownBlocked = !cooldown.decision(
                for: input,
                now: now.addingTimeInterval(1.1)
            ).canRequest
            prefixFamilyCooldownEscalated = repeatedCooldown?.isEscalated == true
        }

        if let partialTypedPrefix = evalCase.partialTypedPrefix,
           let suggestion = selection.suggestion {
            partialAcceptSucceeded = partialAcceptDidAdvance(
                suggestion: suggestion,
                typedPrefix: partialTypedPrefix
            )
        }

        return WordCompletionEvalCaseResult(
            evalCase: evalCase,
            visibleSuffix: visibleSuffix,
            candidateCount: selection.candidateCount,
            candidateTopScore: selection.topScore,
            candidateScoreMargin: selection.scoreMargin,
            candidateSuppressionReason: selection.suppressionReason,
            candidateQualityPassed: candidateQualityPassed,
            repeatedMissSuppressed: repeatedMissSuppressed,
            prefixFamilyCooldownBlocked: prefixFamilyCooldownBlocked,
            prefixFamilyCooldownEscalated: prefixFamilyCooldownEscalated,
            partialAcceptSucceeded: partialAcceptSucceeded
        )
    }

    private static func partialAcceptDidAdvance(
        suggestion: CompletionSuggestion,
        typedPrefix: String
    ) -> Bool {
        var session = SuggestionSession(visibleSuggestion: suggestion)
        guard session.commitTypedVisiblePrefix(typedPrefix) else {
            return false
        }

        let expectedRemainder = String(suggestion.visibleText.dropFirst(typedPrefix.count))
        if expectedRemainder.isEmpty {
            return !session.hasVisibleSuggestion
        }

        return session.visibleSuggestion?.visibleText == expectedRemainder
    }

    private static func surfaceSummaries(
        for results: [WordCompletionEvalCaseResult]
    ) -> [WordCompletionEvalSurfaceSummary] {
        let grouped = Dictionary(grouping: results) { $0.evalCase.surfaceName }
        return grouped.keys.sorted().compactMap { surfaceName in
            guard let surfaceResults = grouped[surfaceName],
                  let bundle = surfaceResults.first?.evalCase.appBundleIdentifier else {
                return nil
            }
            return summary(
                surfaceName: surfaceName,
                appBundleIdentifier: bundle,
                results: surfaceResults
            )
        }
    }

    private static func summary(
        surfaceName: String,
        appBundleIdentifier: String,
        results: [WordCompletionEvalCaseResult]
    ) -> WordCompletionEvalSurfaceSummary {
        WordCompletionEvalSurfaceSummary(
            surfaceName: surfaceName,
            appBundleIdentifier: appBundleIdentifier,
            caseCount: results.count,
            shownCount: results.filter(\.shown).count,
            expectedCandidateCount: results.filter(\.expectedCandidate).count,
            correctCandidateCount: results.filter { $0.expectedCandidate && $0.candidateQualityPassed }.count,
            missCount: results.filter(\.missed).count,
            typedOverCount: results.filter(\.typedOver).count,
            repeatedMissSuppressionTrials: results.filter { $0.repeatedMissSuppressed != nil }.count,
            repeatedMissSuppressedCount: results.filter { $0.repeatedMissSuppressed == true }.count,
            prefixCooldownTrials: results.filter { $0.prefixFamilyCooldownBlocked != nil }.count,
            prefixCooldownBlockedCount: results.filter { $0.prefixFamilyCooldownBlocked == true }.count,
            partialAcceptTrials: results.filter { $0.partialAcceptSucceeded != nil }.count,
            partialAcceptSuccessCount: results.filter { $0.partialAcceptSucceeded == true }.count
        )
    }

    private static func score(for summary: WordCompletionEvalSurfaceSummary) -> Double {
        let value = (
            summary.candidateQualityRate * 0.35
                + (1 - summary.missRate) * 0.25
                + (1 - summary.typedOverRate) * 0.15
                + summary.repeatedMissSuppressionRate * 0.10
                + summary.prefixCooldownRate * 0.05
                + summary.partialAcceptSuccessRate * 0.10
        ) * 10

        return (value * 10).rounded() / 10
    }
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
