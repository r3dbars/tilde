import AutocompleteLabCore
import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab scenario suites")
struct LabScenarioSuiteTests {
    @Test("Slack Reply Gold replays every prefix across the context ladder")
    func slackReplyGold() throws {
        let suite = try LabSlackReplyGoldSuiteFactory.makeSuite()
        #expect(suite.scenarios.count == 300)
        #expect(Set(suite.scenarios.map(\.evaluation.contextVariant)) == Set(LabSlackReplyGoldSuiteFactory.contextVariants))
        #expect(suite.scenarios.allSatisfy { $0.evaluation.source == .handCurated })
        #expect(suite.scenarios.allSatisfy { $0.evaluation.temporalIntegrity.passed })
        #expect(suite.scenarios.contains { $0.evaluation.checkpoint == .twoWords })
        #expect(suite.scenarios.contains { $0.evaluation.checkpoint == .nearEnd })
        for partition in [LabScenarioPartition.development, .validation, .holdout] {
            #expect(suite.scenarios.contains {
                $0.partition == partition && $0.category.hasPrefix("silence.sensitive.")
            })
        }
    }

    @Test("Unverified history cannot leak into protected partitions")
    func temporalLeakageGate() {
        let scenario = LabScenario(
            id: "history.leak",
            category: "reply.history",
            partition: .validation,
            typedContext: "I can ",
            expectation: LabExpectation(shouldSuggest: true, goldenContinuation: "send it"),
            evaluation: LabEvaluationMetadata(
                source: .historicalTypedInstead,
                temporalIntegrity: .unverifiedHistorical
            )
        )
        #expect(throws: LabValidationError.self) {
            try LabScenarioSuite(name: "Leak check", scenarios: [scenario]).validated()
        }
    }

    @Test("Private replay imports opaque development cases without changing its source")
    func historicalReplayLoader() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let events: [[String: Any]] = [
            ["ts": "2026-01-01T00:00:00Z", "event": "accept_all", "app_bundle": "test.chat", "context": "I can ", "ghost": "do it", "accepted": "do it"],
            ["ts": "2026-01-02T00:00:00Z", "event": "typed_instead", "app_bundle": "test.chat", "context": "I will ", "ghost": "wait", "typed": "send it"],
        ]
        let brain: [[String: Any]] = [
            ["app_bundle": "test.chat", "context": "I can ", "suggestion": "do it", "screen": "Synthetic teammate context"],
        ]
        try jsonLines(events).write(
            to: directory.appendingPathComponent("ghost_events_test.jsonl"),
            options: .atomic
        )
        try jsonLines(brain).write(
            to: directory.appendingPathComponent("brain_samples_test.jsonl"),
            options: .atomic
        )

        let loaded = try LabHistoricalReplayLoader.load(from: directory)
        #expect(loaded.summary.acceptedCases == 1)
        #expect(loaded.summary.typedInsteadCases == 1)
        #expect(loaded.summary.screenContextCases == 1)
        #expect(loaded.suite.scenarios.count == 4)
        #expect(loaded.suite.scenarios.allSatisfy { $0.partition == .development })
        #expect(loaded.suite.scenarios.allSatisfy { !$0.evaluation.temporalIntegrity.passed })
        #expect(loaded.suite.scenarios.allSatisfy { $0.id.hasPrefix("history-") })

        let mixed = try LabMixedLearningSuiteFactory.make(
            historical: loaded.suite,
            protected: LabSlackReplyGoldSuiteFactory.makeSuite()
        )
        let mixedDevelopment = mixed.scenarios.filter { $0.partition == .development }
        #expect(mixedDevelopment.count(where: { $0.evaluation.source.isHistorical }) == 4)
        #expect(mixedDevelopment.count(where: { !$0.evaluation.source.isHistorical }) == 2)
        #expect(mixed.scenarios.filter { $0.partition == .validation || $0.partition == .holdout }
            .allSatisfy { !$0.evaluation.source.isHistorical })
    }

    private func jsonLines(_ objects: [[String: Any]]) throws -> Data {
        var data = Data()
        for object in objects {
            data.append(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
            data.append(0x0A)
        }
        return data
    }
    @Test("The improved quiz has 400 unique cases and a locked 60/20/20 split")
    func builtInSuiteV2() throws {
        let suite = try LabScenarioSuiteLoader.builtInReplyingSuite()
        #expect(suite.name == "Replying evaluation v2 400")
        #expect(suite.scenarios.count == 400)
        #expect(suite.scenarios.count(where: { $0.partition == .development }) == 240)
        #expect(suite.scenarios.count(where: { $0.partition == .validation }) == 80)
        #expect(suite.scenarios.count(where: { $0.partition == .holdout }) == 80)
        #expect(suite.scenarios.count(where: { $0.expectation.shouldSuggest }) == 240)
        #expect(suite.scenarios.count(where: { !$0.expectation.shouldSuggest }) == 160)
        #expect(suite.scenarios.count(where: { $0.category.hasPrefix("reply.") }) == 160)
        #expect(suite.scenarios.count(where: { $0.category.hasPrefix("silence.ordinary.") }) == 120)
        #expect(suite.scenarios.count(where: { $0.category.hasPrefix("silence.sensitive.") }) == 40)
        #expect(suite.scenarios.count(where: { $0.category.hasPrefix("stress.") }) == 80)
        #expect(Set(suite.scenarios.map(\.id)).count == suite.scenarios.count)
        let duplicatePrompts = Dictionary(grouping: suite.scenarios, by: signature)
            .values
            .filter { $0.count > 1 }
            .map { $0.map(\.id).joined(separator: ",") }
            .sorted()
        #expect(duplicatePrompts.isEmpty, "Duplicate prompts: \(duplicatePrompts)")
        #expect(try suite.digestSHA256().count == 64)
        #expect(try suite.digestSHA256() == LabScenarioSuiteLoader.builtInReplyingSuiteV2().digestSHA256())
    }

    @Test("Every V2 counterfactual pair has two cases")
    func counterfactualPairs() throws {
        let suite = try LabScenarioSuiteLoader.builtInReplyingSuiteV2()
        let pairs = Dictionary(grouping: suite.scenarios) { scenario in
            scenario.tags.first(where: { $0.hasPrefix("pair-") }) ?? "missing"
        }
        #expect(pairs["missing"] == nil)
        #expect(pairs.count == 200)
        #expect(pairs.values.allSatisfy { $0.count == 2 })
    }

    @Test("Sensitive cases fire the production gate and near-misses do not")
    func sensitiveCoverage() throws {
        let suite = try LabScenarioSuiteLoader.builtInReplyingSuiteV2()
        let sensitive = suite.scenarios.filter { $0.category.hasPrefix("silence.sensitive.") }
        let nearMisses = suite.scenarios.filter { $0.category == "stress.sensitive-near-miss" }

        #expect(sensitive.count == 40)
        #expect(nearMisses.count == 8)
        #expect(sensitive.allSatisfy { SensitiveScenePolicy.isSensitive(scene: $0.scene?.productionScene()) })
        #expect(nearMisses.allSatisfy { !SensitiveScenePolicy.isSensitive(scene: $0.scene?.productionScene()) })
    }

    @Test("The legacy 16-case baseline remains available explicitly")
    func builtInSuiteV1() throws {
        let suite = try LabScenarioSuiteLoader.builtInReplyingSuiteV1()
        #expect(suite.name == "Replying baseline v1")
        #expect(suite.scenarios.count == 16)
    }

    @Test("The default V2 validation selection remains a valid 80-case suite")
    func validationSelection() throws {
        let suite = try LabScenarioSuiteLoader.builtInReplyingSuiteV2()
        let selected = LabScenarioSelector.select(
            from: suite,
            configuration: LabScenarioVariationConfiguration(partition: .validation)
        )
        #expect(selected.scenarios.count == 80)
        _ = try selected.validated()
    }

    @Test("Duplicate stable IDs are rejected without echoing fixture text")
    func duplicateIDs() {
        let scenario = makeScenario(id: "duplicate")
        let suite = LabScenarioSuite(name: "test", scenarios: [scenario, scenario])
        #expect(throws: LabValidationError.self) { try suite.validated() }
    }

    @Test("A positive case needs an objective grading signal")
    func missingExpectation() {
        let scenario = LabScenario(
            id: "missing-grade",
            category: "reply.test",
            typedContext: "Hello ",
            expectation: LabExpectation(shouldSuggest: true)
        )
        let suite = LabScenarioSuite(name: "test", scenarios: [scenario])
        #expect(throws: LabValidationError.self) { try suite.validated() }
    }

    private func makeScenario(id: String) -> LabScenario {
        LabScenario(
            id: id,
            category: "reply.test",
            typedContext: "Hello ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "world"
            )
        )
    }

    private func signature(_ scenario: LabScenario) -> String {
        let turns = scenario.scene?.turns.map { "\($0.speaker.rawValue):\($0.text)" }.joined(separator: "|") ?? ""
        return "\(scenario.typedContext)|\(turns)|\(scenario.expectation.goldenContinuation ?? "silence")"
    }
}
