import Foundation
import Testing
import TildeCore
@testable import TildeLabKit

@Suite("Tilde Lab certified corpus")
struct LabCorpusCertificationTests {
    @Test("Certified V2 has decision-grade static coverage")
    func certifiedV2StaticCoverage() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let report = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite)

        #expect(report.rootCount == 1_000)
        #expect(report.positiveCount == 600)
        #expect(report.silenceCount == 400)
        #expect(report.developmentCount == 600)
        #expect(report.validationCount == 200)
        #expect(report.holdoutCount == 200)
        #expect(report.categoryFamilyCount >= 40)
        #expect(report.applicationCount >= 5)
        #expect(report.counterfactualPairCount == 500)
        #expect(report.supportedPositiveRate == 1)
        let positives = suite.scenarios.filter(\.expectation.shouldSuggest)
        #expect(positives.allSatisfy { $0.intent != nil })
        #expect(positives.allSatisfy { $0.expectation.acceptableContinuations.count == 7 })
        #expect(positives.reduce(0) { $0 + $1.expectation.acceptableContinuations.count } == 4_200)
        #expect(positives.allSatisfy { scenario in
            let paths = [scenario.expectation.goldenContinuation ?? ""]
                + scenario.expectation.acceptableContinuations
            return Set(paths.map { $0.lowercased() }).count == 8
        })
        #expect(report.checks.first { $0.id == "multi-answer" }?.status == .pass)
        #expect(report.passesStaticGate)
        #expect(report.checks.allSatisfy { $0.status == .pass })
        #expect(LabCorpusQualityAuditor.reviewSampleRootIDs(suite: suite).count == 100)
    }

    @Test("Scene gates cover hard negatives without hiding ordinary positive replies")
    func sceneGateCoverage() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let suppressed = suite.scenarios.compactMap { scenario -> (LabScenario, SceneSuggestionPolicy.SuppressionReason)? in
            guard let reason = SceneSuggestionPolicy.suppressionReason(
                scene: scenario.scene?.productionScene(),
                textBeforeCursor: scenario.typedContext
            ) else { return nil }
            return (scenario, reason)
        }
        let suppressedPositiveCategories = Set(
            suppressed.filter { $0.0.expectation.shouldSuggest }.map { $0.0.category }
        )
        let irrelevant = suite.scenarios.filter {
            $0.category == "silence.ordinary.irrelevant-scene"
        }

        #expect(suppressedPositiveCategories == ["stress.prompt-injection.real-request"])
        #expect(!irrelevant.isEmpty)
        #expect(irrelevant.allSatisfy { scenario in
            SceneSuggestionPolicy.suppressionReason(
                scene: scenario.scene?.productionScene(),
                textBeforeCursor: scenario.typedContext
            ) == .nonActionableScene
        })
    }

    @Test("Any corpus edit invalidates the frozen review")
    func staleReviewReceiptIsRejected() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let stale = LabCorpusReviewReceipt(
            rubricVersion: "fair-natural-predictable-v1",
            reviewer: "test",
            reviewedAt: "2026-08-25",
            corpusDigestSHA256: String(repeating: "0", count: 64),
            sampleDigestSHA256: LabCorpusQualityAuditor.reviewSampleDigest(suite: suite),
            reviewedCases: 100,
            approvedCases: 100
        )

        let report = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite, review: stale)

        #expect(report.verdict == .needsReview)
        #expect(report.checks.first { $0.id == "review" }?.status == .pending)
    }

    @Test("Falsification controls preserve targets but remove or mismatch context")
    func contextControlsAreRealAblations() throws {
        let suite = try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        let typedOnly = try LabCorpusFalsificationSuiteFactory.typedOnly(suite)
        let wrongContext = try LabCorpusFalsificationSuiteFactory.wrongContext(suite)

        #expect(typedOnly.scenarios.count == suite.scenarios.count)
        #expect(wrongContext.scenarios.count == suite.scenarios.count)
        for index in suite.scenarios.indices {
            let source = suite.scenarios[index]
            let typed = typedOnly.scenarios[index]
            let wrong = wrongContext.scenarios[index]
            #expect(typed.expectation == source.expectation)
            #expect(typed.scene == nil)
            #expect(typed.evaluation.contextVariant == .typedOnly)
            #expect(wrong.expectation == source.expectation)
            #expect(wrong.scene != source.scene)
            #expect(wrong.partition == source.partition)
        }
    }

    @Test("Model certificate requires context wins everywhere")
    func certificateVerdict() {
        let passing = certificate(
            partitions: LabScenarioPartition.allCases
                .filter { $0 == .development || $0 == .validation || $0 == .holdout }
                .map {
                    LabCorpusPartitionContextResult(
                        partition: $0,
                        correctExactMatchAt1Rate: 0.50,
                        typedOnlyExactMatchAt1Rate: 0.20,
                        wrongContextExactMatchAt1Rate: 0.10
                    )
                }
        )
        #expect(passing.passes)

        let failing = certificate(partitions: [
            LabCorpusPartitionContextResult(
                partition: .holdout,
                correctExactMatchAt1Rate: 0.20,
                typedOnlyExactMatchAt1Rate: 0.20,
                wrongContextExactMatchAt1Rate: 0.10
            ),
        ])
        #expect(!failing.passes)
        #expect(failing.failures.contains("context-win-not-stable-across-partitions"))
    }

    @Test("Aggregate certificate persists without scenario text")
    func certificateStoreRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-corpus-certificate-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LabCorpusCertificateStore(directory: directory)
        let original = certificate(partitions: [])

        try await store.save(original)
        let loaded = await store.load(corpusDigestSHA256: original.corpusDigestSHA256)

        #expect(loaded == original)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        let encoded = try String(contentsOf: files[0], encoding: .utf8)
        #expect(!encoded.contains("typedContext"))
        #expect(!encoded.contains("goldenContinuation"))
    }

    private func certificate(
        partitions: [LabCorpusPartitionContextResult]
    ) -> LabCorpusModelCertificate {
        LabCorpusModelCertificate(
            createdAt: Date(timeIntervalSince1970: 0),
            corpusID: LabCorpusRegistry.tildeCertifiedV2.id,
            corpusDigestSHA256: String(repeating: "a", count: 64),
            modelSHA256: String(repeating: "b", count: 64),
            helperSHA256: String(repeating: "c", count: 64),
            armID: "test-baseline",
            correctContext: LabCorpusContextMetrics(
                exactMatchAt1Rate: 0.50,
                usefulnessRate: 0.60,
                netKeystrokeSavingsRate: 0.40
            ),
            typedOnly: LabCorpusContextMetrics(
                exactMatchAt1Rate: 0.20,
                usefulnessRate: 0.30,
                netKeystrokeSavingsRate: 0.10
            ),
            wrongContext: LabCorpusContextMetrics(
                exactMatchAt1Rate: 0.10,
                usefulnessRate: 0.20,
                netKeystrokeSavingsRate: 0
            ),
            partitions: partitions
        )
    }
}
