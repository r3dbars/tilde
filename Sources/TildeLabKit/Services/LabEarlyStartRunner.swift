import TildeCore
import Foundation

/// Q10 — K=1 early-start timing falsifier.
///
/// Offline replay only. Each synthetic situation's golden continuation is
/// replayed character by character. At the third character of a qualifying
/// word the prompt is snapshotted and one short continuation is requested;
/// the same situation is also requested at the following space, which is
/// today's production behaviour. The runner measures readiness, prefix
/// compatibility at the next boundary, lead time, lock safety, and compute.
///
/// Nothing here touches the running product. No prompt, candidate, scenario,
/// or golden text ever reaches the report.
public struct LabEarlyStartConfiguration: Equatable, Sendable {
    /// Characters of the current word typed before the early request starts.
    public static let earlyCharacterOffset = 3
    /// A word must be long enough that starting early actually buys time.
    public static let minimumWordCharacters = 4
    /// Frozen keystroke model: 180 ms between characters (about 66 wpm).
    public static let keystrokeIntervalMilliseconds = 180
    /// Reported sensitivity points for slower and faster writers.
    public static let sensitivityIntervalsMilliseconds = [120, 240]
    public static let coldTemperature: Double = 0
    public static let hotTemperature: Double = 0.80
    public static let coldSeed = 0
    public static let hotSeed = 907

    public var maximumSituations: Int
    public var maximumOpportunitiesPerSituation: Int
    public var minimumUsefulCharacters: Int
    public var predictionTokens: Int

    public init(
        maximumSituations: Int = 360,
        maximumOpportunitiesPerSituation: Int = 6,
        minimumUsefulCharacters: Int = 6,
        predictionTokens: Int = 12
    ) {
        self.maximumSituations = maximumSituations
        self.maximumOpportunitiesPerSituation = maximumOpportunitiesPerSituation
        self.minimumUsefulCharacters = minimumUsefulCharacters
        self.predictionTokens = predictionTokens
    }

    @discardableResult
    public func validated() throws -> LabEarlyStartConfiguration {
        guard (1...360).contains(maximumSituations),
              (1...16).contains(maximumOpportunitiesPerSituation),
              (1...64).contains(minimumUsefulCharacters),
              (1...32).contains(predictionTokens) else {
            throw LabEarlyStartError.invalidConfiguration
        }
        return self
    }
}

public enum LabEarlyStartError: Error, LocalizedError, Sendable {
    case invalidConfiguration
    case insufficientSituations(expected: Int, actual: Int)
    case unexpectedModelHash(String)
    case notOnACPower
    case noOpportunities
    case incompleteMeasurement(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The early-start configuration is outside its frozen bounds."
        case let .insufficientSituations(expected, actual):
            "Early start expected \(expected) speak situations but found \(actual)."
        case let .unexpectedModelHash(value):
            "Early start refuses the selected model hash \(value); Q10 is pinned to production Gemma 4 E2B."
        case .notOnACPower:
            "Early start requires AC power, normal power mode, and a safe thermal state."
        case .noOpportunities:
            "No golden continuation produced a qualifying mid-word opportunity."
        case let .incompleteMeasurement(expected, actual):
            "Early start expected \(expected) terminal generations but received \(actual)."
        }
    }
}

// MARK: - Replay planning

/// One mid-word start point inside a golden continuation. Offsets are
/// character counts inside that continuation; no text is carried here.
public struct LabEarlyStartCut: Equatable, Sendable {
    /// Characters of the golden continuation already typed at the early start.
    public let cutOffset: Int
    /// Characters the writer still types from the cut through the boundary
    /// space, inclusive of that space.
    public let charactersToBoundary: Int
    /// Golden characters that remain after the boundary space.
    public let charactersAfterBoundary: Int

    public init(cutOffset: Int, charactersToBoundary: Int, charactersAfterBoundary: Int) {
        self.cutOffset = cutOffset
        self.charactersToBoundary = charactersToBoundary
        self.charactersAfterBoundary = charactersAfterBoundary
    }
}

