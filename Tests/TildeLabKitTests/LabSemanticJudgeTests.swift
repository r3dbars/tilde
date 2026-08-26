import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab semantic judging")
struct LabSemanticJudgeTests {
    @Test("Semantic score preserves strict score and exposes graded dimensions")
    func aggregateScore() {
        let report = strictReport(model: "local", useful: true)
        let summary = LabSemanticJudgeScorer.summarize(
            modelIdentifier: "local",
            strictReport: report,
            scores: [
                LabSemanticScores(intent: 4, usefulness: 4, naturalness: 4, factuality: 4),
                LabSemanticScores(intent: 3, usefulness: 2, naturalness: 3, factuality: 4),
            ]
        )

        #expect(summary.strictQualityScore == 100)
        #expect(summary.semanticOverallScore == 85)
        #expect(summary.semanticUsefulRate == 0.5)
        #expect(summary.intentScore == 88)
        #expect(summary.usefulnessScore == 75)
        #expect(summary.factualityScore == 100)
    }

    @Test("Shootout counterbalances anonymous labels before scoring")
    func blindedShootout() async throws {
        let scenarios = [scenario("semantic.one"), scenario("semantic.two")]
        let suite = LabScenarioSuite(name: "semantic fixture", scenarios: scenarios)
        let arm = qualityArm()
        let judge = MockSemanticJudge()
        let runner = LabSemanticShootoutRunner(judge: judge)
        let local = strictReport(model: "local", useful: true, scenarios: scenarios, arm: arm)
        let frontier = strictReport(model: "frontier", useful: false, scenarios: scenarios, arm: arm)

        let report = try await runner.run(
            suite: suite,
            arm: arm,
            localReport: local,
            frontierReport: frontier,
            localCandidates: ["semantic.one": "local answer", "semantic.two": "local answer"],
            frontierCandidates: ["semantic.one": "frontier answer", "semantic.two": "frontier answer"],
            batchSize: 2
        )

        #expect(report.first.modelIdentifier == "local")
        #expect(report.first.semanticOverallScore == 100)
        #expect(report.second.semanticOverallScore == 0)
        #expect(await judge.localAppearedAsA == 1)
        #expect(await judge.localAppearedAsB == 1)
        #expect(!report.rawTextPersisted)
    }

    private func scenario(_ id: String) -> LabScenario {
        LabScenario(
            id: id,
            category: "reply.quality",
            partition: .development,
            typedContext: "Yes, ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "local answer", maximumWords: 3),
            evaluation: LabEvaluationMetadata(
                source: .synthetic,
                corpusID: LabCorpusRegistry.tildeCertifiedV2.id,
                rootScenarioID: id
            )
        )
    }

    private func qualityArm() -> LabArmConfiguration {
        var arm = LabArmConfiguration(id: "semantic", temperature: 0, predictionTokens: 20, maxVisibleWords: 3)
        arm.scenarios = LabScenarioVariationConfiguration(
            partition: .development,
            suggestionExpectation: .speakOnly,
            maximumDistinctSituations: 2
        )
        arm.scoring = LabScoringConfiguration(policyVersion: LabScoringConfiguration.modelOutputQualityPolicy)
        return arm
    }

    private func strictReport(
        model: String,
        useful: Bool,
        scenarios: [LabScenario]? = nil,
        arm: LabArmConfiguration? = nil
    ) -> LabRunReport {
        let scenarios = scenarios ?? [scenario("semantic.one")]
        let arm = arm ?? qualityArm()
        let results = scenarios.map {
            LabScorer.score(
                scenario: $0,
                repetition: 0,
                suggestion: useful ? "local answer" : "wrong answer",
                modelRequested: true
            )
        }
        return LabRunReport(
            startedAt: Date(),
            finishedAt: Date(),
            suiteName: "fixture",
            suiteDigestSHA256: String(repeating: "c", count: 64),
            scenarioCount: scenarios.count,
            arm: arm,
            execution: LabExecutionSnapshot(LabExecutionConfiguration(
                serverExecutable: URL(fileURLWithPath: "/usr/bin/false"),
                modelFile: URL(fileURLWithPath: "/dev/null"),
                repetitions: 1
            )),
            assets: LabAssetSnapshot(
                inferenceBackend: .localLlama,
                verificationMode: .experimentalLocal,
                modelIdentifier: model,
                modelRevision: "test",
                modelSHA256: String(repeating: "a", count: 64),
                helperSHA256: String(repeating: "b", count: 64)
            ),
            metrics: LabScorer.aggregate(results, elapsedSeconds: 1, scoring: arm.scoring),
            cases: results
        )
    }
}

private actor MockSemanticJudge: LabSemanticJudgeBatchClient {
    private(set) var localAppearedAsA = 0
    private(set) var localAppearedAsB = 0

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

    func judge(
        items: [LabSemanticJudgePromptItem],
        model: String,
        timeoutSeconds: Double
    ) async throws -> [LabSemanticPairJudgment] {
        items.map { item in
            let aIsLocal = item.candidateA?.contains("local") == true
            if aIsLocal { localAppearedAsA += 1 } else { localAppearedAsB += 1 }
            let good = LabSemanticScores(intent: 4, usefulness: 4, naturalness: 4, factuality: 4)
            let bad = LabSemanticScores(intent: 0, usefulness: 0, naturalness: 0, factuality: 0)
            return LabSemanticPairJudgment(
                id: item.id,
                candidateA: aIsLocal ? good : bad,
                candidateB: aIsLocal ? bad : good
            )
        }
    }

    func cancel() async {}
}
