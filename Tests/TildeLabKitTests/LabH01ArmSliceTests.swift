import Foundation
import Testing
@testable import TildeCore
@testable import TildeLabKit

/// Lab must be able to tell H01's two arms apart from ingested counts alone.
/// The harness is disabled, so these are schema and ingest checks, not
/// evidence: no live comparison exists and H01 has not started.
@Suite("H01 arm slicing in the instrument report")
struct LabH01ArmSliceTests {
    @Test("Champion-only batches keep the shadow instrument plan")
    func championOnlyStaysShadow() throws {
        let plan = try LabInstrumentCampaign.makePlan(
            covering: [Date(timeIntervalSince1970: 1_500)],
            includesChallenger: false
        )
        #expect(plan.phase == .shadow)
        #expect(plan.challengerAllocation == 0)
    }

    @Test("An arm-tagged batch gets a dogfood plan that may display a challenger")
    func challengerBatchArmsTheDogfoodPlan() throws {
        let plan = try LabInstrumentCampaign.makePlan(
            covering: [Date(timeIntervalSince1970: 1_500)],
            includesChallenger: true
        )
        #expect(plan.phase == .dogfood)
        #expect(plan.challengerAllocation == 0.5)
        #expect(plan.safetyEvidenceDigestSHA256
            == LabInstrumentCampaign.armedSafetyEvidenceDigestSHA256)
    }

    @Test("Ingest accepts both arms, and the report slices by arm")
    func ingestAndSliceByArm() async throws {
        let armA = try makeEvent(arm: .a, accepted: "alpha beta", window: "alpha beta")
        let armB = try makeEvent(arm: .b, accepted: "alpha beta", window: "rewritten now")
        let decoded = try [armA, armB].map(decode)
        #expect(LabInstrumentCampaign.includesChallenger(decoded))
        #expect(decoded[0].variant == .champion)
        #expect(decoded[1].variant == .challenger)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-h01-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try LabResearchDatabase(
            fileURL: root.appendingPathComponent("research.sqlite3")
        )
        let plan = try await LabInstrumentCampaign.ensureReady(
            database: database,
            covering: decoded.map(\.occurredAt),
            includesChallenger: LabInstrumentCampaign.includesChallenger(decoded)
        )
        #expect(plan.phase == .dogfood)
        for event in decoded {
            try await database.recordOnlineEvent(event, plan: plan)
        }

        let stored = try await database.onlineEvents(campaignID: LabInstrumentCampaign.id)
        let comparison = try LabOnlineExperimentAnalyzer.analyzeByArm(stored)
        #expect(comparison.arms.map(\.variant) == [.champion, .challenger])
        let champion = try #require(comparison.arms.first { $0.variant == .champion }).report
        let challenger = try #require(comparison.arms.first { $0.variant == .challenger }).report
        #expect(champion.events == 1)
        #expect(challenger.events == 1)
        #expect(champion.retentionAt5Seconds.netRetainedCharacters == 10)
        #expect(challenger.retentionAt5Seconds.netRetainedCharacters == 0)
        // The pooled report is unchanged; the slices sum to it.
        let pooled = try LabOnlineExperimentAnalyzer.analyze(stored)
        #expect(pooled.events == champion.events + challenger.events)
    }

    @Test("A shadow instrument campaign upgrades in place when arms first appear")
    func shadowUpgradesToDogfoodWithoutLosingEvents() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-h01-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try LabResearchDatabase(
            fileURL: root.appendingPathComponent("research.sqlite3")
        )
        let champion = try decode(makeEvent(arm: .a, accepted: "alpha beta", window: "alpha beta"))
        let shadow = try await LabInstrumentCampaign.ensureReady(
            database: database,
            covering: [champion.occurredAt]
        )
        #expect(shadow.phase == .shadow)
        try await database.recordOnlineEvent(champion, plan: shadow)

        let challenger = try decode(
            makeEvent(arm: .b, accepted: "alpha beta", window: "alpha beta")
        )
        let armed = try await LabInstrumentCampaign.ensureReady(
            database: database,
            covering: [challenger.occurredAt],
            includesChallenger: true
        )
        #expect(armed.phase == .dogfood)
        try await database.recordOnlineEvent(challenger, plan: armed)
        let stored = try await database.onlineEvents(campaignID: LabInstrumentCampaign.id)
        #expect(stored.count == 2)
    }

    private func decode(_ event: TextFreeOnlineEvent) throws -> LabOnlineExperimentEvent {
        let line = try TextFreeOnlineEvent.encodeJSONL(event)
        try LabOnlineEventPrivacy.validateJSON(line.dropLast())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LabOnlineExperimentEvent.self, from: line)
    }

    private func makeEvent(
        arm: H01Arm,
        accepted: String,
        window: String
    ) throws -> TextFreeOnlineEvent {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "h01"),
            variant: arm.eventVariant,
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: accepted.count,
            candidateWordCount: accepted.split(whereSeparator: \Character.isWhitespace).count,
            opportunityCharacters: 20
        )
        opportunity.noteAccepted(accepted, kind: .all, at: shownAt.addingTimeInterval(0.4))
        var watch = PendingRetainedWatch(opportunity: opportunity)
        try watch.observeFiveSeconds(window: window)
        try watch.observeThirtySeconds(window: window)
        try watch.closeSegment(window: window)
        return try watch.finishedEvent()
    }
}
