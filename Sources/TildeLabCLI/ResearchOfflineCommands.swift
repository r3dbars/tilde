import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func run(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["database"],
            flags: ["resume", "no-cache", "allow-battery"]
        )
        let url = try oneDocumentURL(arguments, command: "run")
        let campaign = try LabResearchCampaignFileIO.load(from: url)
        if campaign.manifest.research?.experimentClass == .personalization {
            throw ResearchCLIError.usage(
                "Use `tilde-lab personalization-replay`; ordinary model fixtures do not apply chronological personal history."
            )
        }
        if campaign.manifest.research?.experimentClass == .interaction {
            throw ResearchCLIError.usage(
                "Use the real macOS Interaction Scene Host or compatibility smoke; ordinary model fixtures do not exercise IMKit."
            )
        }
        let suite = try campaign.suite.load()
        try campaign.validated(with: suite)
        let reports = try await runManifest(
            manifest: campaign.manifest,
            campaignID: campaign.id,
            campaignName: campaign.name,
            documentURL: url,
            suite: suite,
            model: campaign.model,
            budget: campaign.budget,
            hypothesisID: campaign.hypothesisID,
            hypothesis: campaign.hypothesis,
            database: try researchDatabase(arguments),
            allowBattery: arguments.hasFlag("allow-battery"),
            usesCandidateCache: !arguments.hasFlag("no-cache"),
            resumeRequested: arguments.hasFlag("resume")
        )
        ResearchConsole.line("Campaign complete: \(reports.count) aggregate reports")
        for report in reports {
            let evidence = report.effectiveEvidenceEligibility
            ResearchConsole.line(
                "  \(report.arm.id): \(report.displayScore); \(report.metrics.useful) useful; \(report.metrics.wrong + report.metrics.unwanted) bad; p95 \(report.metrics.latency.p95Milliseconds.map(String.init) ?? "n/a") ms"
            )
            ResearchConsole.line(
                "    evidence: \(evidence.eligible ? "decision-grade" : evidence.reasons.map(\.rawValue).joined(separator: ", "))"
            )
            if let startup = report.runtimeStartup {
                ResearchConsole.line(
                    "    cold-start p50/p95/p99: \(startup.p50Milliseconds.map(String.init) ?? "n/a")/\(startup.p95Milliseconds.map(String.init) ?? "n/a")/\(startup.p99Milliseconds.map(String.init) ?? "n/a") ms (\(startup.samples) blocks)"
                )
            }
        }
    }

    static func review(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "status", "conclusion", "database"])
        let documentURL = try campaignURL(arguments, command: "review")
        let evidenceID: UUID
        if let campaign = try? LabResearchCampaignFileIO.load(from: documentURL) {
            evidenceID = campaign.id
        } else {
            evidenceID = try LabResearchArtifactIO.load(
                LabResearchPlan.self,
                from: documentURL
            ).validated().id
        }
        guard let status = LabReportReviewStatus(
            rawValue: try arguments.requiredValue("status")
        ), status != .unreviewed else {
            throw ResearchCLIError.invalidValue("--status")
        }
        let conclusion = try arguments.requiredValue("conclusion")
        let layout = LabResearchArtifactLayout(documentURL: documentURL)
        let store = LabReportStore(directory: layout.reportsDirectory)
        let database = try researchDatabase(arguments)
        let snapshot = try await database.reconciledSnapshot(campaignID: evidenceID)
        if snapshot.terminalFailure != nil {
            let failure = try await database.reviewTerminalFailure(
                campaignID: evidenceID,
                status: status,
                conclusion: conclusion
            )
            ResearchConsole.line("Reviewed aggregate terminal failure")
            ResearchConsole.line("  category: \(failure.category.rawValue)")
            ResearchConsole.line("  status: \(failure.review.status.rawValue)")
            ResearchConsole.line("  raw writing data persisted: no")
            return
        }
        let reports = await store.loadAll().filter {
            $0.provenance?.campaignID == evidenceID
        }
        guard !reports.isEmpty else {
            throw ResearchCLIError.missingArtifact("provenance-bearing campaign reports")
        }
        for report in reports {
            try await store.save(try report.reviewed(conclusion: conclusion, status: status))
        }
        let reviewedReports = await store.loadAll().filter {
            $0.provenance?.campaignID == evidenceID
        }
        ResearchConsole.line("Reviewed \(reports.count) campaign reports")
        ResearchConsole.line("  status: \(status.rawValue)")
        ResearchConsole.line(
            "  decision-grade: \(reviewedReports.filter { $0.effectiveEvidenceEligibility.eligible }.count)/\(reviewedReports.count)"
        )
        ResearchConsole.line("  raw writing data persisted: no")
    }

    static func compare(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "paired-bootstrap", "database"]
        )
        let url = try campaignURL(arguments, command: "compare")
        let manifest: LabExperimentManifest
        let campaignID: UUID
        let phase: LabCampaignPhase
        if let campaign = try? LabResearchCampaignFileIO.load(from: url) {
            manifest = campaign.manifest
            campaignID = campaign.id
            phase = campaign.manifest.research?.phase ?? .discovery
        } else {
            let plan = try LabResearchArtifactIO.load(
                LabResearchPlan.self,
                from: url
            ).validated()
            manifest = plan.manifest
            campaignID = plan.id
            guard let planPhase = plan.manifest.research?.phase else {
                throw LabResearchDatabaseError.durableProtocolRequired
            }
            phase = planPhase
        }
        let iterations = try arguments.integer("paired-bootstrap", default: 10_000)
        let artifacts = try await computeComparisons(
            manifest: manifest,
            campaignID: campaignID,
            phase: phase,
            layout: LabResearchArtifactLayout(documentURL: url),
            database: try researchDatabase(arguments),
            bootstrapIterations: iterations
        )
        printComparisons(artifacts)
    }

    static func riskCoverage(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "arm", "trust-limit", "output"],
            flags: ["json"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "risk-coverage"))
        }
        let campaignURL = try campaignURL(arguments, command: "risk-coverage")
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        let armID = try arguments.requiredValue("arm")
        guard campaign.manifest.arms.contains(where: { $0.id == armID }) else {
            throw ResearchCLIError.invalidValue("--arm")
        }
        let trustLimit = try arguments.double("trust-limit", default: 0.01)
        guard (0...1).contains(trustLimit) else {
            throw ResearchCLIError.invalidValue("--trust-limit")
        }
        let reports = try await latestReports(
            manifest: campaign.manifest,
            layout: LabResearchArtifactLayout(documentURL: campaignURL)
        )
        guard let report = reports[armID] else {
            throw ResearchCLIError.missingArtifact("complete report for arm \(armID)")
        }
        let layout = LabResearchArtifactLayout(documentURL: campaignURL)
        let artifact: LabRiskCoverageReport
        if FileManager.default.fileExists(atPath: layout.candidateCacheURL.path),
           let research = campaign.manifest.research {
            artifact = try await LabRiskCoverageAnalyzer.completeSyntheticReplay(
                report: report,
                suite: campaign.suite.load(),
                protocolDefinition: research,
                runtime: campaign.manifest.runtime,
                cache: try LabSyntheticCandidateCache(fileURL: layout.candidateCacheURL),
                trustLimit: trustLimit
            )
        } else {
            artifact = LabPairedComparison.observedRiskCoverage(
                report: report,
                trustLimit: trustLimit,
                utility: campaign.manifest.research?.utility ?? .init()
            )
        }
        guard artifact.scoredCandidateCount > 0 else {
            throw ResearchCLIError.usage(
                "Arm \(armID) has no scored token-probability evidence. Set probabilityCount before running the campaign."
            )
        }
        if let path = arguments.value("output") {
            let output = URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            guard !FileManager.default.fileExists(atPath: output.path) else {
                throw ResearchCLIError.usage("Refusing to overwrite existing report \(output.path).")
            }
            try LabResearchArtifactIO.save(artifact, to: output)
            ResearchConsole.line("Wrote aggregate-only risk-coverage report: \(output.path)")
        } else if arguments.hasFlag("json") {
            try writeJSON(artifact)
        } else {
            ResearchConsole.line("Risk-coverage for \(armID)")
            ResearchConsole.line(
                "  candidate replay: \(artifact.completeCandidateReplay ? "complete synthetic cache" : "observed shown candidates only")"
            )
            ResearchConsole.line("  scored candidates: \(artifact.scoredCandidateCount)/\(artifact.eligibleOpportunities)")
            if let point = artifact.highestCoverageUnderTrustLimit {
                ResearchConsole.line(
                    "  trust limit: \(trustLimit.formatted(.percent.precision(.fractionLength(2))))"
                )
                ResearchConsole.line(
                    "  highest trusted coverage: \(point.coverage.formatted(.percent.precision(.fractionLength(1)))) at threshold \(point.threshold.formatted(.number.precision(.fractionLength(2))))"
                )
                ResearchConsole.line(
                    "  precision/bad/upper95: \(point.precisionWhenShown.formatted(.percent.precision(.fractionLength(1)))) / \(point.badWhenShown.formatted(.percent.precision(.fractionLength(2)))) / \(point.badWhenShownUpper95Wilson.formatted(.percent.precision(.fractionLength(2))))"
                )
                ResearchConsole.line(
                    "  expected utility: \(point.expectedUtilityMillisecondsPer1000Characters.formatted(.number.precision(.fractionLength(1)))) ms / 1,000 chars"
                )
            } else {
                ResearchConsole.line("  no observed threshold satisfies the trust limit")
            }
            ResearchConsole.line("  limitation: \(artifact.limitation)")
        }
    }

    static func personalizationReplay(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["input", "scope", "evaluation-start-ms", "output"],
            flags: ["json"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "personalization-replay"))
        }
        let input = URL(fileURLWithPath: try arguments.requiredValue("input")
            .expandedResearchPath).standardizedFileURL
        guard let scope = LabPersonalHistoryScope(
            rawValue: arguments.value("scope") ?? LabPersonalHistoryScope.appThenGlobal.rawValue
        ) else { throw ResearchCLIError.invalidValue("--scope") }
        let evaluationStart: Int64
        if let raw = arguments.value("evaluation-start-ms") {
            guard let parsed = Int64(raw), parsed >= 0 else {
                throw ResearchCLIError.invalidValue("--evaluation-start-ms")
            }
            evaluationStart = parsed
        } else {
            evaluationStart = 0
        }
        let events = try LabPersonalHistoryReplayLoader.loadJSONLines(from: input)
        let report = try LabChronologicalPersonalization.evaluate(
            events: events,
            configuration: LabPersonalizationConfiguration(enabled: true, scope: scope),
            evaluationStartMilliseconds: evaluationStart
        )
        if let path = arguments.value("output") {
            let output = URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            guard !FileManager.default.fileExists(atPath: output.path) else {
                throw ResearchCLIError.usage("Refusing to overwrite existing report \(output.path).")
            }
            try LabResearchArtifactIO.save(report, to: output)
            ResearchConsole.line(
                "Wrote aggregate-only chronological personalization report: \(output.path)"
            )
        } else if arguments.hasFlag("json") {
            try writeJSON(report)
        } else {
            ResearchConsole.line("Chronological personalization replay")
            ResearchConsole.line("  events: \(report.eventCount); apps: \(report.distinctApplications)")
            ResearchConsole.line("  future-history violations: \(report.futureHistoryViolations)")
            ResearchConsole.line("  selected scope: \(report.selectedScope.rawValue)")
            ResearchConsole.line(
                "  precision: \(report.selected.personalPrecision.formatted(.percent.precision(.fractionLength(1)))); coverage: \(report.selected.personalCoverage.formatted(.percent.precision(.fractionLength(1))))"
            )
            ResearchConsole.line("  personal lift/harm: \(report.personalLift)/\(report.personalHarm)")
            ResearchConsole.line("  raw event text persisted: no")
            ResearchConsole.line("  limitation: \(report.limitation)")
        }
    }

    static func advanceSearch(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "stage", "candidates", "output"]
        )
        let url = try campaignURL(arguments, command: "advance-search")
        let campaign = try LabResearchCampaignFileIO.load(from: url)
        let suite = try campaign.suite.load()
        try campaign.validated(with: suite)
        guard let research = campaign.manifest.research,
              research.experimentClass == .generator,
              let baseline = campaign.manifest.arms.first(where: {
                  $0.id == research.baselineArmID
              }) else {
            throw ResearchCLIError.usage("Staged search currently requires a generator campaign.")
        }
        let reports = try await latestReports(
            manifest: campaign.manifest,
            layout: LabResearchArtifactLayout(documentURL: url)
        )
        guard reports.count == campaign.manifest.arms.count else {
            throw ResearchCLIError.usage(
                "Every arm must have a complete matching report before search can advance. Resume the campaign first."
            )
        }
        let observations = campaign.manifest.arms.compactMap { arm -> LabSearchTrialObservation? in
            guard arm.id != baseline.id, let report = reports[arm.id] else { return nil }
            return searchObservation(report: report)
        }
        guard !observations.isEmpty else { throw ResearchCLIError.noComparableReports }
        let stage = arguments.value("stage") ?? "halving"
        let nextArms: [LabArmConfiguration]
        let strategy: LabSearchStrategy
        switch stage {
        case "halving", "successive-halving":
            let survivors = try LabStagedSearchPlanner.successiveHalvingSurvivors(observations)
            nextArms = [baseline] + survivors.map(\.arm)
            strategy = .successiveHalving
        case "adaptive", "adaptive-local":
            try LabStagedSearchPlanner.assertOptimizerAllowed(phase: research.phase)
            let count = try arguments.integer("candidates", default: 8)
            nextArms = [baseline] + (try LabStagedSearchPlanner.adaptiveLocalArms(
                observations: observations,
                baseline: baseline,
                candidateCount: count,
                sequenceOffset: observations.count
            ))
            strategy = .adaptive
        default:
            throw ResearchCLIError.invalidValue("--stage")
        }
        var nextResearch = research
        nextResearch.searchStrategy = strategy
        nextResearch.frozenInputs = nil
        let childName = "\(campaign.name) \(stage)"
        let child = LabResearchCampaignFile(
            name: childName,
            hypothesisID: campaign.hypothesisID,
            hypothesis: campaign.hypothesis,
            parentCampaignID: campaign.id,
            suite: campaign.suite,
            manifest: LabExperimentManifest(
                name: childName,
                enabledBenches: campaign.manifest.enabledBenches,
                arms: nextArms,
                runtime: campaign.manifest.runtime,
                research: nextResearch
            ),
            budget: campaign.budget,
            model: campaign.model
        )
        try child.validated(with: suite)
        let output = URL(fileURLWithPath: (
            arguments.value("output") ?? "\(childName.researchSlug).json"
        ).expandedResearchPath).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing campaign \(output.path).")
        }
        try LabResearchCampaignFileIO.save(child, to: output)
        ResearchConsole.line("Created \(stage) child campaign")
        ResearchConsole.line("  arms: \(nextArms.count)")
        ResearchConsole.line("  file: \(output.path)")
    }

    static func nominate(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "top", "output", "database"]
        )
        let url = try campaignURL(arguments, command: "nominate")
        let outputValue = try arguments.requiredValue("output")
        let output = URL(fileURLWithPath: outputValue.expandedResearchPath).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing plan \(output.path).")
        }
        let campaign = try LabResearchCampaignFileIO.load(from: url)
        let top = try arguments.integer("top", default: 3)
        guard (1...3).contains(top), let research = campaign.manifest.research else {
            throw ResearchCLIError.invalidValue("--top")
        }
        let layout = LabResearchArtifactLayout(documentURL: url)
        let database = try researchDatabase(arguments)
        let comparisons = try await computeComparisons(
            manifest: campaign.manifest,
            campaignID: campaign.id,
            phase: .discovery,
            layout: layout,
            database: database
        )
        let promoted = comparisons.filter { $0.comparison.decision == .advance }.prefix(top)
        guard !promoted.isEmpty else { throw ResearchCLIError.noPromotableCandidate }
        let reports = try await latestReports(manifest: campaign.manifest, layout: layout)
        guard let baselineReport = reports[research.baselineArmID] else {
            throw ResearchCLIError.noComparableReports
        }
        let candidates = try promoted.map { artifact -> LabArmConfiguration in
            guard let report = reports[artifact.candidateArmID] else {
                throw ResearchCLIError.noComparableReports
            }
            guard report.assets == baselineReport.assets else {
                throw LabResearchProtocolError.frozenInputMismatch
            }
            return report.arm
        }
        let comparisonDigests = try promoted.map {
            try LabResearchPlanBuilder.comparisonDigest($0.comparison)
        }
        let plan = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: campaign.id,
            name: "\(campaign.name) frozen validation",
            phase: .validation,
            experimentClass: research.experimentClass,
            baseline: baselineReport.arm,
            candidates: candidates,
            suite: try campaign.suite.load(),
            assets: baselineReport.assets,
            runtime: campaign.manifest.runtime,
            runtimeByArm: research.runtimeByArm,
            promotionRule: research.promotionRule,
            utility: research.utility,
            primaryMetric: research.primaryMetric,
            fixedGenerationSeeds: research.fixedGenerationSeeds,
            sourceComparisonDigestsSHA256: comparisonDigests
        )
        try LabResearchArtifactIO.save(plan, to: output)
        for (artifact, candidate) in zip(promoted, candidates) {
            try await database.recordPromotion(
                campaignID: campaign.id,
                armDigestSHA256: try candidate.digestSHA256(),
                fromPhase: .discovery,
                toPhase: .validation,
                decision: artifact.comparison.decision.rawValue
            )
        }
        ResearchConsole.line("Frozen validation plan")
        ResearchConsole.line("  candidates: \(candidates.map(\.id).joined(separator: ", "))")
        ResearchConsole.line("  optimizer: disabled")
        ResearchConsole.line("  file: \(output.path)")
    }

    static func validateCandidates(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "database"])
        let planURL = try oneDocumentURL(arguments, command: "validate-candidates")
        let campaignValue = try arguments.requiredValue("campaign")
        let campaignURL = URL(fileURLWithPath: campaignValue.expandedResearchPath)
            .standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        let plan = try LabResearchArtifactIO.load(LabResearchPlan.self, from: planURL).validated()
        guard plan.sourceCampaignID == campaign.id,
              plan.manifest.research?.phase == .validation else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let database = try researchDatabase(arguments)
        let reports = try await runManifest(
            manifest: plan.manifest,
            campaignID: plan.id,
            campaignName: plan.manifest.name,
            documentURL: planURL,
            suite: try campaign.suite.load(),
            model: campaign.model,
            budget: campaign.budget,
            hypothesisID: campaign.hypothesisID,
            hypothesis: campaign.hypothesis,
            database: database,
            allowBattery: false,
            usesCandidateCache: false
        )
        ResearchConsole.line("Frozen validation complete: \(reports.count) reports")
        guard reports.allSatisfy({ $0.effectiveEvidenceEligibility.eligible }) else {
            ResearchConsole.line(
                "  comparison pending: review the plan reports, then run `tilde-lab compare --campaign \(planURL.path)`"
            )
            return
        }
        let comparisons = try await computeComparisons(
            manifest: plan.manifest,
            campaignID: plan.id,
            phase: .validation,
            layout: LabResearchArtifactLayout(documentURL: planURL),
            database: database
        )
        printComparisons(comparisons)
    }

    private static func printComparisons(_ artifacts: [LabResearchComparisonArtifact]) {
        for artifact in artifacts {
            let comparison = artifact.comparison
            let delta = comparison.deltaExpectedUtility
            ResearchConsole.line(
                "\(artifact.candidateArmID): \(comparison.decision.rawValue); Δ utility \(delta.mean.formatted(.number.precision(.fractionLength(2)))) [\(delta.lower95.formatted(.number.precision(.fractionLength(2)))), \(delta.upper95.formatted(.number.precision(.fractionLength(2))))]; P(>0)=\(delta.probabilityPositive.formatted(.percent.precision(.fractionLength(1)))); roots=\(comparison.independentRootCount)"
            )
            if let seed = comparison.worstSeed, comparison.seedComparisons.count > 1 {
                ResearchConsole.line(
                    "  worst seed \(seed.generationSeed): Δ utility \(seed.deltaExpectedUtility.formatted(.number.precision(.fractionLength(2)))); Δ bad/show \(seed.deltaBadWhenShown.formatted(.percent.precision(.fractionLength(2))))"
                )
            }
        }
    }

    private static func searchObservation(report: LabRunReport) -> LabSearchTrialObservation {
        let roots = Set(report.cases.map { $0.rootScenarioID ?? $0.scenarioID }).count
        let selective = LabSelectivePredictionMetrics(cases: report.cases)
        return LabSearchTrialObservation(
            arm: report.arm,
            stage: .spaceFilling,
            completedRoots: roots,
            plannedRoots: roots,
            hardGatesPassed: report.metrics.complete
                && report.metrics.promotionGateFailures.isEmpty
                && report.arm.judgment.cleanerPreset != .diagnostic,
            expectedUtility: selective.expectedUtilityMillisecondsPer1000Characters,
            oracleNetKeystrokeSavings: selective.oracleNetKeystrokeSavingsRate,
            precisionWhenShown: selective.precisionWhenShown,
            badWhenShown: selective.badWhenShown,
            lateRate: selective.lateRate,
            p95LatencyMilliseconds: Double(report.metrics.latency.p95Milliseconds ?? 0)
        )
    }
}
