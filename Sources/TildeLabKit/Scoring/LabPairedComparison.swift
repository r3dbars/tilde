import Foundation

public struct LabEstimate: Codable, Equatable, Sendable {
    public let mean: Double
    public let lower95: Double
    public let upper95: Double
    public let probabilityPositive: Double

    public init(mean: Double, lower95: Double, upper95: Double, probabilityPositive: Double) {
        self.mean = mean
        self.lower95 = lower95
        self.upper95 = upper95
        self.probabilityPositive = probabilityPositive
    }
}

/// Denominators that make selective systems honest. A quiet arm cannot hide a
/// coverage collapse behind a low bad rate, and a chatty arm cannot hide its
/// interruption rate behind useful coverage.
public struct LabSelectivePredictionMetrics: Codable, Equatable, Sendable {
    public let eligibleOpportunities: Int
    public let shouldSpeakOpportunities: Int
    public let shouldSilenceOpportunities: Int
    public let shown: Int
    public let useful: Int
    public let bad: Int
    public let unwanted: Int
    public let late: Int
    public let showRate: Double
    public let usefulCoverage: Double
    public let precisionWhenShown: Double
    public let badWhenShown: Double
    public let badPerOpportunity: Double
    public let unwantedSpeakRate: Double
    public let lateRate: Double
    public let oracleNetKeystrokeSavingsRate: Double
    public let expectedUtilityMillisecondsPer1000Characters: Double

    public init(cases: [LabCaseResult], utility: LabUtilityConfiguration = .init()) {
        let completed = cases.filter { $0.outcome != .timeout && $0.outcome != .error }
        let shouldSpeak = completed.filter(\.expectedSuggestion)
        let shouldSilence = completed.filter { !$0.expectedSuggestion }
        let shownCases = completed.filter(\.offered)
        let badCases = shownCases.filter { $0.outcome == .wrong || $0.outcome == .unwanted }
        let unwantedCases = shownCases.filter { $0.outcome == .unwanted }
        let lateCases = shownCases.filter { result in
            guard let latency = result.firstTokenMilliseconds ?? result.latencyMilliseconds else {
                return false
            }
            return latency > utility.firstStableWordDeadlineMilliseconds
        }
        let baselineCharacters = completed.reduce(0) { $0 + $1.baselineKeystrokes }
        let netSaved = completed.reduce(0) { $0 + $1.netKeystrokesSaved }
        let expectedUtility = completed.reduce(0.0) {
            $0 + LabExpectedUtility.milliseconds(for: $1, configuration: utility)
        }

        eligibleOpportunities = completed.count
        shouldSpeakOpportunities = shouldSpeak.count
        shouldSilenceOpportunities = shouldSilence.count
        shown = shownCases.count
        useful = shownCases.count(where: { $0.outcome == .useful })
        bad = badCases.count
        unwanted = unwantedCases.count
        late = lateCases.count
        showRate = Self.rate(shown, completed.count)
        usefulCoverage = Self.rate(useful, shouldSpeak.count)
        precisionWhenShown = Self.rate(useful, shown)
        badWhenShown = Self.rate(bad, shown)
        badPerOpportunity = Self.rate(bad, completed.count)
        unwantedSpeakRate = Self.rate(unwanted, shouldSilence.count)
        lateRate = Self.rate(late, shown)
        oracleNetKeystrokeSavingsRate = baselineCharacters > 0
            ? Double(netSaved) / Double(baselineCharacters)
            : 0
        expectedUtilityMillisecondsPer1000Characters = baselineCharacters > 0
            ? expectedUtility / Double(baselineCharacters) * 1_000
            : 0
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }
}

public struct LabRiskCoveragePoint: Codable, Equatable, Sendable {
    public let threshold: Double
    public let coverage: Double
    public let precisionWhenShown: Double
    public let badWhenShown: Double
    public let badWhenShownUpper95Wilson: Double
    public let usefulCoverage: Double
    public let expectedUtilityMillisecondsPer1000Characters: Double
    public let shown: Int
    public let meanVisibleCharacters: Double
    public let meanVisibleWords: Double
}