public enum LabEarlyStartPlanner {
    /// Qualifying opportunities inside one golden continuation.
    ///
    /// A word qualifies when it has at least `minimumWordCharacters`
    /// characters, is followed by exactly one space, and leaves at least
    /// `minimumUsefulCharacters` golden characters after that space. That
    /// keeps every opportunity a genuine "next useful boundary".
    public static func cuts(
        in continuation: String,
        minimumUsefulCharacters: Int,
        maximumOpportunities: Int
    ) -> [LabEarlyStartCut] {
        let characters = Array(continuation)
        var result: [LabEarlyStartCut] = []
        for range in wordRanges(in: characters) {
            guard result.count < maximumOpportunities else { break }
            let length = range.upperBound - range.lowerBound
            guard length >= LabEarlyStartConfiguration.minimumWordCharacters else { continue }
            let boundary = range.upperBound
            guard boundary < characters.count, characters[boundary] == " " else { continue }
            let afterBoundary = characters.count - (boundary + 1)
            guard afterBoundary >= minimumUsefulCharacters else { continue }
            let cut = range.lowerBound + LabEarlyStartConfiguration.earlyCharacterOffset
            result.append(LabEarlyStartCut(
                cutOffset: cut,
                charactersToBoundary: (boundary - cut) + 1,
                charactersAfterBoundary: afterBoundary
            ))
        }
        return result
    }

    private static func wordRanges(in characters: [Character]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var index = 0
        while index < characters.count {
            guard characters[index].isLetter || characters[index].isNumber else {
                index += 1
                continue
            }
            let start = index
            while index < characters.count,
                  characters[index].isLetter || characters[index].isNumber {
                index += 1
            }
            ranges.append(start..<index)
        }
        return ranges
    }
}

// MARK: - Measurements

public struct LabEarlyStartGeneration: Equatable, Sendable {
    /// The production-cleaned suggestion, empty when the cleaner suppressed it.
    public let text: String
    /// The normalized but uncleaned continuation, used only to separate a
    /// cleaner artefact from a genuine model miss.
    public let rawContinuation: String
    public let latencyMilliseconds: Int
    public let decodedTokens: Int

    public init(
        text: String,
        rawContinuation: String,
        latencyMilliseconds: Int,
        decodedTokens: Int
    ) {
        self.text = text
        self.rawContinuation = rawContinuation
        self.latencyMilliseconds = latencyMilliseconds
        self.decodedTokens = decodedTokens
    }
}

/// One measured opportunity. `remainderAfterCut` is synthetic corpus text and
/// stays in memory: it is never encoded into a report.
public struct LabEarlyStartMeasurement: Sendable {
    public let cut: LabEarlyStartCut
    public let remainderAfterCut: String
    public let cold: LabEarlyStartGeneration
    public let hot: LabEarlyStartGeneration
    public let boundary: LabEarlyStartGeneration

    public init(
        cut: LabEarlyStartCut,
        remainderAfterCut: String,
        cold: LabEarlyStartGeneration,
        hot: LabEarlyStartGeneration,
        boundary: LabEarlyStartGeneration
    ) {
        self.cut = cut
        self.remainderAfterCut = remainderAfterCut
        self.cold = cold
        self.hot = hot
        self.boundary = boundary
    }
}

// MARK: - Report shapes

public struct LabEarlyStartPrimaryMetrics: Codable, Equatable, Sendable {
    public let opportunityCount: Int
    public let readyByBoundaryCount: Int
    public let readyByBoundaryRate: Double
    public let compatibleThroughBoundaryCount: Int
    public let compatibleThroughBoundaryRate: Double
    public let lockableCount: Int
    public let lockableRate: Double
    public let revealedCount: Int
    public let simulatedFalseLockCount: Int
    public let simulatedFalseLockRate: Double
    public let leadP25Milliseconds: Int
    public let leadMedianMilliseconds: Int
    public let leadP75Milliseconds: Int
    public let meanFutureCharactersBeyondBoundary: Double
    public let earlyLatencyP50Milliseconds: Int
    public let earlyLatencyP95Milliseconds: Int
    public let boundaryLatencyP50Milliseconds: Int
    public let boundaryLatencyP95Milliseconds: Int
    public let computeMultipleDecodedTokens: Double
    public let computeMultipleRequestLatency: Double
    public let earlyCleanerSuppressedCount: Int
    public let earlyCleanerSuppressedRate: Double
    public let uncleanedCompatibleRate: Double
}

public struct LabEarlyStartPairMetrics: Codable, Equatable, Sendable {
    public let coldLockableRate: Double
    public let pairLockableRate: Double
    public let pairCoverageGainPercentagePoints: Double
    public let hotOnlyLockCount: Int
    public let pairComputeMultipleDecodedTokens: Double
    public let hotDuplicatesColdRate: Double
    public let hotCleanerSurvivalRate: Double
    public let hotEmptyRate: Double
}

