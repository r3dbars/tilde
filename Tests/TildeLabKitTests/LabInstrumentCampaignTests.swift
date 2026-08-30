import Foundation
import Testing
@testable import TildeCore
@testable import TildeLabKit

@Suite("F03 live producer ingest")
struct LabInstrumentCampaignTests {
    @Test("Keep and rewrite events decode as v3 and look different in the report")
    func keepAndRewriteDifferAfterIngest() async throws {
        let keep = try makeEvent(accepted: "alpha beta", window: "alpha beta")
        let rewrite = try makeEvent(accepted: "alpha beta", window: "rewritten now")
        let keepLine = try TextFreeOnlineEvent.encodeJSONL(keep)
        let rewriteLine = try TextFreeOnlineEvent.encodeJSONL(rewrite)
        try LabOnlineEventPrivacy.validateJSON(keepLine.dropLast())
        try LabOnlineEventPrivacy.validateJSON(rewriteLine.dropLast())

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let keepEvent = try decoder.decode(LabOnlineExperimentEvent.self, from: keepLine)
        let rewriteEvent = try decoder.decode(LabOnlineExperimentEvent.self, from: rewriteLine)
        #expect(keepEvent.schema == LabOnlineExperimentEvent.currentSchema)
        #expect(keepEvent.retentionAt5Seconds.retainedCharacters == 10)
        #expect(rewriteEvent.retentionAt5Seconds.retainedCharacters == 0)
        #expect(rewriteEvent.replacedCharactersWithin5Seconds == 10)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-instrument-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try LabResearchDatabase(fileURL: root.appendingPathComponent("research.sqlite3"))
        let plan = try await LabInstrumentCampaign.ensureReady(
            database: database,
            covering: [keepEvent.occurredAt, rewriteEvent.occurredAt]
        )
        try await database.recordOnlineEvent(keepEvent, plan: plan)
        try await database.recordOnlineEvent(rewriteEvent, plan: plan)
        let report = try LabOnlineExperimentAnalyzer.analyze(
            try await database.onlineEvents(campaignID: LabInstrumentCampaign.id)
        )
        #expect(report.retentionAt5Seconds.observedEvents == 2)
        #expect(report.retentionAt5Seconds.missingEvents == 0)
        #expect(report.retentionAt5Seconds.netRetainedCharacters == 10)
        #expect(report.retentionAt30Seconds.netRetainedCharacters == 10)
        #expect(report.retentionAtSegmentClose.netRetainedCharacters == 10)
        try await database.deleteOnlineEvents(campaignID: LabInstrumentCampaign.id)
        #expect(try await database.onlineEvents(campaignID: LabInstrumentCampaign.id).isEmpty)
    }

    @Test("A privacy-excluded accept still decodes as an accept, not a zero keep")
    func privacyExcludedAcceptValidates() throws {
        var opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "instrument"),
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: 10,
            candidateWordCount: 2,
            opportunityCharacters: 20
        )
        opportunity.noteAccepted(
            "alpha beta", kind: .all, insertionLocationUTF16: 0,
            at: Date(timeIntervalSince1970: 1_501)
        )
        var watch = PendingRetainedWatch(opportunity: opportunity)
        watch.markPrivacyExcluded()
        let line = try TextFreeOnlineEvent.encodeJSONL(try watch.finishedEvent())
        try LabOnlineEventPrivacy.validateJSON(line.dropLast())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LabOnlineExperimentEvent.self, from: line)
        #expect(event.outcome == .acceptedAll)
        #expect(event.acceptedCharacters == 10)
        #expect(event.retentionAt5Seconds.missingness == .privacyExcluded)
        #expect(event.retentionAt5Seconds.retainedCharacters == nil)
    }

    @Test("A diary line with accepted text is rejected before ingest")
    func diaryLineIsForbiddenInLab() throws {
        let diary = LocalOutcomeDiaryEntry(
            id: UUID(),
            outcome: "accepted-all",
            acceptedText: "alpha beta",
            five: try RetainedCharacterObservation(retainedCharacters: 10),
            thirty: try RetainedCharacterObservation(retainedCharacters: 10),
            segment: try RetainedCharacterObservation(retainedCharacters: 10)
        )
        let line = try LocalOutcomeDiaryEntry.encodeJSONL(diary)
        #expect(throws: LabOnlineExperimentError.forbiddenKey("acceptedText")) {
            try LabOnlineEventPrivacy.validateJSON(line.dropLast())
        }
    }

    private func makeEvent(accepted: String, window: String) throws -> TextFreeOnlineEvent {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "instrument"),
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: accepted.count,
            candidateWordCount: accepted.split(whereSeparator: \Character.isWhitespace).count,
            opportunityCharacters: 20
        )
        opportunity.noteAccepted(
            accepted, kind: .all, insertionLocationUTF16: 0,
            at: shownAt.addingTimeInterval(0.4)
        )
        var watch = PendingRetainedWatch(opportunity: opportunity)
        let snapshot = RetainedContextSnapshot(
            text: window,
            utf16StartLocation: 0,
            caretLocation: window.utf16.count,
            sourceDigestSHA256: TextFreeOnlineEvent.sessionDigest(
                sessionIdentifier: "instrument"
            )
        )
        try watch.observeFiveSeconds(snapshot: snapshot)
        try watch.observeThirtySeconds(snapshot: snapshot)
        try watch.closeSegment(snapshot: snapshot)
        return try watch.finishedEvent()
    }
}
