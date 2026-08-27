import CryptoKit
import Foundation

public enum LabSearchStage: String, Codable, CaseIterable, Sendable {
    case invariantSmoke = "invariant-smoke"
    case spaceFilling = "space-filling"
    case successiveHalving = "successive-halving"
    case adaptiveLocal = "adaptive-local"
    case developmentConfirmation = "development-confirmation"
}

public struct LabResearchBudget: Codable, Equatable, Sendable {
    public var maximumHours: Double
    public var maximumTrials: Int
    public var maximumRootsPerTrial: Int
    public var maximumModelRequests: Int

    public init(
        maximumHours: Double = 12,
        maximumTrials: Int = 96,
        maximumRootsPerTrial: Int = 1_000,
        maximumModelRequests: Int = 250_000
    ) {
        self.maximumHours = maximumHours
        self.maximumTrials = maximumTrials
        self.maximumRootsPerTrial = maximumRootsPerTrial
        self.maximumModelRequests = maximumModelRequests
    }

    @discardableResult
    public func validated() throws -> LabResearchBudget {
        guard maximumHours > 0, maximumHours <= 168,
              (1...128).contains(maximumTrials),
              (1...10_000).contains(maximumRootsPerTrial),
              (1...10_000_000).contains(maximumModelRequests) else {
            throw LabAdaptiveSearchError.invalidBudget
        }
        return self
    }
}

public struct LabGeneratorSearchSpace: Codable, Equatable, Sendable {
    public var temperature: ClosedRange<Double>
    public var predictionTokens: ClosedRange<Int>
    public var topK: ClosedRange<Int>
    public var topP: ClosedRange<Double>
    public var minP: ClosedRange<Double>
    public var typicalP: ClosedRange<Double>
    public var repeatPenalty: ClosedRange<Double>

    public init(
        temperature: ClosedRange<Double> = 0...0.5,
        predictionTokens: ClosedRange<Int> = 8...24,
        topK: ClosedRange<Int> = 10...80,
        topP: ClosedRange<Double> = 0.7...1,
        minP: ClosedRange<Double> = 0...0.2,
        typicalP: ClosedRange<Double> = 0.5...1,
        repeatPenalty: ClosedRange<Double> = 0.95...1.15
    ) {
        self.temperature = temperature
        self.predictionTokens = predictionTokens
        self.topK = topK
        self.topP = topP
        self.minP = minP
        self.typicalP = typicalP
        self.repeatPenalty = repeatPenalty
    }

    @discardableResult
    public func validated() throws -> LabGeneratorSearchSpace {
        guard temperature.lowerBound >= 0, temperature.upperBound <= 2,
              temperature.lowerBound <= temperature.upperBound,
              predictionTokens.lowerBound >= 1, predictionTokens.upperBound <= 128,
              topK.lowerBound >= 0, topK.upperBound <= 10_000,
              Self.probabilityRange(topP), Self.probabilityRange(minP),
              Self.probabilityRange(typicalP),
              repeatPenalty.lowerBound >= 0, repeatPenalty.upperBound <= 3 else {
            throw LabAdaptiveSearchError.invalidSearchSpace
        }
        return self
    }

    private static func probabilityRange(_ value: ClosedRange<Double>) -> Bool {
        value.lowerBound >= 0 && value.upperBound <= 1
            && value.lowerBound <= value.upperBound
    }
}

public struct LabSearchTrialObservation: Codable, Equatable, Sendable {
    public let arm: LabArmConfiguration
    public let stage: LabSearchStage
    public let completedRoots: Int
    public let plannedRoots: Int
    public let hardGatesPassed: Bool
    public let expectedUtility: Double
    public let oracleNetKeystrokeSavings: Double
    public let precisionWhenShown: Double
    public let badWhenShown: Double
    public let lateRate: Double
    public let p95LatencyMilliseconds: Double
    public let peakMemoryMegabytes: Double

