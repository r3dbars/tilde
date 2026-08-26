import CryptoKit
import Foundation

public enum LabCorpusQualityAuditor {
    public static func auditCertifiedV2(
        suite: LabScenarioSuite,
        review: LabCorpusReviewReceipt = LabCertifiedCorpusV2.reviewReceipt
    ) throws -> LabCorpusQualityReport {
        _ = try suite.validated()
        let digest = try suite.digestSHA256()
        let scenarios = suite.scenarios
        let roots = scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }
        let uniqueRoots = Set(roots)
        let positives = scenarios.filter(\.expectation.shouldSuggest)
        let silence = scenarios.filter { !$0.expectation.shouldSuggest }
        let development = scenarios.count(where: { $0.partition == .development })
        let validation = scenarios.count(where: { $0.partition == .validation })
        let holdout = scenarios.count(where: { $0.partition == .holdout })
        let categories = Set(scenarios.map(\.category))
        let applications = Set(scenarios.compactMap(\.appBundleIdentifier))
        let pairGroups = Dictionary(grouping: scenarios) { scenario in
            scenario.tags.first(where: { $0.hasPrefix("pair-") }) ?? "missing"
        }
        let validPairs = pairGroups.filter { $0.key != "missing" && $0.value.count == 2 }
        let supported = positives.count(where: positiveIsGrounded)
        let supportedRate = positives.isEmpty ? 0 : Double(supported) / Double(positives.count)
        let unsupportedByCategory = Dictionary(
            grouping: positives.filter { !positiveIsGrounded($0) },
            by: \.category
        ).mapValues(\.count)
        let unsupportedReasonCounts = Dictionary(
            grouping: positives.flatMap(groundingFailures),
            by: { $0 }
        ).mapValues(\.count)
        let unsupportedAnchorCounts = Dictionary(
            grouping: positives.flatMap(unsupportedAlternativeAnchors),
            by: { $0 }
        ).mapValues(\.count)
        let unsupportedDetail = unsupportedByCategory.keys.sorted().map {
            "\($0)=\(unsupportedByCategory[$0, default: 0])"
        }.joined(separator: ", ")
        let unsupportedReasons = unsupportedReasonCounts.keys.sorted().map {
            "\($0)=\(unsupportedReasonCounts[$0, default: 0])"
        }.joined(separator: ", ")
        let unsupportedAnchors = unsupportedAnchorCounts.keys.sorted().map {
            "\($0)=\(unsupportedAnchorCounts[$0, default: 0])"
        }.joined(separator: ", ")
        let multiAnswerPositives = positives.count(where: hasReviewedAnswerSet)
        let duplicateSignatures = Dictionary(grouping: scenarios, by: signature)
            .values
            .filter { $0.count > 1 }
            .reduce(0) { $0 + $1.count - 1 }
        let invalidPairs = pairGroups.filter { key, values in
            key == "missing" || values.count != 2 || Set(values.map(signature)).count != values.count
        }.count
        let provenanceFailures = scenarios.count { scenario in
            scenario.evaluation.corpusID != LabCorpusRegistry.tildeCertifiedV2.id
                || scenario.evaluation.rootScenarioID != scenario.id
                || !scenario.evaluation.temporalIntegrity.passed
        }
        let sampleDigest = reviewSampleDigest(suite: suite)
        let reviewMatches = review.corpusDigestSHA256 == digest
            && review.sampleDigestSHA256 == sampleDigest
            && review.reviewedCases >= LabCertifiedCorpusV2.reviewSampleSize
            && review.approvalRate >= LabCertifiedCorpusV2.minimumReviewApprovalRate

