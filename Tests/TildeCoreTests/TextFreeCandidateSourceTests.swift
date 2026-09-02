import Foundation
import Testing
@testable import TildeCore

@Suite("Candidate source and the production event contract")
struct TextFreeCandidateSourceTests {
    @Test("The app's arbitration outcome maps onto the fixed source vocabulary")
    func personalArbitrationMapsToSource() {
        #expect(TextFreeCandidateSource(personal: nil) == .baseModel)
        #expect(TextFreeCandidateSource(personal: .base) == .baseModel)
        #expect(TextFreeCandidateSource(personal: .personal) == .personal)
        #expect(TextFreeCandidateSource(personal: .agreed) == .basePersonalAgreement)
    }

    @Test("A shown ghost's event names its source and never the legacy bucket")
    func opportunityEventCarriesSource() throws {
        for source in TextFreeCandidateSource.allCases where source != .unknownLegacy {
            let opportunity = LiveOnlineOpportunity(
                shownAt: Date(timeIntervalSince1970: 1_000),
                sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "s"),
                appCategory: "chat",
                register: "chat",
                boundary: "word-boundary",
                safeOpportunity: true,
                candidateCharacters: 4,
                candidateWordCount: 1,
                candidateSource: source,
                opportunityCharacters: 12
            )
            let event = try opportunity.eventWithoutAcceptedSpan()
            #expect(event.candidateSourceBucket == source.rawValue)
            #expect(event.opportunityCharacters == 12)
        }
    }

    @Test("The production event writes exactly its declared keys")
    func encodedKeysMatchAllowedKeys() throws {
        let event = try sampleEvent()
        let line = try TextFreeOnlineEvent.encodeJSONL(event)
        let object = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        #expect(Set(object.keys) == TextFreeOnlineEvent.allowedKeys)
        let decoded = try TextFreeOnlineEvent.decodeProductionLine(line.dropLast())
        #expect(decoded == event)
    }

    @Test("A live line carrying a Lab-only field is refused by name")
    func labOnlyKeyIsRefused() throws {
        let line = try TextFreeOnlineEvent.encodeJSONL(try sampleEvent())
        var object = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        object["generatorMilliseconds"] = 42
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: TextFreeOnlineEventError.unexpectedKey("generatorMilliseconds")) {
            try TextFreeOnlineEvent.decodeProductionLine(data)
        }
    }

    /// Every field set, including the optional timings, so the encoded key
    /// set is the full contract rather than a subset of it.
    private func sampleEvent() throws -> TextFreeOnlineEvent {
        var opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_000),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "s"),
            appCategory: "prose",
            register: "prose",
            boundary: "mid-word",
            safeOpportunity: true,
            candidateCharacters: 3,
            candidateWordCount: 1,
            candidateSource: .dictionary,
            opportunityCharacters: 8
        )
        opportunity.noteTyped(at: Date(timeIntervalSince1970: 1_000.5))
        return try opportunity.eventWithoutAcceptedSpan()
    }
}