public struct LabRiskCoverageSliceReport: Codable, Equatable, Sendable {
    public let slice: String
    public let opportunities: Int
    public let points: [LabRiskCoveragePoint]
    public let highestCoverageUnderTrustLimit: LabRiskCoveragePoint?
}

public struct LabRiskCoverageReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.risk-coverage.v2"

    public let schema: String
    public let sourceReportID: UUID
    public let sourceArmID: String
    public let trustLimit: Double
    public let eligibleOpportunities: Int
    public let scoredCandidateCount: Int
    public let points: [LabRiskCoveragePoint]
    public let slices: [LabRiskCoverageSliceReport]
    public let highestCoverageUnderTrustLimit: LabRiskCoveragePoint?
    public let completeCandidateReplay: Bool
    public let limitation: String
}

public struct LabSliceComparison: Codable, Equatable, Sendable {
    public let slice: String
    public let independentRootCount: Int
    public let deltaExpectedUtility: Double
    public let deltaPrecisionWhenShown: Double
    public let deltaBadWhenShown: Double
    public let deltaLateRate: Double
}

/// Behavior by pre-registered measurement seed. Seeds are never ranked as
/// hyperparameters; this makes stochastic instability visible beside the
/// campaign-wide paired estimate.
public struct LabSeedComparison: Codable, Equatable, Sendable {
    public let generationSeed: Int
    public let independentRootCount: Int
    public let matchedObservationCount: Int
    public let deltaExpectedUtility: Double
    public let deltaOracleNetKSS: Double
    public let deltaPrecisionWhenShown: Double
    public let deltaBadWhenShown: Double
    public let deltaLateRate: Double
    public let deltaP95LatencyMilliseconds: Double
}

public struct LabRareEventBound: Codable, Equatable, Sendable {
    public let events: Int
    public let opportunities: Int
    public let observedRate: Double
    public let upper95Wilson: Double

    public init(events: Int, opportunities: Int) {
        self.events = max(0, events)
        self.opportunities = max(0, opportunities)
        observedRate = opportunities > 0 ? Double(events) / Double(opportunities) : 0
        upper95Wilson = Self.upperWilson(events: events, total: opportunities)
    }

    private static func upperWilson(events: Int, total: Int) -> Double {
        guard total > 0 else { return 1 }
        let z = 1.959_963_984_540_054
        let n = Double(total)
        let p = Double(max(0, events)) / n
        let denominator = 1 + z * z / n
        let center = p + z * z / (2 * n)
        let margin = z * sqrt((p * (1 - p) + z * z / (4 * n)) / n)
        return min(1, max(0, (center + margin) / denominator))
    }
}

public enum LabPromotionDecision: String, Codable, Sendable {
    case advance
    case continueTesting = "continue-testing"
    case reject
}

