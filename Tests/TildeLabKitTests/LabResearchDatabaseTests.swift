import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab durable research database")
struct LabResearchDatabaseTests {
    @Test("WAL work survives restart and completed observations are never rerun")
    func durableResume() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let item = fixture.workItem(repetition: 0)
        try await fixture.beginSession(
            owner: "first",
            now: Date(timeIntervalSince1970: 1)
        )

        try await fixture.database.enqueue([item])
        #expect(try await fixture.database.claim(
            workItemID: item.id,
            owner: "first",
            now: Date(timeIntervalSince1970: 10)
        ))
        try await fixture.database.complete(
            workItemID: item.id,
            owner: "first",
            result: fixture.result(repetition: 0)
        )
        #expect(try await fixture.database.journalMode().lowercased() == "wal")

        let reopened = try LabResearchDatabase(fileURL: fixture.url)
        let restored = try await reopened.completedResults(
            campaignID: fixture.campaign.id,
            trialID: fixture.trialID
        )
        #expect(restored[item.id] == fixture.result(repetition: 0))
        #expect(!(try await reopened.claim(workItemID: item.id, owner: "second")))
        #expect(try await reopened.summary(campaignID: fixture.campaign.id).completed == 1)
    }

    @Test("Expired leases return to pending and cooperative cancellation releases immediately")
    func leaseRecovery() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let expired = fixture.workItem(repetition: 0)
        let released = fixture.workItem(repetition: 1)
        let owner = "lease-test"
        try await fixture.beginSession(
            owner: owner,
            now: Date(timeIntervalSince1970: 1)
        )
        try await fixture.database.enqueue([expired, released])

        #expect(try await fixture.database.claim(
            workItemID: expired.id,
            owner: owner,
            leaseDuration: 5,
            now: Date(timeIntervalSince1970: 10)
        ))
        #expect(try await fixture.database.recoverExpiredLeases(
            now: Date(timeIntervalSince1970: 16)
        ) == 1)
        #expect(try await fixture.database.claim(
            workItemID: expired.id,
            owner: owner,
            now: Date(timeIntervalSince1970: 16)
        ))

        #expect(try await fixture.database.claim(
            workItemID: released.id,
            owner: owner,
            now: Date(timeIntervalSince1970: 20)
        ))
        try await fixture.database.release(workItemID: released.id, owner: owner)
        #expect(try await fixture.database.claim(
            workItemID: released.id,
            owner: owner,
            now: Date(timeIntervalSince1970: 21)
        ))
    }

    @Test("Duplicate result delivery is idempotent but conflicting delivery is rejected")
    func idempotentCompletion() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let item = fixture.workItem(repetition: 0)
        let result = fixture.result(repetition: 0)
        try await fixture.beginSession(owner: "worker")
        try await fixture.database.enqueue([item])
        #expect(try await fixture.database.claim(workItemID: item.id, owner: "worker"))
        try await fixture.database.complete(workItemID: item.id, owner: "worker", result: result)
        try await fixture.database.complete(workItemID: item.id, owner: "worker", result: result)

        await #expect(throws: LabResearchDatabaseError.leaseConflict) {
            try await fixture.database.complete(
                workItemID: item.id,
                owner: "worker",
                result: fixture.result(repetition: 99)
            )
        }
        #expect(try await fixture.database.summary(campaignID: fixture.campaign.id).completed == 1)
    }

    @Test("A protected suite digest can consume holdout exactly once")
    func holdoutReceipt() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        try await fixture.database.consumeHoldout(
            suiteDigestSHA256: fixture.campaign.suiteDigestSHA256,
            baselineArmDigestSHA256: String(repeating: "1", count: 64),
            candidateArmDigestSHA256: String(repeating: "2", count: 64),
            campaignID: fixture.campaign.id
        )
        try await fixture.database.consumeHoldout(
            suiteDigestSHA256: fixture.campaign.suiteDigestSHA256,
            baselineArmDigestSHA256: String(repeating: "1", count: 64),
            candidateArmDigestSHA256: String(repeating: "2", count: 64),
            campaignID: fixture.campaign.id,
            allowResume: true
        )
        await #expect(throws: LabResearchDatabaseError.holdoutAlreadyConsumed) {
            try await fixture.database.consumeHoldout(
                suiteDigestSHA256: fixture.campaign.suiteDigestSHA256,
                baselineArmDigestSHA256: String(repeating: "1", count: 64),
                candidateArmDigestSHA256: String(repeating: "3", count: 64),
                campaignID: fixture.campaign.id,
                allowResume: true
            )
        }
    }

    @Test("Active budget and block environment provenance survive restart")
    func budgetAndEnvironment() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        try await fixture.database.recordActiveDuration(
            campaignID: fixture.campaign.id, seconds: 12.5
        )
        try await fixture.database.recordActiveDuration(
            campaignID: fixture.campaign.id, seconds: 7.5
        )
        let environment = LabResearchBlockEnvironment(
            blockIndex: 3,
            armRunOrder: ["candidate", "baseline"],
            workerCount: 2,
            configuredSlotsPerWorker: 4,
            candidateCacheEnabled: true,
            machine: LabResearchMachineState(
                powerSourceKnown: true,
                isOnACPower: true,
                lowPowerModeEnabled: false,
                thermalLevel: .fair,
                checkedAt: Date(timeIntervalSince1970: 123)
            )
        )
        try await fixture.database.recordBlockEnvironment(
            campaignID: fixture.campaign.id,
            environment: environment
        )

        let reopened = try LabResearchDatabase(fileURL: fixture.url)
        #expect(try await reopened.activeDurationSeconds(campaignID: fixture.campaign.id) == 20)
        #expect(try await reopened.blockEnvironments(campaignID: fixture.campaign.id) == [environment])
    }

    @Test("The execution engine resumes from observations without calling the model twice")
    func engineResumeSkipsModel() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let client = CountingCompletionClient()
        let context = LabDurableExecutionContext(
            database: fixture.database,
            campaignID: fixture.campaign.id,
            trialID: fixture.trialID,
            blockIndex: 0,
            leaseOwner: "engine-test"
        )
        try await fixture.beginSession(owner: context.leaseOwner)
        let suite = LabScenarioSuite(name: "durable-engine", scenarios: [fixture.scenario])
        let arm = LabArmConfiguration(id: fixture.trialID)

        let first = try await LabExperimentEngine.execute(
            suite: suite,
            arm: arm,
            repetitions: 1,
            timeoutSeconds: 2,
            seed: 7,
            generationSeeds: [17, 41, 73],
            clients: [client],
            durableContext: context
        )
        let second = try await LabExperimentEngine.execute(
            suite: suite,
            arm: arm,
            repetitions: 1,
            timeoutSeconds: 2,
            seed: 7,
            generationSeeds: [17, 41, 73],
            clients: [client],
            durableContext: context
        )

        #expect(first.results == second.results)
        #expect(Set(first.results.map(\.generationSeed)) == [17, 41, 73])
        #expect(await client.requestCount == 3)
    }
}

