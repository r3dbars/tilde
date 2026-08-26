import AutocompleteLabCore
import Foundation

public struct LabRunProgress: Equatable, Sendable {
    public enum Phase: String, Equatable, Sendable {
        case validating
        case verifyingAssets = "verifying-assets"
        case startingWorkers = "starting-workers"
        case running
        case finalizing
        case stopping
    }

    public let phase: Phase
    public let completed: Int
    public let total: Int
    public let armIndex: Int
    public let armCount: Int
    public let armID: String?

    public init(
        phase: Phase,
        completed: Int = 0,
        total: Int = 0,
        armIndex: Int = 0,
        armCount: Int = 1,
        armID: String? = nil
    ) {
        self.phase = phase
        self.completed = completed
        self.total = total
        self.armIndex = armIndex
        self.armCount = armCount
        self.armID = armID
    }

    public var fractionCompleted: Double {
        total > 0 ? min(1, max(0, Double(completed) / Double(total))) : 0
    }
}

public struct LabEngineOutput: Sendable {
    public let results: [LabCaseResult]
    public let elapsedSeconds: TimeInterval
}

public actor LabExperimentRunner {
    public typealias ProgressHandler = @Sendable (LabRunProgress) async -> Void
    public typealias ReportHandler = @Sendable (LabRunReport) async throws -> Void
    public typealias CandidateHandler = @Sendable (LabCandidateObservation) async -> Void

    private let pool: LabLlamaServerPool
    private let verifier: LabAssetVerifier

    public init(
        pool: LabLlamaServerPool = LabLlamaServerPool(),
        verifier: LabAssetVerifier = .shared
    ) {
        self.pool = pool
        self.verifier = verifier
    }

    public func run(
        suite: LabScenarioSuite,
        arm: LabArmConfiguration,
        execution: LabExecutionConfiguration,
        protocolRetryCount: Int = 0,
        restartWorkers: Bool = true,
        stopWorkersAfterRun: Bool = true,
        progress: @escaping ProgressHandler = { _ in },
        candidateObserved: @escaping CandidateHandler = { _ in },
        reportCompleted: @escaping ReportHandler = { _ in }
    ) async throws -> LabRunReport {
        guard let report = try await runMatrix(
            suite: suite,
            arms: [arm],
            execution: execution,
            protocolRetryCount: protocolRetryCount,
            restartWorkers: restartWorkers,
            stopWorkersAfterRun: stopWorkersAfterRun,
            progress: progress,
            candidateObserved: candidateObserved,
            reportCompleted: reportCompleted
        ).first else { throw LabManifestError.noArms }
        return report
    }

    /// Runs every arm against one verified, already-loaded worker pool. This
    /// keeps matrix experiments fast while each report still carries its own
    /// complete arm manifest and selected-suite digest.
    public func runMatrix(
        suite: LabScenarioSuite,
        arms: [LabArmConfiguration],
        execution: LabExecutionConfiguration,
        protocolRetryCount: Int = 0,
        restartWorkers: Bool = true,
        stopWorkersAfterRun: Bool = true,
        progress: @escaping ProgressHandler = { _ in },
        candidateObserved: @escaping CandidateHandler = { _ in },
        reportCompleted: @escaping ReportHandler = { _ in }
    ) async throws -> [LabRunReport] {
        await progress(LabRunProgress(phase: .validating))
        try suite.validated()
        guard !arms.isEmpty else { throw LabManifestError.noArms }
        guard arms.count <= 128 else { throw LabManifestError.tooManyArms }
        try LabExperimentManifest.validateScoringLock(arms)
        var armIDs = Set<String>()
        var selectedSuites: [(arm: LabArmConfiguration, suite: LabScenarioSuite, digest: String)] = []
        for arm in arms {
            try arm.validated()
            guard armIDs.insert(arm.id).inserted else { throw LabManifestError.duplicateArmID }
            let selected = LabScenarioSelector.select(from: suite, configuration: arm.scenarios)
            try selected.validated()
            selectedSuites.append((arm, selected, try selected.digestSHA256()))
        }
        try execution.validated()

        await progress(LabRunProgress(phase: .verifyingAssets))
        let assets = try await verifier.verify(execution)
        try Task.checkCancellation()

        await progress(LabRunProgress(phase: .startingWorkers))
        let clients = try await pool.start(configuration: execution, restart: restartWorkers)
        do {
            let total = selectedSuites.reduce(0) {
                $0 + $1.suite.scenarios.count * execution.repetitions
            }
            var completedBeforeArm = 0
            var reports: [LabRunReport] = []
            reports.reserveCapacity(selectedSuites.count)
            let armCount = selectedSuites.count
            for (index, entry) in selectedSuites.enumerated() {
                try Task.checkCancellation()
                let armTotal = entry.suite.scenarios.count * execution.repetitions
                await progress(LabRunProgress(
                    phase: .running,
                    completed: completedBeforeArm,
                    total: total,
                    armIndex: index,
                    armCount: armCount,
                    armID: entry.arm.id
                ))
                let startedAt = Date()
                let baseCompleted = completedBeforeArm
                let output = try await LabExperimentEngine.execute(
                    suite: entry.suite,
                    arm: entry.arm,
                    repetitions: execution.repetitions,
                    timeoutSeconds: execution.timeoutSeconds,
                    protocolRetryCount: protocolRetryCount,
                    seed: execution.seed,
                    clients: clients,
                    candidateObserved: candidateObserved,
                    progress: { armCompleted in
                        await progress(LabRunProgress(
                            phase: .running,
                            completed: baseCompleted + armCompleted,
                            total: total,
                            armIndex: index,
                            armCount: armCount,
                            armID: entry.arm.id
                        ))
                    }
                )
                let metrics = LabScorer.aggregate(
                    output.results,
                    elapsedSeconds: output.elapsedSeconds,
                    scoring: entry.arm.scoring
                )
                let report = LabRunReport(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    suiteName: entry.suite.name,
                    suiteDigestSHA256: entry.digest,
                    scenarioCount: entry.suite.scenarios.count,
                    arm: entry.arm,
                    execution: LabExecutionSnapshot(execution),
                    assets: assets,
                    metrics: metrics,
                    cases: output.results
                )
                try await reportCompleted(report)
                reports.append(report)
                completedBeforeArm += armTotal
            }
            await progress(LabRunProgress(
                phase: .finalizing,
                completed: total,
                total: total,
                armIndex: max(0, selectedSuites.count - 1),
                armCount: armCount,
                armID: selectedSuites.last?.arm.id
            ))
            if stopWorkersAfterRun {
                await progress(LabRunProgress(phase: .stopping, completed: total, total: total))
                await pool.stop()
            }
            return reports
        } catch {
            await progress(LabRunProgress(phase: .stopping))
            await pool.stop()
            throw error
        }
    }

    public func cancel() async {
        await pool.stop()
    }
}