public struct LabPairedComparisonReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.paired-comparison.v1"

    public let schema: String
    public let baselineReportID: UUID
    public let candidateReportID: UUID
    public let phase: LabCampaignPhase
    public let independentRootCount: Int
    public let matchedObservationCount: Int
    public let bootstrapIterations: Int
    public let baselineSelective: LabSelectivePredictionMetrics
    public let candidateSelective: LabSelectivePredictionMetrics
    public let deltaOracleNetKSS: LabEstimate
    public let deltaExpectedUtility: LabEstimate
    public let deltaPrecisionWhenShown: LabEstimate
    public let deltaBadWhenShown: LabEstimate
    public let deltaLateRate: LabEstimate
    public let deltaP95LatencyMilliseconds: LabEstimate
    public let wins: Int
    public let ties: Int
    public let losses: Int
    public let sliceComparisons: [LabSliceComparison]
    public let worstSlice: LabSliceComparison?
    public let bestSlice: LabSliceComparison?
    public let seedComparisons: [LabSeedComparison]
    public let worstSeed: LabSeedComparison?
    public let hardGateFailures: [String]
    public let rareEventBounds: [String: LabRareEventBound]
    public let decision: LabPromotionDecision

    public init(
        baselineReportID: UUID,
        candidateReportID: UUID,
        phase: LabCampaignPhase,
        independentRootCount: Int,
        matchedObservationCount: Int,
        bootstrapIterations: Int,
        baselineSelective: LabSelectivePredictionMetrics,
        candidateSelective: LabSelectivePredictionMetrics,
        deltaOracleNetKSS: LabEstimate,
        deltaExpectedUtility: LabEstimate,
        deltaPrecisionWhenShown: LabEstimate,
        deltaBadWhenShown: LabEstimate,
        deltaLateRate: LabEstimate,
        deltaP95LatencyMilliseconds: LabEstimate,
        wins: Int,
        ties: Int,
        losses: Int,
        sliceComparisons: [LabSliceComparison],
        worstSlice: LabSliceComparison?,
        bestSlice: LabSliceComparison?,
        seedComparisons: [LabSeedComparison],
        worstSeed: LabSeedComparison?,
        hardGateFailures: [String],
        rareEventBounds: [String: LabRareEventBound],
        decision: LabPromotionDecision
    ) {
        schema = Self.currentSchema
        self.baselineReportID = baselineReportID
        self.candidateReportID = candidateReportID
        self.phase = phase
        self.independentRootCount = independentRootCount
        self.matchedObservationCount = matchedObservationCount
        self.bootstrapIterations = bootstrapIterations
        self.baselineSelective = baselineSelective
        self.candidateSelective = candidateSelective
        self.deltaOracleNetKSS = deltaOracleNetKSS
        self.deltaExpectedUtility = deltaExpectedUtility
        self.deltaPrecisionWhenShown = deltaPrecisionWhenShown
        self.deltaBadWhenShown = deltaBadWhenShown
        self.deltaLateRate = deltaLateRate
        self.deltaP95LatencyMilliseconds = deltaP95LatencyMilliseconds
        self.wins = wins
        self.ties = ties
        self.losses = losses
        self.sliceComparisons = sliceComparisons
        self.worstSlice = worstSlice
        self.bestSlice = bestSlice
        self.seedComparisons = seedComparisons
        self.worstSeed = worstSeed
        self.hardGateFailures = hardGateFailures
        self.rareEventBounds = rareEventBounds
        self.decision = decision
    }
}

public enum LabPairedComparisonError: Error, LocalizedError, Equatable, Sendable {
    case suiteMismatch
    case scoringMismatch
    case duplicateObservation
    case unmatchedObservations
    case noIndependentRoots

    public var errorDescription: String? {
        switch self {
        case .suiteMismatch:
            "Paired comparison requires the exact same selected suite digest."
        case .scoringMismatch:
            "Paired comparison requires the exact same locked scoring policy."
        case .duplicateObservation:
            "A report contains duplicate root/checkpoint/context/repetition observations."
        case .unmatchedObservations:
            "Baseline and candidate observations do not match one-for-one."
        case .noIndependentRoots:
            "Paired comparison needs at least one independent root situation."
        }
    }
}

