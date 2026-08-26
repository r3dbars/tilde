import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab frontier ceiling")
struct LabFrontierCeilingRunnerTests {
    @Test("Synthetic quality cases use the same grader and disclose network inference")
    func syntheticQualityCeiling() async throws {
        let suite = LabScenarioSuite(
            name: "frontier fixture",
            scenarios: [scenario(id: "frontier.one"), scenario(id: "frontier.two")]
        )
        let client = MockFrontierClient(suggestions: [
            "frontier.one": "works",
            "frontier.two": "works",
        ])
        let runner = LabFrontierCeilingRunner(client: client)

        let report = try await runner.run(
            suite: suite,
            arm: qualityArm(maximumSituations: 2),
            configuration: LabFrontierCeilingConfiguration(batchSize: 1)
        )

        #expect(report.assets.inferenceBackend == .codexSubscription)
        #expect(report.privacy.networkInference)
        #expect(report.metrics.qualityScore == 100)
        #expect(report.metrics.useful == 2)
        #expect(report.metrics.totalCases == 2)
        #expect(await client.completedBatchCount == 2)
    }

    @Test("Historical writing is rejected before the frontier client is called")
    func historicalWritingBlocked() async throws {
        let historical = LabScenario(
            id: "frontier.private",
            category: "reply.quality",
            partition: .development,
            typedContext: "Yes, ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "works", maximumWords: 3),
            evaluation: LabEvaluationMetadata(
                source: .historicalAccepted,
                corpusID: "private-tilde-history",
                rootScenarioID: "frontier.private"
            )
        )
        let client = MockFrontierClient(suggestions: [:])
        let runner = LabFrontierCeilingRunner(client: client)

        do {
            _ = try await runner.run(
                suite: LabScenarioSuite(name: "private fixture", scenarios: [historical]),
                arm: qualityArm(maximumSituations: 1)
            )
            Issue.record("Historical writing unexpectedly reached the frontier runner.")
        } catch LabFrontierCeilingError.unsafeSuite {
            // Expected hard privacy boundary.
        } catch {
            Issue.record("Unexpected frontier error: \(error)")
        }
        #expect(await client.completedBatchCount == 0)
    }

    private func scenario(id: String) -> LabScenario {
        LabScenario(
            id: id,
            category: "reply.quality",
            partition: .development,
            typedContext: "Yes, ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "works", maximumWords: 3),
            evaluation: LabEvaluationMetadata(
                source: .synthetic,
                corpusID: LabCorpusRegistry.tildeCertifiedV2.id,
                rootScenarioID: id
            )
        )
    }

    private func qualityArm(maximumSituations: Int) -> LabArmConfiguration {
        var arm = LabArmConfiguration(
            id: "frontier-quality",
            temperature: 0,
            predictionTokens: 20,
            maxVisibleWords: 3
        )
        arm.scenarios = LabScenarioVariationConfiguration(
            partition: .development,
            suggestionExpectation: .speakOnly,
            maximumDistinctSituations: maximumSituations
        )
        arm.scoring = LabScoringConfiguration(
            policyVersion: LabScoringConfiguration.modelOutputQualityPolicy
        )
        return arm
    }
}

private actor MockFrontierClient: LabFrontierBatchClient {
    private let suggestions: [String: String]
    private(set) var completedBatchCount = 0

    init(suggestions: [String: String]) {
        self.suggestions = suggestions
    }

    func verifySubscription(model: String) async throws -> LabAssetSnapshot {
        LabAssetSnapshot(
            inferenceBackend: .codexSubscription,
            verificationMode: .experimentalLocal,
            modelIdentifier: model,
            modelRevision: "test",
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64)
        )
    }

    func complete(
        items: [LabFrontierPromptItem],
        model: String,
        timeoutSeconds: Double
    ) async throws -> [LabFrontierSuggestion] {
        completedBatchCount += 1
        return items.map { LabFrontierSuggestion(id: $0.id, suggestion: suggestions[$0.id]) }
    }

    func cancel() async {}
}