public enum LabExperimentEngine {
    public typealias ProgressHandler = @Sendable (Int) async -> Void

    public static func execute(
        suite: LabScenarioSuite,
        arm: LabArmConfiguration,
        repetitions: Int,
        timeoutSeconds: Double,
        protocolRetryCount: Int = 0,
        seed: UInt64,
        clients: [any LabCompletionClient],
        candidateObserved: @escaping LabExperimentRunner.CandidateHandler = { _ in },
        progress: @escaping ProgressHandler = { _ in }
    ) async throws -> LabEngineOutput {
        precondition(!clients.isEmpty)
        var items: [LabWorkItem] = []
        items.reserveCapacity(suite.scenarios.count * repetitions)
        for repetition in 0..<repetitions {
            for scenario in suite.scenarios {
                items.append(LabWorkItem(scenario: scenario, repetition: repetition))
            }
        }
        var generator = LabSeededGenerator(seed: seed)
        items.shuffle(using: &generator)

        let queue = LabWorkQueue(items: items)
        let totalCount = items.count
        let collector = LabResultCollector(capacity: totalCount)
        let updateStride = max(1, totalCount / 200)
        let clock = ContinuousClock()
        let started = clock.now

        try await withThrowingTaskGroup(of: Void.self) { group in
            for client in clients {
                group.addTask {
                    while let item = await queue.next() {
                        try Task.checkCancellation()
                        let result = try await run(
                            item: item,
                            arm: arm,
                            timeoutSeconds: timeoutSeconds,
                            protocolRetryCount: protocolRetryCount,
                            client: client,
                            candidateObserved: candidateObserved
                        )
                        let completed = await collector.append(result)
                        if completed == totalCount || completed.isMultiple(of: updateStride) {
                            await progress(completed)
                        }
                    }
                }
            }
            try await group.waitForAll()
        }

        let duration = started.duration(to: clock.now)
        let elapsedSeconds = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
        let results = await collector.sortedResults()
        return LabEngineOutput(results: results, elapsedSeconds: max(0, elapsedSeconds))
    }

