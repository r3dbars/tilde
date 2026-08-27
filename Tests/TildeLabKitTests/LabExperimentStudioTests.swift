import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab experiment studio")
struct LabExperimentStudioTests {
    @Test("The complete manifest round-trips without runtime file paths")
    func manifestRoundTrip() throws {
        var arm = LabArmConfiguration(id: "candidate-rich")
        arm.generation.apply(.exploratory)
        arm.generation.advanced.dryMultiplier = 0.4
        arm.prompt.recipe = .minimal
        arm.prompt.conversationFormat = .roleLabels
        arm.judgment.factualGrounding = .numbersAndNames
        arm.sceneBench.captureSource = .ocr
        arm.personalization.enabled = true
        arm.interaction.hosts = [.sceneHost, .textEdit]
        arm.scenarios.partition = .development

        let manifest = LabExperimentManifest(
            name: "Full matrix",
            arms: [LabArmConfiguration(), arm],
            runtime: LabRuntimeConfiguration(
                workerCount: 3,
                slotsPerWorker: 5,
                repetitions: 17,
                flashAttention: .on,
                keyCacheType: .q8_0,
                valueCacheType: .q8_0
            )
        )
        let data = try JSONEncoder().encode(try manifest.validated())
        let decoded = try JSONDecoder().decode(LabExperimentManifest.self, from: data)
        let text = String(decoding: data, as: UTF8.self)

        #expect(decoded == manifest)
        #expect(try decoded.digestSHA256().count == 64)
        #expect(!text.contains("/Applications/"))
        #expect(!text.contains("Application Support"))
    }

    @Test("The first Reply Bench arm format still decodes")
    func legacyArmMigration() throws {
        let json = """
        {
          "id":"legacy-v1",
          "temperature":0.25,
          "predictionTokens":31,
          "maxVisibleWords":6,
          "includesScene":false,
          "suppressesSensitiveScenes":true
        }
        """
        let arm = try JSONDecoder().decode(LabArmConfiguration.self, from: Data(json.utf8))

        #expect(arm.id == "legacy-v1")
        #expect(arm.generation.temperature == 0.25)
        #expect(arm.generation.predictionTokens == 31)
        #expect(arm.judgment.maximumVisibleWords == 6)
        #expect(!arm.prompt.includesScene)
        #expect(arm.judgment.suppressesSensitiveScenes)
    }

    @Test("Locked score weights cannot drift between experiment arms")
    func lockedScoringComparison() throws {
        let baseline = LabArmConfiguration(id: "baseline")
        var candidate = LabArmConfiguration(id: "candidate")
        candidate.scoring.usefulnessWeight = 0.80

        #expect(throws: LabManifestError.self) {
            try LabExperimentManifest(arms: [baseline, candidate]).validated()
        }

