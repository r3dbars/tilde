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

/// Typed-through is a local, text-free judgment: the ghost settled, the writer
/// kept typing, and they did not Tab or Escape. The event stores only that
/// outcome. It must not store the ghost, the keys, or a string match.
public enum TypedThroughRule {
    public static func isEligible(
        displayed: Bool,
        settledVisibleMilliseconds: Int?
    ) -> Bool {
        displayed && SettledVisibility.countsAsRead(settledVisibleMilliseconds)
    }
}
