import Foundation

public enum LabBuiltInCampaign: String, LabNamedOption {
    case quickSweep8 = "quick-8"
    case broadSweep50 = "broad-50"
    case modelQuality50 = "model-quality-50"
    case deepSweep128 = "deep-128"

    public var title: String {
        switch self {
        case .quickSweep8: "Quick 8-arm certified development sweep"
        case .broadSweep50: "Broad 50-arm output sweep"
        case .modelQuality50: "50-arm locked model-quality sweep"
        case .deepSweep128: "Deep 128-arm quality sweep"
        }
    }
}

/// Reproducible screening campaigns for unattended Lab work. Every returned
/// arm carries a complete manifest in its report, so the recipe is only a
/// convenient authoring surface—not hidden experiment state.
public enum LabCampaignFactory {
    public static func arms(for campaign: LabBuiltInCampaign) -> [LabArmConfiguration] {
        switch campaign {
        case .quickSweep8: quickSweep8()
        case .broadSweep50: broadSweep50()
        case .modelQuality50: modelQuality50()
        case .deepSweep128: deepSweep128()
        }
    }

    /// A directly comparable model-quality campaign: every arm sees the same
    /// 360 speak-only development situations and uses the same quality score.
    /// The broad control surface remains, but output length is normalized to
    /// the production three-word experiment except for explicit 1/2/3-word
    /// cap arms.
    private static func modelQuality50() -> [LabArmConfiguration] {
        var arms = broadSweep50()
        for index in arms.indices {
            arms[index].id = arms[index].id.replacingOccurrences(of: "s2-", with: "mq50-")
            arms[index].scenarios = LabScenarioVariationConfiguration(
                partition: .development,
                suggestionExpectation: .speakOnly,
                maximumDistinctSituations: 360
            )
            arms[index].scoring = LabScoringConfiguration(
                policyVersion: LabScoringConfiguration.modelOutputQualityPolicy,
                usefulnessWeight: 0.80,
                restraintWeight: 0,
                factualityWeight: 0.15,
                brevityWeight: 0.05,
                weightsLockedDuringComparison: true
            )
            arms[index].judgment.maximumVisibleWords = 3
            arms[index].judgment.maximumVisibleCharacters = 42
        }

        let explicitCaps = [
            "mq50-visible-3": 1,
            "mq50-visible-5": 2,
            "mq50-visible-12": 3,
        ]
        for index in arms.indices {
            guard let cap = explicitCaps[arms[index].id] else { continue }
            arms[index].id = "mq50-visible-\(cap)"
            arms[index].judgment.maximumVisibleWords = cap
            arms[index].judgment.maximumVisibleCharacters = cap * 14
        }

        precondition(arms.count == 50)
        return arms
    }

    /// A short, production-fidelity learning run for Certified Corpus V2.
    /// Eight arms x 600 development situations = 4,800 completions at one
    /// repetition. Controls at both ends expose obvious run-order drift.
    private static func quickSweep8() -> [LabArmConfiguration] {
        var arms = [
            productionArm("q8-control-start"),
            productionArm("q8-prediction-tokens-8") {
                $0.generation.predictionTokens = 8
            },
            productionArm("q8-visible-words-3") { arm in
                arm.judgment.maximumVisibleWords = 3
                arm.judgment.maximumVisibleCharacters = 36
            },
            productionArm("q8-confidence-020") { arm in
                arm.generation.probabilityCount = 5
                arm.generation.minimumMeanTokenProbability = 0.20
            },
            productionArm("q8-conversation-turns-2") {
                $0.prompt.conversationTurnLimit = 2
            },
            productionArm("q8-intent-futures-2") {
                $0.prompt.maximumIntentFutures = 2
            },
            productionArm("q8-combo-tokens-8-visible-3") { arm in
                arm.generation.predictionTokens = 8
                arm.judgment.maximumVisibleWords = 3
                arm.judgment.maximumVisibleCharacters = 36
            },
            productionArm("q8-control-end"),
        ]
        for index in arms.indices {
            arms[index].scenarios.partition = .development
        }
        precondition(arms.count == 8)
        return arms
    }

