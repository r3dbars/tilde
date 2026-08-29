import Foundation

public struct LabFutureLatticeConfiguration: Equatable, Sendable {
    public static let candidateCounts = [1, 4, 8, 16]
    public static let sampledSeeds = [
        17, 41, 73, 101, 137, 173, 211, 251,
        293, 337, 383, 431, 479, 523, 571,
    ]

    public var maximumSituations: Int
    public var minimumUsefulCharacters: Int
    public var sampledTemperature: Double

    public init(
        maximumSituations: Int = 360,
        minimumUsefulCharacters: Int = 6,
        sampledTemperature: Double = 0.40
    ) {
        self.maximumSituations = maximumSituations
        self.minimumUsefulCharacters = minimumUsefulCharacters
        self.sampledTemperature = sampledTemperature
    }

    @discardableResult
    public func validated() throws -> LabFutureLatticeConfiguration {
        guard (1...360).contains(maximumSituations),
              (1...64).contains(minimumUsefulCharacters),
              (0...2).contains(sampledTemperature) else {
            throw LabFutureLatticeError.invalidConfiguration
        }
        return self
    }
}

public enum LabFutureLatticeError: Error, LocalizedError, Sendable {
    case invalidConfiguration
    case insufficientSituations(expected: Int, actual: Int)
    case unexpectedModelHash(String)
    case incompleteCandidateSet(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The Future Lattice configuration is outside its frozen bounds."
        case let .insufficientSituations(expected, actual):
            "Future Lattice expected \(expected) speak situations but found \(actual)."
        case let .unexpectedModelHash(value):
            "Future Lattice refuses the selected model hash \(value)."
        case let .incompleteCandidateSet(expected, actual):
            "Future Lattice expected \(expected) terminal candidates but received \(actual)."
        }
    }
}

public struct LabFutureLatticeMetric: Codable, Equatable, Sendable {
    public let candidateCount: Int
    public let situationCount: Int
    public let goldenCoverageCount: Int
    public let goldenCoverageRate: Double
    public let reviewedCoverageCount: Int
    public let reviewedCoverageRate: Double
    public let meanBestGoldenPrefixCharacters: Double
    public let medianUniqueCandidates: Double
    public let medianDistinctFirstTwoContentWordPaths: Double
    public let situationsWithAtLeastFourDistinctPaths: Int
    public let atLeastFourDistinctPathsRate: Double
    public let readinessP50Milliseconds: Int
    public let readinessP95Milliseconds: Int
    public let summedRequestLatencyMilliseconds: Int
    public let computeMultiplierVersusK1: Double
    public let decodedTokens: Int
}

public struct LabFutureLatticeReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.future-lattice.v1"

    public let schema: String
    public let startedAt: Date
    public let finishedAt: Date
    public let suiteName: String
    public let suiteDigestSHA256: String
    public let situationCount: Int
    public let plannedGenerations: Int
    public let completedGenerations: Int
    public let candidateCounts: [Int]
    public let sampledSeeds: [Int]
    public let minimumUsefulCharacters: Int
    public let sampledTemperature: Double
    public let assets: LabAssetSnapshot
    public let execution: LabExecutionSnapshot
    public let startingThermalState: String
    public let worstThermalState: String
    public let metrics: [LabFutureLatticeMetric]
    public let privacy: LabAggregateOnlyPrivacy

    public init(
        startedAt: Date,
        finishedAt: Date,
        suiteName: String,
        suiteDigestSHA256: String,
        situationCount: Int,
        plannedGenerations: Int,
        completedGenerations: Int,
        candidateCounts: [Int],
        sampledSeeds: [Int],
        minimumUsefulCharacters: Int,
        sampledTemperature: Double,
        assets: LabAssetSnapshot,
        execution: LabExecutionSnapshot,
        startingThermalState: String,
        worstThermalState: String,
        metrics: [LabFutureLatticeMetric],
        privacy: LabAggregateOnlyPrivacy = .aggregateOnly
    ) {
        schema = Self.currentSchema
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.suiteName = suiteName
        self.suiteDigestSHA256 = suiteDigestSHA256
        self.situationCount = situationCount
        self.plannedGenerations = plannedGenerations
        self.completedGenerations = completedGenerations
        self.candidateCounts = candidateCounts
        self.sampledSeeds = sampledSeeds
        self.minimumUsefulCharacters = minimumUsefulCharacters
        self.sampledTemperature = sampledTemperature
        self.assets = assets
        self.execution = execution
        self.startingThermalState = startingThermalState
        self.worstThermalState = worstThermalState
        self.metrics = metrics
        self.privacy = privacy
    }
}