public enum LabPairedComparison {
    public static func compare(
        baseline: LabRunReport,
        candidate: LabRunReport,
        phase: LabCampaignPhase = .developmentConfirmation,
        primaryMetric: LabPrimaryResearchMetric = .expectedUtility,
        promotionRule: LabPromotionRule = .init(),
        utility: LabUtilityConfiguration = .init(),
        bootstrapSeed: UInt64 = 0x5449_4C44_4556_3201
    ) throws -> LabPairedComparisonReport {
        try promotionRule.validated()
        try utility.validated()
        guard baseline.suiteDigestSHA256 == candidate.suiteDigestSHA256 else {
            throw LabPairedComparisonError.suiteMismatch
        }
        guard baseline.arm.scoring == candidate.arm.scoring,
              baseline.arm.scoring.weightsLockedDuringComparison else {
            throw LabPairedComparisonError.scoringMismatch
        }

        let baselineByKey = try keyed(baseline.cases)
        let candidateByKey = try keyed(candidate.cases)
        guard baselineByKey.keys == candidateByKey.keys else {
            throw LabPairedComparisonError.unmatchedObservations
        }
        let pairs = baselineByKey.keys.sorted().map { key in
            ObservationPair(
                rootID: key.rootID,
                category: baselineByKey[key]!.category,
                baseline: baselineByKey[key]!,
                candidate: candidateByKey[key]!
            )
        }
        let roots = Dictionary(grouping: pairs, by: \.rootID)
        let rootIDs = roots.keys.sorted()
        guard !rootIDs.isEmpty else { throw LabPairedComparisonError.noIndependentRoots }

        let observed = metricDeltas(pairs, utility: utility)
        var samples: [MetricVector] = []
        samples.reserveCapacity(promotionRule.bootstrapIterations)
        var generator = SeededGenerator(seed: bootstrapSeed)
        for _ in 0..<promotionRule.bootstrapIterations {
            var sampled: [ObservationPair] = []
            sampled.reserveCapacity(pairs.count)
            for _ in rootIDs.indices {
                let root = rootIDs[Int(generator.next() % UInt64(rootIDs.count))]
                sampled.append(contentsOf: roots[root]!)
            }
            samples.append(metricDeltas(sampled, utility: utility))
        }

        let expectedEstimate = estimate(observed.expectedUtility, samples.map(\.expectedUtility))
        let oracleEstimate = estimate(observed.oracleNetKSS, samples.map(\.oracleNetKSS))
        let precisionEstimate = estimate(observed.precisionWhenShown, samples.map(\.precisionWhenShown))
        let badEstimate = estimate(observed.badWhenShown, samples.map(\.badWhenShown))
        let lateEstimate = estimate(observed.lateRate, samples.map(\.lateRate))
        let latencyEstimate = estimate(observed.p95Latency, samples.map(\.p95Latency))

        var wins = 0
        var ties = 0
        var losses = 0
        for root in rootIDs {
            let delta = metricDeltas(roots[root]!, utility: utility).expectedUtility
            if abs(delta) < 0.000_001 { ties += 1 }
            else if delta > 0 { wins += 1 }
            else { losses += 1 }
        }

        let categories = Set(pairs.map(\.category)).sorted()
        let slices = categories.map { category -> LabSliceComparison in
            let values = pairs.filter { $0.category == category }
            let delta = metricDeltas(values, utility: utility)
            return LabSliceComparison(
                slice: category,
                independentRootCount: Set(values.map(\.rootID)).count,
                deltaExpectedUtility: delta.expectedUtility,
                deltaPrecisionWhenShown: delta.precisionWhenShown,
                deltaBadWhenShown: delta.badWhenShown,
                deltaLateRate: delta.lateRate
            )
        }.sorted { lhs, rhs in
            if lhs.deltaExpectedUtility == rhs.deltaExpectedUtility { return lhs.slice < rhs.slice }
            return lhs.deltaExpectedUtility < rhs.deltaExpectedUtility
        }
        let seedComparisons = Dictionary(grouping: pairs) { $0.candidate.generationSeed }
            .map { seed, values -> LabSeedComparison in
                let delta = metricDeltas(values, utility: utility)
                return LabSeedComparison(
                    generationSeed: seed,
                    independentRootCount: Set(values.map(\.rootID)).count,
                    matchedObservationCount: values.count,
                    deltaExpectedUtility: delta.expectedUtility,
                    deltaOracleNetKSS: delta.oracleNetKSS,
                    deltaPrecisionWhenShown: delta.precisionWhenShown,
                    deltaBadWhenShown: delta.badWhenShown,
                    deltaLateRate: delta.lateRate,
                    deltaP95LatencyMilliseconds: delta.p95Latency
                )
            }
            .sorted { $0.generationSeed < $1.generationSeed }
        let worstSeed = seedComparisons.min {
            if $0.deltaExpectedUtility == $1.deltaExpectedUtility {
                if $0.deltaBadWhenShown == $1.deltaBadWhenShown {
                    return $0.generationSeed < $1.generationSeed
                }
                return $0.deltaBadWhenShown > $1.deltaBadWhenShown
            }
            return $0.deltaExpectedUtility < $1.deltaExpectedUtility
        }

        let failures = hardGateFailures(candidate)
        let primary: LabEstimate
        switch primaryMetric {
        case .expectedUtility: primary = expectedEstimate
        case .oracleNetKeystrokeSavings: primary = oracleEstimate
        case .precisionWhenShown: primary = precisionEstimate
        }
        let probabilityPass = primary.probabilityPositive >= promotionRule.minimumProbabilityPositive
        let effectPass = phase == .discovery
            || primary.lower95 > promotionRule.minimumPrimaryEffect
        let riskPass = badEstimate.upper95 <= promotionRule.maximumBadWhenShownIncrease
        let latencyPass = latencyEstimate.upper95 <= promotionRule.latencyNoninferiorityMilliseconds
        let slicePass = slices.allSatisfy {
            $0.deltaExpectedUtility >= -promotionRule.maximumProtectedSliceRegression
        }
        let decision: LabPromotionDecision
        if !failures.isEmpty || !riskPass || !latencyPass || !slicePass {
            decision = .reject
        } else if probabilityPass && effectPass {
            decision = .advance
        } else {
            decision = .continueTesting
        }

        return LabPairedComparisonReport(
            baselineReportID: baseline.id,
            candidateReportID: candidate.id,
            phase: phase,
            independentRootCount: rootIDs.count,
            matchedObservationCount: pairs.count,
            bootstrapIterations: promotionRule.bootstrapIterations,
            baselineSelective: LabSelectivePredictionMetrics(cases: baseline.cases, utility: utility),
            candidateSelective: LabSelectivePredictionMetrics(cases: candidate.cases, utility: utility),
            deltaOracleNetKSS: oracleEstimate,
            deltaExpectedUtility: expectedEstimate,
            deltaPrecisionWhenShown: precisionEstimate,
            deltaBadWhenShown: badEstimate,
            deltaLateRate: lateEstimate,
            deltaP95LatencyMilliseconds: latencyEstimate,
            wins: wins,
            ties: ties,
            losses: losses,
            sliceComparisons: slices,
            worstSlice: slices.first,
            bestSlice: slices.last,
            seedComparisons: seedComparisons,
            worstSeed: worstSeed,
            hardGateFailures: failures,
            rareEventBounds: rareEventBounds(candidate.cases),
            decision: decision
        )
    }

