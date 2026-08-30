import Foundation

/// One shown ghost, held only until the text-free event can be written.
///
/// Accept starts an in-memory span watch. The accepted string is dropped
/// when the last horizon is filled. The event never contains it.
public struct LiveOnlineOpportunity: Equatable, Sendable {
    public enum AcceptKind: String, Sendable {
        case word
        case all
    }

    public enum CloseReason: String, Sendable {
        case accepted
        case dismissed
        case typedThrough = "typed-through"
        case ignored
        case segment
        case privacyExcluded = "privacy-excluded"
        case observerStopped = "observer-stopped"
    }

    public let id: UUID
    public let shownAt: Date
    public let sessionDigestSHA256: String
    /// Text-free analysis tag. Product events are `champion`; Lab fixtures may
    /// construct challenger events without adding an experiment path to IMKit.
    public let variant: String
    public let appCategory: String
    public let register: String
    public let boundary: String
    public let safeOpportunity: Bool
    public var candidateCharacters: Int
    public var candidateWordCount: Int
    public let opportunityCharacters: Int
    public var typedAfterShow: Bool
    public var acceptedKind: AcceptKind?
    public var accepted: String
    public var acceptedCharacterCount: Int
    public var acceptedInsertionLocationUTF16: Int?
    public var dismissed: Bool
    public var nextActionMilliseconds: Int?
    public var settledVisibleMilliseconds: Int?

    public init(
        id: UUID = UUID(),
        shownAt: Date,
        sessionDigestSHA256: String,
        variant: String = "champion",
        appCategory: String,
        register: String,
        boundary: String,
        safeOpportunity: Bool,
        candidateCharacters: Int,
        candidateWordCount: Int,
        opportunityCharacters: Int
    ) {
        self.id = id
        self.shownAt = shownAt
        self.sessionDigestSHA256 = sessionDigestSHA256
        self.variant = variant
        self.appCategory = appCategory
        self.register = register
        self.boundary = boundary
        self.safeOpportunity = safeOpportunity
        self.candidateCharacters = max(0, candidateCharacters)
        self.candidateWordCount = max(0, candidateWordCount)
        self.opportunityCharacters = max(1, opportunityCharacters)
        typedAfterShow = false
        acceptedKind = nil
        accepted = ""
        acceptedCharacterCount = 0
        acceptedInsertionLocationUTF16 = nil
        dismissed = false
        nextActionMilliseconds = nil
        settledVisibleMilliseconds = nil
    }

    public var didAccept: Bool { acceptedKind != nil }

    public mutating func noteVisibleCandidate(characters: Int, wordCount: Int) {
        candidateCharacters = max(candidateCharacters, characters)
        candidateWordCount = max(candidateWordCount, wordCount)
    }

    public mutating func noteTyped(at time: Date) {
        recordNextAction(at: time)
        typedAfterShow = true
    }

    public mutating func noteAccepted(
        _ text: String,
        kind: AcceptKind,
        insertionLocationUTF16: Int? = nil,
        at time: Date
    ) {
        recordNextAction(at: time)
        if acceptedKind == nil {
            acceptedKind = kind
            acceptedInsertionLocationUTF16 = insertionLocationUTF16.flatMap { $0 >= 0 ? $0 : nil }
        } else if let start = acceptedInsertionLocationUTF16,
                  insertionLocationUTF16 != start + accepted.utf16.count {
            acceptedInsertionLocationUTF16 = nil
        }
        accepted += text
        acceptedCharacterCount += text.count
    }

    /// Drop the span so it cannot be written later. Counts stay.
    public mutating func wipeAcceptedText() {
        accepted = ""
    }

    public mutating func noteDismissed(at time: Date) {
        recordNextAction(at: time)
        dismissed = true
    }

    public mutating func settleVisible(at time: Date) {
        let milliseconds = milliseconds(from: shownAt, to: time)
        settledVisibleMilliseconds = max(settledVisibleMilliseconds ?? 0, milliseconds)
    }

