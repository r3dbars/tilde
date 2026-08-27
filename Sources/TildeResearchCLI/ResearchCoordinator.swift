import Foundation
import TildeLabKit

enum ResearchCoordinator {
    static func execute(_ arguments: CLIArguments) async throws {
        switch arguments.command {
        case "init": try await initialize(arguments)
        case "validate": try await validate(arguments)
        case "run": try await run(arguments)
        case "status": try await status(arguments)
        case "compare": try await compare(arguments)
        case "risk-coverage": try await riskCoverage(arguments)
        case "personalization-replay": try await personalizationReplay(arguments)
        case "advance-search": try await advanceSearch(arguments)
        case "nominate": try await nominate(arguments)
        case "validate-candidates": try await validateCandidates(arguments)
        case "holdout": try await holdout(arguments)
        case "freeze-regression": try await freezeRegression(arguments)
        case "regression": try await runRegression(arguments)
        case "shadow": try await configureOnline(arguments, phase: .shadow)
        case "dogfood": try await configureOnline(arguments, phase: .dogfood)
        case "soak": try await configureOnline(arguments, phase: .soak)
        case "ingest-events": try await ingestEvents(arguments)
        case "online-report": try await onlineReport(arguments)
        case "confidence-report": try await confidenceReport(arguments)
        case "soak-report": try await soakReport(arguments)
        case "interaction-report": try await interactionReport(arguments)
        case "delete-telemetry": try await deleteTelemetry(arguments)
        case "cache-clear": try await clearCache(arguments)
        case "agent-evidence": try await agentEvidence(arguments)
        case "agent-validate": try await validateAgentProposal(arguments)
        default: throw ResearchCLIError.usage(CLIArguments.usage)
        }
    }

    static func help(for command: String?) -> String {
        guard let command else { return CLIArguments.usage }
        return commandHelp[command] ?? CLIArguments.usage
    }

