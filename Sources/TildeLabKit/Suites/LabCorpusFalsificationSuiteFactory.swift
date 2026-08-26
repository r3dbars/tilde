import Foundation

public enum LabCorpusFalsificationSuiteFactory {
    public static func typedOnly(_ suite: LabScenarioSuite) throws -> LabScenarioSuite {
        try LabScenarioSuite(
            name: "\(suite.name) Typed Only",
            scenarios: suite.scenarios.map { scenario in
                copy(
                    scenario,
                    scene: nil,
                    evidence: LabContextEvidence(),
                    contextVariant: .typedOnly,
                    addedTag: "control-typed-only"
                )
            }
        ).validated()
    }

    public static func wrongContext(_ suite: LabScenarioSuite) throws -> LabScenarioSuite {
        let grouped = Dictionary(grouping: suite.scenarios) { scenario in
            "\(scenario.partition.rawValue):\(scenario.expectation.shouldSuggest ? "speak" : "silence")"
        }
        let scenarios = suite.scenarios.map { scenario -> LabScenario in
            let key = "\(scenario.partition.rawValue):\(scenario.expectation.shouldSuggest ? "speak" : "silence")"
            let candidates = (grouped[key] ?? []).filter {
                $0.id != scenario.id && $0.category != scenario.category
            }.sorted { $0.id < $1.id }
            let donor = candidates[stableIndex(scenario.id, count: candidates.count)]
            return copy(
                scenario,
                scene: donor.scene,
                evidence: donor.evaluation.evidence,
                contextVariant: .structuredThread,
                addedTag: "control-wrong-context"
            )
        }
        return try LabScenarioSuite(
            name: "\(suite.name) Wrong Context",
            scenarios: scenarios
        ).validated()
    }

    private static func copy(
        _ scenario: LabScenario,
        scene: LabScene?,
        evidence: LabContextEvidence,
        contextVariant: LabContextVariant,
        addedTag: String
    ) -> LabScenario {
        LabScenario(
            id: scenario.id,
            category: scenario.category,
            partition: scenario.partition,
            intent: scenario.intent,
            tone: scenario.tone,
            language: scenario.language,
            tags: Array(Set(scenario.tags + [addedTag])).sorted(),
            appBundleIdentifier: scenario.appBundleIdentifier,
            typedContext: scenario.typedContext,
            scene: scene,
            expectation: scenario.expectation,
            evaluation: LabEvaluationMetadata(
                source: scenario.evaluation.source,
                checkpoint: scenario.evaluation.checkpoint,
                contextVariant: contextVariant,
                temporalIntegrity: scenario.evaluation.temporalIntegrity,
                evidence: evidence,
                corpusID: scenario.evaluation.corpusID,
                rootScenarioID: scenario.evaluation.rootScenarioID,
                correctionKeystrokes: scenario.evaluation.correctionKeystrokes,
                dismissalKeystrokes: scenario.evaluation.dismissalKeystrokes
            )
        )
    }

    private static func stableIndex(_ value: String, count: Int) -> Int {
        precondition(count > 0)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(count))
    }
}