    public func outcome() -> String {
        if didAccept {
            return acceptedKind == .all ? "accepted-all" : "accepted-word"
        }
        if dismissed { return "dismissed" }
        if TypedThroughRule.isTypedThrough(
            displayed: true,
            settledVisibleMilliseconds: settledVisibleMilliseconds,
            typedAfterShow: typedAfterShow,
            accepted: false,
            dismissed: false
        ) {
            return "typed-through"
        }
        return "ignored"
    }

    public func finishedEvent(
        retentionAt5Seconds: RetainedCharacterObservation,
        retentionAt30Seconds: RetainedCharacterObservation,
        retentionAtSegmentClose: RetainedCharacterObservation,
        replacedCharactersWithin5Seconds: Int = 0
    ) throws -> TextFreeOnlineEvent {
        let acceptedCount = acceptedCharacterCount
        let outcome = outcome()
        let isAccept = outcome == "accepted-all" || outcome == "accepted-word"
        return TextFreeOnlineEvent(
            id: id,
            occurredAt: shownAt,
            sessionDigestSHA256: sessionDigestSHA256,
            variant: variant,
            appCategory: appCategory,
            register: register,
            boundary: boundary,
            safeOpportunity: safeOpportunity,
            generated: true,
            displayed: true,
            outcome: outcome,
            acceptedCharacters: isAccept ? acceptedCount : 0,
            replacedCharactersWithin5Seconds: isAccept ? replacedCharactersWithin5Seconds : 0,
            nextActionMilliseconds: nextActionMilliseconds,
            settledVisibleMilliseconds: settledVisibleMilliseconds,
            candidateCharacters: max(candidateCharacters, isAccept ? acceptedCount : 0),
            candidateLengthBucket: TextFreeLengthBucket.from(wordCount: candidateWordCount).rawValue,
            opportunityCharacters: opportunityCharacters,
            retentionAt5Seconds: try retentionAt5Seconds.validated(),
            retentionAt30Seconds: try retentionAt30Seconds.validated(),
            retentionAtSegmentClose: try retentionAtSegmentClose.validated()
        )
    }

    public func eventWithoutAcceptedSpan() throws -> TextFreeOnlineEvent {
        if didAccept {
            let missing = RetainedCharacterObservation(missingness: .observerStopped)
            return try finishedEvent(
                retentionAt5Seconds: missing,
                retentionAt30Seconds: missing,
                retentionAtSegmentClose: missing
            )
        }
        // Same 5s default Lab already uses for a finished non-accept:
        // accepted minus replaced is zero. Later horizons stay missing.
        let zero = try RetainedCharacterObservation(retainedCharacters: 0)
        let pending = RetainedCharacterObservation(missingness: .notYetObserved)
        return try finishedEvent(
            retentionAt5Seconds: zero,
            retentionAt30Seconds: pending,
            retentionAtSegmentClose: pending
        )
    }

    private mutating func recordNextAction(at time: Date) {
        if nextActionMilliseconds == nil {
            nextActionMilliseconds = milliseconds(from: shownAt, to: time)
        }
        settleVisible(at: time)
    }

    private func milliseconds(from start: Date, to end: Date) -> Int {
        let value = Int((max(0, end.timeIntervalSince(start)) * 1_000).rounded())
        return min(300_000, value)
    }
}

/// Pending accept whose horizons are not all known yet.
public struct PendingRetainedWatch: Equatable, Sendable {
    public var opportunity: LiveOnlineOpportunity
    public let startedAt: Date
    public var retentionAt5Seconds: RetainedCharacterObservation
    public var retentionAt30Seconds: RetainedCharacterObservation
    public var retentionAtSegmentClose: RetainedCharacterObservation

    public init(opportunity: LiveOnlineOpportunity, startedAt: Date? = nil) {
        self.opportunity = opportunity
        self.startedAt = startedAt ?? opportunity.shownAt
        retentionAt5Seconds = RetainedCharacterObservation(missingness: .notYetObserved)
        retentionAt30Seconds = RetainedCharacterObservation(missingness: .notYetObserved)
        retentionAtSegmentClose = RetainedCharacterObservation(missingness: .notYetObserved)
    }

    public var accepted: String { opportunity.accepted }

