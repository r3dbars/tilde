import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func holdout(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: [
                "campaign", "validation-plan", "candidate", "baseline", "output", "database",
            ],
            flags: ["confirm-consume"]
        )
        guard arguments.positionals.isEmpty, arguments.hasFlag("confirm-consume") else {
            throw ResearchCLIError.usage(help(for: "holdout"))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let validationURL = URL(fileURLWithPath: try arguments.requiredValue("validation-plan")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        let validation = try LabResearchArtifactIO.load(
            LabResearchPlan.self, from: validationURL
        ).validated()
        guard validation.sourceCampaignID == campaign.id,
              validation.manifest.research?.phase == .validation,
              let validationResearch = validation.manifest.research else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let validationLayout = LabResearchArtifactLayout(documentURL: validationURL)
        let validationComparisons = try loadComparisonArtifacts(layout: validationLayout)
            .filter {
                $0.campaignID == validation.id
                    && $0.comparison.phase == .validation
                    && $0.comparison.decision == .advance
            }
        let requestedCandidate = arguments.value("candidate")
        guard let passing = validationComparisons.first(where: {
            requestedCandidate == nil || $0.candidateArmID == requestedCandidate
        }) else { throw ResearchCLIError.protectedEvidenceRequired }
        let baselineID = arguments.value("baseline") ?? validationResearch.baselineArmID
        guard passing.baselineArmID == baselineID else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let reports = try await latestReports(
            manifest: validation.manifest,
            layout: validationLayout
        )
        guard let baselineReport = reports[baselineID],
              let candidateReport = reports[passing.candidateArmID],
              baselineReport.assets == candidateReport.assets else {
            throw ResearchCLIError.noComparableReports
        }

        let defaultOutput = validationURL.deletingLastPathComponent()
            .appendingPathComponent("\(passing.candidateArmID.researchSlug)-holdout-plan.json")
        let output = arguments.value("output").map {
            URL(fileURLWithPath: $0.expandedResearchPath).standardizedFileURL
        } ?? defaultOutput
        let plan: LabResearchPlan
        if FileManager.default.fileExists(atPath: output.path) {
            plan = try LabResearchArtifactIO.load(LabResearchPlan.self, from: output).validated()
            guard plan.sourceCampaignID == campaign.id,
                  plan.manifest.research?.phase == .holdout,
                  plan.manifest.arms.map(\.id) == [baselineID, passing.candidateArmID] else {
                throw ResearchCLIError.protectedEvidenceRequired
            }
        } else {
            plan = try LabResearchPlanBuilder.freeze(
                sourceCampaignID: campaign.id,
                name: "\(campaign.name) one-time holdout",
                phase: .holdout,
                experimentClass: validationResearch.experimentClass,
                baseline: baselineReport.arm,
                candidates: [candidateReport.arm],
                suite: try campaign.suite.load(),
                assets: baselineReport.assets,
                runtime: validation.manifest.runtime,
                runtimeByArm: validationResearch.runtimeByArm,
                promotionRule: validationResearch.promotionRule,
                utility: validationResearch.utility,
                primaryMetric: validationResearch.primaryMetric,
                fixedGenerationSeeds: validationResearch.fixedGenerationSeeds,
                sourceComparisonDigestsSHA256: [
                    try LabResearchPlanBuilder.comparisonDigest(passing.comparison),
                ]
            )
            try LabResearchArtifactIO.save(plan, to: output)
        }

        guard let holdoutResearch = plan.manifest.research,
              let frozen = holdoutResearch.frozenInputs else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let suite = try campaign.suite.load()
        let execution = campaign.model.execution(plan.manifest.runtime)
        let assets = try await LabAssetVerifier.shared.verify(execution)
        let selected = try plan.manifest.arms.map {
            try LabResearchScenarioSelection.select(
                from: suite,
                configuration: $0.scenarios,
                phase: plan.manifest.research!.phase
            )
        }
        let digests = try selected.map { try $0.digestSHA256() }
        try LabResearchProtocolValidator.validateExecution(
            research: holdoutResearch,
            arms: plan.manifest.arms,
            selectedSuites: selected,
            selectedSuiteDigests: digests,
            assets: assets
        )
        let database = try researchDatabase(arguments)
        try await database.registerCampaign(LabResearchCampaignRecord(
            id: plan.id,
            name: plan.manifest.name,
            manifestDigestSHA256: try plan.manifest.digestSHA256(),
            suiteDigestSHA256: frozen.suiteDigestSHA256,
            modelSHA256: assets.modelSHA256,
            helperSHA256: assets.helperSHA256,
            gitCommit: gitCommit(),
            protocolDefinition: holdoutResearch
        ))
        try await database.consumeHoldout(
            suiteDigestSHA256: frozen.suiteDigestSHA256,
            baselineArmDigestSHA256: try plan.manifest.arms[0].digestSHA256(),
            candidateArmDigestSHA256: try plan.manifest.arms[1].digestSHA256(),
            campaignID: plan.id,
            allowResume: true
        )
        ResearchConsole.line("Holdout receipt consumed; optimizer remains disabled.")
        let holdoutReports = try await runManifest(
            manifest: plan.manifest,
            campaignID: plan.id,
            campaignName: plan.manifest.name,
            documentURL: output,
            suite: suite,
            model: campaign.model,
            budget: campaign.budget,
            database: database,
            allowBattery: false,
            usesCandidateCache: false
        )
        ResearchConsole.line("One-time holdout complete: \(holdoutReports.count) reports")
        let comparisons = try await computeComparisons(
            manifest: plan.manifest,
            campaignID: plan.id,
            phase: .holdout,
            layout: LabResearchArtifactLayout(documentURL: output),
            database: database
        )
        for artifact in comparisons {
            ResearchConsole.line(
                "\(artifact.candidateArmID): \(artifact.comparison.decision.rawValue); holdout Δ utility \(artifact.comparison.deltaExpectedUtility.mean.formatted(.number.precision(.fractionLength(2))))"
            )
        }
        ResearchConsole.line("  plan: \(output.path)")
    }
}
