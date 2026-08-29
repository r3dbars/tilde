import Foundation

/// Shared exact-character prefix primitives used by the offline generator
/// experiments. Semantic similarity is never a match: only Unicode-normalized
/// exact characters count, so a coverage number can never be inflated by a
/// paraphrase.
public enum LabExactPrefix {
    /// Canonical form used for every exact comparison. Leading whitespace is
    /// dropped because a continuation may or may not carry the boundary space.
    public static func normalized(_ value: String) -> String {
        String(
            value.precomposedStringWithCanonicalMapping
                .drop(while: { $0.isWhitespace })
        )
    }

    /// The same leading-whitespace rule as `normalized`, but without Unicode
    /// canonical mapping. Comparing two of these scalar by scalar isolates
    /// exactly the differences canonical equivalence would have hidden.
    public static func whitespaceTrimmed(_ value: String) -> String {
        String(value.drop(while: { $0.isWhitespace }))
    }

    /// Count of leading characters two normalized strings share.
    public static func sharedCharacters(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(normalized(lhs))
        let right = Array(normalized(rhs))
        var count = 0
        for (a, b) in zip(left, right) {
            guard a == b else { break }
            count += 1
        }
        return count
    }
}
