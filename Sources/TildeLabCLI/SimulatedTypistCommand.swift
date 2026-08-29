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
                "scenarios", "stride", "maximum-displays", "helper", "model-file",
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
        configuration.strideCharacters = try arguments.integer("stride", default: 4)
        configuration.maximumDisplaysPerScenario = try arguments.integer(
            "maximum-displays", default: 8
        )

        let model = try modelConfiguration(arguments)
        let runtime = LabRuntimeConfiguration(
            workerCount: try arguments.integer("workers", default: 1),
            slotsPerWorker: try arguments.integer("slots", default: 1),
            repetitions: 1
        )
        let pool = LabLlamaServerPool()
        defer { Task { await pool.stop() } }
        let clients = try await pool.start(configuration: model.execution(runtime))
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
            )
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

    private static func decisionPolicy(
        _ arguments: CLIArguments
    ) throws -> any TypistDecisionPolicy {
        switch arguments.value("policy") ?? "heuristic" {
        case "heuristic":
            guard arguments.value("decision-command") == nil else {
                throw ResearchCLIError.usage(
                    "--decision-command requires --policy external-command."
                )
            }
            return DeterministicHeuristicTypist()
        case "external-command":
            let command = try arguments.requiredValue("decision-command")
            let extra = arguments.value("decision-argument").map { [$0] } ?? []
            return try ExternalCommandTypist(command: command, arguments: extra)
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
        ResearchConsole.line(
            "  evidence: discovery-grade simulation (\(report.evidenceEligibility.reasons.map(\.rawValue).joined(separator: ", ")))"
        )
        for slice in report.personas {
            ResearchConsole.line("  \(slice.personaID) [\(slice.register.rawValue)/\(slice.typingSpeed.rawValue)]")
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
