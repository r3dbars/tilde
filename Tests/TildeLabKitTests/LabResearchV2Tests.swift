import AutocompleteLabCore
import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab v2 research protocol")
struct LabResearchV2Tests {
    @Test("Protected partitions and adaptive protected phases fail closed")
    func phaseFirewall() throws {
        var protected = LabArmConfiguration(id: "baseline")
        protected.scenarios.partition = .validation

        #expect(throws: LabResearchProtocolError.protectedPartitionRequiresRegistration) {
            try LabExperimentManifest(arms: [protected]).validated()
        }
        #expect(throws: LabResearchProtocolError.phasePartitionMismatch) {
            try LabExperimentManifest(
                arms: [protected],
                research: LabResearchProtocol(
                    phase: .discovery,
                    baselineArmID: protected.id,
                    fixedGenerationSeeds: [protected.generation.seed]
                )
            ).validated()
        }
        #expect(throws: LabResearchProtocolError.adaptiveProtectedPhase) {
            try LabResearchProtocolValidator.validate(
                LabResearchProtocol(
                    phase: .validation,
                    searchStrategy: .adaptive,
                    baselineArmID: protected.id,
                    fixedGenerationSeeds: [protected.generation.seed]
                ),
                arms: [protected]
            )
        }
    }

    @Test("Candidate ceilings and one-candidate holdout are structural")
    func candidateCeilings() throws {
        var baseline = LabArmConfiguration(id: "baseline")
        baseline.scenarios.partition = .development
        let development = [baseline] + (1...11).map { LabArmConfiguration(id: "dev-\($0)") }
        #expect(throws: LabResearchProtocolError.tooManyDevelopmentCandidates) {
            try LabResearchProtocolValidator.validate(
                LabResearchProtocol(
                    phase: .developmentConfirmation,
                    baselineArmID: baseline.id,
                    fixedGenerationSeeds: [baseline.generation.seed]
                ),
                arms: development
            )
        }

        var validation = [baseline] + (1...4).map { LabArmConfiguration(id: "validation-\($0)") }
        for index in validation.indices { validation[index].scenarios.partition = .validation }
        #expect(throws: LabResearchProtocolError.tooManyValidationCandidates) {
            try LabResearchProtocolValidator.validate(
                LabResearchProtocol(
                    phase: .validation,
                    baselineArmID: baseline.id,
                    fixedGenerationSeeds: [baseline.generation.seed]
                ),
                arms: validation
            )
        }
        #expect(throws: LabResearchProtocolError.holdoutRequiresOneCandidate) {
            try LabResearchProtocolValidator.validate(
                LabResearchProtocol(
                    phase: .holdout,
                    baselineArmID: baseline.id,
                    fixedGenerationSeeds: [baseline.generation.seed]
                ),
                arms: [baseline]
            )
        }
    }

    @Test("Frozen plans bind candidates, suite, scorecard, model, and helper")
    func frozenPlans() throws {
        let suite = protectedSuite()
        let baseline = LabArmConfiguration(id: "baseline")
        var candidate = LabArmConfiguration(id: "candidate")
        candidate.generation.predictionTokens = 12
        let assets = assetSnapshot()
        let sourceID = UUID()

        let validation = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: sourceID,
            name: "Frozen validation",
            phase: .validation,
            experimentClass: .generator,
            baseline: baseline,
            candidates: [candidate],
            suite: suite,
            assets: assets,
            runtime: .init(),
            fixedGenerationSeeds: [baseline.generation.seed]
        )
        #expect(validation.manifest.research?.phase == .validation)
        #expect(validation.manifest.research?.frozenInputs?.modelSHA256 == assets.modelSHA256)
        #expect(try validation.digestSHA256().count == 64)

        var drifted = validation.manifest
        drifted.arms[1].generation.predictionTokens = 13
        #expect(throws: LabResearchProtocolError.frozenInputMismatch) {
            try drifted.validated()
        }

        #expect(throws: LabResearchPlanError.holdoutRequiresValidationEvidence) {
            try LabResearchPlanBuilder.freeze(
                sourceCampaignID: sourceID,
                name: "Unproven holdout",
                phase: .holdout,
                experimentClass: .generator,
                baseline: baseline,
                candidates: [candidate],
                suite: suite,
                assets: assets,
                runtime: .init(),
                fixedGenerationSeeds: [baseline.generation.seed]
            )
        }
        let holdout = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: sourceID,
            name: "Proven holdout",
            phase: .holdout,
            experimentClass: .generator,
            baseline: baseline,
            candidates: [candidate],
            suite: suite,
            assets: assets,
            runtime: .init(),
            fixedGenerationSeeds: [baseline.generation.seed],
            sourceComparisonDigestsSHA256: [String(repeating: "9", count: 64)]
        )
        #expect(holdout.manifest.research?.phase == .holdout)
        #expect(holdout.manifest.arms.count == 2)
    }

    @Test("Runtime campaigns bind one real helper configuration to every identical arm")
    func runtimeCampaigns() throws {
        var baseline = LabArmConfiguration(id: "baseline")
        baseline.scenarios.partition = .development
        var candidate = baseline
        candidate.id = "one-worker"
        let baselineRuntime = LabRuntimeConfiguration(
            workerCount: 2,
            slotsPerWorker: 4,
            repetitions: 3
        )
        var candidateRuntime = baselineRuntime
        candidateRuntime.workerCount = 1
        let runtimes = [
            baseline.id: baselineRuntime,
            candidate.id: candidateRuntime,
        ]
        let research = LabResearchProtocol(
            phase: .discovery,
            experimentClass: .runtime,
            baselineArmID: baseline.id,
            fixedGenerationSeeds: [0],
            runtimeByArm: runtimes
        )
        _ = try LabExperimentManifest(
            arms: [baseline, candidate],
            runtime: baselineRuntime,
            research: research
        ).validated()

        var missing = research
        missing.runtimeByArm?.removeValue(forKey: candidate.id)
        #expect(throws: LabResearchProtocolError.runtimeConfigurationRequired) {
            try LabExperimentManifest(
                arms: [baseline, candidate],
                runtime: baselineRuntime,
                research: missing
            ).validated()
        }

        var unpaired = research
        unpaired.runtimeByArm?[candidate.id]?.repetitions = 4
        #expect(throws: LabResearchProtocolError.runtimeMeasurementDrift) {
            try LabExperimentManifest(
                arms: [baseline, candidate],
                runtime: baselineRuntime,
                research: unpaired
            ).validated()
        }

        let plan = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: UUID(),
            name: "Frozen runtime validation",
            phase: .validation,
            experimentClass: .runtime,
            baseline: baseline,
            candidates: [candidate],
            suite: protectedSuite(),
            assets: assetSnapshot(),
            runtime: baselineRuntime,
            runtimeByArm: runtimes,
            fixedGenerationSeeds: [0]
        )
        #expect(plan.manifest.research?.frozenInputs?.runtimeDigestsSHA256?.count == 2)
        #expect(plan.manifest.research?.runtimeByArm?[candidate.id]?.workerCount == 1)
        var drifted = plan.manifest
        drifted.research?.runtimeByArm?[candidate.id]?.workerCount = 3
        #expect(throws: LabResearchProtocolError.frozenInputMismatch) {
            try drifted.validated()
        }
    }

    @Test("Permanent regression plans bind exact failure evidence and suite digest")
    func regressionPlans() throws {
        let baseline = LabArmConfiguration(id: "baseline")
        var candidate = baseline
        candidate.id = "candidate"
        let suite = LabScenarioSuite(name: "permanent regression", scenarios: [
            scenario(id: "failure-001", partition: .regression),
        ])
        let reference = LabResearchSuiteReference.file("/tmp/permanent-regression.json")
        let evidence = String(repeating: "7", count: 64)
        let plan = try LabResearchPlanBuilder.freeze(
            sourceCampaignID: UUID(),
            name: "Permanent regression",
            phase: .regression,
            experimentClass: .generator,
            baseline: baseline,
            candidates: [candidate],
            suite: suite,
            assets: assetSnapshot(),
            runtime: .init(repetitions: 1),
            suiteReference: reference,
            fixedGenerationSeeds: [0],
            sourceFailureEvidenceDigestsSHA256: [evidence]
        )
        #expect(plan.manifest.research?.phase == .regression)
        #expect(plan.sourceFailureEvidenceDigestsSHA256 == [evidence])
        #expect(plan.suiteReference == reference)
        #expect(plan.manifest.research?.frozenInputs?.suiteDigestSHA256.count == 64)

        #expect(throws: LabResearchPlanError.regressionRequiresFailureEvidence) {
            try LabResearchPlanBuilder.freeze(
                sourceCampaignID: UUID(),
                name: "Unbound regression",
                phase: .regression,
                experimentClass: .generator,
                baseline: baseline,
                candidates: [candidate],
                suite: suite,
                assets: assetSnapshot(),
                runtime: .init(repetitions: 1),
                fixedGenerationSeeds: [0]
            )
        }
    }

    @Test("Research selection injects invariant smoke and fails severe sentinels")
    func invariantSmoke() throws {
        let safe = LabScenario(
            id: "safe-speak",
            category: "reply.chat",
            partition: .development,
            tags: ["word-boundary"],
            typedContext: "Sounds ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "good")
        )
        let sentinel = LabScenario(
            id: "sentinel-silence",
            category: "reply.unsupported",
            partition: .development,
            tags: ["prompt-injection", "sensitive", "stale-context", "irrelevant-context"],
            typedContext: "Private ",
            expectation: .init(
                shouldSuggest: false,
                forbiddenTerms: ["secret"]
            )
        )
        let source = LabScenarioSuite(name: "sentinel fixture", scenarios: [safe, sentinel])
        let selected = try LabResearchScenarioSelection.select(
            from: source,
            configuration: .init(
                partition: .development,
                suggestionExpectation: .speakOnly
            ),
            phase: .discovery
        )
        #expect(Set(selected.scenarios.map(\.id)) == Set([safe.id, sentinel.id]))
        #expect(try LabResearchScenarioSelection.invariantRootIDs(in: selected) == [sentinel.id])
        #expect(
            LabResearchScenarioSelection.stratifiedRootBlocks(
                in: selected,
                excluding: [sentinel.id],
                maximumCount: 1,
                seed: 17
            ) == LabResearchScenarioSelection.stratifiedRootBlocks(
                in: selected,
                excluding: [sentinel.id],
                maximumCount: 1,
                seed: 17
            )
        )
        let unsafe = LabCaseResult(
            scenarioID: sentinel.id,
            category: sentinel.category,
            repetition: 0,
            outcome: .unwanted,
            expectedSuggestion: false,
            hasGoldenContinuation: false,
            offered: true,
            forbiddenTermViolation: true,
            rootScenarioID: sentinel.id
        )
        #expect(throws: LabInvariantSmokeError.self) {
            try LabResearchScenarioSelection.assertPassed(
                armID: "candidate",
                results: [unsafe],
                suite: selected
            )
        }
    }

    @Test("QMC, balanced halving, and local search preserve frozen controls")
    func stagedSearch() throws {
        let baseline = LabArmConfiguration(id: "baseline")
        let QMC = try LabStagedSearchPlanner.spaceFillingArms(
            baseline: baseline,
            candidateCount: 12
        )
        #expect(QMC.count == 12)
        #expect(Set(QMC.map(\.id)).count == 12)
        #expect(QMC.allSatisfy { $0.generation.seed == baseline.generation.seed })
        #expect(QMC.allSatisfy {
            $0.generation.probabilityCount == baseline.generation.probabilityCount
                && $0.generation.minimumMeanTokenProbability
                    == baseline.generation.minimumMeanTokenProbability
                && $0.prompt == baseline.prompt
                && $0.judgment == baseline.judgment
        })

        var observations = QMC.enumerated().map { index, arm in
            observation(
                arm: arm,
                completed: 90,
                safe: index != 11,
                utility: Double(12 - index)
            )
        }
        observations[0] = observation(
            arm: QMC[0], completed: 89, safe: true, utility: 12
        )
        #expect(throws: LabAdaptiveSearchError.incompleteBalancedBlock) {
            try LabStagedSearchPlanner.successiveHalvingSurvivors(observations)
        }
        observations[0] = observation(
            arm: QMC[0], completed: 90, safe: true, utility: 12
        )
        let survivors = try LabStagedSearchPlanner.successiveHalvingSurvivors(observations)
        #expect(survivors.count == 4)
        #expect(survivors.allSatisfy { $0.hardGatesPassed })

        let local = try LabStagedSearchPlanner.adaptiveLocalArms(
            observations: observations,
            baseline: baseline,
            candidateCount: 4
        )
        #expect(local.count == 4)
        #expect(Set(local.map(\.id)).count == 4)
        #expect(local.allSatisfy { $0.generation.seed == baseline.generation.seed })
        #expect(throws: LabAdaptiveSearchError.protectedPhase) {
            try LabStagedSearchPlanner.assertOptimizerAllowed(phase: .validation)
        }
    }

    @Test("Aggregate-only agent proposals cannot change safety, seeds, or phase")
    func agentProposalContract() throws {
        var baseline = LabArmConfiguration(id: "baseline")
        baseline.scenarios.partition = .development
        let research = LabResearchProtocol(
            phase: .discovery,
            experimentClass: .generator,
            searchStrategy: .adaptive,
            baselineArmID: baseline.id,
            fixedGenerationSeeds: [baseline.generation.seed]
        )
        let valid = proposal(
            parent: baseline.id,
            seeds: [baseline.generation.seed],
            changes: [
                "generation.temperature": .number(0.1),
                "generation.predictionTokens": .integer(12),
            ]
        )
        let arm = try LabAgentProposalValidator.apply(
            valid,
            protocolDefinition: research,
            campaignBudget: .init(maximumRootsPerTrial: 100),
            arms: [baseline],
            resultingArmID: "agent-candidate"
        )
        #expect(arm.generation.temperature == 0.1)
        #expect(arm.generation.predictionTokens == 12)
        #expect(arm.judgment.rejectsSceneEcho)

        let unsafe = proposal(
            parent: baseline.id,
            seeds: [baseline.generation.seed],
            changes: ["judgment.rejectsSceneEcho": .boolean(false)]
        )
        #expect(throws: LabAgentProposalError.forbiddenChange("judgment.rejectsSceneEcho")) {
            try LabAgentProposalValidator.apply(
                unsafe,
                protocolDefinition: research,
                campaignBudget: .init(),
                arms: [baseline],
                resultingArmID: "unsafe"
            )
        }
        let mutatedSeed = proposal(
            parent: baseline.id,
            seeds: [999],
            changes: ["generation.temperature": .number(0.1)]
        )
        #expect(throws: LabAgentProposalError.seedMutation) {
            try LabAgentProposalValidator.apply(
                mutatedSeed,
                protocolDefinition: research,
                campaignBudget: .init(),
                arms: [baseline],
                resultingArmID: "seed-mutator"
            )
        }
    }

    @Test("Diagnostic evidence can explain behavior but can never promote")
    func diagnosticCannotPromote() throws {
        let baselineCase = caseResult(
            scenarioID: "root-a",
            outcome: .silent,
            offered: false,
            saved: 0,
            latency: nil
        )
        let candidateCase = caseResult(
            scenarioID: "root-a",
            outcome: .useful,
            offered: true,
            saved: 8,
            latency: 100
        )
        let baselineArm = LabArmConfiguration(id: "baseline")
        var diagnosticArm = LabArmConfiguration(id: "diagnostic")
        diagnosticArm.judgment.cleanerPreset = .diagnostic
        let comparison = try LabPairedComparison.compare(
            baseline: report(arm: baselineArm, cases: [baselineCase]),
            candidate: report(arm: diagnosticArm, cases: [candidateCase]),
            phase: .discovery,
            promotionRule: .init(
                bootstrapIterations: 100,
                minimumProbabilityPositive: 0.5,
                maximumBadWhenShownIncrease: 1,
                latencyNoninferiorityMilliseconds: 1_000,
                maximumProtectedSliceRegression: 1_000
            )
        )
        #expect(comparison.decision == .reject)
        #expect(comparison.hardGateFailures.contains("diagnostic-arm-ineligible"))
        #expect((comparison.rareEventBounds["bad-when-shown"]?.upper95Wilson ?? 0) > 0)
    }

    @Test("Stochastic comparisons report every seed and the worst seed")
    func seedStability() throws {
        let baseline = report(arm: .init(id: "baseline"), cases: [
            caseResult(
                scenarioID: "root-a", generationSeed: 17,
                outcome: .silent, offered: false, saved: 0, latency: nil
            ),
            caseResult(
                scenarioID: "root-a", generationSeed: 41,
                outcome: .silent, offered: false, saved: 0, latency: nil
            ),
        ])
        let candidate = report(arm: .init(id: "candidate"), cases: [
            caseResult(
                scenarioID: "root-a", generationSeed: 17,
                outcome: .useful, offered: true, saved: 8, latency: 100
            ),
            caseResult(
                scenarioID: "root-a", generationSeed: 41,
                outcome: .wrong, offered: true, saved: 0, latency: 100
            ),
        ])
        let comparison = try LabPairedComparison.compare(
            baseline: baseline,
            candidate: candidate,
            phase: .discovery,
            promotionRule: .init(
                bootstrapIterations: 100,
                minimumProbabilityPositive: 0,
                maximumBadWhenShownIncrease: 1,
                latencyNoninferiorityMilliseconds: 1_000,
                maximumProtectedSliceRegression: 1_000
            )
        )
        #expect(comparison.seedComparisons.map(\.generationSeed) == [17, 41])
        #expect(comparison.worstSeed?.generationSeed == 41)
        #expect((comparison.worstSeed?.deltaExpectedUtility ?? 0) < 0)
    }

    @Test("Online plans ramp safely and store only text-free events")
    func onlineExperiment() async throws {
        let campaignID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let shadow = onlinePlan(
            campaignID: campaignID,
            phase: .shadow,
            allocation: 0,
            start: start,
            end: end
        )
        _ = try shadow.validated()
        #expect(throws: LabOnlineExperimentError.shadowMayNotDisplay) {
            try onlinePlan(
                campaignID: campaignID,
                phase: .shadow,
                allocation: 0.01,
                start: start,
                end: end
            ).validated()
        }
        #expect(throws: LabOnlineExperimentError.rampRequiresSafetyEvidence) {
            try onlinePlan(
                campaignID: campaignID,
                phase: .dogfood,
                allocation: 0.25,
                start: start,
                end: end
            ).validated()
        }
        _ = try onlinePlan(
            campaignID: campaignID,
            phase: .dogfood,
            allocation: 0.10,
            start: start,
            end: end
        ).validated()

        let shown = onlineEvent(
            campaignID: campaignID,
            at: 1_500,
            variant: .challenger,
            displayed: true,
            outcome: .acceptedAll,
            nextAction: 300,
            acceptedCharacters: 10
        )
        #expect(throws: LabOnlineExperimentError.shadowMayNotDisplay) {
            try shown.validated(for: shadow)
        }
        let outside = onlineEvent(
            campaignID: campaignID,
            at: 2_001,
            variant: .hidden,
            displayed: false,
            outcome: .hidden,
            nextAction: 100
        )
        #expect(throws: LabOnlineExperimentError.invalidEvent) {
            try outside.validated(for: shadow)
        }
        #expect(throws: LabOnlineExperimentError.invalidEvent) {
            try onlineEvent(
                campaignID: campaignID,
                at: 1_501,
                variant: .hidden,
                displayed: true,
                outcome: .acceptedAll,
                nextAction: 100,
                acceptedCharacters: 0
            ).validated(for: shadow)
        }

        let hidden = onlineEvent(
            campaignID: campaignID,
            at: 1_501,
            variant: .hidden,
            displayed: false,
            outcome: .hidden,
            nextAction: 100
        )
        let report = try LabOnlineExperimentAnalyzer.analyze([shown, hidden])
        #expect(report.attentionTax.matchedStrata == 1)
        #expect(report.attentionTax.attentionTaxMilliseconds == 200)
        #expect(report.netAcceptedCharacters == 10)

        let encoded = try JSONEncoder().encode(shown)
        let keys = Set((try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])).keys)
        #expect(keys.isDisjoint(with: [
            "text", "prompt", "candidate", "bundleIdentifier", "filePath", "screenText",
        ]))

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-online-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try LabResearchDatabase(fileURL: root.appendingPathComponent("research.sqlite3"))
        try await database.registerCampaign(LabResearchCampaignRecord(
            id: campaignID,
            name: "online-fixture",
            manifestDigestSHA256: String(repeating: "1", count: 64),
            suiteDigestSHA256: String(repeating: "2", count: 64),
            modelSHA256: String(repeating: "3", count: 64),
            helperSHA256: String(repeating: "4", count: 64),
            gitCommit: "test",
            protocolDefinition: LabResearchProtocol(
                baselineArmID: "champion",
                fixedGenerationSeeds: [0]
            )
        ))
        try await database.saveOnlinePlan(shadow)
        #expect(try await database.onlinePlan(campaignID: campaignID) == shadow)
        try await database.recordOnlineEvent(hidden, plan: shadow)
        #expect(try await database.onlineEvents(campaignID: campaignID) == [hidden])
        try await database.deleteOnlineEvents(campaignID: campaignID)
        #expect(try await database.onlineEvents(campaignID: campaignID).isEmpty)
    }

    @Test("Soak requires sustained coverage and zero operational failures")
    func soakGates() throws {
        let campaignID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(throws: LabOnlineExperimentError.invalidSoakRequirements) {
            try onlinePlan(
                campaignID: campaignID,
                phase: .soak,
                allocation: 1,
                start: start,
                end: start.addingTimeInterval(300)
            ).validated()
        }
        let plan = try LabOnlineExperimentPlan(
            campaignID: campaignID,
            phase: .soak,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "d", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "e", count: 64),
            challengerAllocation: 1,
            startsAt: start,
            endsAt: start.addingTimeInterval(300),
            safetyEvidenceDigestSHA256: String(repeating: "a", count: 64),
            minimumObservedDurationSeconds: 120,
            minimumEventCount: 3
        ).validated()
        let events = [
            operationalEvent(
                campaignID: campaignID, at: 1_000,
                networkDenied: true, memoryPressure: true,
                runtimeRestarted: true, appSwitch: true, cacheHit: true
            ),
            operationalEvent(
                campaignID: campaignID, at: 1_060,
                networkDenied: false, memoryPressure: false,
                runtimeRestarted: false, appSwitch: true, cacheHit: false
            ),
            operationalEvent(
                campaignID: campaignID, at: 1_120,
                networkDenied: false, memoryPressure: false,
                runtimeRestarted: false, appSwitch: true, cacheHit: true
            ),
        ]
        for event in events { _ = try event.validated(for: plan) }
        let passing = try LabOnlineExperimentAnalyzer.analyzeSoak(events, plan: plan)
        #expect(passing.passed)
        #expect(passing.observedDurationSeconds == 120)
        #expect(passing.operational.maximumResidentMemoryMegabytes == 512)

        var failing = events
        failing.append(operationalEvent(
            campaignID: campaignID,
            at: 1_121,
            networkDenied: false,
            memoryPressure: false,
            runtimeRestarted: false,
            appSwitch: false,
            cacheHit: false,
            networkEgress: true
        ))
        let failed = try LabOnlineExperimentAnalyzer.analyzeSoak(failing, plan: plan)
        #expect(!failed.passed)
        #expect(failed.failures.contains("network-egress"))
    }

    @Test("TildeConfidenceV1 is text-free and calibrates chronologically out of sample")
    func confidenceCalibration() throws {
        let response = LabModelResponse(
            content: "sounds good.",
            latencyMilliseconds: 120,
            firstTokenMilliseconds: 70,
            meanTokenProbability: 0.7,
            tokenIDs: [10, 20],
            tokenLogProbabilities: [log(0.8), log(0.6)],
            tokenProbabilityMargins: [0.6, 0.3],
            tokenEntropies: [0.5, 0.8],
            stopReason: "stop"
        )
        let features = try LabConfidenceFeaturesV1(
            response: response,
            contextSourceQuality: 0.9,
            sceneFreshnessSeconds: 2,
            personalSupport: 3,
            personalConfidence: 0.8,
            perturbationAgreement: 1
        ).validated()
        #expect(features.firstTokenProbability.map { abs($0 - 0.8) < 0.000_001 } == true)
        #expect(features.minimumTokenProbability.map { abs($0 - 0.6) < 0.000_001 } == true)
        #expect(features.suggestionWords == 2)

        let campaignID = UUID()
        let events = (0..<10).map { index in
            let confidence = Double(index + 1) / 10
            return LabOnlineExperimentEvent(
                campaignID: campaignID,
                occurredAt: Date(timeIntervalSince1970: Double(1_000 + index)),
                sessionDigestSHA256: String(repeating: "f", count: 64),
                variant: .challenger,
                appCategory: index.isMultiple(of: 2) ? .chat : .email,
                register: index.isMultiple(of: 2) ? .chat : .email,
                boundary: .wordBoundary,
                typingSpeedBucket: .medium,
                safeOpportunity: true,
                displayed: true,
                outcome: index >= 5 ? .acceptedAll : .ignored,
                confidence: confidence,
                candidateCharacters: 12,
                opportunityCharacters: 20,
                confidenceFeatures: features
            )
        }
        let report = try LabConfidenceCalibrator.calibrate(events)
        #expect(report.trainingEvents == 7)
        #expect(report.validationEvents == 3)
        #expect(report.isotonicKnots.allSatisfy {
            (0...1).contains($0.calibratedAcceptanceProbability)
        })
        #expect(report.featureCoverage["token-entropy"] == 10)
        #expect(report.slices.contains { $0.slice == "boundary:word-boundary" })

        let encoded = try JSONEncoder().encode(events[0])
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(!text.contains("sounds good"))
        #expect(!text.contains("prompt"))
    }

    @Test("Real-host interaction evidence requires the complete host and event matrix")
    func interactionEvidence() throws {
        let campaignID = UUID()
        let armDigest = String(repeating: "6", count: 64)
        let holdoutDigest = String(repeating: "8", count: 64)
        let records = LabInteractionHost.allCases.flatMap { host in
            LabInteractionCheck.allCases.map { check in
                LabInteractionEvidenceRecord(
                    campaignID: campaignID,
                    candidateArmID: "candidate",
                    candidateArmDigestSHA256: armDigest,
                    host: host,
                    check: check,
                    attempts: 3,
                    p95Milliseconds: 150
                )
            }
        }
        let passing = try LabInteractionEvidenceAnalyzer.analyze(
            records,
            holdoutEvidenceDigestSHA256: holdoutDigest
        )
        #expect(passing.passed)
        #expect(passing.missingCoverage.isEmpty)

        let incomplete = try LabInteractionEvidenceAnalyzer.analyze(
            Array(records.dropLast()),
            holdoutEvidenceDigestSHA256: holdoutDigest
        )
        #expect(!incomplete.passed)
        #expect(incomplete.missingCoverage.count == 1)

        let encoded = String(decoding: try JSONEncoder().encode(records[0]), as: UTF8.self)
        #expect(!encoded.contains("text"))
        #expect(!encoded.contains("bundle"))
        #expect(!encoded.contains("\"candidate\":"))
    }

    @Test("Personalization replay is chronological even when input is shuffled")
    func chronologicalPersonalization() throws {
        let events = [
            personalEvent(id: "event-a", time: 100, app: "com.example.Chat", text: "see you monday "),
            personalEvent(id: "event-b", time: 200, app: "com.example.Mail", text: "see you monday "),
            personalEvent(id: "event-c", time: 300, app: "com.example.Chat", text: "see you monday "),
            personalEvent(id: "event-d", time: 400, app: "com.example.Mail", text: "see you monday "),
        ]
        let configuration = LabPersonalizationConfiguration(scope: .global)
        let ordered = try LabChronologicalPersonalization.evaluate(
            events: events,
            configuration: configuration,
            evaluationStartMilliseconds: 250,
            stressLabels: ["event-c": .stale, "event-d": .poisoned]
        )
        let shuffled = try LabChronologicalPersonalization.evaluate(
            events: [events[2], events[0], events[3], events[1]],
            configuration: configuration,
            evaluationStartMilliseconds: 250,
            stressLabels: ["event-c": .stale, "event-d": .poisoned]
        )
        #expect(ordered == shuffled)
        #expect(ordered.futureHistoryViolations == 0)
        #expect(ordered.distinctApplications == 2)
        #expect(ordered.stressCaseCounts[.stale] == 1)
        #expect(ordered.stressCaseCounts[.poisoned] == 1)

        var mixed = events
        mixed.append(personalEvent(
            id: "event-e", time: 500, app: "com.example.Chat", text: "different epoch ",
            history: "other-history"
        ))
        #expect(throws: LabChronologicalPersonalizationError.mixedHistory) {
            try LabChronologicalPersonalization.evaluate(
                events: mixed,
                configuration: configuration
            )
        }


        var enabled = configuration
        enabled.enabled = true
        enabled.scope = .appThenGlobal
        enabled.arbitration = .production
        let guarded = try LabChronologicalPersonalization.evaluate(
            events: events,
            configuration: enabled,
            evaluationStartMilliseconds: 250,
            stressLabels: ["event-c": .stale]
        )
        #expect(guarded.staleOverrideBlocked)
    }

    @Test("Personal History JSONL loader rejects extra keys, duplicates, and symlinks")
    func personalHistoryLoader() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-personal-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let event = personalEvent(
            id: "event-a", time: 100, app: "com.example.Chat", text: "hello there "
        )
        let encoder = JSONEncoder()
        let line = try encoder.encode(event)
        let valid = root.appendingPathComponent("valid.jsonl")
        try (line + Data("\n".utf8)).write(to: valid)
        #expect(try LabPersonalHistoryReplayLoader.loadJSONLines(from: valid) == [event])

        let duplicate = root.appendingPathComponent("duplicate.jsonl")
        try (line + Data("\n".utf8) + line + Data("\n".utf8)).write(to: duplicate)
        #expect(throws: LabPersonalHistoryReplayLoaderError.duplicateEventID(event.id)) {
            try LabPersonalHistoryReplayLoader.loadJSONLines(from: duplicate)
        }

        var object = try #require(
            JSONSerialization.jsonObject(with: line) as? [String: Any]
        )
        object["prompt"] = "must never be accepted"
        let unsupported = root.appendingPathComponent("unsupported.jsonl")
        try JSONSerialization.data(withJSONObject: object).write(to: unsupported)
        #expect(throws: LabPersonalHistoryReplayLoaderError.unsupportedKey("prompt")) {
            try LabPersonalHistoryReplayLoader.loadJSONLines(from: unsupported)
        }

        let link = root.appendingPathComponent("link.jsonl")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: valid)
        #expect(throws: LabPersonalHistoryReplayLoaderError.unsafePath) {
            try LabPersonalHistoryReplayLoader.loadJSONLines(from: link)
        }
    }

    private func protectedSuite() -> LabScenarioSuite {
        LabScenarioSuite(name: "Protected fixture", scenarios: [
            scenario(id: "case.development", partition: .development),
            scenario(id: "case.validation", partition: .validation),
            scenario(id: "case.holdout", partition: .holdout),
        ])
    }

    private func scenario(id: String, partition: LabScenarioPartition) -> LabScenario {
        LabScenario(
            id: id,
            category: "reply.test",
            partition: partition,
            tags: ["prompt-injection", "sensitive", "stale-context", "irrelevant-context"],
            typedContext: "Hello ",
            expectation: .init(
                shouldSuggest: true,
                goldenContinuation: "there",
                forbiddenTerms: ["unsafe"]
            ),
            evaluation: .init(temporalIntegrity: .verified, rootScenarioID: id)
        )
    }

    private func assetSnapshot() -> LabAssetSnapshot {
        LabAssetSnapshot(
            modelIdentifier: "test-model",
            modelRevision: "test-revision",
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64)
        )
    }

    private func observation(
        arm: LabArmConfiguration,
        completed: Int,
        safe: Bool,
        utility: Double
    ) -> LabSearchTrialObservation {
        LabSearchTrialObservation(
            arm: arm,
            stage: .spaceFilling,
            completedRoots: completed,
            plannedRoots: 90,
            hardGatesPassed: safe,
            expectedUtility: utility,
            oracleNetKeystrokeSavings: utility / 100,
            precisionWhenShown: 0.9,
            badWhenShown: 0,
            lateRate: 0,
            p95LatencyMilliseconds: 100
        )
    }

    private func proposal(
        parent: String,
        seeds: [Int],
        changes: [String: LabProposalValue]
    ) -> LabAgentProposal {
        LabAgentProposal(
            hypothesis: "A bounded generator change may improve useful continuation quality.",
            parentArmID: parent,
            experimentClass: .generator,
            phase: .discovery,
            changes: changes,
            expectedAffectedSlices: ["reply.test"],
            successRule: .init(
                minimumDeltaExpectedUtility: 0,
                maximumDeltaBadWhenShown: 0,
                latencyNoninferiorityMilliseconds: 25
            ),
            budget: .init(roots: 90, seeds: seeds),
            stopConditions: ["Stop on any hard-gate failure."]
        )
    }

    private func caseResult(
        scenarioID: String,
        generationSeed: Int = 0,
        outcome: LabCaseOutcome,
        offered: Bool,
        saved: Int,
        latency: Int?
    ) -> LabCaseResult {
        LabCaseResult(
            scenarioID: scenarioID,
            category: "reply.test",
            repetition: 0,
            generationSeed: generationSeed,
            outcome: outcome,
            expectedSuggestion: true,
            hasGoldenContinuation: true,
            offered: offered,
            modelRequested: latency != nil,
            rootScenarioID: scenarioID,
            baselineKeystrokes: 10,
            grossKeystrokesSaved: saved,
            acceptanceKeystrokes: offered ? 1 : 0,
            netKeystrokesSaved: max(0, saved - (offered ? 1 : 0)),
            keystrokesSaved: saved,
            latencyMilliseconds: latency,
            firstTokenMilliseconds: latency,
            meanTokenProbability: offered ? 0.9 : nil,
            visibleWordCount: offered ? 2 : 0,
            visibleCharacterCount: offered ? saved : 0
        )
    }

    private func report(arm: LabArmConfiguration, cases: [LabCaseResult]) -> LabRunReport {
        let execution = LabExecutionConfiguration(
            serverExecutable: URL(fileURLWithPath: "/tmp/tilde-test-helper"),
            modelFile: URL(fileURLWithPath: "/tmp/tilde-test-model"),
            modelProfile: .experimental(identifier: "test-model"),
            repetitions: 1
        )
        return LabRunReport(
            startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 2),
            suiteName: "paired fixture",
            suiteDigestSHA256: String(repeating: "c", count: 64),
            scenarioCount: cases.count,
            arm: arm,
            execution: LabExecutionSnapshot(execution),
            assets: assetSnapshot(),
            metrics: LabScorer.aggregate(cases, elapsedSeconds: 1, scoring: arm.scoring),
            cases: cases
        )
    }

    private func onlinePlan(
        campaignID: UUID,
        phase: LabCampaignPhase,
        allocation: Double,
        start: Date,
        end: Date
    ) -> LabOnlineExperimentPlan {
        LabOnlineExperimentPlan(
            campaignID: campaignID,
            phase: phase,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "d", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "e", count: 64),
            challengerAllocation: allocation,
            attentionHoldbackRate: phase == .dogfood ? 0.1 : 0,
            startsAt: start,
            endsAt: end
        )
    }

    private func onlineEvent(
        campaignID: UUID,
        at timestamp: TimeInterval,
        variant: LabOnlineVariant,
        displayed: Bool,
        outcome: LabOnlineInteractionOutcome,
        nextAction: Int,
        acceptedCharacters: Int = 0
    ) -> LabOnlineExperimentEvent {
        LabOnlineExperimentEvent(
            campaignID: campaignID,
            occurredAt: Date(timeIntervalSince1970: timestamp),
            sessionDigestSHA256: String(repeating: "f", count: 64),
            variant: variant,
            appCategory: .chat,
            register: .chat,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: displayed,
            outcome: outcome,
            acceptedCharacters: acceptedCharacters,
            nextActionMilliseconds: nextAction,
            generatorMilliseconds: 80,
            firstStableWordMilliseconds: 100,
            confidence: 0.85,
            candidateCharacters: displayed ? 10 : 0,
            opportunityCharacters: 20
        )
    }

    private func operationalEvent(
        campaignID: UUID,
        at timestamp: TimeInterval,
        networkDenied: Bool,
        memoryPressure: Bool,
        runtimeRestarted: Bool,
        appSwitch: Bool,
        cacheHit: Bool,
        networkEgress: Bool = false
    ) -> LabOnlineExperimentEvent {
        LabOnlineExperimentEvent(
            campaignID: campaignID,
            occurredAt: Date(timeIntervalSince1970: timestamp),
            sessionDigestSHA256: String(repeating: "f", count: 64),
            variant: .challenger,
            appCategory: .chat,
            register: .chat,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: true,
            outcome: .ignored,
            generatorMilliseconds: 80,
            firstStableWordMilliseconds: 100,
            candidateCharacters: 8,
            opportunityCharacters: 20,
            wrongInsertionCount: 0,
            insertionCorruptionCount: 0,
            networkEgressDetected: networkEgress,
            networkDenied: networkDenied,
            residentMemoryMegabytes: 512,
            memoryPressureObserved: memoryPressure,
            thermalLevel: .nominal,
            runtimeRestarted: runtimeRestarted,
            sleepWakeObserved: false,
            appSwitchObserved: appSwitch,
            cacheHit: cacheHit
        )
    }

    private func personalEvent(
        id: String,
        time: Int64,
        app: String,
        text: String,
        history: String = "history"
    ) -> PersonalHistoryEvent {
        PersonalHistoryEvent(
            id: id,
            timestampMilliseconds: time,
            historyIdentifier: history,
            consentIdentifier: "consent",
            sessionIdentifier: "session",
            appBundleIdentifier: app,
            source: .typed,
            text: text
        )!
    }
}
