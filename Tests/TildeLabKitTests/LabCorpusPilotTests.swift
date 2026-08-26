import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab corpus pilot")
struct LabCorpusPilotTests {
    @Test("The pilot contains exactly 1,000 distinct development situations")
    func exactPilotShape() throws {
        let source = try makeTaskmasterFixture(dialogueCount: 650)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let descriptor = testDescriptor()

        let pilot = try LabCorpusPilotSuiteFactory.make(
            taskmasterSourceURL: source,
            taskmasterDescriptor: descriptor
        )

        #expect(pilot.suite.scenarios.count == 1_000)
        #expect(pilot.distinctRootCount == 1_000)
        #expect(pilot.rootCountsByCorpus[descriptor.id] == 600)
        #expect(pilot.rootCountsByCorpus[LabCorpusRegistry.tildeSyntheticPilot.id] == 400)
        #expect(pilot.suite.scenarios.allSatisfy { $0.partition == .development })
        #expect(pilot.suite.scenarios.count(where: { $0.evaluation.source == .publicCorpus }) == 600)
        #expect(pilot.suite.scenarios.count(where: { $0.evaluation.source == .synthetic }) == 400)
    }

    @Test("Taskmaster normalization is deterministic and never includes the target in prior context")
    func deterministicLeakageSafeImport() throws {
        let source = try makeTaskmasterFixture(dialogueCount: 20)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let descriptor = testDescriptor()

        let first = try LabTaskmasterAdapter.loadScenarios(
            from: source,
            descriptor: descriptor,
            limit: 10
        )
        let second = try LabTaskmasterAdapter.loadScenarios(
            from: source,
            descriptor: descriptor,
            limit: 10
        )

        #expect(first == second)
        #expect(Set(first.map(\.id)).count == 10)
        for scenario in first {
            let target = normalized(
                scenario.typedContext + (scenario.expectation.goldenContinuation ?? "")
            )
            let prior = normalized(scenario.scene?.turns.map(\.text).joined(separator: " ") ?? "")
            #expect(!prior.contains(target))
            #expect(scenario.evaluation.temporalIntegrity.passed)
            #expect(scenario.evaluation.rootScenarioID == scenario.id)
            #expect(scenario.evaluation.corpusID == descriptor.id)
        }
    }

    @Test("Prefix expansion preserves opaque corpus and root identity")
    func prefixIdentity() throws {
        let root = try #require(LabCorpusSyntheticSuiteFactory.makeScenarios().first)
        let expanded = LabPrefixReplay.expand(root)
        #expect(!expanded.isEmpty)
        #expect(expanded.allSatisfy { $0.evaluation.corpusID == root.evaluation.corpusID })
        #expect(expanded.allSatisfy { $0.evaluation.rootScenarioID == root.id })
    }

    private func testDescriptor() -> LabCorpusDescriptor {
        LabCorpusDescriptor(
            id: "taskmaster-test",
            displayName: "Taskmaster test fixture",
            version: "test",
            licenseIdentifier: "test-only",
            mayBundleSourceText: false,
            developmentOnly: true
        )
    }

    private func makeTaskmasterFixture(dialogueCount: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dialogues: [[String: Any]] = (0..<dialogueCount).map { index in
            [
                "conversation_id": "fixture-\(String(format: "%04d", index))",
                "instruction_id": "instruction-\(index)",
                "utterances": [
                    ["index": 0, "speaker": "ASSISTANT", "text": "Can we review request \(index) tomorrow morning?"],
                    ["index": 1, "speaker": "USER", "text": "Yes I can review request \(index) tomorrow morning."],
                    ["index": 2, "speaker": "ASSISTANT", "text": "Please send the updated document \(index) afterward."],
                    ["index": 3, "speaker": "USER", "text": "I will send document \(index) after the review."],
                ],
            ]
        }
        let url = directory.appendingPathComponent("self-dialogs.json")
        try JSONSerialization.data(withJSONObject: dialogues, options: [.sortedKeys])
            .write(to: url, options: .atomic)
        return url
    }

    private func normalized(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}