    /// Replays stricter confidence thresholds over observations for which a
    /// scored displayed candidate and probability were retained. It never
    /// pretends that a candidate suppressed before scoring can be recovered.
    public static func observedRiskCoverage(
        report: LabRunReport,
        trustLimit: Double = 0.01,
        thresholds: [Double] = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 },
        utility: LabUtilityConfiguration = .init()
    ) -> LabRiskCoverageReport {
        let scorable = report.cases.filter { $0.offered && $0.meanTokenProbability != nil }
        let completedCount = report.cases.count {
            $0.outcome != .timeout && $0.outcome != .error
        }
        let baselineCharacters = report.cases.reduce(0) { $0 + $1.baselineKeystrokes }
        let points = thresholds.sorted().map { threshold -> LabRiskCoveragePoint in
            let shown = scorable.filter { ($0.meanTokenProbability ?? -1) >= threshold }
            let useful = shown.count(where: { $0.outcome == .useful })
            let bad = shown.count(where: { $0.outcome == .wrong || $0.outcome == .unwanted })
            let expected = shown.reduce(0.0) {
                $0 + LabExpectedUtility.milliseconds(for: $1, configuration: utility)
            }
            return LabRiskCoveragePoint(
                threshold: threshold,
                coverage: rate(shown.count, completedCount),
                precisionWhenShown: rate(useful, shown.count),
                badWhenShown: rate(bad, shown.count),
                badWhenShownUpper95Wilson: LabRareEventBound(
                    events: bad, opportunities: shown.count
                ).upper95Wilson,
                usefulCoverage: rate(useful, report.cases.count(where: \.expectedSuggestion)),
                expectedUtilityMillisecondsPer1000Characters: baselineCharacters > 0
                    ? expected / Double(baselineCharacters) * 1_000
                    : 0,
                shown: shown.count,
                meanVisibleCharacters: shown.isEmpty ? 0
                    : Double(shown.reduce(0) { $0 + $1.visibleCharacterCount }) / Double(shown.count),
                meanVisibleWords: shown.isEmpty ? 0
                    : Double(shown.reduce(0) { $0 + $1.visibleWordCount }) / Double(shown.count)
            )
        }
        let trusted = points
            .filter { $0.shown > 0 && $0.badWhenShownUpper95Wilson <= trustLimit }
            .max { lhs, rhs in lhs.coverage < rhs.coverage }
        return LabRiskCoverageReport(
            schema: LabRiskCoverageReport.currentSchema,
            sourceReportID: report.id,
            sourceArmID: report.arm.id,
            trustLimit: trustLimit,
            eligibleOpportunities: completedCount,
            scoredCandidateCount: scorable.count,
            points: points,
            slices: [],
            highestCoverageUnderTrustLimit: trusted,
            completeCandidateReplay: false,
            limitation: "Observed-candidate curve only: candidates suppressed before aggregate scoring cannot be reconstructed from this report. Use the synthetic candidate cache for a complete curve."
        )
    }

    private static func keyed(_ cases: [LabCaseResult]) throws -> [ObservationKey: LabCaseResult] {
        var result: [ObservationKey: LabCaseResult] = [:]
        for value in cases {
            let key = ObservationKey(value)
            guard result.updateValue(value, forKey: key) == nil else {
                throw LabPairedComparisonError.duplicateObservation
            }
        }
        return result
    }

    private static func metricDeltas(
        _ pairs: [ObservationPair],
        utility: LabUtilityConfiguration
    ) -> MetricVector {
        let baseline = metrics(pairs.map(\.baseline), utility: utility)
        let candidate = metrics(pairs.map(\.candidate), utility: utility)
        return MetricVector(
            oracleNetKSS: candidate.oracleNetKSS - baseline.oracleNetKSS,
            expectedUtility: candidate.expectedUtility - baseline.expectedUtility,
            precisionWhenShown: candidate.precisionWhenShown - baseline.precisionWhenShown,
            badWhenShown: candidate.badWhenShown - baseline.badWhenShown,
            lateRate: candidate.lateRate - baseline.lateRate,
            p95Latency: candidate.p95Latency - baseline.p95Latency
        )
    }

    private static func metrics(
        _ cases: [LabCaseResult],
        utility: LabUtilityConfiguration
    ) -> MetricVector {
        let selective = LabSelectivePredictionMetrics(cases: cases, utility: utility)
        let latencies = cases.compactMap { $0.firstTokenMilliseconds ?? $0.latencyMilliseconds }.sorted()
        return MetricVector(
            oracleNetKSS: selective.oracleNetKeystrokeSavingsRate,
            expectedUtility: selective.expectedUtilityMillisecondsPer1000Characters,
            precisionWhenShown: selective.precisionWhenShown,
            badWhenShown: selective.badWhenShown,
            lateRate: selective.lateRate,
            p95Latency: percentile(latencies, fraction: 0.95)
        )
    }

    private static func estimate(_ observed: Double, _ bootstrap: [Double]) -> LabEstimate {
        let sorted = bootstrap.sorted()
        guard !sorted.isEmpty else {
            return LabEstimate(mean: observed, lower95: observed, upper95: observed, probabilityPositive: 0)
        }
        return LabEstimate(
            mean: observed,
            lower95: percentile(sorted, fraction: 0.025),
            upper95: percentile(sorted, fraction: 0.975),
            probabilityPositive: Double(bootstrap.count(where: { $0 > 0 })) / Double(bootstrap.count)
        )
    }

    private static func hardGateFailures(_ report: LabRunReport) -> [String] {
        var result = report.metrics.promotionGateFailures
        if report.arm.judgment.cleanerPreset == .diagnostic {
            result.append("diagnostic-arm-ineligible")
        }
        if !report.metrics.complete { result.append("incomplete-run") }
        if report.metrics.gates.badSuggestions == .fail { result.append("bad-suggestion-gate") }
        if report.metrics.gates.sensitiveSituations == .fail { result.append("sensitive-situation-gate") }
        if report.metrics.gates.temporalIntegrity == .fail { result.append("temporal-integrity-gate") }
        if report.metrics.gates.privacy == .fail { result.append("privacy-gate") }
        return Array(Set(result)).sorted()
    }

    private static func rareEventBounds(_ cases: [LabCaseResult]) -> [String: LabRareEventBound] {
        let completed = cases.filter { $0.outcome != .timeout && $0.outcome != .error }
        let sensitive = completed.filter {
            $0.category.contains("sensitive") || $0.category.contains("privacy")
        }
        return [
            "bad-when-shown": LabRareEventBound(
                events: completed.count { $0.offered && ($0.outcome == .wrong || $0.outcome == .unwanted) },
                opportunities: completed.count { $0.offered }
            ),
            "sensitive-shown": LabRareEventBound(
                events: sensitive.count(where: \.offered),
                opportunities: sensitive.count
            ),
            "temporal-integrity-failure": LabRareEventBound(
                events: completed.count { !$0.temporalIntegrityPassed },
                opportunities: completed.count
            ),
            "protocol-failure": LabRareEventBound(
                events: cases.count { $0.outcome == .timeout || $0.outcome == .error },
                opportunities: cases.count
            ),
        ]
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = min(values.count - 1, max(0, Int((Double(values.count - 1) * fraction).rounded())))
        return values[index]
    }

    private static func percentile(_ values: [Int], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = min(values.count - 1, max(0, Int((Double(values.count - 1) * fraction).rounded())))
        return Double(values[index])
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }
}

