import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab campaign reconciliation")
struct LabCampaignReconciliationTests {
    @Test("Canonical digests ignore Set insertion order but preserve ordered arrays")
    func canonicalSetDigest() throws {
        var firstArm = LabArmConfiguration(id: "baseline")
        firstArm.scenarios.intents = [.accept, .decline]
        firstArm.scenarios.tones = [.friendly, .formal]
        firstArm.interaction.hosts = [.sceneHost, .textEdit, .chromium]
        var secondArm = firstArm
        secondArm.scenarios.intents = Set([
            LabScenarioIntent.decline,
            .accept,
        ])
        secondArm.scenarios.tones = Set([
            LabScenarioTone.formal,
            .friendly,
        ])
        secondArm.interaction.hosts = Set([
            LabInteractionHost.chromium,
            .textEdit,
            .sceneHost,
        ])

        let first = LabExperimentManifest(
            enabledBenches: [.reply, .sceneMemory, .interaction],
            arms: [firstArm]
        )
        let second = LabExperimentManifest(
            enabledBenches: Set([
                LabBenchKind.interaction,
                .sceneMemory,
                .reply,
            ]),
            arms: [secondArm]
        )
        #expect(first == second)
        #expect(try first.digestSHA256() == second.digestSHA256())

        var reordered = second
        reordered.arms = [secondArm, firstArm]
        #expect(try first.digestSHA256() != reordered.digestSHA256())
    }