public struct LabAggregateOnlyPrivacy: Codable, Equatable, Sendable {
    public let aggregateOnly: Bool
    public let containsRawPrompts: Bool
    public let containsRawCandidates: Bool
    public let containsScenarioText: Bool
    public let containsPersonalWriting: Bool

    public static let aggregateOnly = LabAggregateOnlyPrivacy(
        aggregateOnly: true,
        containsRawPrompts: false,
        containsRawCandidates: false,
        containsScenarioText: false,
        containsPersonalWriting: false
    )
}

public struct LabFutureLatticeCandidate: Equatable, Sendable {
    public let index: Int
    public let text: String
    public let requestLatencyMilliseconds: Int
    public let readyMilliseconds: Int
    public let decodedTokens: Int

    public init(
        index: Int,
        text: String,
        requestLatencyMilliseconds: Int,
        readyMilliseconds: Int,
        decodedTokens: Int
    ) {
        self.index = index
        self.text = text
        self.requestLatencyMilliseconds = requestLatencyMilliseconds
        self.readyMilliseconds = readyMilliseconds
        self.decodedTokens = decodedTokens
    }
}

private struct LabFutureLatticeSituation: Sendable {
    let golden: String
    let reviewed: [String]
    let candidates: [LabFutureLatticeCandidate]
}

public enum LabFutureLatticeAnalyzer {
    public static func metric(
        candidateCount: Int,
        minimumUsefulCharacters: Int,
        situations: [(golden: String, reviewed: [String], candidates: [LabFutureLatticeCandidate])]
    ) -> LabFutureLatticeMetric {
        let measured = situations.map {
            LabFutureLatticeSituation(golden: $0.golden, reviewed: $0.reviewed, candidates: $0.candidates)
        }
        return metric(
            candidateCount: candidateCount,
            minimumUsefulCharacters: minimumUsefulCharacters,
            situations: measured,
            k1SummedLatency: summedLatency(candidateCount: 1, situations: measured)
        )
    }

    fileprivate static func metrics(
        candidateCounts: [Int],
        minimumUsefulCharacters: Int,
        situations: [LabFutureLatticeSituation]
    ) -> [LabFutureLatticeMetric] {
        let k1Latency = summedLatency(candidateCount: 1, situations: situations)
        return candidateCounts.map {
            metric(
                candidateCount: $0,
                minimumUsefulCharacters: minimumUsefulCharacters,
                situations: situations,
                k1SummedLatency: k1Latency
            )
        }
    }

    private static func metric(
        candidateCount: Int,
        minimumUsefulCharacters: Int,
        situations: [LabFutureLatticeSituation],
        k1SummedLatency: Int
    ) -> LabFutureLatticeMetric {
        var goldenCoverage = 0
        var reviewedCoverage = 0
        var bestGolden: [Int] = []
        var uniqueCandidates: [Int] = []
        var distinctPaths: [Int] = []
        var readiness: [Int] = []
        var summedLatency = 0
        var decodedTokens = 0

        for situation in situations {
            let candidates = Array(situation.candidates.prefix(candidateCount))
            let texts = candidates.map(\.text).filter { !$0.isEmpty }
            let goldenBest = texts.map {
                exactPrefixCharacters($0, situation.golden)
            }.max() ?? 0
            let reviewedBest = texts.flatMap { candidate in
                situation.reviewed.map { exactPrefixCharacters(candidate, $0) }
            }.max() ?? 0
            if goldenBest >= minimumUsefulCharacters { goldenCoverage += 1 }
            if reviewedBest >= minimumUsefulCharacters { reviewedCoverage += 1 }
            bestGolden.append(goldenBest)
            uniqueCandidates.append(Set(texts.map(LabExactPrefix.normalized)).count)
            distinctPaths.append(Set(texts.compactMap(firstTwoContentWordPath)).count)
            readiness.append(candidates.map(\.readyMilliseconds).max() ?? 0)
            summedLatency += candidates.reduce(0) { $0 + $1.requestLatencyMilliseconds }
            decodedTokens += candidates.reduce(0) { $0 + $1.decodedTokens }
        }

        let count = situations.count
        let fourPaths = distinctPaths.count { $0 >= 4 }
        return LabFutureLatticeMetric(
            candidateCount: candidateCount,
            situationCount: count,
            goldenCoverageCount: goldenCoverage,
            goldenCoverageRate: rate(goldenCoverage, count),
            reviewedCoverageCount: reviewedCoverage,
            reviewedCoverageRate: rate(reviewedCoverage, count),
            meanBestGoldenPrefixCharacters: count == 0
                ? 0
                : Double(bestGolden.reduce(0, +)) / Double(count),
            medianUniqueCandidates: median(uniqueCandidates),
            medianDistinctFirstTwoContentWordPaths: median(distinctPaths),
            situationsWithAtLeastFourDistinctPaths: fourPaths,
            atLeastFourDistinctPathsRate: rate(fourPaths, count),
            readinessP50Milliseconds: percentile(readiness, fraction: 0.50),
            readinessP95Milliseconds: percentile(readiness, fraction: 0.95),
            summedRequestLatencyMilliseconds: summedLatency,
            computeMultiplierVersusK1: k1SummedLatency == 0
                ? 0
                : Double(summedLatency) / Double(k1SummedLatency),
            decodedTokens: decodedTokens
        )
    }

