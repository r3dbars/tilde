import Foundation

/// Converts token-level model uncertainty into a visible word budget.
///
/// The policy is intentionally conservative: it only shortens a suggestion
/// when the greedy path hits a genuinely weak token early. It never lengthens
/// a ghost, never invents text, and an unavailable trace returns `nil` so the
/// caller preserves today's behavior.
public enum ConsensusGhostPolicy {
    /// First dogfood bar. This is deliberately simple and lives in one place
    /// so replay can sweep it rather than scattering confidence gates.
    public static let minimumTokenProbability = 0.50

    /// Returns `nil` when no shortening is justified. Otherwise returns the
    /// maximum whole-word budget the caller should expose.
    public static func visibleWordBudget(
        tokens: [CompletionTokenEvidence],
        currentVisibleWords: Int,
        threshold: Double = minimumTokenProbability
    ) -> Int? {
        guard !tokens.isEmpty, currentVisibleWords > 1 else { return nil }
        let bar = min(max(threshold, 0), 1)
        var safeText = ""

        for token in tokens {
            guard token.probability >= bar else {
                var completeWords = wordCount(in: safeText)
                // If the first unsafe token continues the current lexical
                // token, the trailing safe fragment is not a whole word yet.
                if !token.text.first.map(\.isWhitespace, default: false),
                   !safeText.last.map(\.isWhitespace, default: true),
                   completeWords > 0 {
                    completeWords -= 1
                }
                let budget = max(1, completeWords)
                return budget < currentVisibleWords ? budget : nil
            }
            safeText += token.text
        }
        return nil
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

private extension Optional where Wrapped == Bool {
    func map(_ transform: (Bool) -> Bool, default fallback: Bool) -> Bool {
        switch self {
        case let .some(value): transform(value)
        case .none: fallback
        }
    }
}