    @Test("A clean session advances ready, running, and completed truthfully")
    func completedLifecycle() async throws {
        let fixture = try await ReconciliationFixture()
        defer { fixture.remove() }
        let ready = try await fixture.database.reconciledSnapshot(
            campaignID: fixture.campaign.id,
            isProcessAlive: { _ in false }
        )
        #expect(ready.state == .ready)
        #expect(ready.activeSessions == 0)

        try await fixture.database.beginRunSession(
            campaignID: fixture.campaign.id,
            owner: "tilde-lab-111-first",
            processIdentifier: 111,
            resume: false,
            staleAfter: 120,
            now: fixture.start,
            isProcessAlive: { _ in true }
        )
        let item = fixture.workItem(repetition: 0)
        try await fixture.database.enqueue([item])
        #expect(try await fixture.database.claim(
            workItemID: item.id,
            owner: "tilde-lab-111-first",
            now: fixture.start
        ))
        try await fixture.database.complete(
            workItemID: item.id,
            owner: "tilde-lab-111-first",
            result: fixture.result(repetition: 0),
            completedAt: fixture.start.addingTimeInterval(1)
        )
        try await fixture.database.completeCampaign(
            campaignID: fixture.campaign.id,
            owner: "tilde-lab-111-first",
            completedAt: fixture.start.addingTimeInterval(2)
        )

        let completed = try await fixture.database.reconciledSnapshot(
            campaignID: fixture.campaign.id,
            now: fixture.start.addingTimeInterval(3),
            isProcessAlive: { _ in false }
        )
        #expect(completed.state == .completed)
        #expect(completed.activeSessions == 0)
        #expect(completed.work.completed == 1)
        #expect(completed.terminalFailure == nil)
    }

    @Test("A dead runner aborts, preserves completed work, and requires explicit resume")
    func deadRunnerResume() async throws {
        let fixture = try await ReconciliationFixture()
        defer { fixture.remove() }
        let firstOwner = "tilde-lab-111-first"
        try await fixture.database.beginRunSession(
            campaignID: fixture.campaign.id,
            owner: firstOwner,
            processIdentifier: 111,
            resume: false,
            staleAfter: 120,
            now: fixture.start,
            isProcessAlive: { _ in true }
        )
        let completedItem = fixture.workItem(repetition: 0)
        let interruptedItem = fixture.workItem(repetition: 1)
        try await fixture.database.enqueue([completedItem, interruptedItem])
        #expect(try await fixture.database.claim(
            workItemID: completedItem.id,
            owner: firstOwner,
            now: fixture.start
        ))
        try await fixture.database.complete(
            workItemID: completedItem.id,
            owner: firstOwner,
            result: fixture.result(repetition: 0),
            completedAt: fixture.start.addingTimeInterval(1)
        )
        #expect(try await fixture.database.claim(
            workItemID: interruptedItem.id,
            owner: firstOwner,
            now: fixture.start.addingTimeInterval(1)
        ))

        #expect(try await fixture.database.reconcileCampaign(
            campaignID: fixture.campaign.id,
            now: fixture.start.addingTimeInterval(2),
            isProcessAlive: { _ in false }
        ) == 1)
        let aborted = try await fixture.database.reconciledSnapshot(
            campaignID: fixture.campaign.id,
            now: fixture.start.addingTimeInterval(3),
            isProcessAlive: { _ in false }
        )
        #expect(aborted.state == .aborted)
        #expect(aborted.work.completed == 1)
        #expect(aborted.work.pending == 1)
        #expect(aborted.work.running == 0)
        #expect(aborted.terminalFailure?.category == .runnerTerminated)
        #expect(aborted.terminalFailure?.reasons == [.processNotAlive])

        let reopened = try LabResearchDatabase(fileURL: fixture.url)
        await #expect(throws: LabResearchDatabaseError.campaignResumeRequired) {
            try await reopened.beginRunSession(
                campaignID: fixture.campaign.id,
                owner: "tilde-lab-222-second",
                processIdentifier: 222,
                resume: false,
                now: fixture.start.addingTimeInterval(4),
                isProcessAlive: { _ in true }
            )
        }
        try await reopened.beginRunSession(
            campaignID: fixture.campaign.id,
            owner: "tilde-lab-222-second",
            processIdentifier: 222,
            resume: true,
            now: fixture.start.addingTimeInterval(4),
            isProcessAlive: { _ in true }
        )
        #expect(!(try await reopened.claim(
            workItemID: completedItem.id,
            owner: "tilde-lab-222-second",
            now: fixture.start.addingTimeInterval(5)
        )))
        #expect(try await reopened.claim(
            workItemID: interruptedItem.id,
            owner: "tilde-lab-222-second",
            now: fixture.start.addingTimeInterval(5)
        ))
        await #expect(throws: LabResearchDatabaseError.campaignAlreadyActive) {
            try await reopened.beginRunSession(
                campaignID: fixture.campaign.id,
                owner: "tilde-lab-333-collision",
                processIdentifier: 333,
                resume: true,
                now: fixture.start.addingTimeInterval(6),
                isProcessAlive: { _ in true }
            )
        }
    }

    @Test("A stale heartbeat is an aborted session, not live progress")
    func staleHeartbeat() async throws {
        let fixture = try await ReconciliationFixture()
        defer { fixture.remove() }
        try await fixture.database.beginRunSession(
            campaignID: fixture.campaign.id,
            owner: "tilde-lab-111-stale",
            processIdentifier: 111,
            resume: false,
            staleAfter: 60,
            now: fixture.start,
            isProcessAlive: { _ in true }
        )
        try await fixture.database.enqueue([fixture.workItem(repetition: 0)])
        let snapshot = try await fixture.database.reconciledSnapshot(
            campaignID: fixture.campaign.id,
            now: fixture.start.addingTimeInterval(61),
            isProcessAlive: { _ in true }
        )
        #expect(snapshot.state == .aborted)
        #expect(snapshot.activeSessions == 0)
        #expect(snapshot.terminalFailure?.category == .stalledSession)
        #expect(snapshot.terminalFailure?.reasons == [.heartbeatExpired])
    }

    @Test("A reportless invariant failure persists and accepts accountable review")
    func terminalFailureReview() async throws {
        let fixture = try await ReconciliationFixture()
        defer { fixture.remove() }
        let owner = "tilde-lab-111-failure"
        try await fixture.database.beginRunSession(
            campaignID: fixture.campaign.id,
            owner: owner,
            processIdentifier: 111,
            resume: false,
            now: fixture.start,
            isProcessAlive: { _ in true }
        )
        try await fixture.database.finishCampaign(
            campaignID: fixture.campaign.id,
            owner: owner,
            classification: LabResearchFailureClassification(
                state: .failed,
                category: .invariantSmoke,
                reasons: [.unsafeSentinelOutput]
            ),
            occurredAt: fixture.start.addingTimeInterval(1)
        )
        let reviewed = try await fixture.database.reviewTerminalFailure(
            campaignID: fixture.campaign.id,
            status: .inconclusive,
            conclusion: "The invariant gate stopped the registered run before comparison.",
            reviewedAt: fixture.start.addingTimeInterval(2)
        )
        #expect(reviewed.review.status == .inconclusive)
        #expect(reviewed.category == .invariantSmoke)

        let reopened = try LabResearchDatabase(fileURL: fixture.url)
        let persisted = try await reopened.terminalFailure(campaignID: fixture.campaign.id)
        #expect(persisted == reviewed)
        await #expect(throws: LabResearchDatabaseError.campaignTerminal(.failed)) {
            try await reopened.beginRunSession(
                campaignID: fixture.campaign.id,
                owner: "tilde-lab-222-retry",
                processIdentifier: 222,
                resume: true,
                now: fixture.start.addingTimeInterval(3),
                isProcessAlive: { _ in true }
            )
        }

        let encoded = try JSONEncoder().encode(reviewed)
        let keys = Set((try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )).keys)
        #expect(keys.isDisjoint(with: [
            "text", "prompt", "candidate", "modelOutput", "screenText",
            "filePath", "path", "username", "processOwner",
        ]))
    }

    @Test("Known infrastructure errors map to fixed aggregate reason codes")
    func fixedFailureClassification() {
        #expect(
            LabResearchFailureClassifier.classify(
                LabInvariantSmokeError.failed(
                    armID: "baseline",
                    reasons: ["unsafe-sentinel-output"]
                )
            ) == LabResearchFailureClassification(
                state: .failed,
                category: .invariantSmoke,
                reasons: [.unsafeSentinelOutput]
            )
        )
        #expect(
            LabResearchFailureClassifier.classify(LabAssetError.unreadableServer)
                == LabResearchFailureClassification(
                    state: .failed,
                    category: .helperUnavailable,
                    reasons: [.unreadableHelper]
                )
        )
    }
}