    public init(
        arm: LabArmConfiguration,
        stage: LabSearchStage,
        completedRoots: Int,
        plannedRoots: Int,
        hardGatesPassed: Bool,
        expectedUtility: Double,
        oracleNetKeystrokeSavings: Double,
        precisionWhenShown: Double,
        badWhenShown: Double,
        lateRate: Double,
        p95LatencyMilliseconds: Double,
        peakMemoryMegabytes: Double = 0
    ) {
        self.arm = arm
        self.stage = stage
        self.completedRoots = completedRoots
        self.plannedRoots = plannedRoots
        self.hardGatesPassed = hardGatesPassed
        self.expectedUtility = expectedUtility
        self.oracleNetKeystrokeSavings = oracleNetKeystrokeSavings
        self.precisionWhenShown = precisionWhenShown
        self.badWhenShown = badWhenShown
        self.lateRate = lateRate
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.peakMemoryMegabytes = peakMemoryMegabytes
    }
}

public enum LabAdaptiveSearchError: Error, LocalizedError, Equatable, Sendable {
    case invalidBudget
    case invalidSearchSpace
    case invalidPointCount
    case incompleteBalancedBlock
    case noSafeTrials
    case protectedPhase

    public var errorDescription: String? {
        switch self {
        case .invalidBudget: "The research budget is outside its bounded limits."
        case .invalidSearchSpace: "The conditional generator search space is invalid."
        case .invalidPointCount: "A QMC screen requires 1...127 candidate points."
        case .incompleteBalancedBlock:
            "Successive halving cannot prune until every arm completes the same stratified root budget."
        case .noSafeTrials: "Adaptive search has no completed, hard-gate-safe trials to learn from."
        case .protectedPhase: "The optimizer cannot run during validation or holdout."
        }
    }
}

/// Deterministic staged optimizer for development. It uses a Halton QMC screen
/// (a space-filling QMC design), balanced successive halving, and a compact
/// multivariate Parzen density-ratio search around the safe frontier.
public enum LabStagedSearchPlanner {
    public static func spaceFillingArms(
        baseline: LabArmConfiguration,
        candidateCount: Int = 31,
        space: LabGeneratorSearchSpace = .init(),
        sequenceOffset: Int = 0,
        idPrefix: String = "qmc"
    ) throws -> [LabArmConfiguration] {
        try space.validated()
        guard (1...127).contains(candidateCount), sequenceOffset >= 0 else {
            throw LabAdaptiveSearchError.invalidPointCount
        }
        var result: [LabArmConfiguration] = []
        var seen = Set<String>()
        var sequenceIndex = sequenceOffset + 1
        while result.count < candidateCount {
            let point = [2, 3, 5, 7, 11, 13, 17].map {
                halton(index: sequenceIndex, base: $0)
            }
            var candidate = baseline
            candidate.id = "\(idPrefix)-\(String(format: "%03d", result.count + 1))"
            apply(point: point, to: &candidate.generation, baseline: baseline.generation, space: space)
            try candidate.validated()
            let signature = try candidate.generationDigest()
            if seen.insert(signature).inserted { result.append(candidate) }
            sequenceIndex += 1
            if sequenceIndex > sequenceOffset + candidateCount * 100 {
                throw LabAdaptiveSearchError.invalidSearchSpace
            }
        }
        return result
    }

    /// Keeps the strongest safe third, but only after every trial has completed
    /// its full balanced root block. Pareto-front members are ordered before
    /// dominated points; the scalar tie-break never overrides safety.
    public static func successiveHalvingSurvivors(
        _ observations: [LabSearchTrialObservation],
        survivorFraction: Double = 1.0 / 3.0
    ) throws -> [LabSearchTrialObservation] {
        guard !observations.isEmpty,
              observations.allSatisfy({
                  $0.plannedRoots > 0 && $0.completedRoots == $0.plannedRoots
              }) else {
            throw LabAdaptiveSearchError.incompleteBalancedBlock
        }
        let safe = observations.filter(\.hardGatesPassed)
        guard !safe.isEmpty else { throw LabAdaptiveSearchError.noSafeTrials }
        let frontierIDs = Set(paretoFrontier(safe).map { $0.arm.id })
        let ordered = safe.sorted { lhs, rhs in
            let lhsFrontier = frontierIDs.contains(lhs.arm.id)
            let rhsFrontier = frontierIDs.contains(rhs.arm.id)
            if lhsFrontier != rhsFrontier { return lhsFrontier }
            if lhs.expectedUtility != rhs.expectedUtility {
                return lhs.expectedUtility > rhs.expectedUtility
            }
            if lhs.badWhenShown != rhs.badWhenShown {
                return lhs.badWhenShown < rhs.badWhenShown
            }
            if lhs.p95LatencyMilliseconds != rhs.p95LatencyMilliseconds {
                return lhs.p95LatencyMilliseconds < rhs.p95LatencyMilliseconds
            }
            return lhs.arm.id < rhs.arm.id
        }
        let fraction = min(1, max(0.01, survivorFraction))
        return Array(ordered.prefix(max(1, Int(ceil(Double(ordered.count) * fraction)))))
    }