    public var isComplete: Bool {
        retentionAt5Seconds.missingness != .notYetObserved
            && retentionAt30Seconds.missingness != .notYetObserved
            && retentionAtSegmentClose.missingness != .notYetObserved
    }

    public func isFiveSecondDue(at time: Date) -> Bool {
        time.timeIntervalSince(startedAt) >= RetainedSpanWatch.fiveSecondHorizon
    }

    public func isThirtySecondDue(at time: Date) -> Bool {
        time.timeIntervalSince(startedAt) >= RetainedSpanWatch.thirtySecondHorizon
    }

    public mutating func observeFiveSeconds(snapshot: RetainedContextSnapshot?) throws {
        guard retentionAt5Seconds.missingness == .notYetObserved else { return }
        retentionAt5Seconds = try RetainedSpanWatch.observation(
            accepted: accepted,
            insertionLocationUTF16: opportunity.acceptedInsertionLocationUTF16,
            snapshot: matchingSnapshot(snapshot)
        )
    }

    public mutating func observeThirtySeconds(snapshot: RetainedContextSnapshot?) throws {
        guard retentionAt30Seconds.missingness == .notYetObserved else { return }
        retentionAt30Seconds = RetainedSpanWatch.monotone(
            try RetainedSpanWatch.observation(
                accepted: accepted,
                insertionLocationUTF16: opportunity.acceptedInsertionLocationUTF16,
                snapshot: matchingSnapshot(snapshot)
            ),
            notExceeding: retentionAt5Seconds
        )
    }

    public mutating func observeSegment(snapshot: RetainedContextSnapshot?) throws {
        guard retentionAtSegmentClose.missingness == .notYetObserved else { return }
        var observed = RetainedSpanWatch.monotone(
            try RetainedSpanWatch.observation(
                accepted: accepted,
                insertionLocationUTF16: opportunity.acceptedInsertionLocationUTF16,
                snapshot: matchingSnapshot(snapshot)
            ),
            notExceeding: retentionAt30Seconds
        )
        observed = RetainedSpanWatch.monotone(observed, notExceeding: retentionAt5Seconds)
        retentionAtSegmentClose = observed
    }

    public mutating func markPrivacyExcluded() {
        stop(reason: .privacyExcluded)
    }

    private func matchingSnapshot(
        _ snapshot: RetainedContextSnapshot?
    ) -> RetainedContextSnapshot? {
        guard snapshot?.sourceDigestSHA256 == opportunity.sessionDigestSHA256 else { return nil }
        return snapshot
    }

    public mutating func closeSegment(snapshot: RetainedContextSnapshot?) throws {
        try observeSegment(snapshot: snapshot)
        retentionAt5Seconds = RetainedSpanWatch.closedEarlyIfStillWaiting(retentionAt5Seconds)
        retentionAt30Seconds = RetainedSpanWatch.closedEarlyIfStillWaiting(retentionAt30Seconds)
    }

    public mutating func stopObserver() {
        stop(reason: .observerStopped)
    }

    private mutating func stop(reason: RetentionMissingness) {
        if retentionAt5Seconds.missingness == .notYetObserved {
            retentionAt5Seconds = RetainedCharacterObservation(missingness: reason)
        }
        if retentionAt30Seconds.missingness == .notYetObserved {
            retentionAt30Seconds = RetainedCharacterObservation(missingness: reason)
        }
        if retentionAtSegmentClose.missingness == .notYetObserved {
            retentionAtSegmentClose = RetainedCharacterObservation(missingness: reason)
        }
        opportunity.wipeAcceptedText()
    }

    public mutating func finishedEvent() throws -> TextFreeOnlineEvent {
        let replaced: Int
        if let kept = retentionAt5Seconds.retainedCharacters {
            replaced = max(0, opportunity.acceptedCharacterCount - kept)
        } else {
            replaced = 0
        }
        let event = try opportunity.finishedEvent(
            retentionAt5Seconds: retentionAt5Seconds,
            retentionAt30Seconds: retentionAt30Seconds,
            retentionAtSegmentClose: retentionAtSegmentClose,
            replacedCharactersWithin5Seconds: replaced
        )
        opportunity.wipeAcceptedText()
        return event
    }
}