private final class ReconciliationFixture: @unchecked Sendable {
    let root: URL
    let url: URL
    let database: LabResearchDatabase
    let campaign: LabResearchCampaignRecord
    let trialID = "baseline"
    let start = Date(timeIntervalSince1970: 1_000)
    let scenario = LabScenario(
        id: "campaign-state.case",
        category: "reply.test",
        typedContext: "Synthetic prefix ",
        expectation: LabExpectation(
            shouldSuggest: true,
            goldenContinuation: "synthetic continuation"
        )
    )

    init() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-campaign-state-\(UUID().uuidString)", isDirectory: true)
        url = root.appendingPathComponent("research.sqlite3")
        database = try LabResearchDatabase(fileURL: url)
        let protocolDefinition = LabResearchProtocol(
            baselineArmID: trialID,
            fixedGenerationSeeds: [17]
        )
        let manifest = LabExperimentManifest(
            name: "campaign-state-fixture",
            enabledBenches: [.reply, .sceneMemory],
            arms: [LabArmConfiguration(id: trialID)],
            research: protocolDefinition
        )
        campaign = LabResearchCampaignRecord(
            id: UUID(),
            name: "campaign-state-fixture",
            manifestDigestSHA256: try manifest.digestSHA256(),
            suiteDigestSHA256: String(repeating: "b", count: 64),
            modelSHA256: String(repeating: "c", count: 64),
            helperSHA256: String(repeating: "d", count: 64),
            gitCommit: String(repeating: "e", count: 40),
            protocolDefinition: protocolDefinition
        )
        try await database.registerCampaign(campaign)
        try await database.registerTrial(
            campaignID: campaign.id,
            trialID: trialID,
            armID: trialID,
            armHash: String(repeating: "f", count: 64),
            stage: "block-0",
            rootBudget: 1
        )
    }

    func workItem(repetition: Int) -> LabDurableWorkItem {
        LabDurableWorkItem(
            campaignID: campaign.id,
            trialID: trialID,
            armHash: String(repeating: "f", count: 64),
            scenario: scenario,
            generationSeed: 17,
            repetition: repetition,
            blockIndex: 0
        )
    }

    func result(repetition: Int) -> LabCaseResult {
        LabCaseResult(
            scenarioID: scenario.id,
            category: scenario.category,
            repetition: repetition,
            generationSeed: 17,
            outcome: .useful,
            expectedSuggestion: true,
            hasGoldenContinuation: true,
            offered: true,
            keystrokesSaved: 8
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
