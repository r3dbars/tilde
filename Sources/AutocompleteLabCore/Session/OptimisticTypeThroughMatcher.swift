import Foundation

public enum OptimisticTypeThroughMatch: Equatable, Sendable {
    case matched(String)
    case mismatch
    case exhausted
}

/// Performs the allocation-light prefix checks used before the authoritative
/// focused-text snapshot catches up with a keyboard event.
public struct OptimisticTypeThroughMatcher: Equatable, Sendable {
    public init() {}

    public func advance(
        typedCharacter: Character,
        remaining: String
    ) -> OptimisticTypeThroughMatch {
        guard !remaining.isEmpty else {
            return .exhausted
        }

        return match(
            typedPrefix: String(typedCharacter),
            suggestionText: remaining
        )
    }

    /// Rewinds one optimistic keydown. `typedPrefix` is the full prefix that
    /// had been consumed before the backspace, and `originalRemaining` is the
    /// suggestion text from before that optimistic sequence began.
    ///
    /// Recomputing from the original text preserves its exact spelling and
    /// whitespace even when matching folded case/diacritics or whitespace runs.
    public func retreat(
        typedPrefix: String,
        originalRemaining: String
    ) -> OptimisticTypeThroughMatch {
        guard !typedPrefix.isEmpty else {
            return .mismatch
        }

        guard TypeThroughPrefixMatcher.remainingText(
            afterMatching: typedPrefix,
            in: originalRemaining
        ) != nil else {
            return .mismatch
        }

        return match(
            typedPrefix: String(typedPrefix.dropLast()),
            suggestionText: originalRemaining
        )
    }

    private func match(
        typedPrefix: String,
        suggestionText: String
    ) -> OptimisticTypeThroughMatch {
        guard let remaining = TypeThroughPrefixMatcher.remainingText(
            afterMatching: typedPrefix,
            in: suggestionText
        ) else {
            return .mismatch
        }

        guard !remaining.isEmpty else {
            return .exhausted
        }

        return .matched(String(remaining))
    }
}