public struct LabEarlyStartSensitivityPoint: Codable, Equatable, Sendable {
    public let keystrokeIntervalMilliseconds: Int
    public let readyByBoundaryRate: Double
    public let leadMedianMilliseconds: Int
    public let lockableRate: Double
}

/// Registered Q10 thresholds evaluated by the runner itself, so the overnight
/// report adjudicates against the frozen numbers instead of a later reading.
public struct LabEarlyStartGateOutcome: Codable, Equatable, Sendable {
    public static let minimumReadyByBoundaryRate = 0.50
    public static let minimumLeadMedianMilliseconds = 200
    public static let minimumLockableRate = 0.15
    public static let maximumSimulatedFalseLockRate = 0.02
    public static let maximumComputeMultiple = 1.50
    public static let minimumPairCoverageGainPercentagePoints = 5.0
    public static let maximumPairComputeMultiple = 2.00
    public static let maximumHotDuplicateRate = 0.50
    public static let minimumHotCleanerSurvivalRate = 0.60

    public let readinessGatePassed: Bool
    public let leadGatePassed: Bool
    public let lockableGatePassed: Bool
    public let falseLockGatePassed: Bool
    public let computeGatePassed: Bool
    public let primaryPromotionPassed: Bool
    public let pairCoverageGatePassed: Bool
    public let pairComputeGatePassed: Bool
    public let pairPromotionInterestPassed: Bool
    public let pairKillRuleTriggered: Bool

    public init(primary: LabEarlyStartPrimaryMetrics, pair: LabEarlyStartPairMetrics) {
        readinessGatePassed = primary.readyByBoundaryRate >= Self.minimumReadyByBoundaryRate
        leadGatePassed = primary.leadMedianMilliseconds >= Self.minimumLeadMedianMilliseconds
        lockableGatePassed = primary.lockableRate >= Self.minimumLockableRate
        falseLockGatePassed = primary.simulatedFalseLockRate < Self.maximumSimulatedFalseLockRate
        computeGatePassed = primary.computeMultipleDecodedTokens <= Self.maximumComputeMultiple
        primaryPromotionPassed = readinessGatePassed
            && leadGatePassed
            && lockableGatePassed
            && falseLockGatePassed
            && computeGatePassed
        pairCoverageGatePassed = pair.pairCoverageGainPercentagePoints
            >= Self.minimumPairCoverageGainPercentagePoints
        pairComputeGatePassed = pair.pairComputeMultipleDecodedTokens
            <= Self.maximumPairComputeMultiple
        pairPromotionInterestPassed = pairCoverageGatePassed && pairComputeGatePassed
        pairKillRuleTriggered = pair.hotDuplicatesColdRate >= Self.maximumHotDuplicateRate
            || pair.hotCleanerSurvivalRate < Self.minimumHotCleanerSurvivalRate
    }
}

