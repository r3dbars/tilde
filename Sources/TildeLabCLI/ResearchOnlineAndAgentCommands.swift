import Foundation
import TildeLabKit

extension ResearchCoordinator {
    static func configureOnline(
        _ arguments: CLIArguments,
        phase: LabCampaignPhase
    ) async throws {
        let isShadow = phase == .shadow
        let isSoak = phase == .soak
        let challengerOption = isShadow || isSoak ? "candidate" : "challenger"
        try arguments.assertAllowed(options: [
            "campaign", challengerOption, "champion", "holdout-plan", "days", "hours",
            "allocation", "holdback", "minimum-events", "database",
        ])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: phase.rawValue))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let challengerID = try arguments.requiredValue(challengerOption)
        let championID = arguments.value("champion") ?? research.baselineArmID
        guard let champion = campaign.manifest.arms.first(where: { $0.id == championID }),
              let challenger = campaign.manifest.arms.first(where: { $0.id == challengerID }) else {
            throw ResearchCLIError.invalidValue("champion/challenger arm ID")
        }
        let holdoutURL = URL(fileURLWithPath: try arguments.requiredValue("holdout-plan")
            .expandedResearchPath).standardizedFileURL
        let evidenceDigest = try await passingHoldoutEvidence(
            planURL: holdoutURL,
            sourceCampaignID: campaign.id,
            championID: championID,
            challengerID: challengerID
        )
        let durationSeconds: Double
        let minimumEvents: Int?
        if isSoak {
            let hours = try arguments.double("hours", default: 4)
            guard (1.0 / 60...168).contains(hours), arguments.value("days") == nil else {
                throw ResearchCLIError.invalidValue("--hours")
            }
            durationSeconds = hours * 3_600
            let count = try arguments.integer("minimum-events", default: 100)
            guard (1...10_000_000).contains(count) else {
                throw ResearchCLIError.invalidValue("--minimum-events")
            }
            minimumEvents = count
        } else {
            let days = try arguments.integer("days", default: isShadow ? 3 : 7)
            guard (1...31).contains(days), arguments.value("hours") == nil,
                  arguments.value("minimum-events") == nil else {
                throw ResearchCLIError.invalidValue("--days")
            }
            durationSeconds = Double(days) * 86_400
            minimumEvents = nil
        }
        let startsAt = Date()
        let plan = try LabOnlineExperimentPlan(
            campaignID: campaign.id,
            phase: phase,
            championArmID: championID,
            championArmDigestSHA256: try champion.digestSHA256(),
            challengerArmID: challengerID,
            challengerArmDigestSHA256: try challenger.digestSHA256(),
            challengerAllocation: isShadow ? 0 : isSoak
                ? 1 : try arguments.double("allocation", default: 0.10),
            attentionHoldbackRate: isShadow || isSoak
                ? 0 : try arguments.double("holdback", default: 0.10),
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(durationSeconds),
            safetyEvidenceDigestSHA256: evidenceDigest,
            minimumObservedDurationSeconds: isSoak ? durationSeconds : nil,
            minimumEventCount: minimumEvents
        ).validated()
        let database = try researchDatabase(arguments)
        try await ensureCampaignRegistered(campaign, database: database)
        if !(try await database.onlineEvents(campaignID: campaign.id)).isEmpty {
            throw ResearchCLIError.usage(
                "An earlier online phase still has events. Save its report, then use delete-telemetry before replacing the plan."
            )
        }
        try await database.saveOnlinePlan(plan)
        ResearchConsole.line("Created \(phase.rawValue) plan")
        ResearchConsole.line("  champion: \(championID)")
        ResearchConsole.line("  challenger: \(challengerID)")
        ResearchConsole.line("  allocation: \((plan.challengerAllocation * 100).formatted(.number.precision(.fractionLength(1))))%")
        ResearchConsole.line("  raw text fields: structurally unavailable")
        ResearchConsole.line("  next: ingest local text-free events with `tilde-lab ingest-events`")
    }

    static func ingestEvents(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "input", "database"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "ingest-events"))
        }
        let campaign = try campaignFromOption(arguments)
        let input = URL(fileURLWithPath: try arguments.requiredValue("input")
            .expandedResearchPath).standardizedFileURL
        let values = try input.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) <= 64 * 1_024 * 1_024 else {
            throw ResearchCLIError.invalidValue("--input")
        }
        let database = try researchDatabase(arguments)
        guard let plan = try await database.onlinePlan(campaignID: campaign.id) else {
            throw ResearchCLIError.missingArtifact("online plan")
        }
        let bytes = try Data(contentsOf: input, options: [.mappedIfSafe])
        let lines = bytes.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard lines.count <= 1_000_000 else { throw ResearchCLIError.invalidValue("--input") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var accepted = 0
        for line in lines {
            guard line.count <= 64 * 1_024 else { throw ResearchCLIError.invalidValue("event line") }
            let data = Data(line)
            try validateOnlineEventKeys(data)
            let event = try decoder.decode(LabOnlineExperimentEvent.self, from: data)
            try await database.recordOnlineEvent(event, plan: plan)
            accepted += 1
        }
        ResearchConsole.line("Ingested \(accepted) text-free local events.")
    }

    static func onlineReport(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "database"], flags: ["json"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "online-report"))
        }
        let campaign = try campaignFromOption(arguments)
        let events = try await researchDatabase(arguments).onlineEvents(campaignID: campaign.id)
        guard !events.isEmpty else { throw ResearchCLIError.missingArtifact("online events") }
        let report = try LabOnlineExperimentAnalyzer.analyze(events)
        if arguments.hasFlag("json") {
            try writeJSON(report)
        } else {
            ResearchConsole.line("Online utility report")
            ResearchConsole.line("  safe opportunities: \(report.safeOpportunities)")
            ResearchConsole.line("  displayed: \(report.displayed)")
            ResearchConsole.line("  acceptance when shown: \(report.acceptanceRateWhenShown.formatted(.percent.precision(.fractionLength(1))))")
            ResearchConsole.line("  undo/correction when shown: \(report.undoOrCorrectionRateWhenShown.formatted(.percent.precision(.fractionLength(1))))")
            ResearchConsole.line("  deadline miss rate: \(report.deadlineMissRate.formatted(.percent.precision(.fractionLength(1))))")
            ResearchConsole.line("  attention tax: \(report.attentionTax.attentionTaxMilliseconds.map { $0.formatted(.number.precision(.fractionLength(1))) + " ms" } ?? "not estimable")")
            ResearchConsole.line("  net time saved / 1,000 chars: \(report.netTimeSavedPer1000Characters.formatted(.number.precision(.fractionLength(1)))) ms")
            if let calibration = report.confidenceCalibration {
                ResearchConsole.line(
                    "  confidence ECE raw/calibrated: \(calibration.rawExpectedCalibrationError.formatted(.percent.precision(.fractionLength(2)))) / \(calibration.calibratedExpectedCalibrationError.formatted(.percent.precision(.fractionLength(2))))"
                )
            }
        }
    }

    static func confidenceReport(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(
            options: ["campaign", "database", "output"],
            flags: ["json"]
        )
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "confidence-report"))
        }
        let campaign = try campaignFromOption(arguments)
        let events = try await researchDatabase(arguments).onlineEvents(campaignID: campaign.id)
        let report = try LabConfidenceCalibrator.calibrate(events)
        if let path = arguments.value("output") {
            let output = URL(fileURLWithPath: path.expandedResearchPath).standardizedFileURL
            guard !FileManager.default.fileExists(atPath: output.path) else {
                throw ResearchCLIError.usage(
                    "Refusing to overwrite existing confidence report \(output.path)."
                )
            }
            try LabResearchArtifactIO.save(report, to: output)
            ResearchConsole.line("Wrote aggregate-only confidence report: \(output.path)")
        } else if arguments.hasFlag("json") {
            try writeJSON(report)
        } else {
            ResearchConsole.line("Chronological confidence calibration")
            ResearchConsole.line(
                "  eligible/train/validation: \(report.eligibleEvents)/\(report.trainingEvents)/\(report.validationEvents)"
            )
            ResearchConsole.line(
                "  acceptance: \(report.empiricalAcceptanceRate.formatted(.percent.precision(.fractionLength(1))))"
            )
            ResearchConsole.line(
                "  ECE raw/calibrated: \(report.rawExpectedCalibrationError.formatted(.percent.precision(.fractionLength(2)))) / \(report.calibratedExpectedCalibrationError.formatted(.percent.precision(.fractionLength(2))))"
            )
            ResearchConsole.line(
                "  Brier raw/calibrated: \(report.rawBrierScore.formatted(.number.precision(.fractionLength(3)))) / \(report.calibratedBrierScore.formatted(.number.precision(.fractionLength(3))))"
            )
            ResearchConsole.line("  isotonic knots: \(report.isotonicKnots.count)")
            ResearchConsole.line("  limitation: \(report.limitation)")
        }
    }

    static func soakReport(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "database"], flags: ["json"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "soak-report"))
        }
        let campaign = try campaignFromOption(arguments)
        let database = try researchDatabase(arguments)
        guard let plan = try await database.onlinePlan(campaignID: campaign.id),
              plan.phase == .soak else {
            throw ResearchCLIError.missingArtifact("active soak plan")
        }
        let events = try await database.onlineEvents(campaignID: campaign.id)
        guard !events.isEmpty else { throw ResearchCLIError.missingArtifact("soak events") }
        let report = try LabOnlineExperimentAnalyzer.analyzeSoak(events, plan: plan)
        if arguments.hasFlag("json") {
            try writeJSON(report)
        } else {
            ResearchConsole.line("Soak \(report.passed ? "passed" : "not yet passing")")
            ResearchConsole.line(
                "  active duration: \(formatHours(report.observedDurationSeconds))/\(formatHours(report.requiredDurationSeconds)) hours"
            )
            ResearchConsole.line("  events: \(report.eventCount)/\(report.requiredEventCount)")
            ResearchConsole.line(
                "  crash/timeout/wrong insertion/corruption/egress: \(report.operational.crashes)/\(report.operational.timeouts)/\(report.operational.wrongInsertions)/\(report.operational.insertionCorruptions)/\(report.operational.networkEgressViolations)"
            )
            ResearchConsole.line(
                "  first-stable-word p99: \(report.operational.p99FirstStableWordMilliseconds.map(String.init) ?? "n/a") ms"
            )
            ResearchConsole.line("  failures: \(report.failures.isEmpty ? "none" : report.failures.joined(separator: ", "))")
        }
    }

    static func deleteTelemetry(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "database"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "delete-telemetry"))
        }
        let campaign = try campaignFromOption(arguments)
        let database = try researchDatabase(arguments)
        let count = try await database.onlineEvents(campaignID: campaign.id).count
        try await database.deleteOnlineEvents(campaignID: campaign.id)
        ResearchConsole.line("Deleted \(count) online events. This deletion is not recoverable from Tilde Lab.")
    }

    static func clearCache(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "cache-clear"))
        }
        let url = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        _ = try LabResearchCampaignFileIO.load(from: url)
        let cacheURL = LabResearchArtifactLayout(documentURL: url).candidateCacheURL
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            ResearchConsole.line("Synthetic candidate cache is already empty.")
            return
        }
        let cache = try LabSyntheticCandidateCache(fileURL: cacheURL)
        let count = try await cache.count()
        try await cache.deleteEverything()
        ResearchConsole.line("Deleted \(count) synthetic raw candidates. The cache cannot be reconstructed without rerunning inference.")
    }

    static func agentEvidence(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: ["campaign", "output", "database"])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "agent-evidence"))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let output = URL(fileURLWithPath: try arguments.requiredValue("output")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let layout = LabResearchArtifactLayout(documentURL: campaignURL)
        let artifacts = try loadComparisonArtifacts(layout: layout)
        let reports = try await latestReports(manifest: campaign.manifest, layout: layout)
        var reasons: [String: Int] = [:]
        for report in reports.values {
            for (reason, count) in report.metrics.decisionReasonCounts {
                reasons[reason, default: 0] += count
            }
        }
        let redBars = artifacts.flatMap(\.comparison.sliceComparisons).filter {
            $0.deltaExpectedUtility < 0 || $0.deltaBadWhenShown > 0 || $0.deltaLateRate > 0
        }
        let database = try researchDatabase(arguments)
        let active = try await database.activeDurationSeconds(campaignID: campaign.id)
        let summary = try await database.summary(campaignID: campaign.id)
        let remaining = LabResearchBudget(
            maximumHours: max(0.000_1, campaign.budget.maximumHours - active / 3_600),
            maximumTrials: max(1, campaign.budget.maximumTrials - reports.count),
            maximumRootsPerTrial: campaign.budget.maximumRootsPerTrial,
            maximumModelRequests: max(1, campaign.budget.maximumModelRequests - summary.completed)
        )
        let evidence = LabAgentEvidenceEnvelope(
            campaignGoal: LabGoalContract.mission,
            permittedExperimentClass: research.experimentClass,
            aggregateComparisons: artifacts.map(\.comparison),
            failureReasonCounts: reasons,
            sliceRedBars: redBars,
            testedArmDigests: try Dictionary(uniqueKeysWithValues: campaign.manifest.arms.map {
                ($0.id, try $0.digestSHA256())
            }),
            remainingBudget: remaining
        )
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing evidence \(output.path).")
        }
        try LabResearchArtifactIO.save(evidence, to: output)
        ResearchConsole.line("Wrote aggregate-only agent evidence: \(output.path)")
    }

    static func validateAgentProposal(_ arguments: CLIArguments) async throws {
        try arguments.assertAllowed(options: [
            "campaign", "proposal", "arm-id", "output", "database",
        ])
        guard arguments.positionals.isEmpty else {
            throw ResearchCLIError.usage(help(for: "agent-validate"))
        }
        let campaignURL = URL(fileURLWithPath: try arguments.requiredValue("campaign")
            .expandedResearchPath).standardizedFileURL
        let proposalURL = URL(fileURLWithPath: try arguments.requiredValue("proposal")
            .expandedResearchPath).standardizedFileURL
        let output = URL(fileURLWithPath: try arguments.requiredValue("output")
            .expandedResearchPath).standardizedFileURL
        let campaign = try LabResearchCampaignFileIO.load(from: campaignURL)
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let proposal = try LabResearchArtifactIO.load(LabAgentProposal.self, from: proposalURL)
        let database = try researchDatabase(arguments)
        try await ensureCampaignRegistered(campaign, database: database)
        let proposalID = UUID()
        let arm: LabArmConfiguration
        do {
            arm = try LabAgentProposalValidator.apply(
                proposal,
                protocolDefinition: research,
                campaignBudget: campaign.budget,
                arms: campaign.manifest.arms,
                resultingArmID: try arguments.requiredValue("arm-id")
            )
            try await database.saveAgentProposal(
                id: proposalID,
                campaignID: campaign.id,
                proposal: proposal,
                validationStatus: "validated"
            )
        } catch {
            try? await database.saveAgentProposal(
                id: proposalID,
                campaignID: campaign.id,
                proposal: proposal,
                validationStatus: "rejected",
                rejectionReason: "proposal-contract-rejection"
            )
            throw error
        }
        guard let parent = campaign.manifest.arms.first(where: { $0.id == proposal.parentArmID }) else {
            throw LabAgentProposalError.parentMissing
        }
        var childResearch = research
        childResearch.baselineArmID = parent.id
        childResearch.searchStrategy = .adaptive
        let childName = "\(campaign.name) agent proposal"
        let child = LabResearchCampaignFile(
            name: childName,
            hypothesisID: campaign.hypothesisID,
            hypothesis: campaign.hypothesis,
            parentCampaignID: campaign.id,
            suite: campaign.suite,
            manifest: LabExperimentManifest(
                name: childName,
                enabledBenches: campaign.manifest.enabledBenches,
                arms: [parent, arm],
                runtime: campaign.manifest.runtime,
                research: childResearch
            ),
            budget: campaign.budget,
            model: campaign.model
        )
        try child.validated(with: campaign.suite.load())
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw ResearchCLIError.usage("Refusing to overwrite existing campaign \(output.path).")
        }
        try LabResearchCampaignFileIO.save(child, to: output)
        ResearchConsole.line("Agent proposal passed every normal campaign and safety validator.")
        ResearchConsole.line("  runnable child campaign: \(output.path)")
    }

    private static func campaignFromOption(
        _ arguments: CLIArguments
    ) throws -> LabResearchCampaignFile {
        let value = try arguments.requiredValue("campaign")
        return try LabResearchCampaignFileIO.load(
            from: URL(fileURLWithPath: value.expandedResearchPath).standardizedFileURL
        )
    }

    static func passingHoldoutEvidence(
        planURL: URL,
        sourceCampaignID: UUID,
        championID: String,
        challengerID: String
    ) async throws -> String {
        let plan = try LabResearchArtifactIO.load(LabResearchPlan.self, from: planURL).validated()
        guard plan.sourceCampaignID == sourceCampaignID,
              plan.manifest.research?.phase == .holdout,
              plan.manifest.arms.map(\.id) == [championID, challengerID] else {
            throw ResearchCLIError.protectedEvidenceRequired
        }
        let artifacts = try loadComparisonArtifacts(
            layout: LabResearchArtifactLayout(documentURL: planURL)
        )
        guard let passing = artifacts.first(where: {
            $0.campaignID == plan.id
                && $0.baselineArmID == championID
                && $0.candidateArmID == challengerID
                && $0.comparison.phase == .holdout
                && $0.comparison.decision == .advance
        }) else { throw ResearchCLIError.protectedEvidenceRequired }
        let reports = try await latestReports(
            manifest: plan.manifest,
            layout: LabResearchArtifactLayout(documentURL: planURL)
        )
        guard reports[championID]?.effectiveEvidenceEligibility.eligible == true,
              reports[challengerID]?.effectiveEvidenceEligibility.eligible == true else {
            throw ResearchCLIError.decisionGradeEvidenceRequired
        }
        return try LabResearchPlanBuilder.comparisonDigest(passing.comparison)
    }

    private static func ensureCampaignRegistered(
        _ campaign: LabResearchCampaignFile,
        database: LabResearchDatabase
    ) async throws {
        guard let research = campaign.manifest.research else {
            throw LabResearchDatabaseError.durableProtocolRequired
        }
        let suite = try campaign.suite.load()
        let selected = try campaign.manifest.arms.map {
            try LabResearchScenarioSelection.select(
                from: suite,
                configuration: $0.scenarios,
                phase: research.phase
            )
        }
        let digests = try selected.map { try $0.digestSHA256() }
        guard Set(digests).count == 1, let digest = digests.first else {
            throw LabResearchProtocolError.scenarioSelectionDrift
        }
        let assets = try await LabAssetVerifier.shared.verify(
            campaign.model.execution(campaign.manifest.runtime)
        )
        try await database.registerCampaign(LabResearchCampaignRecord(
            id: campaign.id,
            name: campaign.name,
            manifestDigestSHA256: try campaign.manifest.digestSHA256(),
            suiteDigestSHA256: digest,
            modelSHA256: assets.modelSHA256,
            helperSHA256: assets.helperSHA256,
            gitCommit: gitCommit(),
            protocolDefinition: research
        ))
    }

    private static func validateOnlineEventKeys(_ data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResearchCLIError.invalidValue("online event JSON")
        }
        let allowed: Set<String> = [
            "schema", "id", "campaignID", "occurredAt", "sessionDigestSHA256", "variant",
            "appCategory", "register", "boundary", "typingSpeedBucket", "safeOpportunity",
            "displayed", "outcome", "acceptedCharacters", "replacedCharactersWithin5Seconds",
            "nextActionMilliseconds", "generatorMilliseconds", "firstStableWordMilliseconds",
            "deadlineMissed", "confidence", "candidateCharacters", "championDisagreed",
            "guardReason", "crashed", "timedOut", "opportunityCharacters",
            "wrongInsertionCount", "insertionCorruptionCount", "networkEgressDetected",
            "networkDenied", "residentMemoryMegabytes", "memoryPressureObserved",
            "thermalLevel", "runtimeRestarted",
            "sleepWakeObserved", "appSwitchObserved", "cacheHit", "confidenceFeatures",
        ]
        if let key = Set(object.keys).subtracting(allowed).sorted().first {
            throw ResearchCLIError.rawTelemetryKey(key)
        }
        if let features = object["confidenceFeatures"] as? [String: Any] {
            let allowedFeatures: Set<String> = [
                "schema", "firstTokenProbability", "meanSequenceLogProbability",
                "minimumTokenProbability", "meanProbabilityMargin", "meanTokenEntropy",
                "suggestionCharacters", "suggestionWords", "punctuationStop",
                "contextSourceQuality", "sceneFreshnessSeconds", "personalSupport",
                "personalConfidence", "firstTokenMilliseconds", "perturbationAgreement",
            ]
            if let key = Set(features.keys).subtracting(allowedFeatures).sorted().first {
                throw ResearchCLIError.rawTelemetryKey("confidenceFeatures.\(key)")
            }
        }
    }
}