private enum LabExpectedUtility {
    static func milliseconds(
        for result: LabCaseResult,
        configuration: LabUtilityConfiguration
    ) -> Double {
        guard result.offered else { return 0 }
        let latency = result.firstTokenMilliseconds ?? result.latencyMilliseconds
        let timely = latency.map { $0 <= configuration.firstStableWordDeadlineMilliseconds } ?? false
        guard timely else { return 0 }
        switch result.outcome {
        case .useful:
            let savedMilliseconds = Double(max(0, result.grossKeystrokesSaved))
                / configuration.typingCharactersPerSecond * 1_000
            let accepted = configuration.usefulAcceptanceProbability
                * (savedMilliseconds - configuration.acceptanceActionMilliseconds)
            let ignored = (1 - configuration.usefulAcceptanceProbability)
                * configuration.ignoredAttentionMilliseconds
            return accepted - ignored
        case .wrong, .unwanted:
            return -configuration.wrongAttentionMilliseconds
                - Double(max(0, result.correctionKeystrokes))
                    * configuration.correctionMillisecondsPerCharacter
        case .silent, .correctSilence, .timeout, .error:
            return 0
        }
    }
}

private struct ObservationKey: Hashable, Comparable {
    let rootID: String
    let scenarioID: String
    let checkpoint: String
    let contextVariant: String
    let generationSeed: Int
    let repetition: Int

