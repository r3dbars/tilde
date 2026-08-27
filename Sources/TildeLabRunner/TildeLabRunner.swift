import Darwin
import Foundation
import TildeLabKit

@main
struct TildeLabRunner {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            if options.showsHelp {
                print(Options.usage)
                return
            }
            if options.printsLearningLedger {
                let snapshot = try LabLearningLedgerCatalog.loadBundled()
                if options.json {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    FileHandle.standardOutput.write(try encoder.encode(snapshot))
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print(LabLearningLedgerRenderer.humanSummary(snapshot))
                }
                return
            }
            if options.printsModelBenchmarkLeaderboard {
                let snapshot = try LabModelBenchmarkCatalog.loadBundled()
                print("Tilde Lab model benchmark history")
                print("  suite: \(snapshot.suiteName)")
                print("  policy: \(snapshot.comparisonPolicy)")
                for entry in snapshot.fullComparisons {
                    let first = entry.firstTokenP95Milliseconds.map { "\($0) ms" } ?? "n/a"
                    let total = entry.totalP95Milliseconds.map { "\($0) ms" } ?? "n/a"
                    let bad = (entry.badSuggestionRate * 100).formatted(.number.precision(.fractionLength(1)))
                    let saved = (entry.netKeystrokeSavingsRate * 100).formatted(.number.precision(.fractionLength(1)))
                    print("  \(entry.label): score \(entry.qualityScore); useful \(entry.useful); wrong \(entry.wrong); silent \(entry.silent); bad \(bad)%; net saved \(saved)%; first p95 \(first); total p95 \(total); protocol \(entry.comparisonGroupID)")
                }
                let ceilings = snapshot.entries.filter { $0.evaluations != 360 }
                if !ceilings.isEmpty {
                    print("  non-comparable ceilings:")
                    for entry in ceilings {
                        print("    \(entry.label): score \(entry.qualityScore) across \(entry.evaluations) cases")
                    }
                }
                if !snapshot.promotedConfigurations.isEmpty {
                    print("  promoted experimental configurations:")
                    for configuration in snapshot.promotedConfigurations {
                        print("    \(configuration.label): score \(configuration.qualityScore); useful \(configuration.useful); wrong \(configuration.wrong); silent \(configuration.silent); temperature \(configuration.temperature); tokens \(configuration.predictionTokens); visible words \(configuration.maximumVisibleWords); total p95 \(configuration.totalP95Milliseconds) ms")
                    }
                }
                return
            }
            if options.auditsPrivateHistory {
                let loaded = try LabHistoricalReplayLoader.load()
                let roots = Set(loaded.suite.scenarios.map {
                    $0.evaluation.rootScenarioID ?? $0.id
                }).count
                print("Private replay audit")
                print("  distinct situations: \(roots)")
                print("  accepted events: \(loaded.summary.acceptedCases)")
                print("  typed-instead events: \(loaded.summary.typedInsteadCases)")
                print("  situations with recorded screen context: \(loaded.summary.screenContextCases)")
                print("  replay checkpoints: \(loaded.suite.scenarios.count)")
                print("  protected validation/holdout eligible: 0 (temporal integrity is not yet proven)")
                print("  result: development signal only; no source text was printed or copied")
                return
            }
            let modelProfile = options.modelProfile
            if modelProfile.verificationMode == .experimentalLocal,
               options.certifiesCertifiedCorpus
                || (options.campaign != nil && options.campaign != .modelQuality50)
                || options.autoresearchHours != nil
                || options.speakAutoresearchHours != nil {
                throw NSError(
                    domain: "TildeLab",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Experimental models support fixed quality runs and the locked model-quality-50 campaign only. Production certification and adaptive campaigns remain pinned to E2B."]
                )
            }

            let runner = LabExperimentRunner()
            let signals = SignalController {
                LabChildProcessRegistry.shared.terminateAll()
                Darwin.exit(130)
            }
            signals.start()
            defer { LabChildProcessRegistry.shared.terminateAll() }