        var unlockedBaseline = baseline
        unlockedBaseline.scoring.weightsLockedDuringComparison = false
        candidate.scoring.weightsLockedDuringComparison = false
        _ = try LabExperimentManifest(arms: [unlockedBaseline, candidate]).validated()
    }

    @Test("Human-editable sampler order becomes the llama-server JSON array")
    func parsedSamplerOrder() {
        var advanced = LabAdvancedSamplingConfiguration()
        advanced.samplerOrder = "penalties; dry,top_k  temperature"
        #expect(advanced.parsedSamplerOrder == ["penalties", "dry", "top_k", "temperature"])
    }

    @Test("The broad screening campaign has 50 safe reproducible arms")
    func broadCampaignRecipe() throws {
        let arms = LabCampaignFactory.arms(for: .broadSweep50)

        #expect(arms.count == 50)
        #expect(Set(arms.map(\.id)).count == 50)
        #expect(arms.allSatisfy { $0.judgment.suppressesSensitiveScenes })
        #expect(arms.allSatisfy { $0.generation.requestMode == .productionStreaming })
        #expect(arms.first?.id == "s2-control-start")
        #expect(arms.last?.id == "s2-control-end")
        _ = try LabExperimentManifest(
            name: "Broad 50",
            arms: arms,
            research: LabCampaignFactory.researchProtocol(for: .broadSweep50)
        ).validated()
    }

    @Test("The model-quality campaign is exactly 18,000 comparable evaluations")
    func modelQualityCampaignRecipe() throws {
        let arms = LabCampaignFactory.arms(for: .modelQuality50)

        #expect(arms.count == 50)
        #expect(Set(arms.map(\.id)).count == 50)
        #expect(arms.allSatisfy { $0.scenarios.partition == .development })
        #expect(arms.allSatisfy { $0.scenarios.suggestionExpectation == .speakOnly })
        #expect(arms.allSatisfy { $0.scenarios.maximumDistinctSituations == 360 })
        #expect(arms.allSatisfy { $0.scoring.usesModelOutputQuality })
        #expect(arms.allSatisfy { $0.judgment.suppressesSensitiveScenes })
        #expect(arms.allSatisfy { $0.judgment.maximumVisibleWords == 3 })
        #expect(arms.allSatisfy { $0.judgment.maximumVisibleCharacters == 42 })
        _ = try LabExperimentManifest(
            name: "Model quality 50",
            arms: arms,
            research: LabCampaignFactory.researchProtocol(for: .modelQuality50)
        ).validated()
    }

    @Test("The quick campaign is a safe development-only 4,800-completion sweep")
    func quickCampaignRecipe() throws {
        let arms = LabCampaignFactory.arms(for: .quickSweep8)

        #expect(arms.count == 8)
        #expect(Set(arms.map(\.id)).count == 8)
        #expect(arms.allSatisfy { $0.scenarios.partition == .development })
        #expect(arms.allSatisfy { $0.judgment.suppressesSensitiveScenes })
        #expect(arms.allSatisfy { $0.generation.requestMode == .productionStreaming })
        #expect(arms.first?.id == "qwen-factorial-a0")
        #expect(arms.last?.id == "qwen-factorial-a7")
        let cells = Set(arms.map {
            "\($0.generation.temperature):\($0.generation.predictionTokens)"
        })
        #expect(cells == Set([
            "0.0:20", "0.0:12", "0.05:20", "0.05:12",
            "0.1:20", "0.1:12", "0.15:20", "0.15:12",
        ]))
        #expect(arms.allSatisfy { $0.judgment.maximumVisibleWords == 3 })
        #expect(arms.allSatisfy { $0.judgment.maximumVisibleCharacters == 42 })
        _ = try LabExperimentManifest(
            name: "Quick 8",
            arms: arms,
            research: LabCampaignFactory.researchProtocol(for: .quickSweep8)
        ).validated()
    }

    @Test("The deep campaign fills the safe matrix with protected production-fidelity arms")
    func deepCampaignRecipe() throws {
        let arms = LabCampaignFactory.arms(for: .deepSweep128)

        #expect(arms.count == 128)
        #expect(Set(arms.map(\.id)).count == 128)
        #expect(arms.allSatisfy { $0.judgment.suppressesSensitiveScenes })
        #expect(arms.allSatisfy { $0.generation.requestMode == .productionStreaming })
        #expect(arms.first?.id == "s3-control-start")
        #expect(arms.last?.id == "s3-control-end")
        #expect(arms.filter { $0.id.contains("control") }.count == 2)
        _ = try LabExperimentManifest(
            name: "Deep 128",
            arms: arms,
            research: LabCampaignFactory.researchProtocol(for: .deepSweep128)
        ).validated()
    }

    @Test("Intent futures match production by staying out of chat prompts")
    func productionIntentFuturesRegisterGate() {
        let chat = LabScenario(
            id: "prompt.chat",
            category: "reply.test",
            typedContext: "Yes, ",
            scene: LabScene(
                mode: .replying,
                turns: [.init(speaker: .other, text: "Can you send it tomorrow?")]
            ),
            expectation: .init(shouldSuggest: true, goldenContinuation: "tomorrow works")
        )
        var configuration = LabPromptConfiguration(includesIntentFutures: true)
        let chatPrompt = LabPromptComposer.prepare(scenario: chat, configuration: configuration).prompt
        #expect(!chatPrompt.contains("Likely response directions:"))

        configuration.registerOverride = .email
        let emailPrompt = LabPromptComposer.prepare(scenario: chat, configuration: configuration).prompt
        #expect(emailPrompt.contains("Likely response directions:"))
    }

    @Test("Scenario partitions and coverage tags select an honest subset")
    func scenarioSelection() throws {
        let development = scenario(
            id: "dev.typo",
            partition: .development,
            tags: ["typo"]
        )
        let validation = scenario(
            id: "validation.clean",
            partition: .validation,
            tags: []
        )
        let suite = LabScenarioSuite(name: "selector", scenarios: [development, validation])
        var configuration = LabScenarioVariationConfiguration()
        configuration.partition = .development
        configuration.includesTypos = false
        #expect(LabScenarioSelector.select(from: suite, configuration: configuration).scenarios.isEmpty)

        configuration.includesTypos = true
        let selected = LabScenarioSelector.select(from: suite, configuration: configuration)
        #expect(selected.scenarios.map(\.id) == [development.id])
    }

    @Test("Quality-only selection keeps speak cases and limits distinct roots deterministically")
    func qualityOnlyScenarioSelection() {
        func candidate(_ id: String, root: String, shouldSuggest: Bool) -> LabScenario {
            LabScenario(
                id: id,
                category: "reply.quality",
                typedContext: "Hello ",
                expectation: shouldSuggest
                    ? .init(shouldSuggest: true, goldenContinuation: "there")
                    : .init(shouldSuggest: false),
                evaluation: LabEvaluationMetadata(rootScenarioID: root)
            )
        }
        let suite = LabScenarioSuite(
            name: "quality selector",
            scenarios: [
                candidate("a.one", root: "a", shouldSuggest: true),
                candidate("a.two", root: "a", shouldSuggest: true),
                candidate("silence", root: "silence", shouldSuggest: false),
                candidate("b.one", root: "b", shouldSuggest: true),
                candidate("c.one", root: "c", shouldSuggest: true),
            ]
        )
        let configuration = LabScenarioVariationConfiguration(
            suggestionExpectation: .speakOnly,
            maximumDistinctSituations: 2
        )

        let selected = LabScenarioSelector.select(from: suite, configuration: configuration)

        #expect(selected.scenarios.map(\.id) == ["a.one", "a.two", "c.one"])
        #expect(Set(selected.scenarios.map { $0.evaluation.rootScenarioID }).count == 2)
        #expect(selected.scenarios.allSatisfy { $0.expectation.shouldSuggest })
    }

    @Test("The 50-case model smoke slice covers ordinary and stress reply families")
    func modelQualitySmokeBreadth() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let selected = LabScenarioSelector.select(
            from: suite,
            configuration: LabScenarioVariationConfiguration(
                partition: .development,
                suggestionExpectation: .speakOnly,
                maximumDistinctSituations: 50
            )
        )

        #expect(selected.scenarios.count == 50)
        #expect(selected.scenarios.contains { $0.category.hasPrefix("reply.") })
        #expect(selected.scenarios.contains { $0.category.hasPrefix("stress.") })
        #expect(Set(selected.scenarios.map(\.category)).count >= 10)
    }

    @Test("The full model quality slice contains all 360 development reply opportunities")
    func modelQualityFullBreadth() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let selected = LabScenarioSelector.select(
            from: suite,
            configuration: LabScenarioVariationConfiguration(
                partition: .development,
                suggestionExpectation: .speakOnly,
                maximumDistinctSituations: 360
            )
        )

        #expect(selected.scenarios.count == 360)
        #expect(selected.scenarios.allSatisfy { $0.expectation.shouldSuggest })
        #expect(Set(selected.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count == 360)
    }

    @Test("Prompt recipes vary shape while scrubbing structured secrets")
    func promptRecipesAndRedaction() {
        let secret = "sk-abcdefghijklmnopqrstuvwxyz123456"
        let scenario = LabScenario(
            id: "prompt.secret",
            category: "reply.test",
            typedContext: "Yes, ",
            scene: LabScene(
                mode: .replying,
                turns: [.init(speaker: .other, text: "Use token \(secret) and reply today")]
            ),
            expectation: .init(shouldSuggest: true, goldenContinuation: "today works")
        )
        let production = LabPromptComposer.prepare(
            scenario: scenario,
            configuration: LabPromptConfiguration()
        )
        var custom = LabPromptConfiguration()
        custom.recipe = .minimal
        custom.conversationFormat = .roleLabels
        custom.scenePlacement = .afterText
        let experimental = LabPromptComposer.prepare(scenario: scenario, configuration: custom)

        #expect(production.prompt != experimental.prompt)
        #expect(!production.prompt.contains(secret))
        #expect(!experimental.prompt.contains(secret))
        #expect(production.prompt.contains("redacted"))
        #expect(experimental.prompt.contains("redacted"))
    }

    @Test("Strict factual grounding suppresses an invented time with a reason code")
    func factualGroundingReason() {
        let scenario = LabScenario(
            id: "reply.time",
            category: "reply.test",
            typedContext: "Yes, ",
            scene: LabScene(
                mode: .replying,
                turns: [.init(speaker: .other, text: "Can we meet Thursday at 3?")]
            ),
            expectation: .init(shouldSuggest: true, goldenContinuation: "Thursday at 3 works")
        )
        var arm = LabArmConfiguration()
        arm.judgment.factualGrounding = .numbersAndNames
        let prepared = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt)
        let decision = LabOutputJudge.judge(
            rawOutput: "Thursday at 4 works",
            preparedPrompt: prepared,
            scenario: scenario,
            configuration: arm,
            meanTokenProbability: nil
        )

        #expect(decision.suggestion == nil)
        #expect(decision.reason == .unsupportedFact)
    }

    @Test("Default synthetic audits exercise every non-model bench")
    func syntheticBenchAudits() {
        let arm = LabArmConfiguration()
        let runtime = LabRuntimeConfiguration()
        for bench in LabBenchKind.allCases {
            let report = LabSyntheticBenchRunner.run(bench: bench, arm: arm, runtime: runtime)
            #expect(!report.checks.isEmpty)
            #expect(report.failed == 0, "\(bench.rawValue) had failing default checks")
        }
    }

    @Test("Reason codes and expanded scorecard stay aggregate-only")
    func scorecardReasons() throws {
        let value = scenario(id: "reply.reason", partition: .development, tags: [])
        let result = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: nil,
            modelRequested: true,
            decisionReason: .sceneEcho
        )
        let metrics = LabScorer.aggregate([result], elapsedSeconds: 1)
        let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)

        #expect(result.outcome == .silent)
        #expect(metrics.decisionReasonCounts[LabDecisionReason.sceneEcho.rawValue] == 1)
        #expect(metrics.qualityScore != nil)
        #expect(!encoded.contains("RAW_MODEL_OUTPUT"))
    }

    private func scenario(
        id: String,
        partition: LabScenarioPartition,
        tags: [String]
    ) -> LabScenario {
        LabScenario(
            id: id,
            category: "reply.test",
            partition: partition,
            tags: tags,
            typedContext: "Hello ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "world")
        )
    }
}
