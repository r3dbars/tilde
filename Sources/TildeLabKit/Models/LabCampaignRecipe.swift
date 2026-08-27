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
        case .quickSweep8: qwenFactorial8()
        case .broadSweep50: generatorSweep(prefix: "s2", count: 50)
        case .modelQuality50: modelQuality50()
        case .deepSweep128: generatorSweep(prefix: "s3", count: 128)
        }
    }

    public static func researchProtocol(for campaign: LabBuiltInCampaign) -> LabResearchProtocol {
        let values = arms(for: campaign)
        let strategy: LabSearchStrategy
        switch campaign {
        case .quickSweep8, .modelQuality50:
            strategy = .fixed
        case .broadSweep50:
            strategy = .quasiRandom
        case .deepSweep128:
            strategy = .successiveHalving
        }
        return LabResearchProtocol(
            phase: .discovery,
            experimentClass: .generator,
            searchStrategy: strategy,
            baselineArmID: values[0].id,
            fixedGenerationSeeds: [values[0].generation.seed]
        )
    }

    /// The immediate Qwen follow-up from the v2 research protocol. Temperature
    /// and token budget form a clean 4 x 2 factorial while prompt, context,
    /// cleaner, display cap, runtime, and scoring remain fixed.
    private static func qwenFactorial8() -> [LabArmConfiguration] {
        var result: [LabArmConfiguration] = []
        let temperatures = [0.0, 0.05, 0.10, 0.15]
        let tokenBudgets = [20, 12]
        for temperature in temperatures {
            for tokens in tokenBudgets {
                let index = result.count
                var arm = productionArm("qwen-factorial-a\(index)")
                arm.generation.temperature = temperature
                arm.generation.preset = temperature == 0 ? .productionGreedy : .custom
                arm.generation.predictionTokens = tokens
                arm.judgment.maximumVisibleWords = 3
                arm.judgment.maximumVisibleCharacters = 42
                result.append(arm)
            }
        }
        precondition(result.count == 8)
        return result
    }

    /// A deterministic, bounded generator-only design. Single-factor points
    /// map the broad shape first; the remaining budget is filled with paired
    /// low-discrepancy-style combinations. No prompt, context, display, safety,
    /// personalization, or runtime control is allowed to drift.
    private static func generatorSweep(prefix: String, count: Int) -> [LabArmConfiguration] {
        precondition(count >= 2)
        var result: [LabArmConfiguration] = [productionArm("\(prefix)-control-start")]

        func append(_ label: String, mutate: (inout LabGenerationConfiguration) -> Void) {
            guard result.count < count - 1 else { return }
            var arm = productionArm("\(prefix)-\(label)")
            mutate(&arm.generation)
            if arm.generation.temperature > 0 { arm.generation.preset = .custom }
            result.append(arm)
        }

        for (label, value) in [
            ("temp-005", 0.05), ("temp-010", 0.10), ("temp-015", 0.15),
            ("temp-020", 0.20), ("temp-025", 0.25), ("temp-030", 0.30),
            ("temp-040", 0.40), ("temp-050", 0.50), ("temp-070", 0.70),
        ] { append(label) { $0.temperature = value } }
        for value in [0, 10, 20, 80, 160] {
            append("top-k-\(value)") { generation in
                generation.temperature = 0.15
                generation.topK = value
            }
        }
        for (label, value) in [("060", 0.60), ("070", 0.70), ("080", 0.80), ("090", 0.90), ("100", 1.0)] {
            append("top-p-\(label)") { generation in
                generation.temperature = 0.15
                generation.topP = value
            }
        }
        for (label, value) in [("000", 0.0), ("001", 0.01), ("010", 0.10), ("020", 0.20), ("030", 0.30)] {
            append("min-p-\(label)") { generation in
                generation.temperature = 0.15
                generation.minP = value
            }
        }
        for (label, value) in [("050", 0.50), ("070", 0.70), ("085", 0.85), ("095", 0.95)] {
            append("typical-p-\(label)") { generation in
                generation.temperature = 0.15
                generation.typicalP = value
            }
        }
        for (label, value) in [("095", 0.95), ("105", 1.05), ("110", 1.10), ("120", 1.20)] {
            append("repeat-\(label)") { generation in
                generation.temperature = 0.15
                generation.repeatPenalty = value
            }
        }
        for value in [8, 10, 12, 16, 24, 32] {
            append("tokens-\(value)") { $0.predictionTokens = value }
        }

        let temperatures = [0.05, 0.10, 0.15, 0.20, 0.30, 0.40]
        let tokenBudgets = [8, 12, 16, 20, 24]
        let topPs = [0.70, 0.80, 0.90, 0.95]
        let topKs = [10, 20, 40, 80]
        var combination = 0
        outer: for temperature in temperatures {
            for tokens in tokenBudgets {
                for topP in topPs {
                    for topK in topKs {
                        guard result.count < count - 1 else { break outer }
                        append("combo-\(String(format: "%03d", combination))") { generation in
                            generation.temperature = temperature
                            generation.predictionTokens = tokens
                            generation.topP = topP
                            generation.topK = topK
                        }
                        combination += 1
                    }
                }
            }
        }
        result.append(productionArm("\(prefix)-control-end"))
        precondition(result.count == count)
        precondition(Set(result.map(\.id)).count == count)
        return result
    }

    /// A directly comparable model-quality campaign: every arm sees the same
    /// 360 speak-only development situations and uses the same quality score.
    /// The broad control surface remains, but output length is normalized to
    /// the production three-word experiment except for explicit 1/2/3-word
    /// cap arms.
    private static func modelQuality50() -> [LabArmConfiguration] {
        var arms = generatorSweep(prefix: "mq50", count: 50)
        for index in arms.indices {
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

        precondition(arms.count == 50)
        return arms
    }

    private static func productionArm(
        _ id: String,
        mutate: (inout LabArmConfiguration) -> Void = { _ in }
    ) -> LabArmConfiguration {
        var arm = LabArmConfiguration(id: id)
        arm.scenarios.partition = .development
        arm.generation.requestMode = .productionStreaming
        arm.prompt.includesIntentFutures = true
        mutate(&arm)
        return arm
    }

}