            let suite: LabScenarioSuite
            if let suitePath = options.suitePath {
                suite = try LabScenarioSuiteLoader.load(from: URL(fileURLWithPath: suitePath))
            } else if options.certifiedCorpus {
                suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
            } else if options.corpusPilot {
                suite = try LabCorpusPilotSuiteFactory.make().suite
            } else {
                suite = try LabScenarioSuiteLoader.builtIn(options.builtInSuite)
            }
            if options.validatesCorpusPilot {
                let roots = Set(suite.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id })
                let counts = Dictionary(grouping: suite.scenarios) {
                    $0.evaluation.corpusID ?? "unregistered"
                }.mapValues { scenarios in
                    Set(scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
                }
                let sources = counts.keys.sorted().map { "\($0)=\(counts[$0, default: 0])" }
                    .joined(separator: ", ")
                print("Corpus pilot ready: \(roots.count) distinct situations (\(sources)); development-only; no model run started.")
                return
            }
            if options.auditsCertifiedCorpus {
                let report = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite)
                printCorpusQuality(report)
                return
            }
            if options.printsCertifiedReviewSample {
                printCertifiedReviewSample(suite)
                return
            }
            let manifest = try options.manifestPath.map { path -> LabExperimentManifest in
                let decoded = try JSONDecoder().decode(
                    LabExperimentManifest.self,
                    from: Data(contentsOf: URL(fileURLWithPath: path))
                )
                return try decoded.validated()
            }
            var commandLineArm = LabArmConfiguration(
                id: options.armID,
                temperature: options.temperature,
                predictionTokens: options.predictionTokens,
                maxVisibleWords: options.maxVisibleWords,
                includesScene: options.includesScene,
                suppressesSensitiveScenes: options.suppressesSensitiveScenes
            )
            commandLineArm.scenarios.partition = options.corpusPilot
                ? .development
                : options.certifiedCorpus
                    ? .development
                : options.suitePath == nil
                    ? .development
                    : .all
            if options.productionFidelity {
                commandLineArm.generation.requestMode = .productionStreaming
                commandLineArm.prompt.includesIntentFutures = true
            }
            if options.modelQualitySmoke {
                commandLineArm.scenarios = LabScenarioVariationConfiguration(
                    partition: .development,
                    suggestionExpectation: .speakOnly,
                    maximumDistinctSituations: options.modelQualitySituationLimit
                )
                commandLineArm.scoring = LabScoringConfiguration(
                    policyVersion: LabScoringConfiguration.modelOutputQualityPolicy,
                    usefulnessWeight: 0.80,
                    restraintWeight: 0,
                    factualityWeight: 0.15,
                    brevityWeight: 0.05,
                    weightsLockedDuringComparison: true
                )
            }
            var arms = manifest?.arms
                ?? options.campaign.map(LabCampaignFactory.arms(for:))
                ?? [commandLineArm]
            let research = manifest?.research
                ?? options.campaign.map(LabCampaignFactory.researchProtocol(for:))
            if options.certifiedCorpus, options.campaign != nil {
                for index in arms.indices {
                    arms[index].scenarios.partition = .development
                }
            }
            let runtime = manifest?.runtime ?? LabRuntimeConfiguration(
                workerCount: options.workers,
                slotsPerWorker: options.slots,
                repetitions: options.repetitions,
                contextSizePerSlot: options.contextSize,
                cacheReuseTokens: options.cacheReuse,
                timeoutSeconds: options.timeout,
                seed: options.seed
            )
            if options.semanticQualityShootout {
                let execution = runtime.materialize(
                    serverExecutable: URL(fileURLWithPath: options.helperPath),
                    modelFile: URL(fileURLWithPath: options.modelPath),
                    modelProfile: modelProfile
                )
                let localCandidates = LabCandidateObservationStore()
                commandLineArm.id = "semantic-shootout-local-cap3"
                let localReport = try await runner.run(
                    suite: suite,
                    arm: commandLineArm,
                    execution: execution,
                    progress: { update in writeProgress(update) },
                    candidateObserved: { observation in
                        await localCandidates.record(observation)
                    }
                )

                let subscription = LabCodexSubscriptionClient(
                    codexExecutable: URL(fileURLWithPath: options.codexPath)
                )
                let frontierCandidates = LabCandidateObservationStore()
                var frontierArm = commandLineArm
                frontierArm.id = "semantic-shootout-frontier-cap3"
                let frontier = LabFrontierCeilingRunner(client: subscription)
                let frontierReport = try await frontier.run(
                    suite: suite,
                    arm: frontierArm,
                    configuration: LabFrontierCeilingConfiguration(
                        model: options.frontierModel,
                        batchSize: 25,
                        timeoutSecondsPerBatch: 300
                    ),
                    progress: { update in writeProgress(update) },
                    candidateObserved: { observation in
                        await frontierCandidates.record(observation)
                    }
                )
                let semantic = LabSemanticShootoutRunner(judge: subscription)
                let report = try await semantic.run(
                    suite: suite,
                    arm: commandLineArm,
                    localReport: localReport,
                    frontierReport: frontierReport,
                    localCandidates: await localCandidates.snapshot(),
                    frontierCandidates: await frontierCandidates.snapshot(),
                    judgeModel: options.frontierModel
                )
                printSemanticShootout(report)
                return
            }
            if options.frontierQualityCeiling {
                commandLineArm.id = "model-quality-frontier-sol-cap3"
                let frontier = LabFrontierCeilingRunner(client: LabCodexSubscriptionClient(
                    codexExecutable: URL(fileURLWithPath: options.codexPath)
                ))
                let report = try await frontier.run(
                    suite: suite,
                    arm: commandLineArm,
                    configuration: LabFrontierCeilingConfiguration(
                        model: options.frontierModel,
                        batchSize: 25,
                        timeoutSecondsPerBatch: 300
                    ),
                    progress: { update in writeProgress(update) }
                )
                if options.savesReport { try await LabReportStore().save(report) }
                if options.json {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.sortedKeys]
                    FileHandle.standardOutput.write(try encoder.encode(report))
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    printHumanSummary(report, saved: options.savesReport)
                }
                return
            }
            if options.certifiedCorpus,
               (options.campaign != nil && options.campaign != .modelQuality50)
                    || options.autoresearchHours != nil
                    || options.speakAutoresearchHours != nil {
                let quality = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite)
                guard let certificate = await LabCorpusCertificateStore().load(
                    corpusDigestSHA256: quality.corpusDigestSHA256
                ), certificate.passes else {
                    throw NSError(
                        domain: "TildeLab",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Certified Corpus V2 must pass its 3,000-case model certification before optimization."]
                    )
                }
                let verificationExecution = runtime.materialize(
                    serverExecutable: URL(fileURLWithPath: options.helperPath),
                    modelFile: URL(fileURLWithPath: options.modelPath),
                    modelProfile: modelProfile
                )
                let assets = try await LabAssetVerifier.shared.verify(verificationExecution)
                guard certificate.modelSHA256 == assets.modelSHA256,
                      certificate.helperSHA256 == assets.helperSHA256 else {
                    throw NSError(
                        domain: "TildeLab",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "The saved corpus certificate belongs to different model or helper bytes. Rerun certification first."]
                    )
                }
            }
            if options.certifiesCertifiedCorpus {
                var certificationRuntime = runtime
                certificationRuntime.repetitions = 1
                let execution = certificationRuntime.materialize(
                    serverExecutable: URL(fileURLWithPath: options.helperPath),
                    modelFile: URL(fileURLWithPath: options.modelPath),
                    modelProfile: .production
                )
                let certificate = try await LabCorpusModelCertifier.certify(
                    suite: suite,
                    baseline: commandLineArm,
                    execution: execution,
                    runner: runner,
                    progress: { update in writeProgress(update) }
                )
                try await LabCorpusCertificateStore().save(certificate)
                printCorpusCertificate(certificate)
                return
            }
            if let researchHours = options.autoresearchHours {
                try await runAutoresearch(
                    runner: runner,
                    suite: suite,
                    baseline: commandLineArm,
                    runtime: runtime,
                    helperPath: options.helperPath,
                    modelPath: options.modelPath,
                    seed: options.seed,
                    hours: researchHours,
                    focus: .broad
                )
                return
            }
            if let researchHours = options.speakAutoresearchHours {
                try await runAutoresearch(
                    runner: runner,
                    suite: suite,
                    baseline: commandLineArm,
                    runtime: runtime,
                    helperPath: options.helperPath,
                    modelPath: options.modelPath,
                    seed: options.seed,
                    hours: researchHours,
                    focus: .speakPolicy
                )
                return
            }
            let execution = runtime.materialize(
                serverExecutable: URL(fileURLWithPath: options.helperPath),
                modelFile: URL(fileURLWithPath: options.modelPath),
                modelProfile: modelProfile
            )
            let reportStore = LabReportStore()
            let savesReport = options.savesReport
            let reports = try await runner.runMatrix(
                suite: suite,
                arms: arms,
                execution: execution,
                research: research,
                progress: { update in writeProgress(update) },
                reportCompleted: { report in
                    if savesReport { try await reportStore.save(report) }
                }
            )
            if options.json {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.sortedKeys]
                if reports.count == 1 {
                    FileHandle.standardOutput.write(try encoder.encode(reports[0]))
                } else {
                    FileHandle.standardOutput.write(try encoder.encode(reports))
                }
                FileHandle.standardOutput.write(Data("\n".utf8))
            } else {
                for report in reports { printHumanSummary(report, saved: options.savesReport) }
            }
        } catch {
            writeError("tilde-lab-runner: \(error.localizedDescription)\n")
            Darwin.exit(1)
        }
    }

    private static func runAutoresearch(
        runner: LabExperimentRunner,
        suite: LabScenarioSuite,
        baseline: LabArmConfiguration,
        runtime: LabRuntimeConfiguration,
        helperPath: String,
        modelPath: String,
        seed: UInt64,
        hours: Int,
        focus: LabAutoresearchFocus
    ) async throws {
        var baseline = baseline
        switch focus {
        case .broad:
            baseline.id = "overnight-baseline"
        case .speakPolicy:
            baseline.id = "speak-policy-baseline"
        }
        baseline.scenarios.partition = .development
        baseline.generation.requestMode = .productionStreaming
        baseline.prompt.includesIntentFutures = true
        if focus == .speakPolicy {
            // Start from the repeatedly confirmed champion of the broad
            // campaign, then alter only evidence and display-policy controls.
            baseline.generation.preset = .custom
            baseline.generation.temperature = 0.40
            baseline.generation.topK = 80
            baseline.generation.typicalP = 0.50
            baseline.generation.frequencyPenalty = 0.10
            baseline.generation.predictionTokens = 8
            baseline.generation.probabilityCount = 5
            baseline.generation.minimumMeanTokenProbability = 0.20
            baseline.judgment.maximumVisibleWords = 3
        }
        let selectedSuite = LabScenarioSelector.select(from: suite, configuration: baseline.scenarios)
        let digest = try selectedSuite.digestSHA256()
        let mutations = focus.mutations
        let subsystem: LabResearchSubsystem
        let experimentClass: LabExperimentClass
        switch focus {
        case .broad:
            subsystem = .generation
            experimentClass = .generator
        case .speakPolicy:
            subsystem = .display
            experimentClass = .displayPolicy
        }
        let configuration = LabAutoresearchConfiguration(
            screeningRepetitions: focus.screeningRepetitions,
            confirmationRepetitions: focus.confirmationRepetitions,
            maximumTrials: mutations.count,
            survivorCount: 3,
            controlInterval: 4,
            protocolRetryCount: 2,
            minimumBehavioralImprovement: 0.0025,
            randomizesTrialOrder: focus != .speakPolicy,
            restartsWorkersBetweenRounds: false,
            timeBudgetMinutes: hours * 60,
            subsystem: subsystem
        )
        var campaign = LabResearchCampaign(
            name: focus.campaignName(hours: hours),
            suiteDigestSHA256: digest,
            baselineArm: baseline,
            configuration: configuration,
            state: .running
        )
        let reportStore = LabReportStore()
        let campaignStore = LabResearchCampaignStore()
        try await campaignStore.save(campaign)

        var runtime = runtime
        runtime.workerCount = 1
        runtime.slotsPerWorker = 8
        let helper = URL(fileURLWithPath: helperPath)
        let model = URL(fileURLWithPath: modelPath)

        func runArm(
            _ arm: LabArmConfiguration,
            repetitions: Int,
            restartWorkers: Bool
        ) async throws -> LabRunReport {
            var trialRuntime = runtime
            trialRuntime.repetitions = repetitions
            let execution = trialRuntime.materialize(serverExecutable: helper, modelFile: model)
            let protocolDefinition = LabResearchProtocol(
                phase: .discovery,
                experimentClass: experimentClass,
                searchStrategy: .fixed,
                baselineArmID: arm.id,
                fixedGenerationSeeds: [arm.generation.seed]
            )
            return try await runner.run(
                suite: suite,
                arm: arm,
                execution: execution,
                research: protocolDefinition,
                protocolRetryCount: configuration.protocolRetryCount,
                restartWorkers: restartWorkers,
                stopWorkersAfterRun: restartWorkers,
                progress: { update in writeProgress(update) },
                reportCompleted: { report in try await reportStore.save(report) }
            )
        }

        func checkpoint(_ value: LabResearchCampaign) async throws {
            try await campaignStore.save(value)
        }

        writeError("tilde-lab-runner: autoresearch focus=\(focus.rawValue) campaign=\(campaign.id.uuidString) suite=development cases=\(selectedSuite.scenarios.count) mutations=\(mutations.count) budget=\(hours)h\n")
        var championReport = try await runArm(
            baseline,
            repetitions: configuration.screeningRepetitions,
            restartWorkers: false
        )
        campaign.ledger.append(LabResearchLedgerEntry(
            trial: 0,
            parentArmID: nil,
            armID: baseline.id,
            mutation: nil,
            reportID: championReport.id,
            decision: .baseline,
            verdict: championReport.verdict
        ))
        campaign.updatedAt = Date()
        try await checkpoint(campaign)
        printResearchCheckpoint(campaign.ledger.last!, report: championReport)

        // Reserve time for a larger final confirmation and clean shutdown.
        let confirmationReserveMinutes = focus.confirmationReserveMinutes
        let screeningDeadline = campaign.createdAt.addingTimeInterval(
            TimeInterval(max(10, hours * 60 - confirmationReserveMinutes) * 60)
        )
        var latestControlP95 = championReport.metrics.latency.p95Milliseconds
        let pendingMutations = LabAutoresearchPlanner.pendingMutations(
            for: campaign,
            seed: seed,
            candidates: mutations
        )
        for mutation in pendingMutations {
            try Task.checkCancellation()
            guard Date() < screeningDeadline else { break }
            let trial = campaign.ledger.filter { $0.mutation != nil }.count + 1

            if trial > 1, (trial - 1).isMultiple(of: configuration.controlInterval) {
                var controlArm = campaign.championArm
                controlArm.id = "\(focus.armPrefix)-control-\(trial)"
                let control = try await runArm(
                    controlArm,
                    repetitions: configuration.screeningRepetitions,
                    restartWorkers: false
                )
                latestControlP95 = control.metrics.latency.p95Milliseconds
                campaign.ledger.append(LabResearchLedgerEntry(
                    trial: trial,
                    parentArmID: campaign.championArm.id,
                    armID: control.arm.id,
                    mutation: nil,
                    reportID: control.id,
                    decision: .control,
                    verdict: control.verdict
                ))
                campaign.updatedAt = Date()
                try await checkpoint(campaign)
                printResearchCheckpoint(campaign.ledger.last!, report: control)
                guard Date() < screeningDeadline else { break }
            }

            let parentArmID = campaign.championArm.id
            let candidateArm = mutation.applying(to: campaign.championArm, trial: trial)
            let candidate = try await runArm(
                candidateArm,
                repetitions: configuration.screeningRepetitions,
                restartWorkers: false
            )
            let decision = LabAutoresearchPlanner.decision(
                candidate: candidate,
                champion: championReport,
                controlP95Milliseconds: latestControlP95,
                minimumImprovement: configuration.minimumBehavioralImprovement
            )
            if decision == .keep {
                campaign.championArm = candidateArm
                championReport = candidate
            }
            let normalizedP95 = candidate.metrics.latency.p95Milliseconds.flatMap { p95 in
                latestControlP95.map { Double(p95) / Double(max(1, $0)) }
            }
            campaign.ledger.append(LabResearchLedgerEntry(
                trial: trial,
                parentArmID: parentArmID,
                armID: candidate.arm.id,
                mutation: mutation,
                reportID: candidate.id,
                decision: decision,
                verdict: candidate.verdict,
                normalizedP95Milliseconds: normalizedP95
            ))
            campaign.updatedAt = Date()
            try await checkpoint(campaign)
            printResearchCheckpoint(campaign.ledger.last!, report: candidate)
        }

        var stabilityRound = 1
        while Date() < screeningDeadline {
            try Task.checkCancellation()
            var stabilityArm = campaign.championArm
            stabilityArm.id = "\(focus.armPrefix)-stability-\(stabilityRound)"
            let stability = try await runArm(
                stabilityArm,
                repetitions: configuration.screeningRepetitions,
                restartWorkers: false
            )
            campaign.ledger.append(LabResearchLedgerEntry(
                trial: campaign.ledger.count,
                parentArmID: campaign.championArm.id,
                armID: stability.arm.id,
                mutation: nil,
                reportID: stability.id,
                decision: .control,
                verdict: stability.verdict
            ))
            campaign.updatedAt = Date()
            try await checkpoint(campaign)
            printResearchCheckpoint(campaign.ledger.last!, report: stability)
            stabilityRound += 1
        }

        var confirmationArm = campaign.championArm
        confirmationArm.id = "\(focus.armPrefix)-confirmation"
        let confirmation = try await runArm(
            confirmationArm,
            repetitions: configuration.confirmationRepetitions,
            restartWorkers: true
        )
        campaign.ledger.append(LabResearchLedgerEntry(
            trial: campaign.ledger.count,
            parentArmID: campaign.championArm.id,
            armID: confirmation.arm.id,
            mutation: nil,
            reportID: confirmation.id,
            decision: .confirmation,
            verdict: confirmation.verdict
        ))
        campaign.updatedAt = Date()
        try await checkpoint(campaign)
        printResearchCheckpoint(campaign.ledger.last!, report: confirmation)

        campaign.state = .completed
        campaign.updatedAt = Date()
        try await checkpoint(campaign)
        writeError("tilde-lab-runner: autoresearch complete campaign=\(campaign.id.uuidString)\n")
    }

    private static func printResearchCheckpoint(
        _ entry: LabResearchLedgerEntry,
        report: LabRunReport
    ) {
        let p95 = report.metrics.latency.p95Milliseconds.map(String.init) ?? "none"
        print("research\t\(entry.trial)\t\(entry.decision.rawValue)\t\(entry.verdict.rawValue)\t\(entry.armID)\tnks=\(percent(report.metrics.netKeystrokeSavingsRate))\tbad=\(percent(report.metrics.badSuggestionRate))\tacceptable=\(percent(report.metrics.usefulnessRate))\tp95=\(p95)")
        fflush(stdout)
    }

    private static func printHumanSummary(_ report: LabRunReport, saved: Bool) {
        print("Tilde Lab Reply Bench")
        print("  result: \(report.verdict.title)")
        print("  summary: \(report.plainEnglishOutcome)")
        print("  model: \(report.assets.modelIdentifier) (\(report.assets.inferenceBackend.title))")
        print("  evaluations: \(report.metrics.totalCases)")
        if report.arm.scoring.usesModelOutputQuality {
            print("  output quality: \(report.metrics.qualityScore.map { "\($0)/100" } ?? "incomplete")")
        } else {
            print("  net keystroke savings: \(percent(report.metrics.netKeystrokeSavingsRate))")
            print("  net saved per 1,000 characters: \(format(report.metrics.netKeystrokesSavedPer1000Characters))")
            print("  diagnostic quality score: \(report.metrics.qualityScore.map(String.init) ?? "incomplete")")
            print("  legacy reply score: \(report.metrics.replyScore.map(String.init) ?? "incomplete")")
        }
        print("  human acceptable: \(percent(report.metrics.usefulnessRate))")
        print("  exact continuation path: \(percent(report.metrics.exactPredictionRate))")
        print("  accepted alternative: \(percent(report.metrics.acceptableAlternativeRate))")
        print("  factual: \(percent(report.metrics.factualityRate))")
        print("  within visible cap: \(percent(report.metrics.brevityRate))")
        if !report.arm.scoring.usesModelOutputQuality {
            print("  ordinary quiet: \(report.metrics.ordinaryRestraintRate.map(percent) ?? "not measured")")
            print("  sensitive quiet: \(report.metrics.sensitiveRestraintRate.map(percent) ?? "not measured")")
            print("  counterfactual pairs: \(report.metrics.counterfactualPairPassRate.map(percent) ?? "not measured")")
        }
        if let eligible = report.metrics.promotionEligible {
            print("  promotion: \(eligible ? "eligible" : "blocked")")
            if !report.metrics.promotionGateFailures.isEmpty {
                print("  failed gates: \(report.metrics.promotionGateFailures.joined(separator: ", "))")
            }
        }
        print("  exact@1: \(percent(report.metrics.exactMatchAt1Rate))")
        let diagnostic = report.arm.scoring.usesModelOutputQuality ? " (diagnostic only)" : ""
        print("  throughput: \(format(report.metrics.throughputModelRequestsPerSecond)) model requests/s\(diagnostic)")
        print("  p95: \(report.metrics.latency.p95Milliseconds.map { "\($0) ms" } ?? "none")\(diagnostic)")
        print("  errors: \(report.metrics.errors); timeouts: \(report.metrics.timeouts)")
        let evidence = report.effectiveEvidenceEligibility
        print("  research evidence: \(evidence.eligible ? "decision-grade" : "not decision-grade")")
        if !evidence.reasons.isEmpty {
            print("  evidence blockers: \(evidence.reasons.map(\.rawValue).joined(separator: ", "))")
        }
        if saved { print("  aggregate report saved: \(report.id.uuidString)") }
    }

    private static func printSemanticShootout(_ report: LabSemanticShootoutReport) {
        print("Tilde Lab Semantic Shootout")
        print("  referee: \(report.judgeModel), blinded A/B")
        print("  situations: \(report.scenarioCount)")
        for model in [report.first, report.second] {
            print("  \(model.modelIdentifier)")
            print("    semantic overall: \(model.semanticOverallScore)/100")
            print("    semantically useful: \(percent(model.semanticUsefulRate))")
            print("    intent: \(model.intentScore)/100")
            print("    usefulness: \(model.usefulnessScore)/100")
            print("    naturalness: \(model.naturalnessScore)/100")
            print("    factuality: \(model.factualityScore)/100")
            print("    strict path score: \(model.strictQualityScore)/100")
            print("    strict accepted: \(percent(model.strictAcceptableRate))")
        }
        print("  privacy: synthetic prompts only; raw prompts, candidates, and judgments were not persisted")
    }

    private static func printCorpusQuality(_ report: LabCorpusQualityReport) {
        print("Tilde Certified Corpus V2")
        print("  static verdict: \(report.verdict.rawValue)")
        print("  digest: \(report.corpusDigestSHA256)")
        print("  situations: \(report.rootCount)")
        print("  speak / silence: \(report.positiveCount) / \(report.silenceCount)")
        print("  families / apps: \(report.categoryFamilyCount) / \(report.applicationCount)")
        print("  development / validation / holdout: \(report.developmentCount) / \(report.validationCount) / \(report.holdoutCount)")
        for check in report.checks {
            print("  \(check.status.rawValue): \(check.title) — \(check.detail)")
        }
    }

    private static func printCorpusCertificate(_ certificate: LabCorpusModelCertificate) {
        print("Tilde Certified Corpus V2 model certificate")
        print("  result: \(certificate.passes ? "PASS" : "FAIL")")
        print("  corpus digest: \(certificate.corpusDigestSHA256)")
        print("  correct context exact@1: \(percent(certificate.correctContext.exactMatchAt1Rate))")
        print("  wrong context exact@1: \(percent(certificate.wrongContext.exactMatchAt1Rate))")
        print("  typed only exact@1: \(percent(certificate.typedOnly.exactMatchAt1Rate))")
        print("  correct context human acceptable: \(percent(certificate.correctContext.usefulnessRate))")
        print("  wrong context human acceptable: \(percent(certificate.wrongContext.usefulnessRate))")
        print("  typed only human acceptable: \(percent(certificate.typedOnly.usefulnessRate))")
        print("  correct context NKS: \(percent(certificate.correctContext.netKeystrokeSavingsRate))")
        print("  wrong context NKS: \(percent(certificate.wrongContext.netKeystrokeSavingsRate))")
        print("  typed only NKS: \(percent(certificate.typedOnly.netKeystrokeSavingsRate))")
        for partition in certificate.partitions {
            print("  \(partition.partition.rawValue): correct \(percent(partition.correctExactMatchAt1Rate)) · wrong \(percent(partition.wrongContextExactMatchAt1Rate)) · typed \(percent(partition.typedOnlyExactMatchAt1Rate))")
        }
        if !certificate.failures.isEmpty {
            print("  failures: \(certificate.failures.joined(separator: ", "))")
        }
    }

    private static func printCertifiedReviewSample(_ suite: LabScenarioSuite) {
        let ids = Set(LabCorpusQualityAuditor.reviewSampleRootIDs(suite: suite))
        let scenarios = suite.scenarios.filter {
            ids.contains($0.evaluation.rootScenarioID ?? $0.id)
        }.sorted { $0.id < $1.id }
        print("Tilde Certified Corpus V2 review sample")
        print("sample-digest: \(LabCorpusQualityAuditor.reviewSampleDigest(suite: suite))")
        for scenario in scenarios {
            print("CASE \(scenario.id) [\(scenario.partition.rawValue)] [\(scenario.category)]")
            print("INTENT: \(scenario.intent?.rawValue ?? "none") · TONE: \(scenario.tone?.rawValue ?? "none")")
            for turn in scenario.scene?.turns ?? [] {
                print("\(turn.speaker == .selfSpeaker ? "SELF" : "OTHER"): \(turn.text)")
            }
            print("TYPED: \(scenario.typedContext)")
            print("EXPECTED: \(scenario.expectation.shouldSuggest ? scenario.expectation.goldenContinuation ?? "suggest" : "SILENCE")")
            if scenario.expectation.shouldSuggest {
                for alternative in scenario.expectation.acceptableContinuations {
                    print("ALSO ACCEPT: \(alternative)")
                }
                print("REQUIRED FACTS: \(scenario.expectation.requiredTerms.joined(separator: ", "))")
                print("FORBIDDEN FACTS: \(scenario.expectation.forbiddenTerms.joined(separator: ", "))")
            }
            print("")
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func writeProgress(_ progress: LabRunProgress) {
        let suffix = progress.total > 0 ? " \(progress.completed)/\(progress.total)" : ""
        let arm = progress.armID.map { " arm=\($0)" } ?? ""
        writeError("tilde-lab-runner: \(progress.phase.rawValue)\(suffix)\(arm)\n")
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}

private enum LabAutoresearchFocus: String {
    case broad
    case speakPolicy = "speak-policy"

    var mutations: [LabResearchMutation] {
        switch self {
        case .broad: LabResearchMutation.allCases
        case .speakPolicy: LabResearchMutation.speakPolicyCases
        }
    }

    var armPrefix: String {
        switch self {
        case .broad: "overnight"
        case .speakPolicy: "speak"
        }
    }

    var screeningRepetitions: Int {
        switch self {
        case .broad: 20
        case .speakPolicy: 6
        }
    }

    var confirmationRepetitions: Int {
        switch self {
        case .broad: 100
        case .speakPolicy: 20
        }
    }

    var confirmationReserveMinutes: Int {
        switch self {
        case .broad: 30
        case .speakPolicy: 10
        }
    }

    func campaignName(hours: Int) -> String {
        switch self {
        case .broad: "\(hours)-hour overnight autoresearch"
        case .speakPolicy: "\(hours)-hour speak-or-silence autoresearch"
        }
    }
}

private struct Options {
    var suitePath: String?
    var builtInSuite = LabBuiltInSuite.replyingV2
    var corpusPilot = false
    var certifiedCorpus = false
    var validatesCorpusPilot = false
    var auditsCertifiedCorpus = false
    var printsCertifiedReviewSample = false
    var certifiesCertifiedCorpus = false
    var auditsPrivateHistory = false
    var printsModelBenchmarkLeaderboard = false
    var printsLearningLedger = false
    var manifestPath: String?
    var campaign: LabBuiltInCampaign?
    var helperPath = "/Applications/Tilde.app/Contents/Helpers/llama-server"
    var modelPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Tilde/Models")
        .appendingPathComponent("gemma-4-e2b-q4km/model.gguf")
        .path
    var modelVerificationMode = LabModelVerificationMode.productionPinned
    var modelIdentifier = "ggml-org/gemma-4-26B-A4B-GGUF"
    var modelRevision = "0b1367270501454da6df6c53fe46e90de8a1146e"
    var codexPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin/codex")
        .path
    var frontierModel = "gpt-5.6-sol"
    var armID = "baseline-v2"
    var workers = 2
    var slots = 4
    var repetitions = 10
    var contextSize = 4_096
    var cacheReuse = 256
    var timeout = 30.0
    var temperature = 0.0
    var predictionTokens = 20
    var maxVisibleWords = 8
    var seed: UInt64 = 0x5449_4C44_454C_4142
    var includesScene = true
    var suppressesSensitiveScenes = true
    var productionFidelity = false
    var modelQualitySmoke = false
    var modelQualitySituationLimit = 50
    var frontierQualityCeiling = false
    var semanticQualityShootout = false
    var savesReport = true
    var json = false
    var showsHelp = false
    var autoresearchHours: Int?
    var speakAutoresearchHours: Int?

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            func nextValue() throws -> String {
                guard index + 1 < arguments.count else { throw OptionsError.missingValue(argument) }
                index += 1
                return arguments[index]
            }
            switch argument {
            case "--suite": suitePath = try nextValue().expandingTilde
            case "--corpus-pilot": corpusPilot = true
            case "--certified-corpus": certifiedCorpus = true
            case "--validate-corpus-pilot":
                corpusPilot = true
                validatesCorpusPilot = true
            case "--audit-certified-corpus":
                certifiedCorpus = true
                auditsCertifiedCorpus = true
            case "--print-certified-review-sample":
                certifiedCorpus = true
                printsCertifiedReviewSample = true
            case "--certify-corpus":
                certifiedCorpus = true
                certifiesCertifiedCorpus = true
            case "--audit-private-history": auditsPrivateHistory = true
            case "--model-benchmark-leaderboard": printsModelBenchmarkLeaderboard = true
            case "--learning-ledger": printsLearningLedger = true
            case "--built-in-suite":
                guard let value = LabBuiltInSuite(rawValue: try nextValue()) else {
                    throw OptionsError.invalidValue(argument)
                }
                builtInSuite = value
            case "--manifest": manifestPath = try nextValue().expandingTilde
            case "--campaign":
                guard let value = LabBuiltInCampaign(rawValue: try nextValue()) else {
                    throw OptionsError.invalidValue(argument)
                }
                campaign = value
            case "--helper": helperPath = try nextValue().expandingTilde
            case "--model": modelPath = try nextValue().expandingTilde
            case "--experimental-model": modelVerificationMode = .experimentalLocal
            case "--model-id": modelIdentifier = try nextValue()
            case "--model-revision": modelRevision = try nextValue()
            case "--codex": codexPath = try nextValue().expandingTilde
            case "--frontier-model": frontierModel = try nextValue()
            case "--arm": armID = try nextValue()
            case "--workers": workers = try Self.integer(nextValue(), label: argument)
            case "--slots": slots = try Self.integer(nextValue(), label: argument)
            case "--repetitions": repetitions = try Self.integer(nextValue(), label: argument)
            case "--context-size": contextSize = try Self.integer(nextValue(), label: argument)
            case "--cache-reuse": cacheReuse = try Self.integer(nextValue(), label: argument)
            case "--timeout": timeout = try Self.double(nextValue(), label: argument)
            case "--temperature": temperature = try Self.double(nextValue(), label: argument)
            case "--prediction-tokens": predictionTokens = try Self.integer(nextValue(), label: argument)
            case "--max-visible-words": maxVisibleWords = try Self.integer(nextValue(), label: argument)
            case "--seed":
                guard let value = UInt64(try nextValue()) else { throw OptionsError.invalidValue(argument) }
                seed = value
            case "--no-scene": includesScene = false
            case "--no-sensitive-suppression": suppressesSensitiveScenes = false
            case "--production-fidelity": productionFidelity = true
            case "--model-quality-smoke":
                certifiedCorpus = true
                productionFidelity = true
                modelQualitySmoke = true
                workers = 1
                slots = 1
                repetitions = 1
                timeout = 120
                temperature = 0
                predictionTokens = 20
                maxVisibleWords = 3
            case "--model-quality-full":
                certifiedCorpus = true
                productionFidelity = true
                modelQualitySmoke = true
                modelQualitySituationLimit = 360
                workers = 1
                slots = 1
                repetitions = 1
                timeout = 120
                temperature = 0
                predictionTokens = 20
                maxVisibleWords = 3
            case "--frontier-quality-ceiling":
                certifiedCorpus = true
                productionFidelity = true
                modelQualitySmoke = true
                frontierQualityCeiling = true
                workers = 1
                slots = 1
                repetitions = 1
                timeout = 120
                temperature = 0
                predictionTokens = 20
                maxVisibleWords = 3
            case "--semantic-quality-shootout":
                certifiedCorpus = true
                productionFidelity = true
                modelQualitySmoke = true
                semanticQualityShootout = true
                workers = 1
                slots = 1
                repetitions = 1
                timeout = 120
                temperature = 0
                predictionTokens = 20
                maxVisibleWords = 3
            case "--no-save": savesReport = false
            case "--json": json = true
            case "--autoresearch-six-hours": autoresearchHours = 6
            case "--autoresearch-hours":
                let hours = try Self.integer(nextValue(), label: argument)
                guard (1...24).contains(hours) else { throw OptionsError.invalidValue(argument) }
                autoresearchHours = hours
            case "--autoresearch-speak-hours":
                let hours = try Self.integer(nextValue(), label: argument)
                guard (1...24).contains(hours) else { throw OptionsError.invalidValue(argument) }
                speakAutoresearchHours = hours
            case "--learning-loop-hours":
                throw OptionsError.retiredLearningLoop
            case "-h", "--help": showsHelp = true
            default: throw OptionsError.unknownArgument(argument)
            }
            index += 1
        }
        if manifestPath != nil, campaign != nil { throw OptionsError.conflictingInputs }
        if modelQualitySmoke, manifestPath != nil || campaign != nil {
            throw OptionsError.conflictingInputs
        }
        if corpusPilot, suitePath != nil { throw OptionsError.conflictingInputs }
        if certifiedCorpus, suitePath != nil || corpusPilot { throw OptionsError.conflictingInputs }
        if auditsPrivateHistory,
           suitePath != nil || corpusPilot || certifiedCorpus || manifestPath != nil || campaign != nil {
            throw OptionsError.conflictingInputs
        }
        let adaptiveModes = [autoresearchHours, speakAutoresearchHours]
            .compactMap { $0 }
        if adaptiveModes.count > 1 {
            throw OptionsError.conflictingInputs
        }
        if !adaptiveModes.isEmpty,
           manifestPath != nil || campaign != nil {
            throw OptionsError.conflictingInputs
        }
    }

    var modelProfile: LabModelProfile {
        switch modelVerificationMode {
        case .productionPinned:
            .production
        case .experimentalLocal:
            .experimental(identifier: modelIdentifier, revision: modelRevision)
        }
    }

    private static func integer(_ value: String, label: String) throws -> Int {
        guard let result = Int(value) else { throw OptionsError.invalidValue(label) }
        return result
    }

    private static func double(_ value: String, label: String) throws -> Double {
        guard let result = Double(value) else { throw OptionsError.invalidValue(label) }
        return result
    }

    static let usage = """
    Usage: tilde-lab-runner [options]

      --suite PATH                 JSON scenario suite
      --corpus-pilot               run the local 1,000-situation development pilot
      --certified-corpus           run the locked 1,000-situation Corpus V2
      --validate-corpus-pilot      verify its source and counts without loading the model
      --audit-certified-corpus     run static Corpus V2 trust gates without the model
      --print-certified-review-sample
                                   print its deterministic 100-case review sample
      --certify-corpus             run and save correct/wrong/no-context model controls
      --audit-private-history      report aggregate-only local replay suitability
      --model-benchmark-leaderboard
                                   print the checked-in aggregate model leaderboard
      --learning-ledger            print the checked-in findings, limitations,
                                   promotion path, and prioritized research queue
      --built-in-suite NAME        slack-reply-gold-v1, replying-v2 (default), or replying-v1
      --manifest PATH              full exported experiment manifest; runs every arm
      --campaign NAME              built-in campaign recipe (quick-8, broad-50,
                                   model-quality-50, or deep-128)
      --autoresearch-six-hours     adaptive six-hour keep/discard campaign
      --autoresearch-hours N       adaptive keep/discard campaign, 1...24 hours
      --autoresearch-speak-hours N optimize when to show a suggestion, 1...24 hours
      --helper PATH                llama-server executable
      --model PATH                 local GGUF path (production pin by default)
      --experimental-model        explicitly allow a Lab-only alternate GGUF
      --model-id ID               report identity for an experimental model
      --model-revision REV        report revision for an experimental model
      --model-quality-smoke       50 speak-only development cases, 3-word cap,
                                  greedy production prompt, quality-first score
      --model-quality-full        all 360 speak-only development cases with the
                                  identical locked quality settings
      --frontier-quality-ceiling  run that same slice through your ChatGPT Codex
                                  subscription using GPT-5.6 Sol
      --semantic-quality-shootout run local E2B and GPT-5.6 Sol on the same
                                  50 cases, then score both with a blinded referee
      --codex PATH                Codex CLI path for the frontier ceiling
      --frontier-model MODEL      Codex subscription model (default: gpt-5.6-sol)
      --arm ID                     stable experiment arm ID
      --workers N                  server worker processes, 1...60 (default: 2)
      --slots N                    parallel slots per worker, 1...16 (default: 4)
      --repetitions N              suite repetitions, 1...1000 (default: 10)
      --context-size N             context tokens per slot (default: 4096)
      --cache-reuse N              prompt cache reuse tokens (default: 256)
      --timeout SECONDS            per-request timeout (default: 30)
      --temperature N              generation temperature, 0...2 (default: 0)
      --prediction-tokens N        generation token budget (default: 20)
      --max-visible-words N        production cleaner word cap (default: 8)
      --seed N                     deterministic work-order seed
      --no-scene                   omit scene context for this arm
      --no-sensitive-suppression   disable the production sensitive-scene gate
      --production-fidelity       use Tilde's streaming request and non-chat intent hints
      --no-save                    do not persist the aggregate report
      --json                       emit the aggregate-only report JSON
      -h, --help                   show this help
    """
}

private enum OptionsError: Error, LocalizedError {
    case missingValue(String)
    case invalidValue(String)
    case unknownArgument(String)
    case conflictingInputs
    case retiredLearningLoop

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag): "Missing value for \(flag)."
        case let .invalidValue(flag): "Invalid value for \(flag)."
        case let .unknownArgument(flag): "Unknown argument \(flag)."
        case .conflictingInputs: "Choose either --manifest or --campaign, not both."
        case .retiredLearningLoop:
            "--learning-loop-hours was retired because it automatically opened protected partitions. Use tilde-lab nominate, validate-candidates, and holdout with frozen plans."
        }
    }
}

private extension String {
    var expandingTilde: String { (self as NSString).expandingTildeInPath }
}

private final class SignalController: @unchecked Sendable {
    private let handler: @Sendable () -> Void
    private var sources: [DispatchSourceSignal] = []

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func start() {
        for signalNumber in [SIGINT, SIGTERM] {
            Darwin.signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler(handler: handler)
            source.resume()
            sources.append(source)
        }
    }
}