    private static func run(
        item: LabWorkItem,
        arm: LabArmConfiguration,
        timeoutSeconds: Double,
        protocolRetryCount: Int,
        client: any LabCompletionClient,
        candidateObserved: @escaping LabExperimentRunner.CandidateHandler
    ) async throws -> LabCaseResult {
        let scenario = item.scenario
        let prepared = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt)
        if arm.suppressesSensitiveScenes, SensitiveScenePolicy.isSensitive(scene: prepared.scene) {
            await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
            return LabScorer.score(
                scenario: scenario,
                repetition: item.repetition,
                suggestion: nil,
                policySuppressed: true,
                decisionReason: .sensitiveScene,
                workerIndex: client.workerIndex
            )
        }

        guard !prepared.prompt.isEmpty else {
            await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
            return LabScorer.score(
                scenario: scenario,
                repetition: item.repetition,
                suggestion: nil,
                decisionReason: .emptyPrompt,
                workerIndex: client.workerIndex
            )
        }

        let request = LabModelRequest(
            prompt: prepared.prompt,
            generation: arm.generation,
            timeoutSeconds: timeoutSeconds
        )
        for attempt in 0...max(0, protocolRetryCount) {
            do {
                let response = try await client.complete(request)
                let decision = LabOutputJudge.judge(
                    rawOutput: response.content,
                    preparedPrompt: prepared,
                    scenario: scenario,
                    configuration: arm,
                    meanTokenProbability: response.meanTokenProbability
                )
                await candidateObserved(LabCandidateObservation(
                    scenarioID: scenario.id,
                    suggestion: decision.suggestion
                ))
                return LabScorer.score(
                    scenario: scenario,
                    repetition: item.repetition,
                    suggestion: decision.suggestion,
                    modelRequested: true,
                    latencyMilliseconds: response.latencyMilliseconds,
                    firstTokenMilliseconds: response.firstTokenMilliseconds,
                    meanTokenProbability: response.meanTokenProbability,
                    decisionReason: decision.reason,
                    workerIndex: client.workerIndex
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch LabCompletionError.timeout where attempt == protocolRetryCount {
                await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
                return LabScorer.failure(
                    scenario: scenario,
                    repetition: item.repetition,
                    outcome: .timeout,
                    workerIndex: client.workerIndex,
                    decisionReason: .timeout
                )
            } catch where attempt == protocolRetryCount {
                await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
                return LabScorer.failure(
                    scenario: scenario,
                    repetition: item.repetition,
                    outcome: .error,
                    workerIndex: client.workerIndex,
                    decisionReason: .protocolError
                )
            } catch {
                try Task.checkCancellation()
            }
        }
        preconditionFailure("The bounded retry loop must return a result")
    }
}

private struct LabWorkItem: Sendable {
    let scenario: LabScenario
    let repetition: Int
}

private actor LabWorkQueue {
    private let items: [LabWorkItem]
    private var index = 0

    init(items: [LabWorkItem]) { self.items = items }

    func next() -> LabWorkItem? {
        guard index < items.count else { return nil }
        defer { index += 1 }
        return items[index]
    }
}

private actor LabResultCollector {
    private var results: [LabCaseResult]

    init(capacity: Int) {
        results = []
        results.reserveCapacity(capacity)
    }

    func append(_ result: LabCaseResult) -> Int {
        results.append(result)
        return results.count
    }

    func sortedResults() -> [LabCaseResult] {
        results.sorted {
            $0.scenarioID == $1.scenarioID
                ? $0.repetition < $1.repetition
                : $0.scenarioID < $1.scenarioID
        }
    }
}

private struct LabSeededGenerator: RandomNumberGenerator {
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
