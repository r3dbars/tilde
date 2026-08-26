import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab learning cycles")
struct LabLearningCycleTests {
    @Test("Accepted cycles retain the held-out diagnostic score")
    func acceptedScoreUsesHoldout() {
        let summary = makeSummary(outcome: .accepted)
        #expect(summary.finalTildeScore == 17)
        #expect(summary.holdoutCandidate?.hardGatesPassed == true)
    }

    @Test("Rejected cycles retain the baseline score")
    func rejectedScoreUsesBaseline() {
        let summary = makeSummary(outcome: .rejectedOnValidation)
        #expect(summary.finalTildeScore == 13)
    }

    @Test("Aggregate-only summaries persist with owner-only storage")
    func persistence() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-learning-cycle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LabLearningCycleStore(directory: root)
        let summary = makeSummary(outcome: .accepted)
        try await store.save(summary)
        let loaded = await store.loadAll()
        #expect(loaded == [summary])
        let attributes = try FileManager.default.attributesOfItem(
            atPath: root.appendingPathComponent("\(summary.id.uuidString).json").path
        )
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(await store.hasConsumedHoldout(forSuiteDigest: "suite-test"))
        #expect(!(await store.hasConsumedHoldout(forSuiteDigest: "different-suite")))
    }

    private func makeSummary(outcome: LabLearningCycleOutcome) -> LabLearningCycleSummary {
        let baseline = snapshot(partition: .validation, score: 13)
        let candidate = snapshot(partition: .validation, score: 15)
        return LabLearningCycleSummary(
            campaignID: UUID(),
            suiteDigestSHA256: "suite-test",
            outcome: outcome,
            acceptedArm: outcome == .accepted ? LabArmConfiguration(id: "accepted") : nil,
            developmentCandidate: snapshot(partition: .development, score: 16),
            validationBaseline: baseline,
            validationCandidate: candidate,
            holdoutBaseline: snapshot(partition: .holdout, score: 14),
            holdoutCandidate: snapshot(partition: .holdout, score: 17),
            startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 2)
        )
    }

    private func snapshot(partition: LabScenarioPartition, score: Int) -> LabLearningScoreSnapshot {
        LabLearningScoreSnapshot(
            partition: partition,
            tildeScore: score,
            usefulnessRate: 0.2,
            ordinaryRestraintRate: 0.3,
            sensitiveRestraintRate: 1,
            counterfactualPairPassRate: 0.25,
            p95LatencyMilliseconds: 700
        )
    }
}