    private static func broadSweep50() -> [LabArmConfiguration] {
        var arms: [LabArmConfiguration] = []

        arms.append(productionArm("s2-00-production"))
        for (label, value) in [
            ("005", 0.05), ("010", 0.10), ("015", 0.15), ("020", 0.20),
            ("025", 0.25), ("030", 0.30), ("040", 0.40),
        ] {
            arms.append(temperatureArm("s2-temp-\(label)", value))
        }

        for value in [10, 20, 80, 160] {
            arms.append(samplingArm("s2-t015-top-k-\(value)") { $0.topK = value })
        }
        for (label, value) in [("070", 0.70), ("080", 0.80), ("090", 0.90), ("100", 1.0)] {
            arms.append(samplingArm("s2-t015-top-p-\(label)") { $0.topP = value })
        }
        for (label, value) in [("000", 0.0), ("001", 0.01), ("010", 0.10), ("020", 0.20)] {
            arms.append(samplingArm("s2-t015-min-p-\(label)") { $0.minP = value })
        }
        for (label, value) in [("070", 0.70), ("085", 0.85), ("095", 0.95)] {
            arms.append(samplingArm("s2-t015-typical-\(label)") { $0.typicalP = value })
        }
        for (label, value) in [("095", 0.95), ("105", 1.05), ("110", 1.10)] {
            arms.append(samplingArm("s2-t015-repeat-\(label)") { $0.repeatPenalty = value })
        }
        arms.append(samplingArm("s2-t015-presence-025") { $0.presencePenalty = 0.25 })
        arms.append(samplingArm("s2-t015-frequency-025") { $0.frequencyPenalty = 0.25 })

        for value in [12, 16, 24, 28, 36] {
            arms.append(productionArm("s2-tokens-\(value)") { $0.generation.predictionTokens = value })
        }
        for value in [3, 5, 12] {
            arms.append(productionArm("s2-visible-\(value)") { arm in
                arm.judgment.maximumVisibleWords = value
                arm.judgment.maximumVisibleCharacters = value * 12
            })
        }

        arms.append(productionArm("s2-prompt-minimal") { $0.prompt.recipe = .minimal })
        arms.append(productionArm("s2-prompt-no-examples") { $0.prompt.recipe = .noExamples })
        arms.append(productionArm("s2-context-1200") { $0.prompt.maximumContextCharacters = 1_200 })
        arms.append(productionArm("s2-context-6000") { $0.prompt.maximumContextCharacters = 6_000 })
        arms.append(productionArm("s2-scene-1000") { $0.prompt.maximumSceneCharacters = 1_000 })
        arms.append(productionArm("s2-scene-6000") { $0.prompt.maximumSceneCharacters = 6_000 })
        arms.append(productionArm("s2-turns-2") { $0.prompt.conversationTurnLimit = 2 })
        arms.append(productionArm("s2-newest-incoming") { $0.prompt.conversationSelection = .newestIncoming })
        arms.append(productionArm("s2-format-role-labels") { $0.prompt.conversationFormat = .roleLabels })
        arms.append(productionArm("s2-intent-off") { $0.prompt.includesIntentFutures = false })

        arms.append(productionArm("s2-facts-names-numbers") {
            $0.judgment.factualGrounding = .numbersAndNames
        })
        arms.append(productionArm("s2-facts-all-anchors") {
            $0.judgment.factualGrounding = .allAnchors
        })
        arms.append(productionArm("s2-echo-higher-threshold") { arm in
            arm.judgment.sceneEchoMinimumWords = 5
            arm.judgment.sceneEchoMinimumCharacters = 20
        })
        arms.append(productionArm("s2-echo-off-diagnostic") {
            $0.judgment.rejectsSceneEcho = false
        })

        precondition(arms.count == 50)
        return arms
    }

