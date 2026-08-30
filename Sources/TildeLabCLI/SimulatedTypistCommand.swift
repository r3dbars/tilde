import Foundation
import TildeLabKit

extension ResearchCoordinator {
    /// Development-only discovery lane. It drives synthetic personas through
    /// the real completion path and writes a permanently fenced simulated
    /// report. It never touches a campaign's reports directory, so no
    /// protected command can read its output.
    static func simulateTypist(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: [
                "suite", "personas", "policy", "decision-command", "decision-argument",
                "decision-batch-size", "decision-workers", "skip-failed-batches",
                "scenarios", "stride", "maximum-displays", "arm-file", "helper", "model-file",
                "model", "model-revision", "workers", "slots", "output",
            ],
            flags: ["json", "experimental-model"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "simulate-typist"))
        }

        let suite = try suiteReference(arguments.value("suite") ?? "replying-v1").load()
        let limit = try arguments.integer("scenarios", default: 8)
        guard (1...500).contains(limit) else {
            throw ResearchCLIError.invalidValue("--scenarios")
        }
        let simulationSuite = try LabScenarioSuite(
            name: suite.name,
            scenarios: Array(
                suite.scenarios.filter {
                    $0.expectation.shouldSuggest
                        && ($0.expectation.goldenContinuation?.isEmpty == false)
                }.prefix(limit)
            )
        ).validated()

        let personas = try selectedPersonas(arguments)
        let policy = try decisionPolicy(arguments)

        var configuration = LabSimulatedTypistConfiguration()
        // A campaign nominated one arm; running the simulator against a
        // different configuration than the one under discussion would answer a
        // question nobody asked. The file is the campaign manifest's own arm
        // shape, decoded and validated by the same code `validate` uses.
        if let armPath = arguments.value("arm-file") {
            configuration.arm = try LabSimulatedTypistArmFile.load(atPath: armPath)
        }
        configuration.strideCharacters = try arguments.integer("stride", default: 4)
        configuration.maximumDisplaysPerScenario = try arguments.integer(
            "maximum-displays", default: 8
        )
        configuration.decisionWorkers = try decisionWorkers(arguments)
        configuration.skippedBatchAllowance = try skippedBatchAllowance(arguments)

        let model = try modelConfiguration(arguments)
        let runtime = LabRuntimeConfiguration(
            workerCount: try arguments.integer("workers", default: 1),
            slotsPerWorker: try arguments.integer("slots", default: 1),
            repetitions: 1
        )
        let execution = model.execution(runtime)
        // Fingerprint the generation stack before launching it. A simulated
        // report that cannot name the model behind its candidates cannot be
        // read next to another model's run, which is the only thing a
        // discovery-grade number is good for.
        let assets = try await LabAssetVerifier.shared.verify(execution)
        let pool = LabLlamaServerPool()
        defer { Task { await pool.stop() } }
        let clients = try await pool.start(configuration: execution)
        guard let client = clients.first else {
            throw ResearchCLIError.missingArtifact("local llama-server worker")
        }

        let engine = LabSimulatedTypistEngine(configuration: configuration, policy: policy)
        let report = try await engine.run(
            suite: simulationSuite,
            personas: personas,
            client: client,
            provenance: reportProvenance(
                campaignID: UUID(),
                manifestDigestSHA256: try configuration.arm.digestSHA256(),
                hypothesisID: nil,
                hypothesis: nil
            ),
            assets: assets
        )
        await pool.stop()
        try emit(report, arguments: arguments)
    }

    private static func selectedPersonas(
        _ arguments: CLIArguments
    ) throws -> [LabTypistPersona] {
        let catalog = try LabTypistPersonaCatalog.loadBundled()
        guard let requested = arguments.value("personas") else { return catalog.personas }
        let identifiers = requested.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return try identifiers.map { identifier in
            guard let persona = catalog.personas.first(where: { $0.id == identifier }) else {
                throw LabTypistPersonaError.unknownPersonaID(identifier)
            }
            return persona
        }
    }

    /// Concurrency only pays where a decision is a process or a round trip.
    /// The frozen heuristic is a local function call, so asking for workers
    /// there is a mistake worth naming rather than a no-op worth recording.
    static func decisionWorkers(_ arguments: CLIArguments) throws -> Int {
        let workers = try arguments.integer("decision-workers", default: 1)
        guard (1...LabSimulatedTypistConfiguration.maximumDecisionWorkers)
            .contains(workers) else {
            throw ResearchCLIError.invalidValue("--decision-workers")
        }
        guard workers == 1 || (arguments.value("policy") ?? "heuristic") == "external-command"
        else {
            throw ResearchCLIError.usage(
                "--decision-workers requires --policy external-command."
            )
        }
        return workers
    }

    /// A decision batch that fails after the policy's own retries is usually a
    /// provider hiccup, not a result — and today it costs the whole run. This
    /// allowance lets a run survive that many hiccups by abandoning the
    /// sessions those batches held, never by inventing a decision for them.
    /// Only an external command can hiccup: the frozen heuristic is a local
    /// function call, so a failure there is a bug worth aborting on, and asking
    /// for skips is a mistake worth naming rather than a no-op worth recording.
    static func skippedBatchAllowance(_ arguments: CLIArguments) throws -> Int {
        let allowance = try arguments.integer("skip-failed-batches", default: 0)
        guard (0...LabSimulatedTypistConfiguration.maximumSkippedBatches)
            .contains(allowance) else {
            throw ResearchCLIError.invalidValue("--skip-failed-batches")
        }
        guard allowance == 0 || (arguments.value("policy") ?? "heuristic") == "external-command"
        else {
            throw ResearchCLIError.usage(
                "--skip-failed-batches requires --policy external-command."
            )
        }
        return allowance
    }

    private static func decisionPolicy(
        _ arguments: CLIArguments
    ) throws -> any TypistDecisionPolicy {
        let batchSize = try arguments.integer("decision-batch-size", default: 1)
        guard (1...LabTypistMomentBatch.maximumSize).contains(batchSize) else {
            throw ResearchCLIError.invalidValue("--decision-batch-size")
        }
        switch arguments.value("policy") ?? "heuristic" {
        case "heuristic":
            guard arguments.value("decision-command") == nil else {
                throw ResearchCLIError.usage(
                    "--decision-command requires --policy external-command."
                )
            }
            // The frozen heuristic is a local function call; a batch would buy
            // nothing and would only blur what the recorded batch size means.
            guard batchSize == 1 else {
                throw ResearchCLIError.usage(
                    "--decision-batch-size requires --policy external-command."
                )
            }
            return DeterministicHeuristicTypist()
        case "external-command":
            let command = try arguments.requiredValue("decision-command")
            let extra = arguments.value("decision-argument").map { [$0] } ?? []
            return try ExternalCommandTypist(
                command: command, arguments: extra, batchSize: batchSize
            )
        default:
            throw ResearchCLIError.invalidValue("--policy")
        }
    }

    private static func emit(
        _ report: LabSimulatedTypistReport,
        arguments: CLIArguments
    ) throws {
        if let path = arguments.value("output") {
            let output = URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            guard !FileManager.default.fileExists(atPath: output.path) else {
                throw ResearchCLIError.usage(
                    "Refusing to overwrite existing report \(output.path)."
                )
            }
            try LabResearchArtifactIO.save(report, to: output)
            ResearchConsole.line("Wrote aggregate-only simulated-typist report: \(output.path)")
        } else if arguments.hasFlag("json") {
            try writeJSON(report)
        }
        ResearchConsole.line("Simulated typist over \(report.scenarioCount) scenarios")
        ResearchConsole.line("  decision policy: \(report.decisionPolicyIdentifier)")
        ResearchConsole.line("  decision batch size: \(report.decisionBatchSize)")
        ResearchConsole.line("  decision workers: \(report.decisionWorkers)")
        // Only when the run was pinned to a nominated arm: the default run's
        // summary stays exactly what it has always been.
        if let armPath = arguments.value("arm-file") {
            ResearchConsole.line(
                "  arm: \(report.arm.id) (from \(armPath.expandedResearchPath))"
            )
        }
        if let assets = report.assets {
            ResearchConsole.line(
                "  generation model: \(assets.modelIdentifier) @ \(assets.modelRevision) (\(assets.verificationMode.rawValue))"
            )
            ResearchConsole.line("  model SHA-256: \(assets.modelSHA256)")
            ResearchConsole.line("  helper SHA-256: \(assets.helperSHA256)")
        } else {
            ResearchConsole.line("  generation model: not fingerprinted")
        }
        // Loud on purpose. A run that abandoned part of its own sample must not
        // read like a complete one, in the report or on the way past.
        if report.hasSkippedBatches {
            ResearchConsole.line(
                "  !! SKIPPED DECISION BATCHES: \(report.skippedBatches) of \(report.skippedBatchAllowance) allowed"
            )
            ResearchConsole.line(
                "  !! ABANDONED SESSIONS (excluded from every persona aggregate): \(report.abandonedSessions)"
            )
            ResearchConsole.line(
                "  !! ABANDONED DECISION MOMENTS: \(report.abandonedMoments)"
            )
            ResearchConsole.line(
                "  !! this run covers less than the suite and persona set it names"
            )
        } else {
            ResearchConsole.line(
                "  skipped decision batches: 0 of \(report.skippedBatchAllowance) allowed"
            )
        }
        ResearchConsole.line(
            "  evidence: discovery-grade simulation (\(report.evidenceEligibility.reasons.map(\.rawValue).joined(separator: ", ")))"
        )
        for slice in report.personas {
            ResearchConsole.line("  \(slice.personaID) [\(slice.register.rawValue)/\(slice.typingSpeed.rawValue)]")
            if slice.abandonedScenarios > 0 {
                ResearchConsole.line(
                    "    !! \(slice.abandonedScenarios) abandoned scenario(s) excluded; the counts below cover \(slice.scenarios)"
                )
            }
            ResearchConsole.line(
                "    displays \(slice.displays); accept \(slice.simulatedAcceptanceRate.formatted(.percent.precision(.fractionLength(1)))); type-through \(slice.simulatedTypeThroughRate.formatted(.percent.precision(.fractionLength(1)))); wrong \(slice.simulatedWrongDisplayRate.formatted(.percent.precision(.fractionLength(1))))"
            )
            ResearchConsole.line(
                "    retained-character potential: \(slice.retainedCharacterPotential)/\(slice.baselineCharacters) (\(slice.retainedCharacterPotentialRate.formatted(.percent.precision(.fractionLength(1)))))"
            )
        }
        ResearchConsole.line("  raw writing data persisted: no")
        ResearchConsole.line("  limitation: \(report.limitation)")
    }
}
