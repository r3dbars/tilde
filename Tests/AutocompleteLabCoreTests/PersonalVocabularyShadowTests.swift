import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Personal vocabulary shadow")
struct PersonalVocabularyShadowTests {
    @Test("Replay predicts before learning the completed word")
    func onlineMetricsHaveNoLookahead() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([event(id: "one", text: " Transcripted Transcripted Transcripted Traction ")])

        let result = shadow.snapshot
        #expect(result.opportunities == 4)
        #expect(result.predictions == 2)
        #expect(result.exactHits == 1)
        #expect(result.coverage == 0.5)
        #expect(result.precision == 0.5)
    }

    @Test("Arbitrary event chunking does not change the result")
    func chunkingDoesNotChangeOutcome() {
        var whole = PersonalVocabularyShadow()
        whole.consume([event(id: "whole", text: " Transcripted Transcripted Transcripted Traction ")])

        var split = PersonalVocabularyShadow()
        split.consume([
            event(id: "a", text: " Tran"),
            event(id: "b", text: "scripted Trans"),
            event(id: "c", text: "cripted Transcripted Tra"),
            event(id: "d", text: "ction "),
        ])

        #expect(split.snapshot == whole.snapshot)
    }

    @Test("Streams share learned words without splicing partial text")
    func streamsStayIndependent() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([
            event(id: "train", text: " Transcripted Transcripted ", session: "a"),
            event(id: "partial-a", text: "Tra", session: "a"),
            event(id: "complete-b", text: " Transcripted ", session: "b"),
            event(id: "finish-a", text: "nscripted ", session: "a"),
        ])

        #expect(shadow.snapshot.opportunities == 4)
        #expect(shadow.snapshot.predictions == 2)
        #expect(shadow.snapshot.exactHits == 2)
    }

    @Test("Accepted suggestions never train or score personal vocabulary")
    func acceptedSuggestionsAreCensored() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([
            event(id: "typed-prefix", text: "Tra"),
            event(id: "accepted", text: "nscripted ", source: .acceptedSuggestion),
            event(id: "manual", text: "Transcripted "),
        ])

        #expect(shadow.snapshot.opportunities == 1)
        #expect(shadow.snapshot.predictions == 0)
        #expect(shadow.snapshot.learnedWords == 1)
    }

    @Test("At-least-once socket retries count once")
    func duplicateRetriesAreIdempotent() {
        let retry = event(id: "same", text: " Transcripted ")
        var shadow = PersonalVocabularyShadow()
        shadow.consume([retry, retry, retry])

        #expect(shadow.snapshot.opportunities == 1)
        #expect(shadow.snapshot.learnedWords == 1)
    }

    @Test("Ambiguous prefixes and malformed tokens stay silent")
    func conservativeEligibility() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([
            event(id: "training", text: " Transcripted Transcripted Transcend Transcend shouldn't abc123 "),
            event(id: "test", text: "Transcripted "),
        ])

        #expect(shadow.snapshot.opportunities == 7)
        #expect(shadow.snapshot.predictions == 2)
        #expect(shadow.snapshot.exactHits == 0)
        #expect(shadow.snapshot.learnedWords == 2)
    }

    @Test("Leading numbers cannot become a personal word")
    func leadingNumbersInvalidateWord() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([event(id: "number", text: "123Transcripted ")])

        #expect(shadow.snapshot.opportunities == 0)
        #expect(shadow.snapshot.learnedWords == 0)
    }

    @Test("A frozen challenge counts when the suffix becomes ineligible")
    func resolvedChallengesDoNotDisappear() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([event(id: "train", text: " Transcripted Transcripted ")])
        shadow.consume([event(id: "short", text: "trap ")])
        shadow.consume([event(id: "malformed", text: "tra1 ")])

        #expect(shadow.snapshot.opportunities == 4)
        #expect(shadow.snapshot.predictions == 2)
        #expect(shadow.snapshot.exactHits == 0)
        #expect(shadow.snapshot.exactHits <= shadow.snapshot.predictions)
        #expect(shadow.snapshot.predictions <= shadow.snapshot.opportunities)
        #expect((0...1).contains(shadow.snapshot.coverage))
        #expect((0...1).contains(shadow.snapshot.precision))
    }

    @Test("Unicode identity shares support but exact hits require the learned surface")
    func unicodeSurfaceAccuracy() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([event(id: "case", text: " STRASSE STRASSE straße STRASSE ")])

        #expect(shadow.snapshot.learnedWords == 1)
        #expect(shadow.snapshot.exactHits == 1)
    }

    @Test("Case folding that expands a prefix can still challenge at four letters")
    func expandingCaseFoldUsesSurfaceLength() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([event(
            id: "expanding-fold",
            text: " ßabcd ßabcd ßabxd ßabxd ßabcd "
        )])

        #expect(shadow.snapshot.predictions == 3)
        #expect(shadow.snapshot.exactHits == 1)
    }

    @Test("Accepted text taints the rest of its word")
    func acceptedMiddleNeverBecomesManualTraining() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([
            event(id: "typed", text: "pla"),
            event(id: "accepted", text: "y", source: .acceptedSuggestion),
            event(id: "continued", text: "ground "),
        ])

        #expect(shadow.snapshot.opportunities == 0)
        #expect(shadow.snapshot.learnedWords == 0)
    }

    @Test("State remains bounded and reset removes every derived aggregate")
    func boundedReset() {
        var shadow = PersonalVocabularyShadow()
        for index in 0..<(PersonalVocabularyShadow.maximumLearnedWords + 20) {
            shadow.consume([event(
                id: "word-\(index)",
                text: "word\(letters(index)) "
            )])
        }
        #expect(shadow.snapshot.learnedWords == PersonalVocabularyShadow.maximumLearnedWords)

        shadow.consume([
            event(id: "new-one", text: "newpersonalword "),
            event(id: "new-two", text: "newpersonalword "),
            event(id: "new-three", text: "newpersonalword "),
        ])
        #expect(shadow.snapshot.exactHits == 1)

        shadow.reset()
        #expect(shadow.snapshot == PersonalVocabularyShadow().snapshot)
    }

    @Test("Abandoned segments cannot permanently starve new writing")
    func activeStreamBoundAdmitsNewWriting() {
        var shadow = PersonalVocabularyShadow()
        for index in 0..<PersonalVocabularyShadow.maximumActiveStreams {
            shadow.consume([event(id: "partial-\(index)", text: "Tra", session: "s-\(index)")])
        }
        shadow.consume([event(id: "live", text: " Transcripted ", session: "fresh")])

        #expect(shadow.snapshot.opportunities == 1)
        #expect(shadow.snapshot.learnedWords == 1)
    }

    @Test("Recent retry IDs remain protected across the capacity boundary")
    func recentEventWindowEvictsOnlyTheOldest() {
        var shadow = PersonalVocabularyShadow()
        for index in 0...PersonalVocabularyShadow.maximumRecentEventIDs {
            shadow.consume([event(id: "id-\(index)", text: "Transcripted ")])
        }
        let beforeRetry = shadow.snapshot
        shadow.consume([event(id: "id-1", text: "Transcripted ")])

        #expect(shadow.snapshot == beforeRetry)
    }

    @Test("Tail replay drops a possibly truncated first token")
    func tailReplayDoesNotInventAWordSuffix() {
        var shadow = PersonalVocabularyShadow()
        shadow.consume([
            event(id: "tail-a", text: "scrip"),
            event(id: "tail-b", text: "ted Personalized "),
        ])

        #expect(shadow.snapshot.opportunities == 1)
        #expect(shadow.snapshot.learnedWords == 1)
    }

    private func letters(_ number: Int) -> String {
        var value = number
        var result = ""
        for _ in 0..<4 {
            result.append(Character(UnicodeScalar(97 + value % 26)!))
            value /= 26
        }
        return result
    }

    private func event(
        id: String,
        text: String,
        session: String = "session",
        source: PersonalHistoryEventSource = .typed
    ) -> PersonalHistoryEvent {
        PersonalHistoryEvent(
            id: id,
            timestampMilliseconds: 1_786_485_600_000,
            historyIdentifier: "history",
            sessionIdentifier: session,
            appBundleIdentifier: "com.example.Editor",
            source: source,
            text: text
        )!
    }
}