    /// Maximum-width, production-fidelity Reply Bench campaign. It keeps the
    /// runtime and scorecard fixed while screening generation, prompt, and
    /// judgment controls. Repeated controls at the start, middle, and end make
    /// long-run thermal or ordering drift visible without weakening any
    /// sensitive-scene protection.
    private static func deepSweep128() -> [LabArmConfiguration] {
        var arms: [LabArmConfiguration] = [productionArm("s3-control-start")]

        for (label, value) in [
            ("005", 0.05), ("010", 0.10), ("015", 0.15), ("020", 0.20),
            ("025", 0.25), ("030", 0.30), ("040", 0.40), ("050", 0.50),
            ("070", 0.70), ("100", 1.00),
        ] {
            arms.append(temperatureArm("s3-temp-\(label)", value))
        }
        for value in [0, 5, 10, 20, 80, 160] {
            arms.append(samplingArm("s3-top-k-\(value)") { $0.topK = value })
        }
        for (label, value) in [
            ("050", 0.50), ("060", 0.60), ("070", 0.70),
            ("080", 0.80), ("090", 0.90), ("100", 1.00),
        ] {
            arms.append(samplingArm("s3-top-p-\(label)") { $0.topP = value })
        }
        for (label, value) in [
            ("000", 0.00), ("001", 0.01), ("010", 0.10),
            ("020", 0.20), ("030", 0.30),
        ] {
            arms.append(samplingArm("s3-min-p-\(label)") { $0.minP = value })
        }
        for (label, value) in [
            ("050", 0.50), ("070", 0.70), ("085", 0.85), ("095", 0.95),
        ] {
            arms.append(samplingArm("s3-typical-\(label)") { $0.typicalP = value })
        }
        for (label, value) in [
            ("090", 0.90), ("095", 0.95), ("105", 1.05),
            ("110", 1.10), ("120", 1.20),
        ] {
            arms.append(samplingArm("s3-repeat-\(label)") { $0.repeatPenalty = value })
        }
        for (label, value) in [
            ("n050", -0.50), ("n025", -0.25), ("p025", 0.25), ("p050", 0.50),
        ] {
            arms.append(samplingArm("s3-presence-\(label)") { $0.presencePenalty = value })
        }
        for (label, value) in [
            ("n050", -0.50), ("n025", -0.25), ("p025", 0.25), ("p050", 0.50),
        ] {
            arms.append(samplingArm("s3-frequency-\(label)") { $0.frequencyPenalty = value })
        }
        for value in [8, 12, 16, 24, 28, 36, 48] {
            arms.append(productionArm("s3-tokens-\(value)") { $0.generation.predictionTokens = value })
        }
        arms.append(productionArm("s3-stop-sentence") { $0.generation.stopRule = .sentence })
        arms.append(productionArm("s3-stop-character-64") { arm in
            arm.generation.stopRule = .characterLimit
            arm.generation.stopCharacterLimit = 64
        })
        arms.append(productionArm("s3-stop-natural") { $0.generation.stopRule = .natural })

        arms.append(productionArm("s3-control-middle"))

        for value in [LabRegisterOverride.chat, .email, .prose] {
            arms.append(productionArm("s3-register-\(value.rawValue)") {
                $0.prompt.registerOverride = value
            })
        }
        arms.append(productionArm("s3-prompt-minimal") { $0.prompt.recipe = .minimal })
        arms.append(productionArm("s3-prompt-no-examples") { $0.prompt.recipe = .noExamples })
        for value in [400, 1_200, 6_000, 12_000] {
            arms.append(productionArm("s3-context-\(value)") {
                $0.prompt.maximumContextCharacters = value
            })
        }
        for value in [500, 1_000, 6_000, 12_000] {
            arms.append(productionArm("s3-scene-\(value)") {
                $0.prompt.maximumSceneCharacters = value
            })
        }
        for value in [0, 400, 2_400] {
            arms.append(productionArm("s3-reply-reserve-\(value)") {
                $0.prompt.replyReserveCharacters = value
            })
        }
        for value in [100, 1_000] {
            arms.append(productionArm("s3-scene-quantum-\(value)") {
                $0.prompt.sceneBudgetQuantum = value
            })
        }
        for value in [1, 2, 4, 16] {
            arms.append(productionArm("s3-turns-\(value)") {
                $0.prompt.conversationTurnLimit = value
            })
        }
        for value in [
            LabConversationSelection.newestIncoming, .lastTurns, .allBounded,
        ] {
            arms.append(productionArm("s3-selection-\(value.rawValue)") {
                $0.prompt.conversationSelection = value
            })
        }
        for value in [LabConversationFormat.roleLabels, .compact] {
            arms.append(productionArm("s3-format-\(value.rawValue)") {
                $0.prompt.conversationFormat = value
            })
        }
        arms.append(productionArm("s3-scene-after-text") { $0.prompt.scenePlacement = .afterText })
        arms.append(productionArm("s3-intent-off") { $0.prompt.includesIntentFutures = false })
        arms.append(productionArm("s3-intent-weight-070") { $0.prompt.intentPriorWeight = 0.70 })

        arms.append(productionArm("s3-cleaner-strict") { $0.judgment.cleanerPreset = .strict })
        arms.append(productionArm("s3-cleaner-diagnostic") {
            $0.judgment.cleanerPreset = .diagnostic
        })
        for value in [2, 3, 4, 5, 6, 10, 12, 16, 20] {
            arms.append(productionArm("s3-visible-\(value)") { arm in
                arm.judgment.maximumVisibleWords = value
                arm.judgment.maximumVisibleCharacters = value * 12
            })
        }
        for value in [24, 36, 48, 64, 128, 192] {
            arms.append(productionArm("s3-visible-chars-\(value)") {
                $0.judgment.maximumVisibleCharacters = value
            })
        }
        for value in [1, 2, 4, 5, 6, 8] {
            arms.append(productionArm("s3-echo-words-\(value)") {
                $0.judgment.sceneEchoMinimumWords = value
            })
        }
        for value in [5, 15, 20, 30, 50] {
            arms.append(productionArm("s3-echo-chars-\(value)") {
                $0.judgment.sceneEchoMinimumCharacters = value
            })
        }
        arms.append(productionArm("s3-echo-off-diagnostic") {
            $0.judgment.rejectsSceneEcho = false
        })
        arms.append(productionArm("s3-facts-names-numbers") {
            $0.judgment.factualGrounding = .numbersAndNames
        })
        arms.append(productionArm("s3-facts-all-anchors") {
            $0.judgment.factualGrounding = .allAnchors
        })
        arms.append(productionArm("s3-no-dangling-repair") {
            $0.judgment.repairsDanglingTail = false
        })
        arms.append(diagnosticCleanerArm("s3-allow-prompt-leak") {
            $0.rejectsPromptLeaks = false
        })
        arms.append(diagnosticCleanerArm("s3-allow-context-replay") {
            $0.rejectsContextReplay = false
        })
        arms.append(diagnosticCleanerArm("s3-allow-self-repetition") {
            $0.rejectsSelfRepetition = false
        })

        arms.append(productionArm("s3-combo-cap3-echo5") { arm in
            arm.judgment.maximumVisibleWords = 3
            arm.judgment.maximumVisibleCharacters = 36
            arm.judgment.sceneEchoMinimumWords = 5
            arm.judgment.sceneEchoMinimumCharacters = 20
        })
        arms.append(productionArm("s3-combo-cap4-echo5") { arm in
            arm.judgment.maximumVisibleWords = 4
            arm.judgment.maximumVisibleCharacters = 48
            arm.judgment.sceneEchoMinimumWords = 5
            arm.judgment.sceneEchoMinimumCharacters = 20
        })
        arms.append(productionArm("s3-combo-cap5-echo5") { arm in
            arm.judgment.maximumVisibleWords = 5
            arm.judgment.maximumVisibleCharacters = 60
            arm.judgment.sceneEchoMinimumWords = 5
            arm.judgment.sceneEchoMinimumCharacters = 20
        })
        arms.append(samplingArm("s3-combo-temp015-cap3", mutate: { generation in
            generation.temperature = 0.15
        }, judgment: { judgment in
            judgment.maximumVisibleWords = 3
            judgment.maximumVisibleCharacters = 36
        }))
        arms.append(samplingArm("s3-combo-temp015-echo5", mutate: { generation in
            generation.temperature = 0.15
        }, judgment: { judgment in
            judgment.sceneEchoMinimumWords = 5
            judgment.sceneEchoMinimumCharacters = 20
        }))
        arms.append(samplingArm("s3-combo-temp015-cap3-echo5", mutate: { generation in
            generation.temperature = 0.15
        }, judgment: { judgment in
            judgment.maximumVisibleWords = 3
            judgment.maximumVisibleCharacters = 36
            judgment.sceneEchoMinimumWords = 5
            judgment.sceneEchoMinimumCharacters = 20
        }))

        arms.append(productionArm("s3-control-end"))

        precondition(arms.count == 128)
        return arms
    }

