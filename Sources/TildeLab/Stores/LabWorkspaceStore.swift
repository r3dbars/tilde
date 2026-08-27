import AppKit
import Foundation
import Observation
import TildeLabKit

@MainActor
@Observable
final class LabWorkspaceStore {
    var selection: LabSidebarSelection = .bench(.reply)
    var suite: LabScenarioSuite?
    var reports: [LabRunReport] = []
    var campaigns: [LabResearchCampaign] = []
    var learningLedgerSnapshot: LabLearningLedgerSnapshot?
    var modelBenchmarkSnapshot: LabModelBenchmarkSnapshot?
    var researchConfiguration = LabAutoresearchConfiguration(subsystem: .display)
    var manifest = LabExperimentManifest()
    var selectedArmIndex = 0
    var pinnedBaselineRunID: UUID?
    var benchAudits: [LabBenchKind: LabBenchAuditReport] = [:]
    var powerPreflight = LabPowerPreflight.inspect()
    var historicalReplaySummary: LabHistoricalReplaySummary?
    var corpusQualityReport: LabCorpusQualityReport?
    var corpusModelCertificate: LabCorpusModelCertificate?

    var serverPath = "/Applications/Tilde.app/Contents/Helpers/llama-server"
    var modelVerificationMode = LabModelVerificationMode.productionPinned
    var productionModelPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Tilde/Models")
        .appendingPathComponent("gemma-4-e2b-q4km/model.gguf")
        .path
    var experimentalModelPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Tilde Lab/Models")
        .appendingPathComponent("gemma-4-26b-a4b-base-q8_0.gguf")
        .path
    var experimentalModelIdentifier = "ggml-org/gemma-4-26B-A4B-GGUF"
    var experimentalModelRevision = "0b1367270501454da6df6c53fe46e90de8a1146e"
    var codexPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin/codex")
        .path
    var frontierModel = "gpt-5.6-sol"

    var modelPath: String {
        get {
            modelVerificationMode == .productionPinned
                ? productionModelPath
                : experimentalModelPath
        }
        set {
            if modelVerificationMode == .productionPinned {
                productionModelPath = newValue
            } else {
                experimentalModelPath = newValue
            }
        }
    }