    private static let commandHelp: [String: String] = [
        "init": """
        Usage: tilde-research init --name NAME [options]
          --suite certified-v2|replying-v2|replying-v1|slack-reply-gold-v1|/absolute/suite.json
          --recipe qwen-factorial|qmc|context-matrix|display-matrix|runtime-matrix|baseline-only
          --class generator|context|display-policy|personalization|runtime|interaction
          --seeds 17,41,73  --candidates 31  --block-size 20
          --budget-hours 12 --maximum-model-requests 250000
          --workers 2 --slots 4 --repetitions 1
          --experimental-model --model ID --model-revision REV --model-file PATH
          --helper PATH --output CAMPAIGN.json
        """,
        "validate": "Usage: tilde-research validate CAMPAIGN.json",
        "run": "Usage: tilde-research run CAMPAIGN.json [--resume] [--no-cache] [--database PATH] [--allow-battery]",
        "status": "Usage: tilde-research status CAMPAIGN.json [--database PATH] [--json]",
        "compare": "Usage: tilde-research compare --campaign CAMPAIGN.json [--paired-bootstrap 10000] [--database PATH]",
        "risk-coverage": "Usage: tilde-research risk-coverage --campaign CAMPAIGN.json --arm ID [--trust-limit 0.01] [--output report.json] [--json]",
        "personalization-replay": "Usage: tilde-research personalization-replay --input events.jsonl [--scope app-specific|global|app-then-global] [--evaluation-start-ms UNIX_MS] [--output report.json] [--json]",
        "advance-search": "Usage: tilde-research advance-search --campaign CAMPAIGN.json --stage halving|adaptive [--candidates 8] [--output CHILD.json]",
        "nominate": "Usage: tilde-research nominate --campaign CAMPAIGN.json [--top 3] --output validation-plan.json",
        "validate-candidates": "Usage: tilde-research validate-candidates PLAN.json --campaign CAMPAIGN.json [--database PATH]",
        "holdout": "Usage: tilde-research holdout --campaign CAMPAIGN.json --validation-plan PLAN.json [--candidate ID] [--baseline ID] --confirm-consume [--output holdout-plan.json]",
        "freeze-regression": "Usage: tilde-research freeze-regression --campaign CAMPAIGN.json --candidate ID --suite /absolute/regression-suite.json [--partition regression|adversarial] --evidence-digest SHA256 --output regression-plan.json",
        "regression": "Usage: tilde-research regression PLAN.json --campaign CAMPAIGN.json [--database PATH]",
        "shadow": "Usage: tilde-research shadow --campaign CAMPAIGN.json --candidate ID --holdout-plan PLAN.json [--days 3] [--database PATH]",
        "dogfood": "Usage: tilde-research dogfood --campaign CAMPAIGN.json --challenger ID --holdout-plan PLAN.json [--champion ID] [--allocation 0.10] [--holdback 0.10] [--days 7]",
        "soak": "Usage: tilde-research soak --campaign CAMPAIGN.json --candidate ID --holdout-plan PLAN.json [--champion ID] [--hours 4] [--minimum-events 100] [--database PATH]",
        "ingest-events": "Usage: tilde-research ingest-events --campaign CAMPAIGN.json --input events.jsonl [--database PATH]",
        "online-report": "Usage: tilde-research online-report --campaign CAMPAIGN.json [--database PATH] [--json]",
        "confidence-report": "Usage: tilde-research confidence-report --campaign CAMPAIGN.json [--database PATH] [--output report.json] [--json]",
        "soak-report": "Usage: tilde-research soak-report --campaign CAMPAIGN.json [--database PATH] [--json]",
        "interaction-report": "Usage: tilde-research interaction-report --campaign CAMPAIGN.json --candidate ID --holdout-plan PLAN.json --input interaction.jsonl [--output report.json] [--json]",
        "delete-telemetry": "Usage: tilde-research delete-telemetry --campaign CAMPAIGN.json [--database PATH]",
        "cache-clear": "Usage: tilde-research cache-clear --campaign CAMPAIGN.json",
        "agent-evidence": "Usage: tilde-research agent-evidence --campaign CAMPAIGN.json --output evidence.json",
        "agent-validate": "Usage: tilde-research agent-validate --campaign CAMPAIGN.json --proposal proposal.json --arm-id ID --output child-campaign.json [--database PATH]",
    ]