public struct LabEarlyStartReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.early-start.v1"

    public let schema: String
    public let startedAt: Date
    public let finishedAt: Date
    public let suiteName: String
    public let suiteDigestSHA256: String
    public let situationCount: Int
    public let opportunityCount: Int
    public let plannedGenerations: Int
    public let completedGenerations: Int
    public let earlyCharacterOffset: Int
    public let minimumWordCharacters: Int
    public let keystrokeIntervalMilliseconds: Int
    public let minimumUsefulCharacters: Int
    public let predictionTokens: Int
    public let hotTemperature: Double
    public let hotSeed: Int
    public let assets: LabAssetSnapshot
    public let execution: LabExecutionSnapshot
    public let startingThermalState: String
    public let worstThermalState: String
    public let startingMachineState: LabResearchMachineState
    public let finishingMachineState: LabResearchMachineState
    public let primary: LabEarlyStartPrimaryMetrics
    public let pair: LabEarlyStartPairMetrics
    public let sensitivity: [LabEarlyStartSensitivityPoint]
    public let gates: LabEarlyStartGateOutcome
    public let privacy: LabAggregateOnlyPrivacy

    public init(
        startedAt: Date,
        finishedAt: Date,
        suiteName: String,
        suiteDigestSHA256: String,
        situationCount: Int,
        opportunityCount: Int,
        plannedGenerations: Int,
        completedGenerations: Int,
        minimumUsefulCharacters: Int,
        predictionTokens: Int,
        assets: LabAssetSnapshot,
        execution: LabExecutionSnapshot,
        startingThermalState: String,
        worstThermalState: String,
        startingMachineState: LabResearchMachineState,
        finishingMachineState: LabResearchMachineState,
        primary: LabEarlyStartPrimaryMetrics,
        pair: LabEarlyStartPairMetrics,
        sensitivity: [LabEarlyStartSensitivityPoint],
        privacy: LabAggregateOnlyPrivacy = .aggregateOnly
    ) {
        schema = Self.currentSchema
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.suiteName = suiteName
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.situationCount = situationCount
        self.opportunityCount = opportunityCount
        self.plannedGenerations = plannedGenerations
        self.completedGenerations = completedGenerations
        earlyCharacterOffset = LabEarlyStartConfiguration.earlyCharacterOffset
        minimumWordCharacters = LabEarlyStartConfiguration.minimumWordCharacters
        keystrokeIntervalMilliseconds = LabEarlyStartConfiguration.keystrokeIntervalMilliseconds
        self.minimumUsefulCharacters = minimumUsefulCharacters
        self.predictionTokens = predictionTokens
        hotTemperature = LabEarlyStartConfiguration.hotTemperature
        hotSeed = LabEarlyStartConfiguration.hotSeed
        self.assets = assets
        self.execution = execution
        self.startingThermalState = startingThermalState
        self.worstThermalState = worstThermalState
        self.startingMachineState = startingMachineState
        self.finishingMachineState = finishingMachineState
        self.primary = primary
        self.pair = pair
        self.sensitivity = sensitivity
        gates = LabEarlyStartGateOutcome(primary: primary, pair: pair)
        self.privacy = privacy
    }
}

// MARK: - Analysis

public enum LabEarlyStartAnalyzer {
    /// True when the early candidate still agrees with what the writer typed
    /// all the way through the boundary space.
    public static func compatibleThroughBoundary(
        candidate: String,
        measurement: LabEarlyStartMeasurement
    ) -> Bool {
        LabExactPrefix.sharedCharacters(candidate, measurement.remainderAfterCut)
            >= measurement.cut.charactersToBoundary
    }

    /// Exact golden characters the candidate offers beyond the boundary.
    public static func futureCharactersBeyondBoundary(
        candidate: String,
        measurement: LabEarlyStartMeasurement
    ) -> Int {
        let normalizedCandidate = LabExactPrefix.normalized(candidate)
        let normalizedRemainder = LabExactPrefix.normalized(measurement.remainderAfterCut)
        let consumed = measurement.cut.charactersToBoundary
        guard normalizedCandidate.count > consumed, normalizedRemainder.count > consumed else {
            return 0
        }
        return LabExactPrefix.sharedCharacters(
            String(normalizedCandidate.dropFirst(consumed)),
            String(normalizedRemainder.dropFirst(consumed))
        )
    }

    /// A lock the rule would take: ready in time, still compatible, and
    /// carrying enough new characters to be worth showing.
    public static func isLockable(
        candidate: LabEarlyStartGeneration,
        measurement: LabEarlyStartMeasurement,
        minimumUsefulCharacters: Int,
        keystrokeIntervalMilliseconds: Int
    ) -> Bool {
        guard isReady(
            candidate: candidate,
            measurement: measurement,
            keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
        ) else { return false }
        guard compatibleThroughBoundary(candidate: candidate.text, measurement: measurement) else {
            return false
        }
        return futureCharactersBeyondBoundary(
            candidate: candidate.text,
            measurement: measurement
        ) >= minimumUsefulCharacters
    }

    public static func isReady(
        candidate: LabEarlyStartGeneration,
        measurement: LabEarlyStartMeasurement,
        keystrokeIntervalMilliseconds: Int
    ) -> Bool {
        candidate.latencyMilliseconds
            <= measurement.cut.charactersToBoundary * keystrokeIntervalMilliseconds
    }

    /// Lead over today's start-at-space request: how much earlier the hidden
    /// candidate is available than the boundary-started one.
    public static func leadMilliseconds(
        measurement: LabEarlyStartMeasurement,
        keystrokeIntervalMilliseconds: Int
    ) -> Int {
        measurement.cut.charactersToBoundary * keystrokeIntervalMilliseconds
            + measurement.boundary.latencyMilliseconds
            - measurement.cold.latencyMilliseconds
    }

