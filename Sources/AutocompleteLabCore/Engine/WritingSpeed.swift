import Foundation

/// Writing-speed math for the Tilde window (docs/tilde-app-build-spec.md).
///
/// The keyboard accumulates `activeTypingMilliseconds` — inter-keystroke gaps
/// with anything over `maximumGapMilliseconds` excluded, so thinking pauses
/// never count against the writer. From that one honest denominator:
///   raw wpm      = words the writer typed themselves, per active minute
///   assisted wpm = typed + ghost-written words, per the same active minute
/// The delta between the two is causally the app's contribution.
public enum WritingSpeed {

    /// A gap longer than this is a pause, not typing.
    public static let maximumGapMilliseconds = 3_000

    /// Below this much active typing, a wpm figure is noise — show nothing.
    public static let minimumActiveMilliseconds = 30_000

    public static func wordsPerMinute(words: Int, activeTypingMilliseconds: Int) -> Double? {
        guard activeTypingMilliseconds >= minimumActiveMilliseconds, words > 0 else { return nil }
        return Double(words) / (Double(activeTypingMilliseconds) / 60_000)
    }

    /// Whole-percent speedup of assisted over raw, or nil when there is no
    /// real gain to claim (never show "0% faster" or a negative brag).
    public static func speedupPercent(raw: Double, assisted: Double) -> Int? {
        guard raw > 0, assisted > raw else { return nil }
        return Int((((assisted - raw) / raw) * 100).rounded())
    }

    /// "About H hours of typing you didn't do": ghost-written characters
    /// divided by the writer's own measured character rate. Nil until both
    /// sides are measurable.
    public static func hoursSaved(charactersAccepted: Int, typedCharacters: Int, activeTypingMilliseconds: Int) -> Double? {
        guard
            charactersAccepted > 0,
            typedCharacters > 0,
            activeTypingMilliseconds >= minimumActiveMilliseconds
        else { return nil }
        let charactersPerMs = Double(typedCharacters) / Double(activeTypingMilliseconds)
        let savedMs = Double(charactersAccepted) / charactersPerMs
        return savedMs / 3_600_000
    }
}