    private static func initialize(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: [
                "name", "phase", "class", "suite", "partition", "model",
                "model-revision", "model-file", "helper", "budget-hours", "output",
                "recipe", "search", "candidates", "seeds", "workers", "slots",
                "repetitions", "maximum-model-requests", "maximum-roots-per-trial",
                "block-size",
            ],
            flags: ["experimental-model"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "init"))
        }
        let name = try arguments.requiredValue("name")
        let phase = LabCampaignPhase(rawValue: arguments.value("phase") ?? "discovery")
        guard phase == .discovery else {
            throw ResearchCLIError.usage(
                "`init` creates development-only discovery campaigns. Use nomination commands for protected phases."
            )
        }
        guard let experimentClass = LabExperimentClass(
            rawValue: arguments.value("class") ?? "generator"
        ) else { throw ResearchCLIError.invalidValue("--class") }
        if experimentClass == .personalization {
            throw ResearchCLIError.usage(
                "Personalization must use `tilde-research personalization-replay` so history is strictly chronological and stays local."
            )
        }
        if experimentClass == .interaction {
            throw ResearchCLIError.usage(
                "Interaction evidence must come from the real macOS Interaction Scene Host or compatibility smoke; offline model fixtures cannot establish IMKit correctness."
            )
        }
        guard let partition = LabScenarioPartition(
            rawValue: arguments.value("partition") ?? "development"
        ), partition == .development else {
            throw ResearchCLIError.invalidValue("--partition (discovery requires development)")
        }
        let suiteReference = try suiteReference(arguments.value("suite") ?? "certified-v2")
        let seeds = try generationSeeds(arguments.value("seeds") ?? "17,41,73")
        let runtime = LabRuntimeConfiguration(
            workerCount: try arguments.integer("workers", default: 2),
            slotsPerWorker: try arguments.integer("slots", default: 4),
            repetitions: try arguments.integer("repetitions", default: 1)
        )
        let defaultRecipe: String = switch experimentClass {
        case .generator: "qwen-factorial"
        case .context: "context-matrix"
        case .displayPolicy: "display-matrix"
        case .runtime: "runtime-matrix"
        case .personalization, .interaction: "baseline-only"
        }
        let recipe = arguments.value("recipe")
            ?? arguments.value("search")
            ?? defaultRecipe
        var arms: [LabArmConfiguration]
        var runtimeByArm: [String: LabRuntimeConfiguration]?
        let strategy: LabSearchStrategy
        switch recipe {
        case "qwen-factorial":
            guard experimentClass == .generator else {
                throw ResearchCLIError.invalidValue("--recipe for non-generator class")
            }
            arms = LabCampaignFactory.arms(for: .quickSweep8)
            strategy = .fixed
        case "qmc":
            guard experimentClass == .generator else {
                throw ResearchCLIError.invalidValue("--recipe for non-generator class")
            }
            var baseline = LabArmConfiguration(id: "baseline")
            baseline.generation.requestMode = .productionStreaming
            baseline.prompt.includesIntentFutures = true
            let count = try arguments.integer("candidates", default: 31)
            arms = [baseline] + (try LabStagedSearchPlanner.spaceFillingArms(
                baseline: baseline,
                candidateCount: count
            ))
            strategy = .quasiRandom
        case "baseline-only":
            guard experimentClass != .runtime else {
                throw ResearchCLIError.invalidValue("--recipe for runtime class")
            }
            arms = [LabArmConfiguration(id: "baseline")]
            strategy = .fixed
        case "context-matrix":
            guard experimentClass == .context else {
                throw ResearchCLIError.invalidValue("--recipe for non-context class")
            }
            arms = contextMatrix()
            strategy = .fixed
        case "display-matrix":
            guard experimentClass == .displayPolicy else {
                throw ResearchCLIError.invalidValue("--recipe for non-display-policy class")
            }
            arms = displayPolicyMatrix()
            strategy = .fixed
        case "runtime-matrix":
            guard experimentClass == .runtime else {
                throw ResearchCLIError.invalidValue("--recipe for non-runtime class")
            }
            let matrix = runtimeMatrix(baseline: runtime)
            arms = matrix.arms
            runtimeByArm = matrix.configurations
            strategy = .fixed
        default:
            throw ResearchCLIError.invalidValue("--recipe")
        }
        for index in arms.indices {
            arms[index].scenarios.partition = partition
            arms[index].generation.seed = seeds[0]
            // One bounded probability payload makes confidence replay and
            // calibration possible without changing the generated candidate.
            arms[index].generation.probabilityCount = max(
                5, arms[index].generation.probabilityCount
            )
        }
        let protocolDefinition = LabResearchProtocol(
            phase: .discovery,
            experimentClass: experimentClass,
            searchStrategy: strategy,
            baselineArmID: arms[0].id,
            fixedGenerationSeeds: seeds,
            interleavedRootBlockSize: try arguments.integer("block-size", default: 20),
            runtimeByArm: runtimeByArm
        )
        let manifest = LabExperimentManifest(
            name: name,
            arms: arms,
            runtime: runtime,
            research: protocolDefinition
        )
        let maximumTrials = max(arms.count, 96)
        let budget = LabResearchBudget(
            maximumHours: try arguments.double("budget-hours", default: 12),
            maximumTrials: maximumTrials,
            maximumRootsPerTrial: try arguments.integer("maximum-roots-per-trial", default: 1_000),
            maximumModelRequests: try arguments.integer(
                "maximum-model-requests", default: 250_000
            )
        )
        let model = try modelConfiguration(arguments)
        let campaign = LabResearchCampaignFile(
            name: name,
            suite: suiteReference,
            manifest: manifest,
            budget: budget,
            model: model
        )
        let loadedSuite = try suiteReference.load()
        try campaign.validated(with: loadedSuite)
        let output = URL(fileURLWithPath: (
            arguments.value("output") ?? "\(name.researchSlug).json"
        ).expandedResearchPath).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing campaign \(output.path).")
        }
        try LabResearchCampaignFileIO.save(campaign, to: output)
        ResearchConsole.line("Created discovery campaign \(campaign.name)")
        ResearchConsole.line("  id: \(campaign.id.uuidString.lowercased())")
        ResearchConsole.line("  arms: \(campaign.manifest.arms.count)")
        ResearchConsole.line("  fixed seeds: \(seeds.map(String.init).joined(separator: ","))")
        ResearchConsole.line("  planned model requests: \(campaign.plannedModelRequests ?? 0)")
        ResearchConsole.line("  file: \(output.path)")
    }

    private static func contextMatrix() -> [LabArmConfiguration] {
        var baseline = LabArmConfiguration(id: "baseline")
        baseline.prompt.includesIntentFutures = true
        var result = [baseline]
        func candidate(
            _ id: String,
            _ mutate: (inout LabArmConfiguration) -> Void
        ) {
            var arm = baseline
            arm.id = id
            mutate(&arm)
            result.append(arm)
        }
        candidate("typed-only") {
            $0.prompt.includesScene = false
            $0.prompt.includesIntentFutures = false
        }
        candidate("no-intent-futures") { $0.prompt.includesIntentFutures = false }
        candidate("last-four-turns") { $0.prompt.conversationTurnLimit = 4 }
        candidate("compact-context") {
            $0.prompt.maximumContextCharacters = 1_500
            $0.prompt.maximumSceneCharacters = 1_500
            $0.prompt.conversationCharacterBudget = 900
            $0.prompt.referenceCharacterBudget = 400
        }
        candidate("scene-after-text") { $0.prompt.scenePlacement = .afterText }
        candidate("accurate-recognition") { $0.sceneBench.recognitionMode = .accurate }
        return result
    }

    private static func displayPolicyMatrix() -> [LabArmConfiguration] {
        let baseline = LabArmConfiguration(id: "baseline")
        var result = [baseline]
        func candidate(
            _ id: String,
            _ mutate: (inout LabArmConfiguration) -> Void
        ) {
            var arm = baseline
            arm.id = id
            mutate(&arm)
            result.append(arm)
        }
        candidate("confidence-20") { $0.generation.minimumMeanTokenProbability = 0.20 }
        candidate("confidence-35") { $0.generation.minimumMeanTokenProbability = 0.35 }
        candidate("three-word-cap") {
            $0.judgment.maximumVisibleWords = 3
            $0.judgment.maximumVisibleCharacters = 42
        }
        candidate("eight-word-cap") {
            $0.judgment.maximumVisibleWords = 8
            $0.judgment.maximumVisibleCharacters = 96
        }
        candidate("strict-cleaner") { $0.judgment.cleanerPreset = .strict }
        candidate("ground-all-anchors") { $0.judgment.factualGrounding = .allAnchors }
        candidate("dynamic-length") { $0.judgment.lengthPolicy = .confidenceBased }
        return result
    }

    private static func runtimeMatrix(
        baseline: LabRuntimeConfiguration
    ) -> (arms: [LabArmConfiguration], configurations: [String: LabRuntimeConfiguration]) {
        var variants: [(String, LabRuntimeConfiguration)] = [("baseline", baseline)]
        func candidate(
            _ id: String,
            _ mutate: (inout LabRuntimeConfiguration) -> Void
        ) {
            var configuration = baseline
            mutate(&configuration)
            guard configuration != baseline,
                  !variants.contains(where: { $0.1 == configuration }) else { return }
            variants.append((id, configuration))
        }
        candidate("one-worker") { $0.workerCount = 1 }
        candidate("one-slot") { $0.slotsPerWorker = 1 }
        candidate("eight-slots") { $0.slotsPerWorker = 8 }
        candidate("context-2048") { $0.contextSizePerSlot = 2_048 }
        candidate("flash-on") { $0.flashAttention = .on }
        candidate("kv-q8") {
            $0.keyCacheType = .q8_0
            $0.valueCacheType = .q8_0
        }
        candidate("prompt-cache-off") { $0.promptCaching = false }
        candidate("cache-reuse-off") { $0.cacheReuseTokens = 0 }

        let arms = variants.map { id, _ in LabArmConfiguration(id: id) }
        return (
            arms,
            Dictionary(uniqueKeysWithValues: variants.map { ($0.0, $0.1) })
        )
    }

    private static func validate(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: [])
        let url = try oneDocumentURL(arguments, command: "validate")
        let campaign = try LabResearchCampaignFileIO.load(from: url)
        let suite = try campaign.suite.load()
        try campaign.validated(with: suite)
        let roots = Set(suite.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
        ResearchConsole.line("Valid discovery campaign")
        ResearchConsole.line("  phase firewall: development only")
        ResearchConsole.line("  experiment class: \(campaign.manifest.research!.experimentClass.rawValue)")
        ResearchConsole.line("  source roots: \(roots)")
        ResearchConsole.line("  arms: \(campaign.manifest.arms.count)")
        ResearchConsole.line("  planned model requests: \(campaign.plannedModelRequests ?? 0)")
        ResearchConsole.line("  budget hours: \(campaign.budget.maximumHours)")
    }

    private static func status(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["database"], flags: ["json"])
        let url = try oneDocumentURL(arguments, command: "status")
        let campaign = try LabResearchCampaignFileIO.load(from: url)
        let layout = LabResearchArtifactLayout(documentURL: url)
        let database = try researchDatabase(arguments)
        let summary = try await database.summary(campaignID: campaign.id)
        let activeSeconds = try await database.activeDurationSeconds(campaignID: campaign.id)
        let reports = await LabReportStore(directory: layout.reportsDirectory).loadAll()
        let cacheCount: Int
        if FileManager.default.fileExists(atPath: layout.candidateCacheURL.path) {
            cacheCount = try await LabSyntheticCandidateCache(
                fileURL: layout.candidateCacheURL
            ).count()
        } else {
            cacheCount = 0
        }
        if arguments.hasFlag("json") {
            let value = ResearchStatusOutput(
                campaignID: campaign.id,
                pending: summary.pending,
                running: summary.running,
                completed: summary.completed,
                failed: summary.failed,
                reports: reports.count,
                cachedSyntheticCandidates: cacheCount,
                activeSeconds: activeSeconds,
                budgetSeconds: campaign.budget.maximumHours * 3_600
            )
            try writeJSON(value)
        } else {
            ResearchConsole.line("Campaign \(campaign.name)")
            ResearchConsole.line("  work: \(summary.completed)/\(summary.total) completed; \(summary.running) running; \(summary.failed) failed")
            ResearchConsole.line("  reports: \(reports.count)/\(campaign.manifest.arms.count)")
            ResearchConsole.line("  synthetic cache entries: \(cacheCount)")
            ResearchConsole.line("  active budget: \(formatHours(activeSeconds))/\(campaign.budget.maximumHours.formatted()) hours")
        }
    }
}

private struct ResearchStatusOutput: Codable {
    let campaignID: UUID
    let pending: Int
    let running: Int
    let completed: Int
    let failed: Int
    let reports: Int
    let cachedSyntheticCandidates: Int
    let activeSeconds: Double
    let budgetSeconds: Double
}
