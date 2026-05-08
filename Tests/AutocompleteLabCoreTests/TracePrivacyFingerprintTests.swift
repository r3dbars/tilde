import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Trace privacy fingerprints")
struct TracePrivacyFingerprintTests {
    @Test("Builds stable HMAC token and n-gram fingerprints without raw text")
    func buildsStableFingerprints() throws {
        let secret = Data("unit-test-secret".utf8)
        let metadata = TracePrivacyFingerprint.metadata(
            for: "Make this tiny suggestion useful",
            secret: secret
        )
        let same = TracePrivacyFingerprint.metadata(
            for: "make this tiny suggestion useful",
            secret: secret
        )
        let differentSecret = TracePrivacyFingerprint.metadata(
            for: "Make this tiny suggestion useful",
            secret: Data("different-secret".utf8)
        )

        #expect(metadata["acceptedTextFingerprintVersion"] == TracePrivacyFingerprint.version)
        #expect(metadata["acceptedTokenCount"] == "5")
        #expect(metadata["acceptedText3GramCount"] == "3")
        #expect(metadata["acceptedTextHMACToken"] == same["acceptedTextHMACToken"])
        #expect(metadata["acceptedTextHMACToken"] != differentSecret["acceptedTextHMACToken"])
        let json = String(decoding: try JSONEncoder().encode(metadata), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("suggestion"))
        #expect(!json.localizedCaseInsensitiveContains("useful"))
    }

    @Test("Builds keyed prefix family fingerprints without raw tokens")
    func buildsPrefixFamilyFingerprints() throws {
        let secret = Data("unit-test-secret".utf8)
        let metadata = TracePrivacyFingerprint.prefixFamilyMetadata(
            for: ["secret", "customer", "name"],
            secret: secret
        )
        let same = TracePrivacyFingerprint.prefixFamilyMetadata(
            for: ["secret", "customer", "name"],
            secret: secret
        )
        let differentSecret = TracePrivacyFingerprint.prefixFamilyMetadata(
            for: ["secret", "customer", "name"],
            secret: Data("different-secret".utf8)
        )

        #expect(metadata["prefixFamilyFingerprintVersion"] == TracePrivacyFingerprint.prefixFamilyVersion)
        #expect(metadata["prefixFamilyHMACToken"] == same["prefixFamilyHMACToken"])
        #expect(metadata["prefixFamilyHMACToken"] != differentSecret["prefixFamilyHMACToken"])
        #expect(metadata["prefixFamilyHMACToken"]?.count == 24)
        let json = String(decoding: try JSONEncoder().encode(metadata), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("secret"))
        #expect(!json.localizedCaseInsensitiveContains("customer"))
    }

    @Test("Rotates default trace session ids once per UTC day")
    func rotatesSessionIDsDaily() throws {
        let firstDay = try #require(ISO8601DateFormatter().date(from: "2026-05-07T12:00:00Z"))
        let nextDay = try #require(ISO8601DateFormatter().date(from: "2026-05-08T00:00:01Z"))
        let first = TraceSessionRotator.session(
            existingID: nil,
            existingDay: nil,
            now: firstDay,
            generateID: { "session-one" }
        )
        let sameDay = TraceSessionRotator.session(
            existingID: first.sessionID,
            existingDay: first.day,
            now: firstDay,
            generateID: { "session-two" }
        )
        let rotated = TraceSessionRotator.session(
            existingID: first.sessionID,
            existingDay: first.day,
            now: nextDay,
            generateID: { "session-two" }
        )

        #expect(first.sessionID == "session-one")
        #expect(first.rotated)
        #expect(sameDay.sessionID == "session-one")
        #expect(!sameDay.rotated)
        #expect(rotated.sessionID == "session-two")
        #expect(rotated.rotated)
    }
}
