import TildeCore
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
    public typealias BlockGateHandler = @Sendable (Int) async throws -> Void
    public typealias BlockObservedHandler = @Sendable (Int, [String]) async throws -> Void

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
        research: LabResearchProtocol? = nil,
        protectedPurpose: LabProtectedEvaluationPurpose = .none,
        durable: LabDurableRunConfiguration? = nil,
        candidateCache: LabSyntheticCandidateCache? = nil,
        protocolRetryCount: Int = 0,
        restartWorkers: Bool = true,
        stopWorkersAfterRun: Bool = true,
        progress: @escaping ProgressHandler = { _ in },
        blockGate: @escaping BlockGateHandler = { _ in },
        blockObserved: @escaping BlockObservedHandler = { _, _ in },
        candidateObserved: @escaping CandidateHandler = { _ in },
        reportCompleted: @escaping ReportHandler = { _ in }
    ) async throws -> LabRunReport {
        guard let report = try await runMatrix(
            suite: suite,
            arms: [arm],
            execution: execution,
            executionsByArm: nil,
            research: research,
            protectedPurpose: protectedPurpose,
            durable: durable,
            candidateCache: candidateCache,
            protocolRetryCount: protocolRetryCount,
            restartWorkers: restartWorkers,
            stopWorkersAfterRun: stopWorkersAfterRun,
            progress: progress,
            blockGate: blockGate,
            blockObserved: blockObserved,
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
        executionsByArm: [String: LabExecutionConfiguration]? = nil,
        research: LabResearchProtocol? = nil,
        protectedPurpose: LabProtectedEvaluationPurpose = .none,
        durable: LabDurableRunConfiguration? = nil,
        candidateCache: LabSyntheticCandidateCache? = nil,
        protocolRetryCount: Int = 0,
        restartWorkers: Bool = true,
        stopWorkersAfterRun: Bool = true,
        progress: @escaping ProgressHandler = { _ in },
        blockGate: @escaping BlockGateHandler = { _ in },
        blockObserved: @escaping BlockObservedHandler = { _, _ in },
        candidateObserved: @escaping CandidateHandler = { _ in },
        reportCompleted: @escaping ReportHandler = { _ in }
    ) async throws -> [LabRunReport] {
        await progress(LabRunProgress(phase: .validating))
        try suite.validated()
        guard !arms.isEmpty else { throw LabManifestError.noArms }
        guard arms.count <= 128 else { throw LabManifestError.tooManyArms }
        try LabExperimentManifest.validateScoringLock(arms)
        var armIDs = Set<String>()
        var selectedSuites: [LabSelectedArmSuite] = []
        for arm in arms {
            try arm.validated()
            guard armIDs.insert(arm.id).inserted else { throw LabManifestError.duplicateArmID }
            let selected: LabScenarioSuite
            if let research {
                selected = try LabResearchScenarioSelection.select(
                    from: suite,
                    configuration: arm.scenarios,
                    phase: research.phase
                )
            } else {
                selected = LabScenarioSelector.select(from: suite, configuration: arm.scenarios)
            }
            try selected.validated()
            selectedSuites.append(LabSelectedArmSuite(
                arm: arm,
                suite: selected,
                digest: try selected.digestSHA256()
            ))
        }
        let primaryExecution: LabExecutionConfiguration
        if let executionsByArm {
            guard let research, research.experimentClass == .runtime,
                  Set(executionsByArm.keys) == Set(arms.map(\.id)),
                  let baselineExecution = executionsByArm[research.baselineArmID],
                  let registered = research.runtimeByArm,
                  Dictionary(uniqueKeysWithValues: executionsByArm.map {
                      ($0.key, LabRuntimeConfiguration($0.value))
                  }) == registered,
                  executionsByArm.values.allSatisfy({
                      $0.serverExecutable == baselineExecution.serverExecutable
                          && $0.modelFile == baselineExecution.modelFile
                          && $0.modelProfile == baselineExecution.modelProfile
                  }) else {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
            for configuration in executionsByArm.values {
                try configuration.validated()
            }
            primaryExecution = baselineExecution
        } else {
            try execution.validated()
            primaryExecution = execution
        }

        await progress(LabRunProgress(phase: .verifyingAssets))
        let assets = try await verifier.verify(primaryExecution)
        try LabResearchProtocolValidator.validateExecution(
            research: research,
            arms: arms,
            selectedSuites: selectedSuites.map(\.suite),
            selectedSuiteDigests: selectedSuites.map(\.digest),
            assets: assets,
            protectedPurpose: protectedPurpose
        )
        if let durable {
            guard let research, Set(selectedSuites.map(\.digest)).count == 1,
                  let suiteDigest = selectedSuites.first?.digest else {
                throw LabResearchDatabaseError.durableProtocolRequired
            }
            try await durable.database.registerCampaign(LabResearchCampaignRecord(
                id: durable.campaignID,
                name: durable.campaignName,
                manifestDigestSHA256: durable.manifestDigestSHA256,
                suiteDigestSHA256: suiteDigest,
                modelSHA256: assets.modelSHA256,
                helperSHA256: assets.helperSHA256,
                gitCommit: durable.gitCommit,
                protocolDefinition: research
            ))
            try await durable.database.beginRunSession(
                campaignID: durable.campaignID,
                owner: durable.leaseOwner,
                processIdentifier: durable.processIdentifier,
                resume: durable.resumeRequested,
                staleAfter: durable.sessionStaleAfter
            )
        }
        try Task.checkCancellation()
        try await blockGate(0)

        if let executionsByArm, let research {
            do {
                let reports = try await runInterleavedMatrix(
                    selectedSuites: selectedSuites,
                    execution: primaryExecution,
                    executionsByArm: executionsByArm,
                    research: research,
                    protocolRetryCount: protocolRetryCount,
                    clients: nil,
                    assets: assets,
                    durable: durable,
                    candidateCache: nil,
                    progress: progress,
                    blockGate: blockGate,
                    blockObserved: blockObserved,
                    candidateObserved: candidateObserved,
                    reportCompleted: reportCompleted
                )
                let total = selectedSuites.reduce(0) { total, entry in
                    let armExecution = executionsByArm[entry.arm.id]!
                    return total + entry.suite.scenarios.count * armExecution.repetitions
                        * research.fixedGenerationSeeds.count
                }
                if stopWorkersAfterRun {
                    await progress(LabRunProgress(
                        phase: .stopping,
                        completed: total,
                        total: total
                    ))
                    await pool.stop()
                }
                return reports
            } catch {
                await progress(LabRunProgress(phase: .stopping))
                await pool.stop()
                throw error
            }
        }

        await progress(LabRunProgress(phase: .startingWorkers))
        let clients = try await pool.start(configuration: execution, restart: restartWorkers)
        do {
            if let research {
                let reports = try await runInterleavedMatrix(
                    selectedSuites: selectedSuites,
                    execution: execution,
                    executionsByArm: nil,
                    research: research,
                    protocolRetryCount: protocolRetryCount,
                    clients: clients,
                    assets: assets,
                    durable: durable,
                    candidateCache: candidateCache,
                    progress: progress,
                    blockGate: blockGate,
                    blockObserved: blockObserved,
                    candidateObserved: candidateObserved,
                    reportCompleted: reportCompleted
                )
                let total = selectedSuites.reduce(0) {
                    $0 + $1.suite.scenarios.count * execution.repetitions
                        * research.fixedGenerationSeeds.count
                }
                if stopWorkersAfterRun {
                    await progress(LabRunProgress(phase: .stopping, completed: total, total: total))
                    await pool.stop()
                }
                return reports
            }
            let total = selectedSuites.reduce(0) {
                let seedCount = research?.fixedGenerationSeeds.count ?? 1
                return $0 + $1.suite.scenarios.count * execution.repetitions * seedCount
            }
            var completedBeforeArm = 0
            var reports: [LabRunReport] = []
            reports.reserveCapacity(selectedSuites.count)
            let armCount = selectedSuites.count
            for (index, entry) in selectedSuites.enumerated() {
                try Task.checkCancellation()
                if index > 0 { try await blockGate(index) }
                try await blockObserved(index, [entry.arm.id])
                let generationSeeds = research?.fixedGenerationSeeds
                    ?? [entry.arm.generation.seed]
                let armTotal = entry.suite.scenarios.count * execution.repetitions
                    * generationSeeds.count
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
                    generationSeeds: generationSeeds,
                    clients: clients,
                    durableContext: durable.map {
                        LabDurableExecutionContext(
                            database: $0.database,
                            campaignID: $0.campaignID,
                            trialID: entry.arm.id,
                            blockIndex: 0,
                            leaseOwner: $0.leaseOwner,
                            leaseDuration: $0.leaseDuration
                        )
                    },
                    candidateCache: candidateCache.map {
                        LabCandidateCacheContext(cache: $0, assets: assets)
                    },
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
                    provenance: durable?.reportProvenance ?? .unavailable(),
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

    /// Interleaves candidate arms inside deterministic root blocks so each arm
    /// sees nearly the same cache, power, and thermal window. Arm order rotates
    /// every block; the scenario work-order seed remains paired within a block.
    static func interleavedArmOrder(armCount: Int, blockIndex: Int) -> [Int] {
        guard armCount > 0 else { return [] }
        // Rotating and then reversing cancels out for two arms, always
        // putting the control first. Alternate paired blocks explicitly.
        if armCount == 2 {
            return blockIndex.isMultiple(of: 2) ? [0, 1] : [1, 0]
        }
        let indices = Array(0..<armCount)
        let rotation = blockIndex % armCount
        let rotated = Array(indices[rotation...]) + Array(indices[..<rotation])
        return blockIndex.isMultiple(of: 2) ? rotated : Array(rotated.reversed())
    }

    private func runInterleavedMatrix(
        selectedSuites: [LabSelectedArmSuite],
        execution: LabExecutionConfiguration,
        executionsByArm: [String: LabExecutionConfiguration]?,
        research: LabResearchProtocol,
        protocolRetryCount: Int,
        clients: [any LabCompletionClient]?,
        assets: LabAssetSnapshot,
        durable: LabDurableRunConfiguration?,
        candidateCache: LabSyntheticCandidateCache?,
        progress: @escaping ProgressHandler,
        blockGate: @escaping BlockGateHandler,
        blockObserved: @escaping BlockObservedHandler,
        candidateObserved: @escaping CandidateHandler,
        reportCompleted: @escaping ReportHandler
    ) async throws -> [LabRunReport] {
        let total = selectedSuites.reduce(0) { total, entry in
            let repetitions = executionsByArm?[entry.arm.id]?.repetitions
                ?? execution.repetitions
            return total + entry.suite.scenarios.count * repetitions
                * research.fixedGenerationSeeds.count
        }
        let invariantRoots = try LabResearchScenarioSelection.invariantRootIDs(
            in: selectedSuites[0].suite
        )
        let remaining = LabResearchScenarioSelection.stratifiedRootBlocks(
            in: selectedSuites[0].suite,
            excluding: Set(invariantRoots),
            maximumCount: research.interleavedRootBlockSize,
            seed: execution.seed
        )
        let blocks = [invariantRoots] + remaining
        var results = Array(repeating: [LabCaseResult](), count: selectedSuites.count)
        var elapsed = Array(repeating: 0.0, count: selectedSuites.count)
        var startupMilliseconds = Array(repeating: [Int](), count: selectedSuites.count)
        let started = Array(repeating: Date(), count: selectedSuites.count)
        var completed = 0

        for (blockIndex, rootBlock) in blocks.enumerated() {
            try Task.checkCancellation()
            if blockIndex > 0 { try await blockGate(blockIndex) }
            let order = Self.interleavedArmOrder(
                armCount: selectedSuites.count, blockIndex: blockIndex
            )
            try await blockObserved(blockIndex, order.map { selectedSuites[$0].arm.id })
            let rootSet = Set(rootBlock)
            let blockSeed = execution.seed &+ UInt64(blockIndex) &* 0x9E37_79B9

            for armIndex in order {
                try Task.checkCancellation()
                let entry = selectedSuites[armIndex]
                let scenarios = entry.suite.scenarios.filter {
                    rootSet.contains($0.evaluation.rootScenarioID ?? $0.id)
                }
                let blockSuite = LabScenarioSuite(
                    schema: entry.suite.schema,
                    name: entry.suite.name,
                    scenarios: scenarios
                )
                let armExecution = executionsByArm?[entry.arm.id] ?? execution
                let activeClients: [any LabCompletionClient]
                if executionsByArm != nil {
                    await progress(LabRunProgress(
                        phase: .startingWorkers,
                        completed: completed,
                        total: total,
                        armIndex: armIndex,
                        armCount: selectedSuites.count,
                        armID: entry.arm.id
                    ))
                    let startupStartedAt = Date()
                    activeClients = try await pool.start(
                        configuration: armExecution,
                        restart: true
                    )
                    startupMilliseconds[armIndex].append(Int(
                        Date().timeIntervalSince(startupStartedAt) * 1_000
                    ))
                } else if let clients {
                    activeClients = clients
                } else {
                    throw LabResearchProtocolError.runtimeConfigurationRequired
                }
                let baseCompleted = completed
                await progress(LabRunProgress(
                    phase: .running,
                    completed: completed,
                    total: total,
                    armIndex: armIndex,
                    armCount: selectedSuites.count,
                    armID: entry.arm.id
                ))
                let output: LabEngineOutput
                do {
                    output = try await LabExperimentEngine.execute(
                        suite: blockSuite,
                        arm: entry.arm,
                        repetitions: armExecution.repetitions,
                        timeoutSeconds: armExecution.timeoutSeconds,
                        protocolRetryCount: protocolRetryCount,
                        seed: blockSeed,
                        generationSeeds: research.fixedGenerationSeeds,
                        clients: activeClients,
                        durableContext: durable.map {
                            LabDurableExecutionContext(
                                database: $0.database,
                                campaignID: $0.campaignID,
                                trialID: entry.arm.id,
                                blockIndex: blockIndex,
                                leaseOwner: $0.leaseOwner,
                                leaseDuration: $0.leaseDuration
                            )
                        },
                        candidateCache: candidateCache.map {
                            LabCandidateCacheContext(cache: $0, assets: assets)
                        },
                        candidateObserved: candidateObserved,
                        progress: { blockCompleted in
                            await progress(LabRunProgress(
                                phase: .running,
                                completed: baseCompleted + blockCompleted,
                                total: total,
                                armIndex: armIndex,
                                armCount: selectedSuites.count,
                                armID: entry.arm.id
                            ))
                        }
                    )
                } catch {
                    if executionsByArm != nil { await pool.stop() }
                    throw error
                }
                if executionsByArm != nil { await pool.stop() }
                results[armIndex].append(contentsOf: output.results)
                elapsed[armIndex] += output.elapsedSeconds
                completed += scenarios.count * armExecution.repetitions
                    * research.fixedGenerationSeeds.count
            }
            if blockIndex == 0 {
                for armIndex in selectedSuites.indices {
                    try LabResearchScenarioSelection.assertPassed(
                        armID: selectedSuites[armIndex].arm.id,
                        results: results[armIndex],
                        suite: selectedSuites[armIndex].suite
                    )
                }
            }
        }

        var reports: [LabRunReport] = []
        reports.reserveCapacity(selectedSuites.count)
        for index in selectedSuites.indices {
            let entry = selectedSuites[index]
            let cases = results[index].sorted {
                if $0.scenarioID != $1.scenarioID { return $0.scenarioID < $1.scenarioID }
                if $0.generationSeed != $1.generationSeed {
                    return $0.generationSeed < $1.generationSeed
                }
                return $0.repetition < $1.repetition
            }
            let metrics = LabScorer.aggregate(
                cases,
                elapsedSeconds: elapsed[index],
                scoring: entry.arm.scoring
            )
            let armExecution = executionsByArm?[entry.arm.id] ?? execution
            let report = LabRunReport(
                startedAt: started[index],
                finishedAt: Date(),
                suiteName: entry.suite.name,
                suiteDigestSHA256: entry.digest,
                scenarioCount: entry.suite.scenarios.count,
                arm: entry.arm,
                execution: LabExecutionSnapshot(armExecution),
                runtimeStartup: executionsByArm == nil
                    ? nil
                    : LabRuntimeStartupSummary(milliseconds: startupMilliseconds[index]),
                assets: assets,
                provenance: durable?.reportProvenance ?? .unavailable(),
                metrics: metrics,
                cases: cases
            )
            try await reportCompleted(report)
            reports.append(report)
        }
        await progress(LabRunProgress(
            phase: .finalizing,
            completed: total,
            total: total,
            armIndex: selectedSuites.count - 1,
            armCount: selectedSuites.count,
            armID: selectedSuites.last?.arm.id
        ))
        return reports
    }
}

private struct LabSelectedArmSuite: Sendable {
    let arm: LabArmConfiguration
    let suite: LabScenarioSuite
    let digest: String
}

private extension Array {
    func chunked(maximumCount: Int) -> [[Element]] {
        guard maximumCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maximumCount).map { start in
            Array(self[start..<Swift.min(start + maximumCount, count)])
        }
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
        generationSeeds: [Int]? = nil,
        clients: [any LabCompletionClient],
        durableContext: LabDurableExecutionContext? = nil,
        candidateCache: LabCandidateCacheContext? = nil,
        candidateObserved: @escaping LabExperimentRunner.CandidateHandler = { _ in },
        progress: @escaping ProgressHandler = { _ in }
    ) async throws -> LabEngineOutput {
        precondition(!clients.isEmpty)
        var items: [LabWorkItem] = []
        let activeGenerationSeeds = generationSeeds ?? [arm.generation.seed]
        precondition(!activeGenerationSeeds.isEmpty)
        items.reserveCapacity(suite.scenarios.count * repetitions * activeGenerationSeeds.count)
        let armHash = try arm.digestSHA256()
        for generationSeed in activeGenerationSeeds {
            for repetition in 0..<repetitions {
                for scenario in suite.scenarios {
                    let durableItem = durableContext.map { context in
                        LabDurableWorkItem(
                            campaignID: context.campaignID,
                            trialID: context.trialID,
                            armHash: armHash,
                            scenario: scenario,
                            generationSeed: generationSeed,
                            repetition: repetition,
                            blockIndex: context.blockIndex
                        )
                    }
                    items.append(LabWorkItem(
                        scenario: scenario,
                        repetition: repetition,
                        generationSeed: generationSeed,
                        durableItem: durableItem
                    ))
                }
            }
        }
        var generator = LabSeededGenerator(seed: seed)
        items.shuffle(using: &generator)

        var restored: [String: LabCaseResult] = [:]
        if let durableContext {
            let rootCount = Set(suite.scenarios.map {
                $0.evaluation.rootScenarioID ?? $0.id
            }).count
            try await durableContext.database.registerTrial(
                campaignID: durableContext.campaignID,
                trialID: durableContext.trialID,
                armID: arm.id,
                armHash: armHash,
                stage: "block-\(durableContext.blockIndex)",
                rootBudget: rootCount
            )
            let durableItems = items.compactMap(\.durableItem)
            try await durableContext.database.enqueue(durableItems)
            restored = try await durableContext.database.completedResults(
                campaignID: durableContext.campaignID,
                trialID: durableContext.trialID,
                workItemIDs: Set(durableItems.map(\.id))
            )
            items.removeAll { item in
                item.durableItem.map { restored[$0.id] != nil } ?? false
            }
        }

        let queue = LabWorkQueue(items: items)
        let totalCount = suite.scenarios.count * repetitions * activeGenerationSeeds.count
        let collector = LabResultCollector(
            capacity: totalCount,
            initial: Array(restored.values)
        )
        if !restored.isEmpty { await progress(restored.count) }
        let updateStride = max(1, totalCount / 200)
        let clock = ContinuousClock()
        let started = clock.now

        try await withThrowingTaskGroup(of: Void.self) { group in
            for client in clients {
                group.addTask {
                    while let item = await queue.next() {
                        try Task.checkCancellation()
                        if let context = durableContext, let durableItem = item.durableItem {
                            let claimed = try await context.database.claim(
                                workItemID: durableItem.id,
                                owner: context.leaseOwner,
                                leaseDuration: context.leaseDuration
                            )
                            guard claimed else { throw LabResearchDatabaseError.leaseConflict }
                        }
                        let result: LabCaseResult
                        do {
                            result = try await run(
                                item: item,
                                arm: arm,
                                timeoutSeconds: timeoutSeconds,
                                protocolRetryCount: protocolRetryCount,
                                client: client,
                                candidateCache: candidateCache,
                                candidateObserved: candidateObserved
                            )
                        } catch {
                            if let context = durableContext, let durableItem = item.durableItem {
                                try? await context.database.release(
                                    workItemID: durableItem.id,
                                    owner: context.leaseOwner
                                )
                            }
                            throw error
                        }
                        if let context = durableContext, let durableItem = item.durableItem {
                            try await context.database.complete(
                                workItemID: durableItem.id,
                                owner: context.leaseOwner,
                                result: result
                            )
                        }
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
        candidateCache: LabCandidateCacheContext?,
        candidateObserved: @escaping LabExperimentRunner.CandidateHandler
    ) async throws -> LabCaseResult {
        let scenario = item.scenario
        let prepared = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt)
        if let reason = SceneSuggestionPolicy.suppressionReason(
            scene: prepared.scene,
            textBeforeCursor: scenario.typedContext
        ) {
            await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
            return LabScorer.score(
                scenario: scenario,
                repetition: item.repetition,
                generationSeed: item.generationSeed,
                suggestion: nil,
                policySuppressed: true,
                decisionReason: .sceneSuppression(reason),
                workerIndex: client.workerIndex
            )
        }
        if arm.suppressesSensitiveScenes, SensitiveScenePolicy.isSensitive(scene: prepared.scene) {
            await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
            return LabScorer.score(
                scenario: scenario,
                repetition: item.repetition,
                generationSeed: item.generationSeed,
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
                generationSeed: item.generationSeed,
                suggestion: nil,
                decisionReason: .emptyPrompt,
                workerIndex: client.workerIndex
            )
        }

        var generation = arm.generation
        generation.seed = item.generationSeed
        let request = LabModelRequest(
            prompt: prepared.prompt,
            generation: generation,
            timeoutSeconds: timeoutSeconds
        )
        let cacheKey = try candidateCache.map { context in
            try LabCandidateCacheKey(
                modelSHA256: context.assets.modelSHA256,
                helperSHA256: context.assets.helperSHA256,
                prompt: request.prompt,
                generation: request.generation,
                scenario: scenario
            )
        }
        for attempt in 0...max(0, protocolRetryCount) {
            do {
                let response: LabModelResponse
                let cacheHit: Bool?
                if let candidateCache, let cacheKey,
                   let cached = try await candidateCache.cache.value(for: cacheKey) {
                    response = cached.modelResponse
                    cacheHit = true
                } else {
                    response = try await client.complete(request)
                    cacheHit = candidateCache == nil ? nil : false
                    if let candidateCache, let cacheKey {
                        try await candidateCache.cache.store(
                            LabCachedCandidate(response: response, assets: candidateCache.assets),
                            for: cacheKey
                        )
                    }
                }
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
                    generationSeed: item.generationSeed,
                    suggestion: decision.suggestion,
                    modelRequested: true,
                    latencyMilliseconds: response.latencyMilliseconds,
                    firstTokenMilliseconds: response.firstTokenMilliseconds,
                    meanTokenProbability: response.meanTokenProbability,
                    decisionReason: decision.reason,
                    workerIndex: client.workerIndex,
                    candidateCacheHit: cacheHit
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch LabCompletionError.timeout where attempt == protocolRetryCount {
                await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
                return LabScorer.failure(
                    scenario: scenario,
                    repetition: item.repetition,
                    generationSeed: item.generationSeed,
                    outcome: .timeout,
                    workerIndex: client.workerIndex,
                    decisionReason: .timeout,
                    candidateCacheHit: candidateCache == nil ? nil : false
                )
            } catch where attempt == protocolRetryCount {
                await candidateObserved(LabCandidateObservation(scenarioID: scenario.id, suggestion: nil))
                return LabScorer.failure(
                    scenario: scenario,
                    repetition: item.repetition,
                    generationSeed: item.generationSeed,
                    outcome: .error,
                    workerIndex: client.workerIndex,
                    decisionReason: .protocolError,
                    candidateCacheHit: candidateCache == nil ? nil : false
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
    let generationSeed: Int
    let durableItem: LabDurableWorkItem?
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

    init(capacity: Int, initial: [LabCaseResult] = []) {
        results = initial
        results.reserveCapacity(capacity)
    }

    func append(_ result: LabCaseResult) -> Int {
        results.append(result)
        return results.count
    }

    func sortedResults() -> [LabCaseResult] {
        results.sorted {
            if $0.scenarioID != $1.scenarioID { return $0.scenarioID < $1.scenarioID }
            if $0.generationSeed != $1.generationSeed {
                return $0.generationSeed < $1.generationSeed
            }
            return $0.repetition < $1.repetition
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
