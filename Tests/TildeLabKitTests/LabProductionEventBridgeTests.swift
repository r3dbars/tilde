import Foundation
import Testing
@testable import TildeCore
@testable import TildeLabKit

/// Production's `TextFreeOnlineEvent` is the one definition of a live event.
/// These fixtures pin the four measurement bugs fixed on 2026-09-02: a
/// browser reply recorded under the register the generator used, dictionary
/// and model ghosts kept apart, the authored-character denominator, and one
/// decode path for live lines.
@Suite("Production event bridge")
struct LabProductionEventBridgeTests {
    @Test("A Slack reply in Chrome is ingested as the chat register the app served, not the browser's prose")
    func browserChatKeepsServedRegister() throws {
        // The app's receipt said chat (Screen Memory saw a reply); the host
        // bundle alone would have said prose. The ledger writes the receipt.
        let event = try liveEvent(register: .chat, source: .baseModel, opportunityCharacters: 9)
        let bridged = try LabOnlineExperimentEvent(production: event)
        #expect(bridged.register == .chat)
        #expect(bridged.appCategory == .chat)
        #expect(bridged.candidateSourceBucket == .baseModel)
    }

    @Test("Dictionary and model ghosts stay separate buckets after ingest")
    func dictionaryAndModelStaySeparate() throws {
        let dictionary = try LabOnlineExperimentEvent(
            production: try liveEvent(register: .prose, source: .dictionary, opportunityCharacters: 3)
        )
        let model = try LabOnlineExperimentEvent(
            production: try liveEvent(register: .prose, source: .basePersonalAgreement, opportunityCharacters: 3)
        )
        #expect(dictionary.candidateSourceBucket == .dictionary)
        #expect(model.candidateSourceBucket == .basePersonalAgreement)
        #expect(dictionary.candidateSourceBucket != model.candidateSourceBucket)
    }

    @Test("The bridge and the Lab decoder agree on every production field of a live line")
    func bridgeMatchesLabDecoder() throws {
        let event = try liveEvent(register: .email, source: .personal, opportunityCharacters: 17)
        let line = try TextFreeOnlineEvent.encodeJSONL(event)
        let bridged = try LabOnlineExperimentEvent.decodeProductionLine(line.dropLast())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let direct = try decoder.decode(LabOnlineExperimentEvent.self, from: line)
        #expect(bridged == direct)
        #expect(bridged.opportunityCharacters == 17)
        #expect(bridged.generatorMilliseconds == nil)
        #expect(bridged.guardReason == nil)
        #expect(bridged.confidenceFeatures == nil)
        #expect(bridged.retentionAt5Seconds == event.retentionAt5Seconds)
        #expect(bridged.retentionAtSegmentClose == event.retentionAtSegmentClose)
    }

    @Test("A live line with a Lab-only key does not enter through the production path")
    func labOnlyKeyRefusedOnProductionPath() throws {
        let line = try TextFreeOnlineEvent.encodeJSONL(
            try liveEvent(register: .prose, source: .baseModel, opportunityCharacters: 1)
        )
        var object = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        object["cacheHit"] = true
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: TextFreeOnlineEventError.unexpectedKey("cacheHit")) {
            try LabOnlineExperimentEvent.decodeProductionLine(data)
        }
    }

    @Test("Ten ghosts in a long document divide by the writing that happened, not ten copies of the document")
    func longDocumentDenominator() throws {
        var meter = OpportunityCharacterMeter()
        var events: [LabOnlineExperimentEvent] = []
        for _ in 0..<10 {
            meter.noteTyped(characters: 5)
            events.append(try LabOnlineExperimentEvent(
                production: try liveEvent(
                    register: .prose,
                    source: .baseModel,
                    opportunityCharacters: meter.takeForOpportunity()
                )
            ))
        }
        let authored = events.reduce(0) { $0 + $1.opportunityCharacters }
        #expect(authored == 50)
    }

    private func liveEvent(
        register: ContinuationRegister,
        source: TextFreeCandidateSource,
        opportunityCharacters: Int
    ) throws -> TextFreeOnlineEvent {
        let opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_700_000_000),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "bridge"),
            appCategory: TextFreeAppCategory.from(register: register).rawValue,
            register: register.rawValue,
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: 6,
            candidateWordCount: 1,
            candidateSource: source,
            opportunityCharacters: opportunityCharacters
        )
        return try opportunity.eventWithoutAcceptedSpan()
    }
}