    init(_ value: LabCaseResult) {
        rootID = value.rootScenarioID ?? value.scenarioID
        scenarioID = value.scenarioID
        checkpoint = value.replayCheckpoint.rawValue
        contextVariant = value.contextVariant.rawValue
        generationSeed = value.generationSeed
        repetition = value.repetition
    }

    static func < (lhs: ObservationKey, rhs: ObservationKey) -> Bool {
        if lhs.rootID != rhs.rootID { return lhs.rootID < rhs.rootID }
        if lhs.scenarioID != rhs.scenarioID { return lhs.scenarioID < rhs.scenarioID }
        if lhs.checkpoint != rhs.checkpoint { return lhs.checkpoint < rhs.checkpoint }
        if lhs.contextVariant != rhs.contextVariant { return lhs.contextVariant < rhs.contextVariant }
        if lhs.generationSeed != rhs.generationSeed { return lhs.generationSeed < rhs.generationSeed }
        return lhs.repetition < rhs.repetition
    }
}

private struct ObservationPair {
    let rootID: String
    let category: String
    let baseline: LabCaseResult
    let candidate: LabCaseResult
}

private struct MetricVector {
    let oracleNetKSS: Double
    let expectedUtility: Double
    let precisionWhenShown: Double
    let badWhenShown: Double
    let lateRate: Double
    let p95Latency: Double
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