        let checks = [
            check(
                id: "grain",
                title: "1,000 unique situations",
                passes: scenarios.count == 1_000 && uniqueRoots.count == 1_000,
                detail: "\(uniqueRoots.count) unique roots; \(scenarios.count) evaluations"
            ),
            check(
                id: "duplicates",
                title: "No duplicate questions",
                passes: duplicateSignatures == 0,
                detail: "\(duplicateSignatures) duplicate prompt-and-target signatures"
            ),
            check(
                id: "grounding",
                title: "Every answer is supported",
                passes: supported == positives.count,
                detail: supported == positives.count
                    ? "\(supported) of \(positives.count) positive targets grounded in visible context"
                    : "\(supported) of \(positives.count) grounded; failures: \(unsupportedDetail); reasons: \(unsupportedReasons); anchors: \(unsupportedAnchors)"
            ),
            check(
                id: "multi-answer",
                title: "Multiple human-acceptable replies",
                passes: multiAnswerPositives == positives.count,
                detail: "\(multiAnswerPositives) of \(positives.count) speak cases carry one recorded continuation plus seven reviewed alternatives"
            ),
            check(
                id: "balance",
                title: "Speak and silence balance",
                passes: positives.count == 600 && silence.count == 400,
                detail: "\(positives.count) speak; \(silence.count) silence"
            ),
            check(
                id: "diversity",
                title: "Broad behavioral coverage",
                passes: categories.count >= 40 && applications.count >= 5,
                detail: "\(categories.count) behavioral families across \(applications.count) applications"
            ),
            check(
                id: "counterfactuals",
                title: "Counterfactual controls",
                passes: validPairs.count == 500 && invalidPairs == 0,
                detail: "\(validPairs.count) valid two-case pairs; \(invalidPairs) malformed"
            ),
            check(
                id: "split",
                title: "Locked 60/20/20 split",
                passes: development == 600 && validation == 200 && holdout == 200,
                detail: "\(development) development; \(validation) validation; \(holdout) holdout"
            ),
            check(
                id: "provenance",
                title: "Versioned provenance",
                passes: provenanceFailures == 0,
                detail: "\(provenanceFailures) unregistered or temporally invalid cases"
            ),
            LabCorpusQualityCheck(
                id: "review",
                title: "Documented 100-case review",
                status: reviewMatches ? .pass : .pending,
                detail: reviewMatches
                    ? "\(review.approvedCases) of \(review.reviewedCases) approved under \(review.rubricVersion)"
                    : "The deterministic 100-case sample must be reviewed after the corpus is frozen"
            ),
        ]
        return LabCorpusQualityReport(
            corpusID: LabCorpusRegistry.tildeCertifiedV2.id,
            corpusName: suite.name,
            corpusDigestSHA256: digest,
            rootCount: uniqueRoots.count,
            positiveCount: positives.count,
            silenceCount: silence.count,
            categoryFamilyCount: categories.count,
            applicationCount: applications.count,
            counterfactualPairCount: validPairs.count,
            supportedPositiveRate: supportedRate,
            developmentCount: development,
            validationCount: validation,
            holdoutCount: holdout,
            checks: checks
        )
    }

    public static func reviewSampleRootIDs(suite: LabScenarioSuite) -> [String] {
        let targets: [(LabScenarioPartition, Int)] = [
            (.development, 60),
            (.validation, 20),
            (.holdout, 20),
        ]
        var selected: [String] = []
        for (partition, count) in targets {
            let partitioned = suite.scenarios.filter { $0.partition == partition }
            let groups = Dictionary(grouping: partitioned, by: \.category)
            let categories = groups.keys.sorted()
            var offsets = Dictionary(uniqueKeysWithValues: categories.map { ($0, 0) })
            while selected.count < targets.prefix(while: { $0.0 != partition }).reduce(0, { $0 + $1.1 }) + count {
                var madeProgress = false
                for category in categories {
                    guard selected.count < targets.prefix(while: { $0.0 != partition }).reduce(0, { $0 + $1.1 }) + count,
                          let values = groups[category] else { break }
                    let ordered = values.sorted { stableDigest($0.id) < stableDigest($1.id) }
                    let offset = offsets[category, default: 0]
                    guard ordered.indices.contains(offset) else { continue }
                    selected.append(ordered[offset].evaluation.rootScenarioID ?? ordered[offset].id)
                    offsets[category] = offset + 1
                    madeProgress = true
                }
                if !madeProgress { break }
            }
        }
        return Array(selected.prefix(LabCertifiedCorpusV2.reviewSampleSize))
    }

    public static func reviewSampleDigest(suite: LabScenarioSuite) -> String {
        stableDigest(reviewSampleRootIDs(suite: suite).joined(separator: "\n"))
    }

    private static func positiveIsGrounded(_ scenario: LabScenario) -> Bool {
        groundingFailures(scenario).isEmpty
    }

    private static func groundingFailures(_ scenario: LabScenario) -> [String] {
        guard scenario.expectation.shouldSuggest,
              let golden = scenario.expectation.goldenContinuation,
              !golden.isEmpty,
              !scenario.expectation.requiredTerms.isEmpty else { return ["missing-contract"] }
        let source = ([scenario.typedContext]
            + (scenario.scene?.turns.map(\.text) ?? [])
            + (scenario.scene?.references ?? []))
            .joined(separator: " ")
        let normalizedSource = normalized(source)
        let normalizedGolden = normalized(golden)
        let requiredAreGrounded = scenario.expectation.requiredTerms.allSatisfy { term in
            let normalizedTerm = normalized(term)
            return !normalizedTerm.isEmpty
                && normalizedSource.contains(normalizedTerm)
                && normalizedGolden.contains(normalizedTerm)
        }
        let forbiddenAreAbsent = scenario.expectation.forbiddenTerms.allSatisfy {
            !normalizedGolden.contains(normalized($0))
        }
        let sourceAnchors = factualAnchors(source, dropsLeadingCapital: false)
        let alternativeForbidden = scenario.expectation.acceptableContinuations.contains { alternative in
            scenario.expectation.forbiddenTerms.contains {
                normalized(alternative).contains(normalized($0))
            }
        }
        let alternativeUnsupported = scenario.expectation.acceptableContinuations.contains { alternative in
            !factualAnchors(alternative, dropsLeadingCapital: true).isSubset(of: sourceAnchors)
        }
        var failures: [String] = []
        if !requiredAreGrounded { failures.append("required-not-grounded") }
        if !forbiddenAreAbsent { failures.append("golden-forbidden") }
        if alternativeForbidden { failures.append("alternative-forbidden") }
        if alternativeUnsupported { failures.append("alternative-unsupported-anchor") }
        if !factualAnchors(golden, dropsLeadingCapital: true).isSubset(of: sourceAnchors) {
            failures.append("golden-unsupported-anchor")
        }
        return failures
    }

    private static func hasReviewedAnswerSet(_ scenario: LabScenario) -> Bool {
        guard scenario.intent != nil,
              let golden = scenario.expectation.goldenContinuation,
              !golden.isEmpty,
              scenario.expectation.acceptableContinuations.count == 7 else { return false }
        let paths = [golden] + scenario.expectation.acceptableContinuations
        let normalizedPaths = paths.map(normalized)
        return normalizedPaths.allSatisfy { !$0.isEmpty }
            && Set(normalizedPaths).count == 8
    }

    private static func unsupportedAlternativeAnchors(_ scenario: LabScenario) -> [String] {
        let source = ([scenario.typedContext]
            + (scenario.scene?.turns.map(\.text) ?? [])
            + (scenario.scene?.references ?? []))
            .joined(separator: " ")
        let sourceAnchors = factualAnchors(source, dropsLeadingCapital: false)
        return Array(Set(scenario.expectation.acceptableContinuations.flatMap { alternative in
            factualAnchors(alternative, dropsLeadingCapital: true).subtracting(sourceAnchors)
        })).sorted()
    }

    private static func signature(_ scenario: LabScenario) -> String {
        let turns = scenario.scene?.turns.map {
            "\($0.speaker.rawValue):\(normalized($0.text))"
        }.joined(separator: "|") ?? ""
        let expectation = [
            scenario.expectation.shouldSuggest ? "speak" : "silence",
            scenario.intent?.rawValue ?? "no-intent",
            normalized(scenario.expectation.goldenContinuation ?? ""),
            scenario.expectation.acceptablePrefixes.map(normalized).sorted().joined(separator: ","),
            scenario.expectation.acceptableContinuations.map(normalized).sorted().joined(separator: ","),
            scenario.expectation.requiredTerms.map(normalized).sorted().joined(separator: ","),
            scenario.expectation.forbiddenTerms.map(normalized).sorted().joined(separator: ","),
        ].joined(separator: "|")
        return stableDigest("\(normalized(scenario.typedContext))|\(turns)|\(expectation)")
    }

    private static func check(
        id: String,
        title: String,
        passes: Bool,
        detail: String
    ) -> LabCorpusQualityCheck {
        LabCorpusQualityCheck(
            id: id,
            title: title,
            status: passes ? .pass : .fail,
            detail: detail
        )
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "@" })
            .joined(separator: " ")
    }

    private static func factualAnchors(
        _ text: String,
        dropsLeadingCapital: Bool
    ) -> Set<String> {
        let tokens = text.split { !$0.isLetter && !$0.isNumber && $0 != "@" }
        var result = Set<String>()
        for (index, tokenValue) in tokens.enumerated() {
            let token = String(tokenValue)
            let folded = token.lowercased()
            let hasDigit = token.contains(where: \.isNumber)
            let capitalized = token.first?.isUppercase == true && !(dropsLeadingCapital && index == 0)
            let isMeridiem = (folded == "am" || folded == "pm")
                && index > 0
                && tokens[index - 1].contains(where: \.isNumber)
            if (folded == "am" || folded == "pm") && !isMeridiem { continue }
            if hasDigit || token.contains("@") || factWords.contains(folded) || capitalized {
                if !ignoredCapitalizedWords.contains(folded) { result.insert(folded) }
            }
        }
        return result
    }

    private static func stableDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static let factWords: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december", "today", "tomorrow", "yesterday",
        "am", "pm", "noon", "midnight",
    ]

    private static let ignoredCapitalizedWords: Set<String> = [
        "i", "yes", "no", "okay", "ok", "thanks", "thank", "sure", "sounds", "sorry",
    ]
}
