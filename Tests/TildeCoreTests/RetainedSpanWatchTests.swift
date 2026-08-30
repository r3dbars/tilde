import Foundation
import Testing
@testable import TildeCore

@Suite("Retained span watch and local diary")
struct RetainedSpanWatchTests {
    @Test("Retention is measured at the accepted insertion range, not a duplicate elsewhere")
    func exactInsertionRangeIgnoresDuplicateText() throws {
        let accepted = "the"
        let kept = RetainedSpanWatch.retainedCharacters(
            accepted: accepted,
            insertionLocationUTF16: 6,
            snapshot: snapshot("the x the")
        )
        let deletedAtAnchor = RetainedSpanWatch.retainedCharacters(
            accepted: accepted,
            insertionLocationUTF16: 6,
            snapshot: snapshot("the x Z")
        )
        #expect(kept == accepted.count)
        #expect(deletedAtAnchor == 0)

        let missing = try RetainedSpanWatch.observation(
            accepted: accepted,
            insertionLocationUTF16: 6,
            snapshot: nil
        )
        #expect(missing.missingness == .observerStopped)
        #expect(missing.retainedCharacters == nil)
    }

    @Test("Appended text is harmless and an internal edit keeps only the exact prefix")
    func appendedAndInternallyEditedText() {
        #expect(RetainedSpanWatch.retainedCharacters(
            accepted: "alpha beta",
            insertionLocationUTF16: 6,
            snapshot: snapshot("hello alpha beta and more")
        ) == 10)
        #expect(RetainedSpanWatch.retainedCharacters(
            accepted: "alpha beta",
            insertionLocationUTF16: 6,
            snapshot: snapshot("hello alpha X and more")
        ) == 6)
    }

    @Test("A rolled-out insertion range is missing and a preceding edit is conservative")
    func rolledOutAndShiftedRanges() throws {
        let rolledOut = try RetainedSpanWatch.observation(
            accepted: "word",
            insertionLocationUTF16: 50,
            snapshot: snapshot("new bounded window", start: 100)
        )
        #expect(rolledOut.missingness == .observerStopped)
        #expect(RetainedSpanWatch.retainedCharacters(
            accepted: "word",
            insertionLocationUTF16: 6,
            snapshot: snapshot("hello Xword")
        ) == 0)
    }

    @Test("UTF-16 offsets still report retained grapheme counts")
    func utf16OffsetCountsGraphemes() {
        #expect(RetainedSpanWatch.retainedCharacters(
            accepted: "🫶🏽a",
            insertionLocationUTF16: 2,
            snapshot: snapshot("😀🫶🏽a later")
        ) == 2)
    }

    @Test("Deleted-then-retyped text cannot resurrect at a later horizon")
    func retentionStaysMonotoneAcrossHorizons() throws {
        var watch = PendingRetainedWatch(
            opportunity: acceptedOpportunity("word", shownAt: Date(timeIntervalSince1970: 1_500))
        )
        // Gone at 5s: the writer deleted the accepted span.
        try watch.observeFiveSeconds(snapshot: snapshot("something else"))
        #expect(watch.retentionAt5Seconds.retainedCharacters == 0)
        // Retyped by 30s and still present at segment close: authored, not retained.
        try watch.observeThirtySeconds(snapshot: snapshot("something else word"))
        #expect(watch.retentionAt30Seconds.retainedCharacters == 0)
        try watch.observeSegment(snapshot: snapshot("something else word"))
        #expect(watch.retentionAtSegmentClose.retainedCharacters == 0)
    }

    @Test("Retention horizons start when the accepted watch starts, not when the ghost appeared")
    func horizonClockStartsAtAcceptanceClose() {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        let startedAt = shownAt.addingTimeInterval(40)
        let watch = PendingRetainedWatch(
            opportunity: acceptedOpportunity("word", shownAt: shownAt),
            startedAt: startedAt
        )
        #expect(!watch.isFiveSecondDue(at: startedAt.addingTimeInterval(1)))
        #expect(watch.isFiveSecondDue(at: startedAt.addingTimeInterval(5)))
        #expect(!watch.isThirtySecondDue(at: startedAt.addingTimeInterval(5)))
        #expect(watch.isThirtySecondDue(at: startedAt.addingTimeInterval(30)))
    }

    @Test("Retyped text after a missing 5s observation clamps to the 30s count")
    func segmentClampsToThirtySecondsWhenFiveIsMissing() throws {
        var watch = PendingRetainedWatch(
            opportunity: acceptedOpportunity("word", shownAt: Date(timeIntervalSince1970: 1_500))
        )
        try watch.observeFiveSeconds(snapshot: nil)
        #expect(watch.retentionAt5Seconds.missingness == .observerStopped)
        try watch.observeThirtySeconds(snapshot: snapshot("woX"))
        #expect(watch.retentionAt30Seconds.retainedCharacters == 2)
        try watch.observeSegment(snapshot: snapshot("word"))
        #expect(watch.retentionAtSegmentClose.retainedCharacters == 2)
    }

    private func acceptedOpportunity(
        _ text: String,
        shownAt: Date
    ) -> LiveOnlineOpportunity {
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: text.count,
            candidateWordCount: 1,
            opportunityCharacters: 10
        )
        opportunity.noteAccepted(
            text,
            kind: .all,
            insertionLocationUTF16: 0,
            at: shownAt.addingTimeInterval(1)
        )
        return opportunity
    }

    private func snapshot(_ text: String, start: Int = 0) -> RetainedContextSnapshot {
        RetainedContextSnapshot(
            text: text,
            utf16StartLocation: start,
            caretLocation: start + text.utf16.count,
            sourceDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session")
        )
    }

    @Test("A caret inside or immediately before the span is missing, not a rewrite")
    func truncatedBeforeCaretIsMissing() throws {
        let atAnchor = try RetainedSpanWatch.observation(
            accepted: "word",
            insertionLocationUTF16: 6,
            snapshot: snapshot("hello ")
        )
        let inside = try RetainedSpanWatch.observation(
            accepted: "word",
            insertionLocationUTF16: 6,
            snapshot: snapshot("hello wo")
        )
        #expect(atAnchor.missingness == .observerStopped)
        #expect(inside.missingness == .observerStopped)
    }

    @Test("A snapshot from another field cannot receive retention credit")
    func sourceIdentityMustMatch() throws {
        var watch = PendingRetainedWatch(
            opportunity: acceptedOpportunity("word", shownAt: Date(timeIntervalSince1970: 1_500))
        )
        let otherField = RetainedContextSnapshot(
            text: "word",
            utf16StartLocation: 0,
            caretLocation: 4,
            sourceDigestSHA256: String(repeating: "b", count: 64)
        )
        try watch.observeFiveSeconds(snapshot: otherField)
        #expect(watch.retentionAt5Seconds.missingness == .observerStopped)
    }

    @Test("Contiguous Tab chunks share an anchor; a discontinuous chunk becomes missing")
    func multiChunkAnchorContinuity() throws {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        var contiguous = acceptedOpportunity("alpha ", shownAt: shownAt)
        contiguous.noteAccepted(
            "beta",
            kind: .word,
            insertionLocationUTF16: 6,
            at: shownAt.addingTimeInterval(2)
        )
        var kept = PendingRetainedWatch(opportunity: contiguous)
        try kept.observeFiveSeconds(snapshot: snapshot("alpha beta"))
        #expect(kept.retentionAt5Seconds.retainedCharacters == 10)

        var discontinuous = acceptedOpportunity("alpha ", shownAt: shownAt)
        discontinuous.noteAccepted(
            "beta",
            kind: .word,
            insertionLocationUTF16: 9,
            at: shownAt.addingTimeInterval(2)
        )
        var missing = PendingRetainedWatch(opportunity: discontinuous)
        try missing.observeFiveSeconds(snapshot: snapshot("alpha beta"))
        #expect(missing.retentionAt5Seconds.missingness == .observerStopped)
    }

    @Test("Typed-through requires a settled show and typing, and loses to Tab")
    func typedThroughCloseRule() {
        #expect(
            TypedThroughRule.isTypedThrough(
                displayed: true,
                settledVisibleMilliseconds: 250,
                typedAfterShow: true,
                accepted: false,
                dismissed: false
            )
        )
        #expect(
            !TypedThroughRule.isTypedThrough(
                displayed: true,
                settledVisibleMilliseconds: 80,
                typedAfterShow: true,
                accepted: false,
                dismissed: false
            )
        )
        #expect(
            !TypedThroughRule.isTypedThrough(
                displayed: true,
                settledVisibleMilliseconds: 250,
                typedAfterShow: true,
                accepted: true,
                dismissed: false
            )
        )
    }

    @Test("A finished keep event has no text keys and a diary row does")
    func eventStaysTextFreeWhileDiaryHoldsWords() throws {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
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
            at: shownAt.addingTimeInterval(0.4)
        )
        opportunity.settleVisible(at: shownAt.addingTimeInterval(0.4))

        var watch = PendingRetainedWatch(opportunity: opportunity)
        try watch.observeFiveSeconds(snapshot: snapshot("alpha beta"))
        try watch.observeThirtySeconds(snapshot: snapshot("alpha beta"))
        try watch.closeSegment(snapshot: snapshot("alpha beta"))
        let acceptedText = watch.accepted
        let event = try watch.finishedEvent()
        let eventLine = try TextFreeOnlineEvent.encodeJSONL(event)
        let eventObject = try #require(
            JSONSerialization.jsonObject(with: eventLine) as? [String: Any]
        )
        #expect(event.outcome == "accepted-all")
        #expect(event.retentionAt5Seconds.retainedCharacters == 10)
        #expect(Set(eventObject.keys).isDisjoint(with: [
            "text", "prompt", "candidate", "acceptedText", "screenText",
        ]))

        let diary = LocalOutcomeDiaryEntry(
            id: event.id,
            recordedAt: shownAt,
            outcome: event.outcome,
            acceptedText: acceptedText,
            five: event.retentionAt5Seconds,
            thirty: event.retentionAt30Seconds,
            segment: event.retentionAtSegmentClose
        )
        #expect(diary.acceptedText == "alpha beta")
        #expect(diary.fate == .kept)
        #expect(diary.schema == LocalOutcomeDiaryEntry.schema)
        #expect(event.schema == TextFreeOnlineEvent.schema)
    }

    @Test("Rewrite before five seconds is edited, not a missing zero")
    func rewriteIsEdited() throws {
        let shownAt = Date(timeIntervalSince1970: 1_500)
        var opportunity = LiveOnlineOpportunity(
            shownAt: shownAt,
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
            appCategory: "chat",
            register: "chat",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: 10,
            candidateWordCount: 2,
            opportunityCharacters: 20
        )
        opportunity.noteAccepted(
            "alpha beta", kind: .all, insertionLocationUTF16: 0,
            at: shownAt.addingTimeInterval(0.5)
        )
        var watch = PendingRetainedWatch(opportunity: opportunity)
        try watch.observeFiveSeconds(snapshot: snapshot("rewritten"))
        try watch.observeThirtySeconds(snapshot: snapshot("rewritten"))
        try watch.closeSegment(snapshot: snapshot("rewritten"))
        let event = try watch.finishedEvent()
        #expect(event.retentionAt5Seconds.retainedCharacters == 0)
        #expect(event.replacedCharactersWithin5Seconds == 10)
        #expect(event.retentionAt5Seconds.missingness == nil)

        let diary = LocalOutcomeDiaryEntry(
            id: event.id,
            outcome: event.outcome,
            acceptedText: "alpha beta",
            five: event.retentionAt5Seconds,
            thirty: event.retentionAt30Seconds,
            segment: event.retentionAtSegmentClose
        )
        #expect(diary.fate == .edited)
    }

    @Test("An unwitnessed horizon stays missing, not zero")
    func missingHorizonIsNotZero() throws {
        var opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
            appCategory: "email",
            register: "email",
            boundary: "sentence-boundary",
            safeOpportunity: true,
            candidateCharacters: 10,
            candidateWordCount: 2,
            opportunityCharacters: 20
        )
        opportunity.noteAccepted(
            "alpha beta", kind: .word, insertionLocationUTF16: 0,
            at: Date(timeIntervalSince1970: 1_501)
        )
        var watch = PendingRetainedWatch(opportunity: opportunity)
        try watch.closeSegment(snapshot: snapshot("alpha beta"))
        #expect(watch.retentionAt5Seconds.missingness == .segmentClosedEarly)
        #expect(watch.retentionAt30Seconds.missingness == .segmentClosedEarly)
        #expect(watch.retentionAtSegmentClose.retainedCharacters == 10)
        let event = try watch.finishedEvent()
        #expect(event.retentionAt5Seconds.retainedCharacters == nil)
    }

    @Test("Privacy wipe drops the span and keeps the accept count")
    func privacyWipeKeepsCounts() throws {
        var opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
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
        #expect(watch.accepted.isEmpty)
        let event = try watch.finishedEvent()
        #expect(event.outcome == "accepted-all")
        #expect(event.acceptedCharacters == 10)
        #expect(event.safeOpportunity)
        #expect(event.retentionAt5Seconds.missingness == .privacyExcluded)
        #expect(event.retentionAt5Seconds.retainedCharacters == nil)
        #expect(event.replacedCharactersWithin5Seconds == 0)
    }

    @Test("A close without Tab is not stored as zero kept accepts")
    func dismissDoesNotClaimAnAccept() throws {
        var opportunity = LiveOnlineOpportunity(
            shownAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: TextFreeOnlineEvent.sessionDigest(sessionIdentifier: "session"),
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: 10,
            candidateWordCount: 2,
            opportunityCharacters: 20
        )
        opportunity.settleVisible(at: Date(timeIntervalSince1970: 1_501))
        let event = try opportunity.eventWithoutAcceptedSpan()
        #expect(event.outcome == "ignored")
        #expect(event.acceptedCharacters == 0)
        #expect(event.retentionAt5Seconds.retainedCharacters == 0)
        #expect(event.retentionAt30Seconds.missingness == .notYetObserved)
    }
}