    public static func adaptiveLocalArms(
        observations: [LabSearchTrialObservation],
        baseline: LabArmConfiguration,
        candidateCount: Int,
        space: LabGeneratorSearchSpace = .init(),
        sequenceOffset: Int = 0,
        idPrefix: String = "tpe"
    ) throws -> [LabArmConfiguration] {
        try space.validated()
        guard (1...127).contains(candidateCount) else {
            throw LabAdaptiveSearchError.invalidPointCount
        }
        let safe = observations.filter {
            $0.hardGatesPassed && $0.plannedRoots > 0 && $0.completedRoots == $0.plannedRoots
        }.sorted {
            if $0.expectedUtility == $1.expectedUtility { return $0.arm.id < $1.arm.id }
            return $0.expectedUtility > $1.expectedUtility
        }
        guard !safe.isEmpty else { throw LabAdaptiveSearchError.noSafeTrials }
        let split = max(1, Int(ceil(Double(safe.count) * 0.25)))
        let good = safe.prefix(split).map { normalized($0.arm.generation, in: space) }
        let bad = safe.dropFirst(split).map { normalized($0.arm.generation, in: space) }
        let fallbackBad = bad.isEmpty ? [normalized(baseline.generation, in: space)] : bad

        var pool: [(score: Double, point: [Double])] = []
        let poolCount = max(256, candidateCount * 32)
        for index in 0..<poolCount {
            let anchor = good[(sequenceOffset + index) % good.count]
            let perturbations = [19, 23, 29, 31, 37, 41, 43].enumerated().map { dimension, base in
                let u = halton(index: sequenceOffset + index + 1, base: base)
                let width = max(0.035, 0.22 / sqrt(Double(good.count)))
                return min(1, max(0, anchor[dimension] + (u - 0.5) * 2 * width))
            }
            let score = logDensity(perturbations, samples: good)
                - logDensity(perturbations, samples: fallbackBad)
            pool.append((score, perturbations))
        }
        pool.sort {
            if $0.score == $1.score { return $0.point.lexicographicallyPrecedes($1.point) }
            return $0.score > $1.score
        }

        let prior = Set(try observations.map { try $0.arm.generationDigest() })
        var seen = prior
        var result: [LabArmConfiguration] = []
        for entry in pool where result.count < candidateCount {
            var candidate = baseline
            candidate.id = "\(idPrefix)-\(String(format: "%03d", result.count + 1))"
            apply(point: entry.point, to: &candidate.generation, baseline: baseline.generation, space: space)
            let signature = try candidate.generationDigest()
            guard seen.insert(signature).inserted else { continue }
            try candidate.validated()
            result.append(candidate)
        }
        guard result.count == candidateCount else { throw LabAdaptiveSearchError.invalidSearchSpace }
        return result
    }

    public static func paretoFrontier(
        _ observations: [LabSearchTrialObservation]
    ) -> [LabSearchTrialObservation] {
        observations.filter { candidate in
            !observations.contains { other in
                other.arm.id != candidate.arm.id && dominates(other, candidate)
            }
        }.sorted { $0.arm.id < $1.arm.id }
    }

    public static func assertOptimizerAllowed(phase: LabCampaignPhase) throws {
        guard phase == .discovery else { throw LabAdaptiveSearchError.protectedPhase }
    }

    private static func dominates(
        _ lhs: LabSearchTrialObservation,
        _ rhs: LabSearchTrialObservation
    ) -> Bool {
        guard lhs.hardGatesPassed else { return false }
        let noWorse = lhs.expectedUtility >= rhs.expectedUtility
            && lhs.oracleNetKeystrokeSavings >= rhs.oracleNetKeystrokeSavings
            && lhs.precisionWhenShown >= rhs.precisionWhenShown
            && lhs.badWhenShown <= rhs.badWhenShown
            && lhs.lateRate <= rhs.lateRate
            && lhs.p95LatencyMilliseconds <= rhs.p95LatencyMilliseconds
            && lhs.peakMemoryMegabytes <= rhs.peakMemoryMegabytes
        let better = lhs.expectedUtility > rhs.expectedUtility
            || lhs.oracleNetKeystrokeSavings > rhs.oracleNetKeystrokeSavings
            || lhs.precisionWhenShown > rhs.precisionWhenShown
            || lhs.badWhenShown < rhs.badWhenShown
            || lhs.lateRate < rhs.lateRate
            || lhs.p95LatencyMilliseconds < rhs.p95LatencyMilliseconds
            || lhs.peakMemoryMegabytes < rhs.peakMemoryMegabytes
        return noWorse && better
    }

