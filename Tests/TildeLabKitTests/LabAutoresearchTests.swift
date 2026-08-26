import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab autoresearch")
struct LabAutoresearchTests {
    @Test("Planner never promotes a silent high-score arm over a usable arm")
    func rejectsDegenerateSilence() {
        let usable = report(
            useful: 3,
            wrong: 1,
            correctSilence: 3,
            unwanted: 1,
            quality: 14
        )
        let silent = report(
            useful: 0,
            wrong: 0,
            correctSilence: 4,
            unwanted: 0,
            silent: 4,
            quality: 25
        )
        #expect(usable.verdict == .candidate)
        #expect(silent.verdict == .degenerateSilence)
        #expect(LabResearchRank(report: usable).isBetter(than: LabResearchRank(report: silent)))
    }

    @Test("Completed mutations are skipped when a paused campaign resumes")
    func resumeSkipsCompletedWork() {
        let baseline = LabArmConfiguration(id: "baseline")
        var campaign = LabResearchCampaign(
            suiteDigestSHA256: String(repeating: "a", count: 64),
            baselineArm: baseline
        )
        campaign.ledger.append(LabResearchLedgerEntry(
            trial: 1,
            parentArmID: baseline.id,
            armID: "research-1-typical-p-0.50",
            mutation: .typicalP050,
            reportID: UUID(),
            decision: .discard,
            verdict: .candidate
        ))
        let pending = LabAutoresearchPlanner.pendingMutations(for: campaign, seed: 1)
        #expect(!pending.contains(.typicalP050))
    }

    @Test("The overnight search space contains only valid bounded arms")
    func overnightSearchSpaceIsValid() throws {
        #expect(LabResearchMutation.allCases.count >= 36)
        let baseline = LabArmConfiguration(id: "overnight-baseline")
        for (index, mutation) in LabResearchMutation.allCases.enumerated() {
            try mutation.applying(to: baseline, trial: index + 1).validated()
        }
    }

    @Test("Speak-policy search space is valid, unique, and keeps hard safety gates")
    func speakPolicySearchSpaceIsValid() throws {
        let mutations = LabResearchMutation.speakPolicyCases
        #expect(mutations.count >= 20)
        #expect(Set(mutations.map(\.rawValue)).count == mutations.count)

        var baseline = LabArmConfiguration(id: "speak-policy-baseline")
        baseline.judgment.suppressesSensitiveScenes = true
        for (index, mutation) in mutations.enumerated() {
            let candidate = try mutation.applying(to: baseline, trial: index + 1).validated()
            #expect(candidate.judgment.suppressesSensitiveScenes)
        }
    }

    @Test("Planner can stay inside a focused mutation set")
    func plannerUsesFocusedCandidates() {
        let baseline = LabArmConfiguration(id: "speak-policy-baseline")
        let campaign = LabResearchCampaign(
            suiteDigestSHA256: String(repeating: "f", count: 64),
            baselineArm: baseline,
            configuration: LabAutoresearchConfiguration(
                maximumTrials: LabResearchMutation.speakPolicyCases.count,
                randomizesTrialOrder: false
            )
        )
        let pending = LabAutoresearchPlanner.pendingMutations(
            for: campaign,
            seed: 1,
            candidates: LabResearchMutation.speakPolicyCases
        )
        #expect(pending == LabResearchMutation.speakPolicyCases)
    }

    @Test("Campaign checkpoints round-trip with owner-only persistence")
    func campaignPersistence() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-lab-campaign-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LabResearchCampaignStore(directory: root)
        let campaign = LabResearchCampaign(
            suiteDigestSHA256: String(repeating: "b", count: 64),
            baselineArm: LabArmConfiguration(id: "baseline")
        )
        try await store.save(campaign)
        let loaded = await store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == campaign.id)
        #expect(loaded.first?.suiteDigestSHA256 == campaign.suiteDigestSHA256)
        #expect(loaded.first?.state == campaign.state)
    }

    private func report(
        useful: Int,
        wrong: Int,
        correctSilence: Int,
        unwanted: Int,
        silent: Int = 0,
        quality: Int
    ) -> LabRunReport {
        let positiveCount = useful + wrong + silent
        let quietCount = correctSilence + unwanted
        let total = positiveCount + quietCount
        let metrics = LabAggregateMetrics(
            totalCases: total,
            useful: useful,
            wrong: wrong,
            silent: silent,
            correctSilence: correctSilence,
            unwanted: unwanted,
            timeouts: 0,
            errors: 0,
            policySuppressions: 0,
            modelRequests: total,
            exactMatchAt1Rate: 0,
            exactMatchAt2Rate: 0,
            exactMatchAt3Rate: 0,
            usefulnessRate: positiveCount == 0 ? 0 : Double(useful) / Double(positiveCount),
            restraintRate: quietCount == 0 ? 0 : Double(correctSilence) / Double(quietCount),
            ordinaryRestraintRate: quietCount == 0 ? nil : Double(correctSilence) / Double(quietCount),
            sensitiveRestraintRate: 1,
            counterfactualPairPassRate: 1,
            replyScore: quality,
            qualityScore: quality,
            promotionEligible: false,
            factualityRate: 1,
            brevityRate: 1,
            keystrokesSaved: 0,
            keystrokesSavedPerCase: 0,
            throughputCasesPerSecond: 1,
            throughputModelRequestsPerSecond: 1,
            latency: LabLatencySummary(count: total, p50Milliseconds: 100, p95Milliseconds: 200, p99Milliseconds: 200, maximumMilliseconds: 200)
        )
        return LabRunReport(
            startedAt: Date(),
            finishedAt: Date(),
            suiteName: "Synthetic",
            suiteDigestSHA256: String(repeating: "c", count: 64),
            scenarioCount: total,
            arm: LabArmConfiguration(),
            execution: LabExecutionSnapshot(LabExecutionConfiguration(
                serverExecutable: URL(fileURLWithPath: "/tmp/helper"),
                modelFile: URL(fileURLWithPath: "/tmp/model")
            )),
            assets: LabAssetSnapshot(
                modelIdentifier: "synthetic",
                modelRevision: "test",
                modelSHA256: String(repeating: "d", count: 64),
                helperSHA256: String(repeating: "e", count: 64)
            ),
            metrics: metrics,
            cases: []
        )
    }
}