private actor CountingCompletionClient: LabCompletionClient {
    nonisolated let workerIndex = 0
    private(set) var requestCount = 0

    func complete(_ request: LabModelRequest) async throws -> LabModelResponse {
        requestCount += 1
        return LabModelResponse(content: "world", latencyMilliseconds: 10)
    }
}

private final class Fixture: @unchecked Sendable {
    let root: URL
    let url: URL
    let database: LabResearchDatabase
    let campaign: LabResearchCampaignRecord
    let trialID = "candidate"
    let scenario = LabScenario(
        id: "durable.case",
        category: "reply.test",
        typedContext: "Hello ",
        expectation: LabExpectation(shouldSuggest: true, goldenContinuation: "world")
    )

    init() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-lab-db-\(UUID().uuidString)", isDirectory: true)
        url = root.appendingPathComponent("research.sqlite3")
        database = try LabResearchDatabase(fileURL: url)
        campaign = LabResearchCampaignRecord(
            id: UUID(),
            name: "durability-test",
            manifestDigestSHA256: String(repeating: "a", count: 64),
            suiteDigestSHA256: String(repeating: "b", count: 64),
            modelSHA256: String(repeating: "c", count: 64),
            helperSHA256: String(repeating: "d", count: 64),
            gitCommit: "test",
            protocolDefinition: LabResearchProtocol(
                baselineArmID: "candidate",
                fixedGenerationSeeds: [0]
            )
        )
        try await database.registerCampaign(campaign)
        try await database.registerTrial(
            campaignID: campaign.id,
            trialID: trialID,
            armID: trialID,
            armHash: String(repeating: "e", count: 64),
            stage: "screen",
            rootBudget: 1
        )
    }

    func workItem(repetition: Int) -> LabDurableWorkItem {
        LabDurableWorkItem(
            campaignID: campaign.id,
            trialID: trialID,
            armHash: String(repeating: "e", count: 64),
            scenario: scenario,
            generationSeed: 0,
            repetition: repetition,
            blockIndex: 0
        )
    }

    func beginSession(
        owner: String,
        now: Date = Date()
    ) async throws {
        try await database.beginRunSession(
            campaignID: campaign.id,
            owner: owner,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            resume: false,
            staleAfter: 3_600,
            now: now,
            isProcessAlive: { _ in true }
        )
    }

    func result(repetition: Int) -> LabCaseResult {
        LabCaseResult(
            scenarioID: scenario.id,
            category: scenario.category,
            repetition: repetition,
            outcome: .useful,
            expectedSuggestion: true,
            hasGoldenContinuation: true,
            offered: true,
            keystrokesSaved: 5
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