    var modelProfile: LabModelProfile {
        switch modelVerificationMode {
        case .productionPinned:
            .production
        case .experimentalLocal:
            .experimental(
                identifier: experimentalModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                revision: experimentalModelRevision.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    var selectedModelIsInstalled: Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    var isRunning = false
    var isResearchRun = false
    var isLoadingSuite = false
    var progress = LabRunProgress(phase: .validating)
    var errorMessage: String?

    private let runner = LabExperimentRunner()
    private let reportStore = LabReportStore()
    private let campaignStore = LabResearchCampaignStore()
    private let corpusCertificateStore = LabCorpusCertificateStore()
    private var runTask: Task<Void, Never>?
    private var activeFrontierRunner: LabFrontierCeilingRunner?

    init() {
        loadCertifiedCorpus()
        learningLedgerSnapshot = try? LabLearningLedgerCatalog.loadBundled()
        modelBenchmarkSnapshot = try? LabModelBenchmarkCatalog.loadBundled()
        Task { [weak self] in
            guard let self else { return }
            async let loadedReports = reportStore.loadAll()
            async let loadedCampaigns = campaignStore.loadAll()
            reports = await loadedReports
            campaigns = await loadedCampaigns
        }
    }

    var selectedArm: LabArmConfiguration {
        get {
            guard manifest.arms.indices.contains(selectedArmIndex) else {
                return manifest.arms.first ?? LabArmConfiguration()
            }
            return manifest.arms[selectedArmIndex]
        }
        set {
            guard manifest.arms.indices.contains(selectedArmIndex) else { return }
            manifest.arms[selectedArmIndex] = newValue
        }
    }

    var plannedEvaluations: Int {
        guard let suite else { return 0 }
        return manifest.arms.reduce(0) { count, arm in
            let selected = LabScenarioSelector.select(from: suite, configuration: arm.scenarios)
            return count + selected.scenarios.count * manifest.runtime.repetitions
        }
    }

    var selectedArmEvaluations: Int {
        guard let suite else { return 0 }
        return LabScenarioSelector.select(from: suite, configuration: selectedArm.scenarios)
            .scenarios.count * manifest.runtime.repetitions
    }

    var selectedDistinctRootCount: Int {
        guard let suite else { return 0 }
        let selected = LabScenarioSelector.select(from: suite, configuration: selectedArm.scenarios)
        return Set(selected.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
    }

    var effectiveConcurrency: Int { manifest.runtime.concurrency }

    var canStart: Bool {
        suite != nil
            && !isRunning
            && !isLoadingSuite
            && !manifest.arms.isEmpty
            && plannedEvaluations > 0
            && selectedModelIsInstalled
            && FileManager.default.isExecutableFile(atPath: serverPath)
            && (try? modelProfile.validated()) != nil
    }

    var selectedReport: LabRunReport? {
        guard case let .run(id) = selection else { return nil }
        return reports.first { $0.id == id }
    }

    var activeCampaign: LabResearchCampaign? { campaigns.first }

    var researchChampion: LabRunReport? {
        guard let id = activeCampaign?.championReportID else { return nil }
        return reports.first { $0.id == id }
    }

    var pressureWarning: String? { draftExecutionConfiguration.pressureWarning }

    var isCertifiedCorpusLoaded: Bool { corpusQualityReport != nil }

    var canStartCorpusCertification: Bool {
        modelVerificationMode == .productionPinned
            && corpusQualityReport?.passesStaticGate == true
            && !isRunning
            && !isLoadingSuite
    }

    var canStartQuickCertifiedExperiment: Bool {
        modelVerificationMode == .productionPinned
            && isCertifiedCorpusLoaded
            && corpusModelCertificate?.passes == true
            && !isRunning
            && !isLoadingSuite
    }

    var canStartFrontierQualityCeiling: Bool {
        isCertifiedCorpusLoaded
            && !isRunning
            && !isLoadingSuite
            && FileManager.default.isExecutableFile(atPath: codexPath)
    }

    var independentModelFootprint: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: draftExecutionConfiguration.independentModelFootprintBytes),
            countStyle: .memory
        )
    }

    func startRun() {
        guard canStart, let suite else { return }
        let arms = manifest.arms
        let execution = draftExecutionConfiguration
        isRunning = true
        errorMessage = nil
        progress = LabRunProgress(phase: .validating, armCount: arms.count)
        selection = .bench(.reply)

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let completed = try await runner.runMatrix(
                    suite: suite,
                    arms: arms,
                    execution: execution,
                    research: manifest.research,
                    progress: { [weak self] update in
                        await MainActor.run { self?.progress = update }
                    },
                    reportCompleted: { [weak self] report in
                        guard let self else { return }
                        try await self.reportStore.save(report)
                        await MainActor.run { self.record(report) }
                    }
                )
                if let newest = completed.last { selection = .run(newest.id) }
            } catch is CancellationError {
                // Cancellation is an explicit owner action, not an error dialog.
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
            runTask = nil
        }
    }

