import Foundation

/// A text-free count of how many accepted suggestion characters were still
/// present at one horizon, or an explicit reason that count was not observed.
///
/// Missingness and zero are different facts. A missing horizon must never be
/// stored or read as zero retained characters.
public struct RetainedCharacterObservation: Codable, Equatable, Sendable {
    public let retainedCharacters: Int?
    public let missingness: RetentionMissingness?

    public init(retainedCharacters: Int) throws {
        guard retainedCharacters >= 0 else {
            throw RetainedCharacterObservationError.negativeCount
        }
        self.retainedCharacters = retainedCharacters
        missingness = nil
    }

    public init(missingness: RetentionMissingness) {
        retainedCharacters = nil
        self.missingness = missingness
    }

    /// Test and decoder hook. Call `validated()` before treating this as a fact.
    init(unchecked retainedCharacters: Int?, missingness: RetentionMissingness?) {
        self.retainedCharacters = retainedCharacters
        self.missingness = missingness
    }

    public var isObserved: Bool { retainedCharacters != nil }

    public func validated() throws -> RetainedCharacterObservation {
        switch (retainedCharacters, missingness) {
        case (let count?, nil) where count >= 0:
            return self
        case (nil, .some):
            return self
        default:
            throw RetainedCharacterObservationError.ambiguous
        }
    }
}

public enum RetentionMissingness: String, Codable, CaseIterable, Sendable {
    case notYetObserved = "not-yet-observed"
    case observerStopped = "observer-stopped"
    case segmentClosedEarly = "segment-closed-early"
    case privacyExcluded = "privacy-excluded"
    case legacySchema = "legacy-schema"
}

public enum RetainedCharacterObservationError: Error, Equatable, Sendable {
    case ambiguous
    case negativeCount
}

/// A ghost that was on screen long enough to be read, versus a flicker.
///
/// Two hundred milliseconds is a conservative glance floor: shorter than that
/// is treated as not-read so a flash-and-Tab cannot look like attention.
public enum SettledVisibility {
    public static let minimumReadMilliseconds = 200

    public static func countsAsRead(_ milliseconds: Int?) -> Bool {
        guard let milliseconds, milliseconds >= minimumReadMilliseconds else {
            return false
        }
        return true
    }
}

/// Typed-through is a local, text-free judgment at opportunity close:
/// the ghost settled long enough to be a read, the writer typed at least
/// one key, and they did not Tab or Escape.
///
/// Matching the ghost is not required and must not be stored. A flicker
/// shorter than `SettledVisibility.minimumReadMilliseconds` that is then
/// typed through is ignored, not typed-through.
public enum TypedThroughRule {
    public static func isEligible(
        displayed: Bool,
        settledVisibleMilliseconds: Int?
    ) -> Bool {
        displayed && SettledVisibility.countsAsRead(settledVisibleMilliseconds)
    }

    /// Close-time classification. Accept and dismiss win over type-through.
    public static func isTypedThrough(
        displayed: Bool,
        settledVisibleMilliseconds: Int?,
        typedAfterShow: Bool,
        accepted: Bool,
        dismissed: Bool
    ) -> Bool {
        !accepted && !dismissed && typedAfterShow
            && isEligible(
                displayed: displayed,
                settledVisibleMilliseconds: settledVisibleMilliseconds
            )
    }
}

/// A bounded, in-memory view of text before the current caret. Absolute UTF-16
/// locations let retention check the original insertion range instead of
/// finding the same word somewhere else in the document.
public struct RetainedContextSnapshot: Equatable, Sendable {
    public let text: String
    public let utf16StartLocation: Int
    public let caretLocation: Int

    public init(text: String, utf16StartLocation: Int, caretLocation: Int) {
        self.text = text
        self.utf16StartLocation = utf16StartLocation
        self.caretLocation = caretLocation
    }
}

/// In-memory count of how much of an accepted span is still at its insertion
/// range. The accepted text and context snapshot never enter the event.
/// A missing or rolled-out range is missingness, never zero.
public enum RetainedSpanWatch {
    public static let fiveSecondHorizon: TimeInterval = 5
    public static let thirtySecondHorizon: TimeInterval = 30
    /// Privacy-safe idle close: the writer stopped, so the segment ended.
    public static let idleSegmentSeconds: TimeInterval = 60
    public static let maximumPendingWatches = 32

    /// Longest accepted prefix still present at the exact original UTF-16
    /// insertion location. Returns `nil` when that range is outside or invalid
    /// in the bounded snapshot, because unwitnessed text is not a rewrite.
    public static func retainedCharacters(
        accepted: String,
        insertionLocationUTF16: Int,
        snapshot: RetainedContextSnapshot
    ) -> Int? {
        let utf16Count = snapshot.text.utf16.count
        guard snapshot.utf16StartLocation >= 0,
              snapshot.caretLocation >= snapshot.utf16StartLocation,
              snapshot.caretLocation - snapshot.utf16StartLocation == utf16Count,
              insertionLocationUTF16 >= snapshot.utf16StartLocation,
              insertionLocationUTF16 <= snapshot.caretLocation else { return nil }
        let offset = insertionLocationUTF16 - snapshot.utf16StartLocation
        let utf16 = snapshot.text.utf16
        let utf16Index = utf16.index(utf16.startIndex, offsetBy: offset)
        guard let insertionIndex = String.Index(utf16Index, within: snapshot.text) else {
            return nil
        }
        let observed = snapshot.text[insertionIndex...]
        return zip(accepted, observed).prefix { $0 == $1 }.count
    }

    public static func observation(
        accepted: String,
        insertionLocationUTF16: Int?,
        snapshot: RetainedContextSnapshot?
    ) throws -> RetainedCharacterObservation {
        guard let insertionLocationUTF16,
              let snapshot,
              let retained = retainedCharacters(
                  accepted: accepted,
                  insertionLocationUTF16: insertionLocationUTF16,
                  snapshot: snapshot
              ) else {
            return RetainedCharacterObservation(missingness: .observerStopped)
        }
        return try RetainedCharacterObservation(
            retainedCharacters: retained
        ).validated()
    }

    /// Characters gone at an earlier horizon cannot return at a later one.
    /// A retyped span is authored text, not retained text.
    public static func monotone(
        _ later: RetainedCharacterObservation,
        notExceeding earlier: RetainedCharacterObservation
    ) -> RetainedCharacterObservation {
        guard let laterCount = later.retainedCharacters,
              let earlierCount = earlier.retainedCharacters,
              laterCount > earlierCount,
              let clamped = try? RetainedCharacterObservation(
                  retainedCharacters: earlierCount
              ) else { return later }
        return clamped
    }

    public static func closedEarlyIfStillWaiting(
        _ observation: RetainedCharacterObservation
    ) -> RetainedCharacterObservation {
        if observation.missingness == .notYetObserved {
            return RetainedCharacterObservation(missingness: .segmentClosedEarly)
        }
        return observation
    }
}
