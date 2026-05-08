import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suppressed suggestion store")
struct SuppressedSuggestionStoreTests {
    private let secret = Data("unit-test-secret".utf8)

    @Test("Exact suppression is normalized and scoped by app and mode")
    func exactSuppressionIsNormalizedAndScoped() {
        var store = SuppressedSuggestionStore()

        store.suppressExact(
            "Follow up tomorrow.",
            mode: .phraseContinuation,
            scope: "com.apple.TextEdit",
            secret: secret,
            createdAt: "2026-05-08T12:00:00Z"
        )

        #expect(store.shouldSuppress(
            "follow up tomorrow",
            mode: .phraseContinuation,
            scope: "COM.APPLE.TEXTEDIT",
            secret: secret
        ))
        #expect(!store.shouldSuppress(
            "follow up tomorrow",
            mode: .phraseContinuation,
            scope: "com.apple.Notes",
            secret: secret
        ))
        #expect(!store.shouldSuppress(
            "follow up tomorrow",
            mode: .wordCompletion,
            scope: "com.apple.TextEdit",
            secret: secret
        ))
    }

    @Test("Persisted entries round trip without raw suggestion text")
    func persistedEntriesRoundTripWithoutRawText() throws {
        var store = SuppressedSuggestionStore()

        let maybeEntry = store.suppressExact(
            "Never store this raw phrase",
            mode: .sentenceContinuation,
            scope: "com.example.writer",
            secret: secret,
            source: "menu",
            createdAt: "2026-05-08T12:00:00Z"
        )
        let entry = try #require(maybeEntry)

        let encoded = try JSONEncoder().encode(store.entries)
        let json = String(decoding: encoded, as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("Never store"))
        #expect(!json.localizedCaseInsensitiveContains("raw phrase"))
        #expect(json.contains(entry.hmacToken))

        let decodedEntries = try JSONDecoder().decode([SuppressedSuggestionEntry].self, from: encoded)
        let decodedStore = SuppressedSuggestionStore(entries: decodedEntries)

        #expect(decodedStore.shouldSuppress(
            "never store this raw phrase",
            mode: .sentenceContinuation,
            scope: "com.example.writer",
            secret: secret
        ))
    }

    @Test("Trace metadata is safe and contains only fingerprints and shape")
    func traceMetadataIsSafe() throws {
        var store = SuppressedSuggestionStore()

        let maybeEntry = store.suppressExact(
            "Private sentence should not leak",
            mode: .phraseContinuation,
            scope: "com.example.writer",
            secret: secret,
            source: "menu",
            createdAt: "2026-05-08T12:00:00Z"
        )
        let entry = try #require(maybeEntry)
        let metadata = entry.traceMetadata

        #expect(metadata["blockedFingerprintVersion"] == TracePrivacyFingerprint.version)
        #expect(metadata["blockedTokenCount"] == "5")
        #expect(metadata["blockedTextChars"] == "32")
        #expect(metadata["blockedRequestMode"] == CompletionRequestMode.phraseContinuation.rawValue)
        #expect(metadata["blockedScope"] == "com.example.writer")
        #expect(metadata["blockedSource"] == "menu")

        let json = String(decoding: try JSONEncoder().encode(metadata), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("Private sentence"))
        #expect(!json.localizedCaseInsensitiveContains("leak"))
    }

    @Test("Empty and punctuation only suggestions are ignored")
    func emptySuggestionsAreIgnored() {
        var store = SuppressedSuggestionStore()

        let empty = store.suppressExact(
            "   ... ",
            mode: .phraseContinuation,
            scope: "com.example.writer",
            secret: secret
        )

        #expect(empty == nil)
        #expect(store.isEmpty)
    }

    @Test("Acceptance does not clear explicit durable suppression")
    func durableSuppressionDoesNotDecayThroughAcceptance() {
        var repetitionSuppressor = SuggestionRepetitionSuppressor(missThreshold: 1)
        var durableStore = SuppressedSuggestionStore()

        repetitionSuppressor.recordMiss(
            "not this",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        )
        durableStore.suppressExact(
            "not this",
            mode: .phraseContinuation,
            scope: "com.example.writer",
            secret: secret
        )

        repetitionSuppressor.recordAcceptance(
            "not this",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        )

        #expect(!repetitionSuppressor.shouldSuppress(
            "not this",
            mode: .phraseContinuation,
            scope: "com.example.writer"
        ))
        #expect(durableStore.shouldSuppress(
            "not this",
            mode: .phraseContinuation,
            scope: "com.example.writer",
            secret: secret
        ))
    }
}
