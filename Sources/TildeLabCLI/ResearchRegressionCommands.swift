import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func freezeRegression(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: [
            "campaign", "candidate", "suite", "partition", "evidence-digest", "output",
        ])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "freeze-regression"))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let candidateID = try arguments.requiredValue("candidate")
        let reports = try await latestReports(
            manifest: campaign.manifest,
            layout: LabResearchArtifactLayout(documentURL: campaignURL)
        )
        guard let baseline = reports[research.baselineArmID],
              let candidate = reports[candidateID],
              candidateID != research.baselineArmID,
              baseline.effectiveEvidenceEligibility.eligible,
              candidate.effectiveEvidenceEligibility.eligible,
              baseline.assets == candidate.assets else {
            throw ResearchCLIError.noComparableReports
        }
        let suiteReference = try suiteReference(try arguments.requiredValue("suite"))
        let suite = try suiteReference.load()
        guard let partition = LabScenarioPartition(
            rawValue: arguments.value("partition") ?? LabScenarioPartition.regression.rawValue
        ), partition == .regression || partition == .adversarial else {
            throw ResearchCLIError.invalidValue("--partition")
        }
        let evidence = try arguments.requiredValue("evidence-digest")
        guard evidence.range(
            of: "^[a-f0-9]{64}$", options: .regularExpression
        ) == evidence.startIndex..<evidence.endIndex else {
            throw ResearchCLIError.invalidValue("--evidence-digest")
        }
        let plan = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: campaign.id,
            name: "\(campaign.name) permanent regression",
            phase: .regression,
            experimentClass: research.experimentClass,
            baseline: baseline.arm,
            candidates: [candidate.arm],
            suite: suite,
            assets: baseline.assets,
            runtime: campaign.manifest.runtime,
            runtimeByArm: research.runtimeByArm,
            suiteReference: suiteReference,
            regressionPartition: partition,
            promotionRule: research.promotionRule,
            utility: research.utility,
            primaryMetric: research.primaryMetric,
            fixedGenerationSeeds: research.fixedGenerationSeeds,
            sourceFailureEvidenceDigestsSHA256: [evidence]
        )
        let output = URL(fileURLWithPath: try arguments.requiredValue("output")
            .expandedResearchPath).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing regression plan \(output.path).")
        }
        try LabResearchArtifactIO.save(plan, to: output)
        ResearchConsole.line("Frozen permanent regression plan")
        ResearchConsole.line("  candidate: \(candidateID)")
        ResearchConsole.line("  partition: \(partition.rawValue)")
        ResearchConsole.line("  suite digest: \(plan.manifest.research!.frozenInputs!.suiteDigestSHA256)")
        ResearchConsole.line("  failure evidence: \(evidence)")
        ResearchConsole.line("  file: \(output.path)")
    }

    static func runRegression(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "database"])
        let planURL = try oneDocumentURL(arguments, command: "regression")
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        let plan = try LabResearchArtifactIO.load(
            LabResearchPlan.self, from: planURL
        ).validated()
        guard plan.sourceCampaignID == campaign.id,
              let research = plan.manifest.research,
              research.phase == .regression,
              let suiteReference = plan.suiteReference else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let reports = try await runManifest(
            manifest: plan.manifest,
            campaignID: plan.id,
            campaignName: plan.manifest.name,
            documentURL: planURL,
            suite: try suiteReference.load(),
            model: campaign.model,
            budget: campaign.budget,
            hypothesisID: campaign.hypothesisID,
            hypothesis: campaign.hypothesis,
            database: try researchDatabase(arguments),
            allowBattery: false,
            usesCandidateCache: false
        )
        guard let candidate = reports.first(where: { $0.arm.id != research.baselineArmID }) else {
            throw ResearchCLIError.noComparableReports
        }
        let failures = candidate.cases.filter {
            !($0.outcome == .useful || $0.outcome == .correctSilence)
                || !$0.temporalIntegrityPassed
                || $0.forbiddenTermViolation
        }
        guard candidate.metrics.complete,
              candidate.metrics.promotionGateFailures.isEmpty,
              failures.isEmpty else {
            throw ResearchCLIError.regressionFailed(
                armID: candidate.arm.id,
                failedCases: failures.count,
                gates: candidate.metrics.promotionGateFailures
            )
        }
        ResearchConsole.line("Permanent regression passed")
        ResearchConsole.line("  candidate: \(candidate.arm.id)")
        ResearchConsole.line("  cases: \(candidate.cases.count)")
        ResearchConsole.line("  failure evidence: \(plan.sourceFailureEvidenceDigestsSHA256!.joined(separator: ","))")
    }
}