    private static func productionArm(
        _ id: String,
        mutate: (inout LabArmConfiguration) -> Void = { _ in }
    ) -> LabArmConfiguration {
        var arm = LabArmConfiguration(id: id)
        arm.scenarios.partition = .validation
        arm.generation.requestMode = .productionStreaming
        arm.prompt.includesIntentFutures = true
        mutate(&arm)
        return arm
    }

    private static func temperatureArm(_ id: String, _ temperature: Double) -> LabArmConfiguration {
        productionArm(id) { arm in
            arm.generation.temperature = temperature
            arm.generation.preset = .custom
        }
    }

    private static func samplingArm(
        _ id: String,
        mutate: (inout LabGenerationConfiguration) -> Void
    ) -> LabArmConfiguration {
        productionArm(id) { arm in
            arm.generation.temperature = 0.15
            arm.generation.preset = .custom
            mutate(&arm.generation)
        }
    }

    private static func samplingArm(
        _ id: String,
        mutate: (inout LabGenerationConfiguration) -> Void,
        judgment: (inout LabJudgmentConfiguration) -> Void
    ) -> LabArmConfiguration {
        productionArm(id) { arm in
            arm.generation.temperature = 0.15
            arm.generation.preset = .custom
            mutate(&arm.generation)
            judgment(&arm.judgment)
        }
    }

    private static func diagnosticCleanerArm(
        _ id: String,
        mutate: (inout LabJudgmentConfiguration) -> Void
    ) -> LabArmConfiguration {
        productionArm(id) { arm in
            arm.judgment.cleanerPreset = .diagnostic
            mutate(&arm.judgment)
        }
    }
}
