import Foundation
import Testing
@testable import TildeCore

@Suite("Personal History replay evaluation")
struct ReplayEvalTests {
    @Test("A clean segment yields one boundary per word after the first")
    func basicSegmentBoundaries() {
        let events = [event(id: "1", text: "hello world foo ")]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.totalSegments == 1)
        #expect(extraction.totalEligibleBoundaries == 2)
        #expect(extraction.boundaries == [
            .init(context: "hello ", appBundleIdentifier: "com.example.Editor", golden: "world foo"),
            .init(context: "hello world ", appBundleIdentifier: "com.example.Editor", golden: "foo"),
        ])
    }

    @Test("A single word in a stream produces no boundary")
    func singleWordProducesNoBoundary() {
        let extraction = PersonalReplayEval.extract(from: [event(id: "1", text: "hello ")])

        #expect(extraction.totalSegments == 1)
        #expect(extraction.boundaries.isEmpty)
    }

    @Test("A word still being typed with no trailing separator is not counted")
    func inProgressWordIsNotACompletedTarget() {
        let extraction = PersonalReplayEval.extract(from: [event(id: "1", text: "hello world")])

        // "world" never saw a separator, so only "hello" completed — no boundary.
        #expect(extraction.boundaries.isEmpty)
    }

    @Test("Accepted-suggestion text never appears in golden truth, and resets eligibility")
    func acceptedSuggestionIsCensoredFromGolden() {
        let events = [
            event(id: "1", text: "I think "),
            event(id: "2", text: "we should ", source: .acceptedSuggestion),
            event(id: "3", text: "go now "),
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.totalSegments == 2)
        #expect(extraction.boundaries == [
            .init(context: "I ", appBundleIdentifier: "com.example.Editor", golden: "think"),
            .init(
                context: "I think we should go ",
                appBundleIdentifier: "com.example.Editor",
                golden: "now"
            ),
        ])
        for boundary in extraction.boundaries {
            #expect(!boundary.golden.contains("we"))
            #expect(!boundary.golden.contains("should"))
        }
    }

    @Test("A word merged with an accepted suggestion's dangling letters is discarded, not scored")
    func wordTouchingAcceptedTailIsDiscarded() {
        let events = [
            event(id: "1", text: "cat "),
            event(id: "2", text: "run", source: .acceptedSuggestion), // ends in a letter
            event(id: "3", text: "ning fast now "),
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        // "ning" (the corrupted merge of "run"+"ning") is discarded entirely,
        // and — like the live shadow's `hasOpportunity` — the word right after
        // it ("fast") starts the new segment and so is context-only too; only
        // "now" is a scored target, and "ning" never appears anywhere.
        #expect(extraction.boundaries == [
            .init(
                context: "cat running fast ",
                appBundleIdentifier: "com.example.Editor",
                golden: "now"
            ),
        ])
    }

    @Test("An accepted suggestion ending in whitespace does not poison the next word")
    func acceptedSuggestionEndingCleanlyDoesNotDiscard() {
        let events = [
            event(id: "1", text: "cat "),
            event(id: "2", text: "runs fast. ", source: .acceptedSuggestion),
            event(id: "3", text: "today now "),
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.boundaries == [
            .init(
                context: "cat runs fast. today ",
                appBundleIdentifier: "com.example.Editor",
                golden: "now"
            ),
        ])
    }

    @Test("A long gap resets the stream and does not leak golden across it")
    func gapResetsStream() {
        let events = [
            event(id: "1", text: "alpha beta ", time: 1),
            event(id: "2", text: "gamma delta ", time: 1 + 60 * 60 * 1_000), // 1 hour later
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.totalSegments == 2)
        #expect(extraction.boundaries == [
            .init(context: "alpha ", appBundleIdentifier: "com.example.Editor", golden: "beta"),
            .init(context: "gamma ", appBundleIdentifier: "com.example.Editor", golden: "delta"),
        ])
    }

    @Test("Out-of-order timestamps also reset the stream")
    func outOfOrderResetsStream() {
        let events = [
            event(id: "1", text: "alpha beta ", time: 100),
            event(id: "2", text: "gamma delta ", time: 50),
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.totalSegments == 2)
    }

    @Test("An over-length word is discarded but does not derail the rest of the segment")
    func overlongWordIsDiscarded() {
        let garbage = String(repeating: "x", count: 40)
        let events = [event(id: "1", text: "hi \(garbage) there ")]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.boundaries.count == 1)
        #expect(extraction.boundaries.first?.golden == "there")
        #expect(!(extraction.boundaries.first?.golden.contains(garbage) ?? true))
    }

    @Test("Streams are kept separate by session and app")
    func distinctStreamsDoNotMix() {
        let events = [
            event(id: "1", text: "alpha beta ", session: "s1", app: "com.a"),
            event(id: "2", text: "gamma delta ", session: "s2", app: "com.b"),
        ]
        let extraction = PersonalReplayEval.extract(from: events)

        #expect(extraction.totalSegments == 2)
        let apps = Set(extraction.boundaries.map(\.appBundleIdentifier))
        #expect(apps == ["com.a", "com.b"])
    }

    @Test("Limit keeps the most recent boundaries and stays deterministic")
    func limitIsDeterministicAndKeepsMostRecent() {
        let text = (1...6).map { "w\($0) " }.joined()
        let events = [event(id: "1", text: text)]

        let all = PersonalReplayEval.extract(from: events, limit: 100)
        #expect(all.totalEligibleBoundaries == 5)
        #expect(all.boundaries.count == 5)

        let limited = PersonalReplayEval.extract(from: events, limit: 2)
        #expect(limited.totalEligibleBoundaries == 5)
        #expect(limited.boundaries == Array(all.boundaries.suffix(2)))

        let again = PersonalReplayEval.extract(from: events, limit: 2)
        #expect(again == limited)
    }

    @Test("A non-positive limit yields nothing")
    func nonPositiveLimitYieldsNothing() {
        let extraction = PersonalReplayEval.extract(
            from: [event(id: "1", text: "hello world ")], limit: 0
        )
        #expect(extraction.boundaries.isEmpty)
        #expect(extraction.totalEligibleBoundaries == 0)
    }

    @Test("An extremely large limit does not overflow tail trimming")
    func extremelyLargeLimitDoesNotOverflow() {
        let extraction = PersonalReplayEval.extract(
            from: [event(id: "1", text: "hello world ")], limit: .max
        )

        #expect(extraction.boundaries.count == 1)
        #expect(extraction.totalEligibleBoundaries == 1)
    }

    // MARK: - Scoring parity with script/golden_eval.py

    @Test("Word normalization strips surrounding punctuation and lowercases")
    func normalizeWordMatchesGoldenEval() {
        #expect(PersonalReplayEval.normalizeWord("Thanks,") == "thanks")
        #expect(PersonalReplayEval.normalizeWord("\"hello\"") == "hello")
        #expect(PersonalReplayEval.normalizeWord("WORLD.") == "world")
    }

    @Test("Exact-match-at-one only compares the first word, normalized")
    func exactMatchAtOneMatchesGoldenEval() {
        #expect(PersonalReplayEval.exactMatchAtOne(suggestion: "Thanks, for today", golden: "thanks for today"))
        #expect(!PersonalReplayEval.exactMatchAtOne(suggestion: "nope", golden: "thanks"))
        #expect(!PersonalReplayEval.exactMatchAtOne(suggestion: "", golden: "thanks"))
        #expect(!PersonalReplayEval.exactMatchAtOne(suggestion: "thanks", golden: ""))
    }

    @Test("Keystrokes saved matches the known golden_eval.py vector")
    func keystrokesSavedMatchesGoldenEval() {
        #expect(
            PersonalReplayEval.keystrokesSaved(suggestion: "alpha beta extra", golden: "alpha beta gamma")
                == "alpha beta".count
        )
        #expect(PersonalReplayEval.keystrokesSaved(suggestion: "nope", golden: "alpha beta") == 0)
        #expect(PersonalReplayEval.keystrokesSaved(suggestion: "alpha", golden: "alpha") == 5)
        #expect(PersonalReplayEval.keystrokesSaved(suggestion: "", golden: "alpha") == 0)
    }

    private func event(
        id: String,
        text: String,
        time: Int64 = 1,
        history: String = "history",
        consent: String = "consent",
        session: String = "session",
        app: String = "com.example.Editor",
        source: PersonalHistoryEventSource = .typed
    ) -> PersonalHistoryEvent {
        PersonalHistoryEvent(
            id: id,
            timestampMilliseconds: time,
            historyIdentifier: history,
            consentIdentifier: consent,
            sessionIdentifier: session,
            appBundleIdentifier: app,
            source: source,
            text: text
        )!
    }
}
