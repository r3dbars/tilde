import Foundation
import Testing
import TildeCore
@testable import TildeLabKit

/// Offline measurement of the development-only extended ordinary-silence
/// gate. Aggregate counts only: no scenario text is asserted or printed.
@Suite("Extended ordinary-silence gate")
struct LabExtendedSilenceGateTests {
    private static let targetCategories: Set<String> = [
        "silence.ordinary.complete-sentence",
        "silence.ordinary.multiple-questions",
        "silence.ordinary.ambiguous-reference",
    ]

    private func suppressedCategories(
        _ suite: LabScenarioSuite,
        extended: Bool
    ) -> [String: Int] {
        var counts: [String: Int] = [:]
        for scenario in suite.scenarios {
            let reason = SceneSuggestionPolicy.suppressionReason(
                scene: scenario.scene?.productionScene(),
                textBeforeCursor: scenario.typedContext,
                options: .init(extendedOrdinarySilenceGate: extended)
            )
            guard reason != nil else { continue }
            counts[scenario.category, default: 0] += 1
        }
        return counts
    }

    @Test("Measured coverage: the three leaking subcategories move from 0 to fully gated")
    func extendedGateCoversTheLeakingSubcategories() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let targets = suite.scenarios.filter { Self.targetCategories.contains($0.category) }
        let before = suppressedCategories(suite, extended: false)
        let after = suppressedCategories(suite, extended: true)

        #expect(targets.count == 90)
        #expect(targets.allSatisfy { !$0.expectation.shouldSuggest })
        for category in Self.targetCategories {
            #expect(before[category, default: 0] == 0)
            #expect(after[category, default: 0] == 30)
        }
        let beforeTotal: Int = before.values.reduce(0, +)
        let afterTotal: Int = after.values.reduce(0, +)
        #expect(afterTotal - beforeTotal == 90)
    }

    @Test("Measured cost: no wanted-suggestion scenario is newly suppressed")
    func extendedGateAddsNoWantedSuppression() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let positives = suite.scenarios.filter(\.expectation.shouldSuggest)
        var newlySuppressed = 0
        var suppressedPositiveCategories: Set<String> = []
        for scenario in positives {
            let baseline = SceneSuggestionPolicy.suppressionReason(
                scene: scenario.scene?.productionScene(),
                textBeforeCursor: scenario.typedContext
            )
            let extended = SceneSuggestionPolicy.suppressionReason(
                scene: scenario.scene?.productionScene(),
                textBeforeCursor: scenario.typedContext,
                options: .init(extendedOrdinarySilenceGate: true)
            )
            guard extended != nil else { continue }
            suppressedPositiveCategories.insert(scenario.category)
            if baseline == nil { newlySuppressed += 1 }
        }

        #expect(positives.count == 600)
        #expect(newlySuppressed == 0)
        #expect(suppressedPositiveCategories == ["stress.prompt-injection.real-request"])
    }

    @Test("Neighbouring suites keep every wanted suggestion eligible")
    func neighbouringSuitesKeepPositivesEligible() throws {
        let suites = [
            try LabReplyingV2SuiteFactory.makeSuite(),
            try LabSlackReplyGoldSuiteFactory.makeSuite(),
            try LabScenarioSuite(
                name: "corpus-synthetic",
                scenarios: LabCorpusSyntheticSuiteFactory.makeScenarios()
            ),
        ]
        var positives = 0
        var newlySuppressed = 0
        for suite in suites {
            for scenario in suite.scenarios where scenario.expectation.shouldSuggest {
                positives += 1
                let baseline = SceneSuggestionPolicy.suppressionReason(
                    scene: scenario.scene?.productionScene(),
                    textBeforeCursor: scenario.typedContext
                )
                let extended = SceneSuggestionPolicy.suppressionReason(
                    scene: scenario.scene?.productionScene(),
                    textBeforeCursor: scenario.typedContext,
                    options: .init(extendedOrdinarySilenceGate: true)
                )
                if baseline == nil, extended != nil { newlySuppressed += 1 }
            }
        }

        #expect(positives > 200)
        #expect(newlySuppressed == 0)
    }

    @Test("The wider gate stays off unless a Lab arm opts in")
    func productionArmsKeepTheProductionGate() throws {
        let production = LabArmConfiguration()
        var probe = LabArmConfiguration()
        probe.judgment.extendedOrdinarySilenceGate = true

        #expect(!production.judgment.extendedOrdinarySilenceGate)
        #expect(!production.sceneSuppressionOptions.extendedOrdinarySilenceGate)
        #expect(probe.sceneSuppressionOptions.extendedOrdinarySilenceGate)
        #expect(try probe.validated().judgment.extendedOrdinarySilenceGate)
    }

    @Test("Stored arms without the key decode with the gate off")
    func legacyArmsDecodeGateOff() throws {
        let json = Data("""
        {"cleanerPreset":"production","maximumVisibleWords":6}
        """.utf8)
        let decoded = try JSONDecoder().decode(LabJudgmentConfiguration.self, from: json)
        #expect(!decoded.extendedOrdinarySilenceGate)
    }
}