    public static func exactPrefixCharacters(_ lhs: String, _ rhs: String) -> Int {
        LabExactPrefix.sharedCharacters(lhs, rhs)
    }

    public static func firstTwoContentWordPath(_ value: String) -> String? {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "at", "be", "for", "i", "in", "is", "it",
            "of", "on", "or", "that", "the", "this", "to", "we", "will", "you",
        ]
        let words = LabExactPrefix.normalized(value).lowercased().split {
            !$0.isLetter && !$0.isNumber
        }.map(String.init)
        let content = words.filter { !stopWords.contains($0) }
        let path = Array(content.prefix(2))
        guard !path.isEmpty else { return nil }
        return path.joined(separator: " ")
    }

    private static func summedLatency(
        candidateCount: Int,
        situations: [LabFutureLatticeSituation]
    ) -> Int {
        situations.reduce(0) { total, situation in
            total + situation.candidates.prefix(candidateCount).reduce(0) {
                $0 + $1.requestLatencyMilliseconds
            }
        }
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func median(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Double(sorted[middle - 1] + sorted[middle]) / 2
        }
        return Double(sorted[middle])
    }

    private static func percentile(_ values: [Int], fraction: Double) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))
        return sorted[index]
    }
}

public actor LabFutureLatticeRunner {
    public typealias ProgressHandler = @Sendable (_ completedSituations: Int, _ totalSituations: Int) async -> Void

    private static let expectedQwenSHA256 = "4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
    private let pool: LabLlamaServerPool

    public init(pool: LabLlamaServerPool = LabLlamaServerPool()) {
        self.pool = pool
    }

    public func run(
        suite: LabScenarioSuite,
        arm: LabArmConfiguration,
        execution: LabExecutionConfiguration,
        configuration: LabFutureLatticeConfiguration = .init(),
        progress: @escaping ProgressHandler = { _, _ in }
    ) async throws -> LabFutureLatticeReport {
        let configuration = try configuration.validated()
        let execution = try execution.validated()
        let arm = try arm.validated()
        let assets = try await LabAssetVerifier.shared.verify(execution)
        guard assets.modelSHA256 == Self.expectedQwenSHA256 else {
            throw LabFutureLatticeError.unexpectedModelHash(assets.modelSHA256)
        }

        var selector = arm.scenarios
        selector.partition = .development
        selector.suggestionExpectation = .speakOnly
        selector.maximumDistinctSituations = configuration.maximumSituations
        let selected = LabScenarioSelector.select(from: suite, configuration: selector)
        let scenarios = selected.scenarios.filter { $0.expectation.goldenContinuation != nil }
        guard scenarios.count == configuration.maximumSituations else {
            throw LabFutureLatticeError.insufficientSituations(
                expected: configuration.maximumSituations,
                actual: scenarios.count
            )
        }

        let startedAt = Date()
        let startingThermal = ProcessInfo.processInfo.thermalState
        var worstThermal = startingThermal
        var measurements: [LabFutureLatticeSituation] = []
        measurements.reserveCapacity(scenarios.count)
        let clients = try await pool.start(configuration: execution)
        defer { Task { await pool.stop() } }

        for (offset, scenario) in scenarios.enumerated() {
            try Task.checkCancellation()
            let prepared = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt)
            let scenarioStartedAt = Date()
            var candidates: [LabFutureLatticeCandidate] = []
            for tier in [0..<1, 1..<4, 4..<8, 8..<16] {
                let tierResults = try await generate(
                    indices: Array(tier),
                    scenario: scenario,
                    prepared: prepared,
                    arm: arm,
                    clients: clients,
                    configuration: configuration,
                    scenarioStartedAt: scenarioStartedAt
                )
                candidates.append(contentsOf: tierResults)
            }
            candidates.sort { $0.index < $1.index }
            guard candidates.count == 16 else {
                throw LabFutureLatticeError.incompleteCandidateSet(
                    expected: 16,
                    actual: candidates.count
                )
            }
            let golden = scenario.expectation.goldenContinuation ?? ""
            var reviewed = [golden]
            reviewed.append(contentsOf: scenario.expectation.acceptableContinuations)
            reviewed.append(contentsOf: scenario.expectation.acceptablePrefixes)
            measurements.append(LabFutureLatticeSituation(
                golden: golden,
                reviewed: reviewed,
                candidates: candidates
            ))
            worstThermal = Self.worse(worstThermal, ProcessInfo.processInfo.thermalState)
            await progress(offset + 1, scenarios.count)
        }
        await pool.stop()

        let completed = measurements.reduce(0) { $0 + $1.candidates.count }
        return LabFutureLatticeReport(
            startedAt: startedAt,
            finishedAt: Date(),
            suiteName: selected.name,
            suiteDigestSHA256: try selected.digestSHA256(),
            situationCount: scenarios.count,
            plannedGenerations: scenarios.count * 16,
            completedGenerations: completed,
            candidateCounts: LabFutureLatticeConfiguration.candidateCounts,
            sampledSeeds: LabFutureLatticeConfiguration.sampledSeeds,
            minimumUsefulCharacters: configuration.minimumUsefulCharacters,
            sampledTemperature: configuration.sampledTemperature,
            assets: assets,
            execution: LabExecutionSnapshot(execution),
            startingThermalState: Self.name(startingThermal),
            worstThermalState: Self.name(worstThermal),
            metrics: LabFutureLatticeAnalyzer.metrics(
                candidateCounts: LabFutureLatticeConfiguration.candidateCounts,
                minimumUsefulCharacters: configuration.minimumUsefulCharacters,
                situations: measurements
            )
        )
    }

    public func cancel() async {
        await pool.stop()
    }

    private func generate(
        indices: [Int],
        scenario: LabScenario,
        prepared: LabPreparedPrompt,
        arm: LabArmConfiguration,
        clients: [any LabCompletionClient],
        configuration: LabFutureLatticeConfiguration,
        scenarioStartedAt: Date
    ) async throws -> [LabFutureLatticeCandidate] {
        try await withThrowingTaskGroup(of: LabFutureLatticeCandidate.self) { group in
            for (offset, index) in indices.enumerated() {
                let client = clients[offset % clients.count]
                group.addTask {
                    var candidateArm = arm
                    candidateArm.generation.temperature = index == 0
                        ? 0
                        : configuration.sampledTemperature
                    candidateArm.generation.preset = index == 0 ? .productionGreedy : .custom
                    candidateArm.generation.seed = index == 0
                        ? 0
                        : LabFutureLatticeConfiguration.sampledSeeds[index - 1]
                    candidateArm.generation.predictionTokens = 12
                    candidateArm.generation.probabilityCount = 1
                    candidateArm.generation.requestMode = .finalResponse
                    let response = try await client.complete(LabModelRequest(
                        prompt: prepared.prompt,
                        generation: candidateArm.generation,
                        timeoutSeconds: 120
                    ))
                    let decision = LabOutputJudge.judge(
                        rawOutput: response.content,
                        preparedPrompt: prepared,
                        scenario: scenario,
                        configuration: candidateArm,
                        meanTokenProbability: response.meanTokenProbability
                    )
                    return LabFutureLatticeCandidate(
                        index: index,
                        text: decision.suggestion ?? "",
                        requestLatencyMilliseconds: response.latencyMilliseconds,
                        readyMilliseconds: max(0, Int(Date().timeIntervalSince(scenarioStartedAt) * 1_000)),
                        decodedTokens: response.tokenIDs.count
                    )
                }
            }
            var result: [LabFutureLatticeCandidate] = []
            for try await candidate in group { result.append(candidate) }
            return result
        }
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