    private static func apply(
        point: [Double],
        to generation: inout LabGenerationConfiguration,
        baseline: LabGenerationConfiguration,
        space: LabGeneratorSearchSpace
    ) {
        generation.temperature = rounded(interpolate(point[0], space.temperature), places: 3)
        generation.predictionTokens = interpolateInteger(point[1], space.predictionTokens)
        if generation.temperature == 0 {
            generation.topK = baseline.topK
            generation.topP = baseline.topP
            generation.minP = baseline.minP
            generation.typicalP = baseline.typicalP
            generation.repeatPenalty = baseline.repeatPenalty
            generation.preset = .productionGreedy
        } else {
            generation.topK = interpolateInteger(point[2], space.topK)
            generation.topP = rounded(interpolate(point[3], space.topP), places: 3)
            generation.minP = rounded(interpolate(point[4], space.minP), places: 3)
            generation.typicalP = rounded(interpolate(point[5], space.typicalP), places: 3)
            generation.repeatPenalty = rounded(interpolate(point[6], space.repeatPenalty), places: 3)
            generation.preset = .custom
        }
        // Confidence/display controls and the measurement seed are frozen.
        generation.probabilityCount = baseline.probabilityCount
        generation.minimumMeanTokenProbability = baseline.minimumMeanTokenProbability
        generation.seed = baseline.seed
    }

    private static func normalized(
        _ generation: LabGenerationConfiguration,
        in space: LabGeneratorSearchSpace
    ) -> [Double] {
        [
            normalize(generation.temperature, in: space.temperature),
            normalize(Double(generation.predictionTokens), in: doubleRange(space.predictionTokens)),
            normalize(Double(generation.topK), in: doubleRange(space.topK)),
            normalize(generation.topP, in: space.topP),
            normalize(generation.minP, in: space.minP),
            normalize(generation.typicalP, in: space.typicalP),
            normalize(generation.repeatPenalty, in: space.repeatPenalty),
        ]
    }

    private static func logDensity(_ point: [Double], samples: [[Double]]) -> Double {
        let bandwidth = max(0.04, 0.3 / sqrt(Double(samples.count)))
        let values = samples.map { sample in
            zip(point, sample).reduce(0.0) { partial, pair in
                let z = (pair.0 - pair.1) / bandwidth
                return partial - 0.5 * z * z - log(bandwidth)
            }
        }
        let maximum = values.max() ?? 0
        let sum = values.reduce(0.0) { $0 + exp($1 - maximum) }
        return maximum + log(max(sum, .leastNonzeroMagnitude)) - log(Double(values.count))
    }

    private static func halton(index: Int, base: Int) -> Double {
        var index = max(1, index)
        var fraction = 1.0
        var result = 0.0
        while index > 0 {
            fraction /= Double(base)
            result += fraction * Double(index % base)
            index /= base
        }
        return result
    }

    private static func interpolate(_ unit: Double, _ range: ClosedRange<Double>) -> Double {
        range.lowerBound + min(1, max(0, unit)) * (range.upperBound - range.lowerBound)
    }

    private static func interpolateInteger(_ unit: Double, _ range: ClosedRange<Int>) -> Int {
        Int(interpolate(unit, doubleRange(range)).rounded())
    }

    private static func normalize(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let width = range.upperBound - range.lowerBound
        guard width > 0 else { return 0.5 }
        return min(1, max(0, (value - range.lowerBound) / width))
    }

    private static func doubleRange(_ value: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(value.lowerBound)...Double(value.upperBound)
    }

    private static func rounded(_ value: Double, places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (value * scale).rounded() / scale
    }
}

private extension LabArmConfiguration {
    func generationDigest() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try LabResearchHash.sha256(encoder.encode(generation))
    }
}

private enum LabResearchHash {
    static func sha256(_ data: Data) throws -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
