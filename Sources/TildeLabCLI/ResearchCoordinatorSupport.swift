import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func suiteReference(_ value: String) throws -> LabResearchSuiteReference {
        switch value {
        case "certified-v2": return .certifiedV2
        case let raw where LabBuiltInSuite(rawValue: raw) != nil:
            return .builtIn(LabBuiltInSuite(rawValue: raw)!)
        default:
            let path = value.expandedResearchPath
            guard path.hasPrefix("/") else { throw ResearchCLIError.invalidValue("--suite") }
            return .file(path)
        }
    }

    static func generationSeeds(_ value: String) throws -> [Int] {
        let values = try value.split(separator: ",").map { token -> Int in
            guard let result = Int(token.trimmingCharacters(in: .whitespaces)),
                  (0...Int(Int32.max)).contains(result) else {
                throw ResearchCLIError.invalidValue("--seeds")
            }
            return result
        }
        guard !values.isEmpty, Set(values).count == values.count, values.count <= 16 else {
            throw ResearchCLIError.invalidValue("--seeds")
        }
        return values
    }

    static func modelConfiguration(
        _ arguments: CLIArguments
    ) throws -> LabResearchModelConfiguration {
        let experimental = arguments.hasFlag("experimental-model")
        let requestedIdentifier = arguments.value("model")
        if !experimental, let requestedIdentifier,
           requestedIdentifier != LabResearchModelConfiguration().identifier {
            throw ResearchCLIError.usage(
                "Alternate Lab models require --experimental-model; Tilde production remains pinned to Gemma 4 E2B."
            )
        }
        var configuration = LabResearchModelConfiguration()
        if experimental {
            guard let identifier = requestedIdentifier, !identifier.isEmpty else {
                throw ResearchCLIError.usage("--experimental-model requires --model ID.")
            }
            configuration.verificationMode = .experimentalLocal
            configuration.identifier = identifier
            configuration.revision = arguments.value("model-revision") ?? "local"
        }
        if let path = arguments.value("helper") {
            configuration.helperPath = path.expandedResearchPath
        }
        if let path = arguments.value("model-file") {
            configuration.modelPath = path.expandedResearchPath
        }
        return try configuration.validated()
    }

    static func oneDocumentURL(
        _ arguments: CLIArguments,
        command: String
    ) throws -> URL {
        guard arguments.positionals.count == 1 else {
            throw ResearchCLIError.usage(help(for: command))
        }
        return URL(fileURLWithPath: arguments.positionals[0].expandedResearchPath)
            .standardizedFileURL
    }

    static func campaignURL(_ arguments: CLIArguments, command: String) throws -> URL {
        if let value = arguments.value("campaign") {
            guard arguments.positionals.isEmpty else {
                throw ResearchCLIError.usage(help(for: command))
            }
            return URL(fileURLWithPath: value.expandedResearchPath).standardizedFileURL
        }
        return try oneDocumentURL(arguments, command: command)
    }

    static func researchDatabase(_ arguments: CLIArguments) throws -> LabResearchDatabase {
        if let path = arguments.value("database") {
            return try LabResearchDatabase(
                fileURL: URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            )
        }
        return try LabResearchDatabase()
    }

    static func writeJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(value))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    static func formatHours(_ seconds: Double) -> String {
        (seconds / 3_600).formatted(.number.precision(.fractionLength(2)))
    }

    static func gitCommit() -> String {
        commandOutput("/usr/bin/git", ["rev-parse", "HEAD"]) ?? "unknown"
    }

    static func reportProvenance(
        campaignID: UUID,
        manifestDigestSHA256: String,
        hypothesisID: String?,
        hypothesis: String?
    ) -> LabReportProvenance {
        let experiment: LabExperimentRegistration?
        if let hypothesisID, let hypothesis {
            experiment = LabExperimentRegistration(
                id: hypothesisID,
                campaignID: campaignID,
                manifestDigestSHA256: manifestDigestSHA256,
                hypothesis: hypothesis
            )
        } else {
            experiment = nil
        }
        return (try? LabReportProvenanceCapture.capture(experiment: experiment))
            ?? .unavailable()
    }

    private static func commandOutput(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(
                decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    static func runManifest(
        manifest: LabExperimentManifest,
        campaignID: UUID,
        campaignName: String,
        documentURL: URL,
        suite: LabScenarioSuite,
        model: LabResearchModelConfiguration,
        budget: LabResearchBudget,
        hypothesisID: String?,
        hypothesis: String?,
        database: LabResearchDatabase,
        allowBattery: Bool,
        usesCandidateCache: Bool,
        resumeRequested: Bool = false
    ) async throws -> [LabRunReport] {
        guard let research = manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        if research.phase != .discovery, allowBattery {
            throw ResearchCLIError.usage("Protected evaluation cannot use --allow-battery.")
        }
        try manifest.validated()
        try suite.validated()
        let manifestDigestSHA256 = try manifest.digestSHA256()
        // Capture before preparing report/checkpoint directories so the run's
        // own artifacts cannot make an otherwise clean source tree look dirty.
        let provenance = reportProvenance(
            campaignID: campaignID,
            manifestDigestSHA256: manifestDigestSHA256,
            hypothesisID: hypothesisID,
            hypothesis: hypothesis
        )
        let selected = try manifest.arms.map {
            try LabResearchScenarioSelection.select(
                from: suite,
                configuration: $0.scenarios,
                phase: research.phase
            )
        }
        let plannedRequests = selected.enumerated().reduce(0) { total, entry in
            let armID = manifest.arms[entry.offset].id
            let repetitions = research.runtimeByArm?[armID]?.repetitions
                ?? manifest.runtime.repetitions
            return total + entry.element.scenarios.count * repetitions
                * research.fixedGenerationSeeds.count
        }
        guard manifest.arms.count <= budget.maximumTrials,
              plannedRequests <= budget.maximumModelRequests,
              selected.allSatisfy({ selectedSuite in
                  Set(selectedSuite.scenarios.map {
                      $0.evaluation.rootScenarioID ?? $0.id
                  }).count <= budget.maximumRootsPerTrial
              }) else {
            throw LabResearchCampaignFileError.budgetExceeded
        }

        let layout = LabResearchArtifactLayout(documentURL: documentURL)
        try layout.prepare()
        let store = LabReportStore(directory: layout.reportsDirectory)
        let candidateCache: LabSyntheticCandidateCache?
        if usesCandidateCache,
           research.phase == .discovery,
           research.experimentClass != .runtime,
           research.experimentClass != .interaction,
           selected.flatMap(\.scenarios).allSatisfy({ $0.evaluation.source == .synthetic }) {
            candidateCache = try LabSyntheticCandidateCache(fileURL: layout.candidateCacheURL)
        } else {
            candidateCache = nil
        }

        let priorActive = try await database.activeDurationSeconds(campaignID: campaignID)
        let remainingSeconds = budget.maximumHours * 3_600 - priorActive
        guard remainingSeconds > 0 else { throw ResearchCLIError.budgetExpired }
        let progress = ResearchProgressPrinter()
        let runner = LabExperimentRunner()
        let execution = model.execution(manifest.runtime)
        let executionsByArm = research.runtimeByArm.map { runtimes in
            Dictionary(uniqueKeysWithValues: runtimes.map {
                ($0.key, model.execution($0.value))
            })
        }
        let durable = LabDurableRunConfiguration(
            database: database,
            campaignID: campaignID,
            campaignName: campaignName,
            manifestDigestSHA256: manifestDigestSHA256,
            gitCommit: gitCommit(),
            reportProvenance: provenance,
            resumeRequested: resumeRequested
        )
        let started = ContinuousClock.now
        do {
            let reports = try await withThrowingTaskGroup(of: [LabRunReport].self) { group in
                group.addTask {
                    try await runner.runMatrix(
                        suite: suite,
                        arms: manifest.arms,
                        execution: execution,
                        executionsByArm: executionsByArm,
                        research: research,
                        durable: durable,
                        candidateCache: candidateCache,
                        progress: { update in await progress.accept(update) },
                        blockGate: { block in
                            let state = LabResearchMachinePreflight.inspect()
                            if !state.isStable(allowBattery: allowBattery) {
                                ResearchConsole.line(
                                    "Paused before block \(block): waiting for stable power and thermal state."
                                )
                            }
                            try await LabResearchMachinePreflight.waitUntilStable(
                                allowBattery: allowBattery
                            )
                        },
                        blockObserved: { block, armOrder in
                            try await database.recordBlockEnvironment(
                                campaignID: campaignID,
                                environment: LabResearchBlockEnvironment(
                                    blockIndex: block,
                                    armRunOrder: armOrder,
                                    workerCount: manifest.runtime.workerCount,
                                    configuredSlotsPerWorker: manifest.runtime.slotsPerWorker,
                                    candidateCacheEnabled: candidateCache != nil,
                                    runtimeByArm: executionsByArm.map { executions in
                                        Dictionary(uniqueKeysWithValues: executions.map {
                                            ($0.key, LabExecutionSnapshot($0.value))
                                        })
                                    },
                                    machine: LabResearchMachinePreflight.inspect()
                                )
                            )
                        },
                        reportCompleted: { report in try await store.save(report) }
                    )
                }
                group.addTask {
                    let nanoseconds = UInt64(min(
                        Double(UInt64.max), remainingSeconds * 1_000_000_000
                    ))
                    try await Task.sleep(nanoseconds: nanoseconds)
                    throw ResearchCLIError.budgetExpired
                }
                group.addTask {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(30))
                        guard try await database.heartbeatRunSession(
                            campaignID: campaignID,
                            owner: durable.leaseOwner,
                            staleAfter: durable.sessionStaleAfter
                        ) else {
                            throw LabResearchDatabaseError.sessionNotActive
                        }
                    }
                    throw CancellationError()
                }
                guard let first = try await group.next() else {
                    throw ResearchCLIError.noComparableReports
                }
                group.cancelAll()
                return first
            }
            let elapsed = started.duration(to: .now)
            try? await database.recordActiveDuration(
                campaignID: campaignID,
                seconds: elapsed.secondsValue
            )
            try await database.completeCampaign(
                campaignID: campaignID,
                owner: durable.leaseOwner
            )
            return reports
        } catch {
            let elapsed = started.duration(to: .now)
            try? await database.recordActiveDuration(
                campaignID: campaignID,
                seconds: elapsed.secondsValue
            )
            let classification: LabResearchFailureClassification
            if case ResearchCLIError.budgetExpired = error {
                classification = LabResearchFailureClassification(
                    state: .aborted,
                    category: .budgetExpired,
                    reasons: [.activeBudgetExhausted]
                )
            } else {
                classification = LabResearchFailureClassifier.classify(error)
            }
            try await database.finishCampaign(
                campaignID: campaignID,
                owner: durable.leaseOwner,
                classification: classification
            )
            throw error
        }
    }

    static func latestReports(
        manifest: LabExperimentManifest,
        layout: LabResearchArtifactLayout
    ) async throws -> [String: LabRunReport] {
        let reports = await LabReportStore(directory: layout.reportsDirectory).loadAll()
        var result: [String: LabRunReport] = [:]
        for arm in manifest.arms {
            let digest = try arm.digestSHA256()
            if let report = reports.first(where: {
                guard $0.arm.id == arm.id,
                      (try? $0.arm.digestSHA256()) == digest else { return false }
                guard let expectedRuntime = manifest.research?.runtimeByArm?[arm.id] else {
                    return true
                }
                return LabRuntimeConfiguration($0.execution) == expectedRuntime
            }) {
                result[arm.id] = report
            }
        }
        return result
    }

    @discardableResult
    static func computeComparisons(
        manifest: LabExperimentManifest,
        campaignID: UUID,
        phase: LabCampaignPhase,
        layout: LabResearchArtifactLayout,
        database: LabResearchDatabase,
        bootstrapIterations: Int? = nil
    ) async throws -> [LabResearchComparisonArtifact] {
        guard var research = manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        if let bootstrapIterations {
            research.promotionRule.bootstrapIterations = bootstrapIterations
        }
        try research.promotionRule.validated()
        let campaign = try await database.reconciledSnapshot(campaignID: campaignID)
        guard campaign.state == .completed, campaign.terminalFailure == nil else {
            throw ResearchCLIError.decisionGradeEvidenceRequired
        }
        let reports = try await latestReports(manifest: manifest, layout: layout)
        guard reports.values.allSatisfy({ $0.effectiveEvidenceEligibility.eligible }) else {
            throw ResearchCLIError.decisionGradeEvidenceRequired
        }
        guard let baseline = reports[research.baselineArmID] else {
            throw ResearchCLIError.noComparableReports
        }
        try layout.prepare()
        var artifacts: [LabResearchComparisonArtifact] = []
        for arm in manifest.arms where arm.id != research.baselineArmID {
            guard let candidate = reports[arm.id] else { continue }
            let comparison = try LabPairedComparison.compare(
                baseline: baseline,
                candidate: candidate,
                phase: phase,
                primaryMetric: research.primaryMetric,
                promotionRule: research.promotionRule,
                utility: research.utility
            )
            let artifact = try LabResearchComparisonArtifact(
                campaignID: campaignID,
                baselineArmID: baseline.arm.id,
                candidateArmID: candidate.arm.id,
                comparison: comparison
            ).validated()
            let destination = layout.comparisonsDirectory
                .appendingPathComponent("\(candidate.arm.id.researchSlug).json")
            try LabResearchArtifactIO.save(artifact, to: destination)
            try await database.saveComparison(
                campaignID: campaignID,
                trialID: candidate.arm.id,
                report: comparison
            )
            artifacts.append(artifact)
        }
        guard !artifacts.isEmpty else { throw ResearchCLIError.noComparableReports }
        // Ranked on the registered primary metric, always oriented so a larger
        // mean is the better candidate. Rank alone never promotes; this only
        // decides which passing candidates `nominate --top` freezes first.
        return artifacts.sorted {
            let left = ($0.comparison.deltaPrimaryMetric ?? $0.comparison.deltaExpectedUtility).mean
            let right = ($1.comparison.deltaPrimaryMetric ?? $1.comparison.deltaExpectedUtility).mean
            if left == right { return $0.candidateArmID < $1.candidateArmID }
            return left > right
        }
    }

    static func loadComparisonArtifacts(
        layout: LabResearchArtifactLayout
    ) throws -> [LabResearchComparisonArtifact] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: layout.comparisonsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return try urls.filter { $0.pathExtension == "json" }.compactMap { url in
            let value = try LabResearchArtifactIO.load(
                LabResearchComparisonArtifact.self, from: url
            )
            return try value.validated()
        }
    }
}

private actor ResearchProgressPrinter {
    private var lastBucket = -1
    private var lastArm: String?

    func accept(_ update: LabRunProgress) {
        let bucket = update.total > 0 ? update.completed * 20 / update.total : 0
        guard bucket != lastBucket || update.armID != lastArm
                || update.phase != .running else { return }
        lastBucket = bucket
        lastArm = update.armID
        let arm = update.armID.map { " arm=\($0)" } ?? ""
        ResearchConsole.line(
            "\(update.phase.rawValue) \(update.completed)/\(update.total)\(arm)"
        )
    }
}

private extension Duration {
    var secondsValue: Double {
        Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