    /// A lock accepted only because normalization hid a real difference
    /// between the typed characters and the candidate's leading characters.
    /// This is a soundness check on the reveal rule, not a quality metric.
    public static func isSimulatedFalseLock(
        measurement: LabEarlyStartMeasurement,
        keystrokeIntervalMilliseconds: Int
    ) -> Bool {
        guard isReady(
            candidate: measurement.cold,
            measurement: measurement,
            keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
        ),
        compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ) else { return false }
        let span = measurement.cut.charactersToBoundary
        let typed = LabExactPrefix.whitespaceTrimmed(measurement.remainderAfterCut)
        let shown = LabExactPrefix.whitespaceTrimmed(measurement.cold.text)
        return Array(typed.prefix(span).unicodeScalars)
            != Array(shown.prefix(span).unicodeScalars)
    }

    public static func primary(
        measurements: [LabEarlyStartMeasurement],
        minimumUsefulCharacters: Int,
        keystrokeIntervalMilliseconds: Int = LabEarlyStartConfiguration.keystrokeIntervalMilliseconds
    ) -> LabEarlyStartPrimaryMetrics {
        let count = measurements.count
        var ready = 0
        var compatible = 0
        var lockable = 0
        var revealed = 0
        var falseLocks = 0
        var leads: [Int] = []
        var futureCharacters: [Int] = []
        var earlyLatencies: [Int] = []
        var boundaryLatencies: [Int] = []
        var suppressed = 0
        var uncleanedCompatible = 0
        var controlTokens = 0
        var treatmentTokens = 0
        var controlLatency = 0
        var treatmentLatency = 0

        for measurement in measurements {
            let isReadyNow = isReady(
                candidate: measurement.cold,
                measurement: measurement,
                keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
            )
            let isCompatible = compatibleThroughBoundary(
                candidate: measurement.cold.text,
                measurement: measurement
            )
            let locks = isLockable(
                candidate: measurement.cold,
                measurement: measurement,
                minimumUsefulCharacters: minimumUsefulCharacters,
                keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
            )
            if isReadyNow { ready += 1 }
            if isCompatible { compatible += 1 }
            if locks { lockable += 1 }
            if isReadyNow, isCompatible {
                revealed += 1
                if isSimulatedFalseLock(
                    measurement: measurement,
                    keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
                ) { falseLocks += 1 }
            }
            if measurement.cold.text.isEmpty { suppressed += 1 }
            if compatibleThroughBoundary(
                candidate: measurement.cold.rawContinuation,
                measurement: measurement
            ) { uncleanedCompatible += 1 }
            leads.append(leadMilliseconds(
                measurement: measurement,
                keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
            ))
            futureCharacters.append(futureCharactersBeyondBoundary(
                candidate: measurement.cold.text,
                measurement: measurement
            ))
            earlyLatencies.append(measurement.cold.latencyMilliseconds)
            boundaryLatencies.append(measurement.boundary.latencyMilliseconds)
            controlTokens += measurement.boundary.decodedTokens
            controlLatency += measurement.boundary.latencyMilliseconds
            treatmentTokens += measurement.cold.decodedTokens
            treatmentLatency += measurement.cold.latencyMilliseconds
            // A branch that arrived in time and still agrees with the typed
            // characters is the answer at the boundary, whether or not it is
            // long enough to be worth showing. Only a late or contradicted
            // branch forces today's start-at-space request as well.
            if !(isReadyNow && isCompatible) {
                treatmentTokens += measurement.boundary.decodedTokens
                treatmentLatency += measurement.boundary.latencyMilliseconds
            }
        }

        return LabEarlyStartPrimaryMetrics(
            opportunityCount: count,
            readyByBoundaryCount: ready,
            readyByBoundaryRate: rate(ready, count),
            compatibleThroughBoundaryCount: compatible,
            compatibleThroughBoundaryRate: rate(compatible, count),
            lockableCount: lockable,
            lockableRate: rate(lockable, count),
            revealedCount: revealed,
            simulatedFalseLockCount: falseLocks,
            simulatedFalseLockRate: rate(falseLocks, revealed),
            leadP25Milliseconds: percentile(leads, fraction: 0.25),
            leadMedianMilliseconds: percentile(leads, fraction: 0.50),
            leadP75Milliseconds: percentile(leads, fraction: 0.75),
            meanFutureCharactersBeyondBoundary: mean(futureCharacters),
            earlyLatencyP50Milliseconds: percentile(earlyLatencies, fraction: 0.50),
            earlyLatencyP95Milliseconds: percentile(earlyLatencies, fraction: 0.95),
            boundaryLatencyP50Milliseconds: percentile(boundaryLatencies, fraction: 0.50),
            boundaryLatencyP95Milliseconds: percentile(boundaryLatencies, fraction: 0.95),
            computeMultipleDecodedTokens: ratio(treatmentTokens, controlTokens),
            computeMultipleRequestLatency: ratio(treatmentLatency, controlLatency),
            earlyCleanerSuppressedCount: suppressed,
            earlyCleanerSuppressedRate: rate(suppressed, count),
            uncleanedCompatibleRate: rate(uncleanedCompatible, count)
        )
    }

    public static func pair(
        measurements: [LabEarlyStartMeasurement],
        minimumUsefulCharacters: Int,
        keystrokeIntervalMilliseconds: Int = LabEarlyStartConfiguration.keystrokeIntervalMilliseconds
    ) -> LabEarlyStartPairMetrics {
        let count = measurements.count
        var coldLocks = 0
        var pairLocks = 0
        var hotOnly = 0
        var duplicates = 0
        var hotSurvives = 0
        var hotEmpty = 0
        var controlTokens = 0
        var pairTokens = 0

        for measurement in measurements {
            let cold = isLockable(
                candidate: measurement.cold,
                measurement: measurement,
                minimumUsefulCharacters: minimumUsefulCharacters,
                keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
            )
            let hot = isLockable(
                candidate: measurement.hot,
                measurement: measurement,
                minimumUsefulCharacters: minimumUsefulCharacters,
                keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
            )
            let survives = [measurement.cold, measurement.hot].contains {
                isReady(
                    candidate: $0,
                    measurement: measurement,
                    keystrokeIntervalMilliseconds: keystrokeIntervalMilliseconds
                ) && compatibleThroughBoundary(candidate: $0.text, measurement: measurement)
            }
            if cold { coldLocks += 1 }
            if cold || hot { pairLocks += 1 }
            if hot, !cold { hotOnly += 1 }
            if LabExactPrefix.normalized(measurement.hot.text)
                == LabExactPrefix.normalized(measurement.cold.text) { duplicates += 1 }
            if measurement.hot.text.isEmpty {
                hotEmpty += 1
            } else {
                hotSurvives += 1
            }
            controlTokens += measurement.boundary.decodedTokens
            pairTokens += measurement.cold.decodedTokens + measurement.hot.decodedTokens
            if !survives { pairTokens += measurement.boundary.decodedTokens }
        }

        let coldRate = rate(coldLocks, count)
        let pairRate = rate(pairLocks, count)
        return LabEarlyStartPairMetrics(
            coldLockableRate: coldRate,
            pairLockableRate: pairRate,
            pairCoverageGainPercentagePoints: (pairRate - coldRate) * 100,
            hotOnlyLockCount: hotOnly,
            pairComputeMultipleDecodedTokens: ratio(pairTokens, controlTokens),
            hotDuplicatesColdRate: rate(duplicates, count),
            hotCleanerSurvivalRate: rate(hotSurvives, count),
            hotEmptyRate: rate(hotEmpty, count)
        )
    }

    public static func sensitivity(
        measurements: [LabEarlyStartMeasurement],
        minimumUsefulCharacters: Int,
        intervals: [Int] = LabEarlyStartConfiguration.sensitivityIntervalsMilliseconds
    ) -> [LabEarlyStartSensitivityPoint] {
        intervals.sorted().map { interval in
            let metrics = primary(
                measurements: measurements,
                minimumUsefulCharacters: minimumUsefulCharacters,
                keystrokeIntervalMilliseconds: interval
            )
            return LabEarlyStartSensitivityPoint(
                keystrokeIntervalMilliseconds: interval,
                readyByBoundaryRate: metrics.readyByBoundaryRate,
                leadMedianMilliseconds: metrics.leadMedianMilliseconds,
                lockableRate: metrics.lockableRate
            )
        }
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func mean(_ values: [Int]) -> Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func percentile(_ values: [Int], fraction: Double) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))
        return sorted[index]
    }
}