    func startResearch(
        forceNew: Bool = false,
        name: String = "Autoresearch campaign"
    ) {
        guard canStart, let suite else { return }
        guard modelVerificationMode == .productionPinned else {
            errorMessage = "Experimental models use fixed quality runs. Autoresearch and corpus certification remain pinned to the production model."
            return
        }
        if isCertifiedCorpusLoaded {
            guard corpusModelCertificate?.passes == true else {
                errorMessage = "Run and pass the 3,000-case corpus certification before using this corpus for autoresearch."
                return
            }
            guard selectedArm.scenarios.partition == .development else {
                errorMessage = "Autoresearch may tune only the development split. Validation and holdout stay locked."
                return
            }
        }
        let selectedSuite = LabScenarioSelector.select(from: suite, configuration: selectedArm.scenarios)
        guard let digest = try? selectedSuite.digestSHA256() else {
            errorMessage = "The fixed research suite could not be identified."
            return
        }

        var campaign: LabResearchCampaign
        if !forceNew,
           let existing = activeCampaign,
           existing.suiteDigestSHA256 == digest,
           existing.state != .completed {
            campaign = existing
            campaign.configuration = researchConfiguration
        } else {
            campaign = LabResearchCampaign(
                name: name,
                suiteDigestSHA256: digest,
                baselineArm: selectedArm,
                configuration: researchConfiguration
            )
            campaigns.insert(campaign, at: 0)
        }

        campaign.state = .running
        campaign.updatedAt = Date()
        replaceCampaign(campaign)
        isRunning = true
        isResearchRun = true
        errorMessage = nil
        selection = .research

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                var working = campaign
                var championReport: LabRunReport

                if let reportID = working.championReportID,
                   let saved = reports.first(where: { $0.id == reportID }) {
                    championReport = saved
                } else {
                    championReport = try await runResearchArm(
                        working.baselineArm,
                        suite: suite,
                        repetitions: working.configuration.screeningRepetitions,
                        retries: working.configuration.protocolRetryCount,
                        restartWorkers: working.configuration.restartsWorkersBetweenRounds
                    )
                    working.ledger.append(LabResearchLedgerEntry(
                        trial: 0,
                        parentArmID: nil,
                        armID: championReport.arm.id,
                        mutation: nil,
                        reportID: championReport.id,
                        decision: .baseline,
                        verdict: championReport.verdict
                    ))
                    try await checkpoint(&working)
                }

                let pending = LabAutoresearchPlanner.pendingMutations(
                    for: working,
                    seed: manifest.runtime.seed
                )
                let deadline = Date().addingTimeInterval(
                    TimeInterval(working.configuration.timeBudgetMinutes * 60)
                )
                var latestControlP95 = championReport.metrics.latency.p95Milliseconds
                for mutation in pending {
                    try Task.checkCancellation()
                    guard Date() < deadline else { break }
                    let trial = working.ledger.filter { $0.mutation != nil }.count + 1

                    if trial > 1,
                       working.configuration.controlInterval > 0,
                       (trial - 1).isMultiple(of: working.configuration.controlInterval) {
                        var controlArm = working.championArm
                        controlArm.id = "research-control-\(trial)"
                        let control = try await runResearchArm(
                            controlArm,
                            suite: suite,
                            repetitions: working.configuration.screeningRepetitions,
                            retries: working.configuration.protocolRetryCount,
                            restartWorkers: working.configuration.restartsWorkersBetweenRounds
                        )
                        latestControlP95 = control.metrics.latency.p95Milliseconds
                        working.ledger.append(LabResearchLedgerEntry(
                            trial: trial,
                            parentArmID: working.championArm.id,
                            armID: control.arm.id,
                            mutation: nil,
                            reportID: control.id,
                            decision: .control,
                            verdict: control.verdict
                        ))
                        try await checkpoint(&working)
                    }

                    let candidateArm = mutation.applying(to: working.championArm, trial: trial)
                    let parentArmID = working.championArm.id
                    let candidate = try await runResearchArm(
                        candidateArm,
                        suite: suite,
                        repetitions: working.configuration.screeningRepetitions,
                        retries: working.configuration.protocolRetryCount,
                        restartWorkers: working.configuration.restartsWorkersBetweenRounds
                    )
                    let decision = LabAutoresearchPlanner.decision(
                        candidate: candidate,
                        champion: championReport,
                        controlP95Milliseconds: latestControlP95,
                        minimumImprovement: working.configuration.minimumBehavioralImprovement
                    )
                    if decision == .keep {
                        working.championArm = candidateArm
                        championReport = candidate
                    }
                    let normalizedP95 = candidate.metrics.latency.p95Milliseconds.flatMap { p95 in
                        latestControlP95.map { Double(p95) / Double(max(1, $0)) }
                    }
                    working.ledger.append(LabResearchLedgerEntry(
                        trial: trial,
                        parentArmID: parentArmID,
                        armID: candidate.arm.id,
                        mutation: mutation,
                        reportID: candidate.id,
                        decision: decision,
                        verdict: candidate.verdict,
                        normalizedP95Milliseconds: normalizedP95
                    ))
                    try await checkpoint(&working)
                }

                try Task.checkCancellation()
                var confirmationArm = working.championArm
                confirmationArm.id = "research-confirmation"
                let confirmation = try await runResearchArm(
                    confirmationArm,
                    suite: suite,
                    repetitions: working.configuration.confirmationRepetitions,
                    retries: working.configuration.protocolRetryCount,
                    restartWorkers: true
                )
                working.ledger.append(LabResearchLedgerEntry(
                    trial: working.ledger.count,
                    parentArmID: working.championArm.id,
                    armID: confirmation.arm.id,
                    mutation: nil,
                    reportID: confirmation.id,
                    decision: .confirmation,
                    verdict: confirmation.verdict
                ))
                working.state = .completed
                try await checkpoint(&working)
                await runner.cancel()
            } catch is CancellationError {
                if var paused = activeCampaign {
                    paused.state = .paused
                    try? await checkpoint(&paused)
                }
            } catch {
                errorMessage = error.localizedDescription
                if var paused = activeCampaign {
                    paused.state = .paused
                    try? await checkpoint(&paused)
                }
            }
            isRunning = false
            isResearchRun = false
            runTask = nil
        }
    }

    func startSixHourResearch() {
        guard !isRunning else { return }
        applyProductionFidelity()
        var arm = selectedArm
        arm.id = "overnight-baseline"
        arm.scenarios.partition = .development
        selectedArm = arm

        manifest.runtime.workerCount = 1
        manifest.runtime.slotsPerWorker = 8
        researchConfiguration = LabAutoresearchConfiguration(
            screeningRepetitions: 20,
            confirmationRepetitions: 100,
            maximumTrials: LabResearchMutation.allCases.count,
            survivorCount: 3,
            controlInterval: 4,
            protocolRetryCount: 2,
            minimumBehavioralImprovement: 0.0025,
            randomizesTrialOrder: true,
            restartsWorkersBetweenRounds: false,
            timeBudgetMinutes: 360,
            subsystem: .display
        )
        startResearch(
            forceNew: true,
            name: "Six-hour overnight autoresearch"
        )
    }

    func pauseResearch() {
        guard isResearchRun else { return }
        cancelRun()
    }

    func refreshPowerPreflight() {
        powerPreflight = LabPowerPreflight.inspect()
    }

    func cancelRun() {
        runTask?.cancel()
        Task { await runner.cancel() }
        if let activeFrontierRunner {
            Task { await activeFrontierRunner.cancel() }
        }
    }

    private func runResearchArm(
        _ arm: LabArmConfiguration,
        suite: LabScenarioSuite,
        repetitions: Int,
        retries: Int,
        restartWorkers: Bool
    ) async throws -> LabRunReport {
        var runtime = manifest.runtime
        runtime.repetitions = repetitions
        let execution = runtime.materialize(
            serverExecutable: URL(fileURLWithPath: serverPath),
            modelFile: URL(fileURLWithPath: modelPath),
            modelProfile: modelProfile
        )
        return try await runner.run(
            suite: suite,
            arm: arm,
            execution: execution,
            protocolRetryCount: retries,
            restartWorkers: restartWorkers,
            stopWorkersAfterRun: restartWorkers,
            progress: { [weak self] update in
                await MainActor.run { self?.progress = update }
            },
            reportCompleted: { [weak self] report in
                guard let self else { return }
                try await self.reportStore.save(report)
                await MainActor.run { self.record(report) }
            }
        )
    }

    private func checkpoint(_ campaign: inout LabResearchCampaign) async throws {
        campaign.updatedAt = Date()
        try await campaignStore.save(campaign)
        replaceCampaign(campaign)
    }

    private func replaceCampaign(_ campaign: LabResearchCampaign) {
        campaigns.removeAll { $0.id == campaign.id }
        campaigns.insert(campaign, at: 0)
    }

    private func record(_ report: LabRunReport) {
        reports.removeAll { $0.id == report.id }
        reports.insert(report, at: 0)
    }

    func addArm(duplicatingCurrent: Bool) {
        guard manifest.arms.count < 128 else { return }
        var arm = duplicatingCurrent ? selectedArm : LabArmConfiguration()
        arm.id = uniqueArmID(base: duplicatingCurrent ? selectedArm.id + "-copy" : "candidate")
        manifest.arms.append(arm)
        selectedArmIndex = manifest.arms.count - 1
    }

    func removeSelectedArm() {
        guard manifest.arms.count > 1, manifest.arms.indices.contains(selectedArmIndex) else { return }
        manifest.arms.remove(at: selectedArmIndex)
        selectedArmIndex = min(selectedArmIndex, manifest.arms.count - 1)
    }

    func resetSelectedArmToLabDefaults() {
        let id = selectedArm.id
        selectedArm = LabArmConfiguration(id: id)
    }

    func applyProductionFidelity() {
        var arm = selectedArm
        arm.generation = LabGenerationConfiguration(requestMode: .productionStreaming)
        arm.prompt = LabPromptConfiguration(includesIntentFutures: true)
        arm.judgment = LabJudgmentConfiguration()
        selectedArm = arm
    }

    func prepareProductionModelQualityBaseline() {
        modelVerificationMode = .productionPinned
        prepareModelQualityRun(armID: "model-quality-e2b-cap3")
    }

    func prepareGemma26BModelQualityCandidate() {
        modelVerificationMode = .experimentalLocal
        experimentalModelIdentifier = "ggml-org/gemma-4-26B-A4B-GGUF"
        experimentalModelRevision = "0b1367270501454da6df6c53fe46e90de8a1146e"
        prepareModelQualityRun(armID: "model-quality-26b-a4b-cap3")
    }

    func startFrontierQualityCeiling() {
        guard canStartFrontierQualityCeiling, let suite else {
            errorMessage = "Certified Corpus V2 and a ChatGPT-authenticated Codex CLI are required."
            return
        }
        prepareModelQualityRun(armID: "model-quality-frontier-sol-cap3")
        let arm = selectedArm
        let frontier = LabFrontierCeilingRunner(client: LabCodexSubscriptionClient(
            codexExecutable: URL(fileURLWithPath: codexPath)
        ))
        activeFrontierRunner = frontier
        isRunning = true
        isResearchRun = false
        errorMessage = nil
        progress = LabRunProgress(phase: .verifyingAssets, total: 50, armID: arm.id)
        selection = .bench(.reply)

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let report = try await frontier.run(
                    suite: suite,
                    arm: arm,
                    configuration: LabFrontierCeilingConfiguration(
                        model: frontierModel,
                        batchSize: 25,
                        timeoutSecondsPerBatch: 300
                    ),
                    progress: { [weak self] update in
                        await MainActor.run { self?.progress = update }
                    }
                )
                try await reportStore.save(report)
                record(report)
                selection = .run(report.id)
            } catch is CancellationError {
                // Owner-requested cancellation is not a failed quality result.
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
            activeFrontierRunner = nil
            runTask = nil
        }
    }

    func chooseExperimentalModel() {
        let panel = NSOpenPanel()
        panel.title = "Choose an experimental GGUF model"
        panel.prompt = "Use Model"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let selected = panel.url else { return }
        modelVerificationMode = .experimentalLocal
        experimentalModelPath = selected.path
    }

    private func prepareModelQualityRun(armID: String) {
        guard isCertifiedCorpusLoaded else {
            errorMessage = "Load Certified Corpus V2 before preparing the model quality comparison."
            return
        }
        var arm = LabArmConfiguration(
            id: armID,
            temperature: 0,
            predictionTokens: 20,
            maxVisibleWords: 3,
            includesScene: true,
            suppressesSensitiveScenes: true
        )
        arm.generation.requestMode = .productionStreaming
        arm.prompt.includesIntentFutures = true
        arm.scenarios = LabScenarioVariationConfiguration(
            partition: .development,
            suggestionExpectation: .speakOnly,
            maximumDistinctSituations: 50
        )
        arm.scoring = LabScoringConfiguration(
            policyVersion: LabScoringConfiguration.modelOutputQualityPolicy,
            usefulnessWeight: 0.80,
            restraintWeight: 0,
            factualityWeight: 0.15,
            brevityWeight: 0.05,
            weightsLockedDuringComparison: true
        )
        manifest.name = "Model quality · 3-word cap · 50 situations"
        manifest.arms = [arm]
        manifest.runtime.workerCount = 1
        manifest.runtime.slotsPerWorker = 1
        manifest.runtime.repetitions = 1
        manifest.runtime.contextSizePerSlot = 4_096
        manifest.runtime.timeoutSeconds = 120
        selectedArmIndex = 0
        selection = .bench(.reply)
        errorMessage = nil
    }

    func applySamplerPreset(_ preset: LabSamplerPreset) {
        var arm = selectedArm
        arm.generation.apply(preset)
        selectedArm = arm
    }

    func runSyntheticAudit(_ bench: LabBenchKind) {
        benchAudits[bench] = LabSyntheticBenchRunner.run(
            bench: bench,
            arm: selectedArm,
            runtime: manifest.runtime
        )
    }

    func importSuite(from url: URL) {
        Task { [weak self] in
            guard let self else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try LabScenarioSuiteLoader.load(from: url)
                }.value
                suite = loaded
                historicalReplaySummary = nil
                clearCorpusCertificationState()
                selection = .bench(.reply)
            } catch {
                errorMessage = "The selected scenario suite is invalid: \(error.localizedDescription)"
            }
        }
    }

    func loadBuiltInSuite(_ version: LabBuiltInSuite) {
        do {
            suite = try LabScenarioSuiteLoader.builtIn(version)
            historicalReplaySummary = nil
            clearCorpusCertificationState()
            for index in manifest.arms.indices {
                manifest.arms[index].scenarios.partition = version.recommendedPartition
            }
            selection = .bench(.reply)
            errorMessage = nil
        } catch {
            errorMessage = "The built-in quiz could not be loaded: \(error.localizedDescription)"
        }
    }

    func loadCorpusPilot() {
        guard !isLoadingSuite, !isRunning else { return }
        isLoadingSuite = true
        errorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let pilot = try await Task.detached(priority: .userInitiated) {
                    try LabCorpusPilotSuiteFactory.make()
                }.value
                suite = pilot.suite
                historicalReplaySummary = nil
                clearCorpusCertificationState()
                for index in manifest.arms.indices {
                    manifest.arms[index].scenarios.partition = .development
                }
                var arm = selectedArm
                arm.id = "corpus-pilot-baseline"
                selectedArm = arm
                selection = .bench(.reply)
            } catch {
                errorMessage = "The 1,000-situation corpus pilot could not be loaded: \(error.localizedDescription)"
            }
            isLoadingSuite = false
        }
    }

    func loadCertifiedCorpus() {
        guard !isLoadingSuite, !isRunning else { return }
        isLoadingSuite = true
        errorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
                    let quality = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite)
                    return (suite, quality)
                }.value
                suite = loaded.0
                corpusQualityReport = loaded.1
                corpusModelCertificate = nil
                historicalReplaySummary = nil
                for index in manifest.arms.indices {
                    manifest.arms[index].scenarios = LabScenarioVariationConfiguration(
                        partition: .development
                    )
                }
                var arm = selectedArm
                arm.id = "corpus-v2-baseline"
                selectedArm = arm
                selection = .bench(.reply)

                if let saved = await corpusCertificateStore.load(
                    corpusDigestSHA256: loaded.1.corpusDigestSHA256
                ) {
                    let execution = certificationExecutionConfiguration
                    if let assets = try? await LabAssetVerifier.shared.verify(execution),
                       saved.modelSHA256 == assets.modelSHA256,
                       saved.helperSHA256 == assets.helperSHA256 {
                        corpusModelCertificate = saved
                    }
                }
            } catch {
                clearCorpusCertificationState()
                errorMessage = "The certified corpus could not be loaded: \(error.localizedDescription)"
            }
            isLoadingSuite = false
        }
    }

    func startCorpusCertification() {
        guard canStartCorpusCertification,
              let suite,
              let quality = corpusQualityReport else { return }
        isRunning = true
        isResearchRun = false
        errorMessage = nil
        corpusModelCertificate = nil
        progress = LabRunProgress(phase: .validating, total: 3_000, armCount: 3)

        var baseline = selectedArm
        baseline.id = "corpus-v2-production-baseline"
        baseline.generation = LabGenerationConfiguration(requestMode: .productionStreaming)
        baseline.prompt = LabPromptConfiguration(includesIntentFutures: true)
        baseline.judgment = LabJudgmentConfiguration()
        baseline.scenarios = LabScenarioVariationConfiguration(partition: .all)
        let execution = certificationExecutionConfiguration

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let certificate = try await LabCorpusModelCertifier.certify(
                    suite: suite,
                    baseline: baseline,
                    execution: execution,
                    runner: runner,
                    progress: { [weak self] update in
                        await MainActor.run { self?.progress = update }
                    }
                )
                guard certificate.corpusDigestSHA256 == quality.corpusDigestSHA256 else {
                    throw LabCorpusCertificationError.incompleteReports
                }
                try await corpusCertificateStore.save(certificate)
                corpusModelCertificate = certificate
            } catch is CancellationError {
                // Cancellation is an explicit owner action, not a failed certificate.
            } catch {
                errorMessage = "Corpus certification could not finish: \(error.localizedDescription)"
            }
            isRunning = false
            runTask = nil
        }
    }

    func startQuickCertifiedExperiment() {
        guard canStartQuickCertifiedExperiment else {
            errorMessage = "Certified Corpus V2 must pass certification before the quick experiment can run."
            return
        }
        manifest.name = "Certified Corpus V2 · Quick 8"
        manifest.arms = LabCampaignFactory.arms(for: .quickSweep8)
        manifest.runtime.workerCount = 1
        manifest.runtime.slotsPerWorker = 8
        manifest.runtime.repetitions = 1
        selectedArmIndex = 0
        startRun()
    }

    func loadPrivateHistoricalReplay() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try LabHistoricalReplayLoader.load()
                }.value
                suite = loaded.suite
                historicalReplaySummary = loaded.summary
                clearCorpusCertificationState()
                for index in manifest.arms.indices {
                    manifest.arms[index].scenarios.partition = .development
                }
                selection = .bench(.reply)
                errorMessage = nil
            } catch {
                errorMessage = "Private replay could not be loaded from the local Tilde-usage folder. No source files were changed."
            }
        }
    }

    func loadMixedLearningSuite() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    let history = try LabHistoricalReplayLoader.load()
                    let protected = try LabSlackReplyGoldSuiteFactory.makeSuite()
                    return (
                        try LabMixedLearningSuiteFactory.make(
                            historical: history.suite,
                            protected: protected
                        ),
                        history.summary
                    )
                }.value
                suite = loaded.0
                historicalReplaySummary = loaded.1
                clearCorpusCertificationState()
                for index in manifest.arms.indices {
                    manifest.arms[index].scenarios.partition = .development
                }
                selection = .bench(.reply)
                errorMessage = nil
            } catch {
                errorMessage = "The mixed learning suite could not be built from local history. No source files were changed."
            }
        }
    }

    func importManifest(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let decoder = JSONDecoder()
            let loaded = try decoder.decode(LabExperimentManifest.self, from: Data(contentsOf: url))
            manifest = try loaded.validated()
            selectedArmIndex = 0
            selection = .bench(.reply)
        } catch {
            errorMessage = "The selected experiment manifest is invalid: \(error.localizedDescription)"
        }
    }

    func exportManifest() {
        do {
            let value = try manifest.validated()
            let panel = NSSavePanel()
            panel.title = "Export Tilde Lab Experiment"
            panel.nameFieldStringValue = safeFilename(value.name) + ".tilde-lab.json"
            panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: destination, options: .atomic)
        } catch {
            errorMessage = "The experiment manifest could not be exported: \(error.localizedDescription)"
        }
    }

    func baseline(for report: LabRunReport) -> LabRunReport? {
        if let pinnedBaselineRunID,
           let pinned = reports.first(where: { $0.id == pinnedBaselineRunID }),
           pinned.id != report.id,
           pinned.suiteDigestSHA256 == report.suiteDigestSHA256,
           pinned.arm.scoring == report.arm.scoring {
            return pinned
        }
        return reports.first {
            $0.id != report.id
                && $0.suiteDigestSHA256 == report.suiteDigestSHA256
                && $0.arm.scoring == report.arm.scoring
                && $0.finishedAt < report.finishedAt
        }
    }

    func pinBaseline(_ report: LabRunReport) {
        pinnedBaselineRunID = pinnedBaselineRunID == report.id ? nil : report.id
    }

    func delete(_ report: LabRunReport) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await reportStore.delete(report)
                reports.removeAll { $0.id == report.id }
                if pinnedBaselineRunID == report.id { pinnedBaselineRunID = nil }
                selection = .bench(.reply)
            } catch {
                errorMessage = "The aggregate report could not be deleted."
            }
        }
    }

    func revealReportsFolder() {
        NSWorkspace.shared.open(reportStore.directory)
    }

    func scenario(for result: LabCaseResult, report: LabRunReport) -> LabScenario? {
        guard let suite,
              (try? LabScenarioSelector.select(from: suite, configuration: report.arm.scenarios)
                .digestSHA256()) == report.suiteDigestSHA256 else { return nil }
        return suite.scenarios.first { $0.id == result.scenarioID }
    }

    private var draftExecutionConfiguration: LabExecutionConfiguration {
        manifest.runtime.materialize(
            serverExecutable: URL(fileURLWithPath: serverPath),
            modelFile: URL(fileURLWithPath: modelPath),
            modelProfile: modelProfile
        )
    }

    private var certificationExecutionConfiguration: LabExecutionConfiguration {
        var runtime = manifest.runtime
        runtime.workerCount = 1
        runtime.slotsPerWorker = 8
        runtime.repetitions = 1
        return runtime.materialize(
            serverExecutable: URL(fileURLWithPath: serverPath),
            modelFile: URL(fileURLWithPath: productionModelPath),
            modelProfile: .production
        )
    }

    private func clearCorpusCertificationState() {
        corpusQualityReport = nil
        corpusModelCertificate = nil
    }

    private func uniqueArmID(base: String) -> String {
        let cleaned = base
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9._:+-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let root = cleaned.isEmpty ? "candidate" : String(cleaned.prefix(110))
        let existing = Set(manifest.arms.map(\.id))
        if !existing.contains(root) { return root }
        for suffix in 2...999 {
            let candidate = "\(root)-\(suffix)"
            if !existing.contains(candidate) { return candidate }
        }
        return "candidate-\(UUID().uuidString.lowercased().prefix(8))"
    }

    private func safeFilename(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]+"#,
            with: "-",
            options: .regularExpression
        )
    }
}