// MARK: - Runner

public actor LabEarlyStartRunner {
    public typealias ProgressHandler = @Sendable (
        _ completedSituations: Int,
        _ totalSituations: Int,
        _ opportunities: Int
    ) async -> Void

    private let pool: LabLlamaServerPool

    public init(pool: LabLlamaServerPool = LabLlamaServerPool()) {
        self.pool = pool
    }

    public func run(
        suite: LabScenarioSuite,
        arm: LabArmConfiguration,
        execution: LabExecutionConfiguration,
        configuration: LabEarlyStartConfiguration = .init(),
        requiresACPower: Bool = true,
        progress: @escaping ProgressHandler = { _, _, _ in }
    ) async throws -> LabEarlyStartReport {
        let configuration = try configuration.validated()
        let execution = try execution.validated()
        let arm = try arm.validated()
        let startingMachine = LabResearchMachinePreflight.inspect()
        if requiresACPower, !startingMachine.isStable(allowBattery: false) {
            throw LabEarlyStartError.notOnACPower
        }
        let assets = try await LabAssetVerifier.shared.verify(execution)
        guard assets.modelSHA256 == ProductionModelAsset.sha256 else {
            throw LabEarlyStartError.unexpectedModelHash(assets.modelSHA256)
        }

        var selector = arm.scenarios
        selector.partition = .development
        selector.suggestionExpectation = .speakOnly
        selector.maximumDistinctSituations = configuration.maximumSituations
        let selected = LabScenarioSelector.select(from: suite, configuration: selector)
        let scenarios = selected.scenarios.filter { $0.expectation.goldenContinuation != nil }
        guard scenarios.count == configuration.maximumSituations else {
            throw LabEarlyStartError.insufficientSituations(
                expected: configuration.maximumSituations,
                actual: scenarios.count
            )
        }

        let startedAt = Date()
        let startingThermal = ProcessInfo.processInfo.thermalState
        var worstThermal = startingThermal
        var measurements: [LabEarlyStartMeasurement] = []
        var plannedGenerations = 0
        let clients = try await pool.start(configuration: execution)
        defer { Task { await pool.stop() } }
        guard let client = clients.first else {
            throw LabEarlyStartError.incompleteMeasurement(expected: 1, actual: 0)
        }

        for (offset, scenario) in scenarios.enumerated() {
            try Task.checkCancellation()
            let golden = scenario.expectation.goldenContinuation ?? ""
            let cuts = LabEarlyStartPlanner.cuts(
                in: golden,
                minimumUsefulCharacters: configuration.minimumUsefulCharacters,
                maximumOpportunities: configuration.maximumOpportunitiesPerSituation
            )
            plannedGenerations += cuts.count * 3
            for cut in cuts {
                let characters = Array(golden)
                let earlyTyped = String(characters[0..<cut.cutOffset])
                let boundaryTyped = String(
                    characters[0..<(cut.cutOffset + cut.charactersToBoundary)]
                )
                let remainder = String(characters[cut.cutOffset...])

                // Order is fixed: both early requests precede the control so a
                // stale early branch can never borrow the control's work.
                // Prompt caching is disabled for this experiment, so ordering
                // cannot leak timing between the three requests.
                let cold = try await generate(
                    scenario: scenario,
                    typedSuffix: earlyTyped,
                    arm: arm,
                    client: client,
                    configuration: configuration,
                    temperature: LabEarlyStartConfiguration.coldTemperature,
                    seed: LabEarlyStartConfiguration.coldSeed
                )
                let hot = try await generate(
                    scenario: scenario,
                    typedSuffix: earlyTyped,
                    arm: arm,
                    client: client,
                    configuration: configuration,
                    temperature: LabEarlyStartConfiguration.hotTemperature,
                    seed: LabEarlyStartConfiguration.hotSeed
                )
                let boundary = try await generate(
                    scenario: scenario,
                    typedSuffix: boundaryTyped,
                    arm: arm,
                    client: client,
                    configuration: configuration,
                    temperature: LabEarlyStartConfiguration.coldTemperature,
                    seed: LabEarlyStartConfiguration.coldSeed
                )
                measurements.append(LabEarlyStartMeasurement(
                    cut: cut,
                    remainderAfterCut: remainder,
                    cold: cold,
                    hot: hot,
                    boundary: boundary
                ))
            }
            worstThermal = Self.worse(worstThermal, ProcessInfo.processInfo.thermalState)
            await progress(offset + 1, scenarios.count, measurements.count)
        }
        await pool.stop()

        guard !measurements.isEmpty else { throw LabEarlyStartError.noOpportunities }
        let completed = measurements.count * 3
        guard completed == plannedGenerations else {
            throw LabEarlyStartError.incompleteMeasurement(
                expected: plannedGenerations,
                actual: completed
            )
        }

        return LabEarlyStartReport(
            startedAt: startedAt,
            finishedAt: Date(),
            suiteName: selected.name,
            suiteDigestSHA256: try selected.digestSHA256(),
            situationCount: scenarios.count,
            opportunityCount: measurements.count,
            plannedGenerations: plannedGenerations,
            completedGenerations: completed,
            minimumUsefulCharacters: configuration.minimumUsefulCharacters,
            predictionTokens: configuration.predictionTokens,
            assets: assets,
            execution: LabExecutionSnapshot(execution),
            startingThermalState: Self.name(startingThermal),
            worstThermalState: Self.name(worstThermal),
            startingMachineState: startingMachine,
            finishingMachineState: LabResearchMachinePreflight.inspect(),
            primary: LabEarlyStartAnalyzer.primary(
                measurements: measurements,
                minimumUsefulCharacters: configuration.minimumUsefulCharacters
            ),
            pair: LabEarlyStartAnalyzer.pair(
                measurements: measurements,
                minimumUsefulCharacters: configuration.minimumUsefulCharacters
            ),
            sensitivity: LabEarlyStartAnalyzer.sensitivity(
                measurements: measurements,
                minimumUsefulCharacters: configuration.minimumUsefulCharacters
            )
        )
    }

    public func cancel() async {
        await pool.stop()
    }

    private func generate(
        scenario: LabScenario,
        typedSuffix: String,
        arm: LabArmConfiguration,
        client: any LabCompletionClient,
        configuration: LabEarlyStartConfiguration,
        temperature: Double,
        seed: Int
    ) async throws -> LabEarlyStartGeneration {
        let replayed = Self.replayed(scenario, typedSuffix: typedSuffix)
        let prepared = LabPromptComposer.prepare(scenario: replayed, configuration: arm.prompt)
        var requestArm = arm
        requestArm.generation.temperature = temperature
        requestArm.generation.preset = temperature == 0 ? .productionGreedy : .custom
        requestArm.generation.seed = seed
        requestArm.generation.predictionTokens = configuration.predictionTokens
        requestArm.generation.probabilityCount = 1
        requestArm.generation.requestMode = .finalResponse
        requestArm.generation.cachePrompt = false
        let response = try await client.complete(LabModelRequest(
            prompt: prepared.prompt,
            generation: requestArm.generation,
            timeoutSeconds: 120
        ))
        let decision = LabOutputJudge.judge(
            rawOutput: response.content,
            preparedPrompt: prepared,
            scenario: replayed,
            configuration: requestArm,
            meanTokenProbability: response.meanTokenProbability
        )
        return LabEarlyStartGeneration(
            text: decision.suggestion ?? "",
            rawContinuation: prepared.normalizedContinuation(response.content),
            latencyMilliseconds: response.latencyMilliseconds,
            decodedTokens: response.tokenIDs.count
        )
    }

    /// The situation as it stands after the writer has typed `typedSuffix` of
    /// the golden continuation. Only the typed context and the remaining
    /// golden text move; scene, app, and evaluation metadata are unchanged.
    static func replayed(_ scenario: LabScenario, typedSuffix: String) -> LabScenario {
        let golden = scenario.expectation.goldenContinuation ?? ""
        let remaining = String(golden.dropFirst(typedSuffix.count))
        return LabScenario(
            id: scenario.id,
            category: scenario.category,
            partition: scenario.partition,
            intent: scenario.intent,
            tone: scenario.tone,
            language: scenario.language,
            tags: scenario.tags,
            appBundleIdentifier: scenario.appBundleIdentifier,
            typedContext: scenario.typedContext + typedSuffix,
            scene: scenario.scene,
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: remaining,
                acceptablePrefixes: [remaining],
                requiredTerms: scenario.expectation.requiredTerms.filter {
                    !typedSuffix.localizedCaseInsensitiveContains($0)
                },
                forbiddenTerms: scenario.expectation.forbiddenTerms,
                maximumWords: scenario.expectation.maximumWords
            ),
            evaluation: scenario.evaluation
        )
    }

    private static func worse(
        _ lhs: ProcessInfo.ThermalState,
        _ rhs: ProcessInfo.ThermalState
    ) -> ProcessInfo.ThermalState {
        rank(lhs) >= rank(rhs) ? lhs : rhs
    }

    private static func rank(_ value: ProcessInfo.ThermalState) -> Int {
        switch value {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical: 3
        @unknown default: 4
        }
    }

    private static func name(_ value: ProcessInfo.ThermalState) -> String {
        switch value {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
