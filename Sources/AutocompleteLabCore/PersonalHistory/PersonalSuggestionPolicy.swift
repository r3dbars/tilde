import Foundation

/// Which engine's word actually reached the user, for the count-only
/// `suggestion-served` diagnostic's `source` field
/// (`DiagnosticsMetadataRedactor`). Only ever emitted when the "Personal
/// suggestions (experimental)" toggle is on; toggle-off behavior stays
/// byte-identical to before this feature existed (no `source` field at
/// all).
public enum PersonalSuggestionSource: String, Equatable, Sendable {
    case base
    case personal
    case agreed
}

/// v1 policy for serving the Personal History next-word model's prediction
/// alongside the base ghost (`docs/plans/road-to-paid.md` Phase 3). Pure and
/// stateless: a comparison of two already-computed strings. Deliberately
/// does not touch `PersonalNextWordShadow`'s paired A/B scoring in any way —
/// that experiment keeps running untouched regardless of this policy's
/// outcome (`docs/evaluation.md`).
public enum PersonalSuggestionPolicy {
    /// Matches `PersonalNextWordShadow.predictNextWord`'s own context
    /// window (the conservative baseline recipe's 2-word lookback).
    public static let maximumTailWords = 2

    /// Up to `maximumWords` trailing words from field text that ends in
    /// whitespace (the same precondition `GhostBrainRequest` enforces on
    /// the wire — see `GhostBrainServerHost`'s request validation), each
    /// cleaned the same way replay scoring cleans a golden word
    /// (`PersonalReplayEval.normalizeWord`) so the lookup's vocabulary
    /// roughly matches what the shadow model learned from typed text.
    public static func tailWords(
        fromContext context: String,
        maximumWords: Int = maximumTailWords
    ) -> [String] {
        let tokens = context.split(whereSeparator: \.isWhitespace)
        return tokens.suffix(maximumWords).map { PersonalReplayEval.normalizeWord($0) }
    }

    /// The v1 blend, deliberately simple (a feel-it experiment, not the
    /// final Smart-Compose-style interpolation Phase 3 describes):
    /// - No personal candidate, or nothing to compare against (empty base
    ///   ghost — i.e. the base engine is already silent): serve the base
    ///   ghost untouched, `source: .base`. This policy never turns a
    ///   silence into a suggestion.
    /// - The personal candidate's word agrees with the base ghost's first
    ///   word: serve the base ghost untouched, `source: .agreed` —
    ///   agreement IS the confidence signal, so the (possibly longer) base
    ///   ghost is kept rather than truncated to one word.
    /// - The personal candidate disagrees with the base ghost's first word:
    ///   replace the ghost with just the single personal word, `source:
    ///   .personal` — a confident personal word beats a plausible-but-generic
    ///   phrase, but only that one word, never a personal phrase the model
    ///   hasn't actually vetted beyond the next token.
    public static func apply(
        baseGhost: String,
        personalPrediction: PersonalNextWordPrediction?
    ) -> (text: String, source: PersonalSuggestionSource) {
        guard !baseGhost.isEmpty, let personalPrediction else {
            return (baseGhost, .base)
        }
        let normalizedPersonal = PersonalReplayEval.normalizeWord(personalPrediction.word)
        guard !normalizedPersonal.isEmpty,
              let baseFirstWord = baseGhost.split(whereSeparator: \.isWhitespace).first else {
            return (baseGhost, .base)
        }
        let normalizedBase = PersonalReplayEval.normalizeWord(baseFirstWord)
        if normalizedBase == normalizedPersonal {
            return (baseGhost, .agreed)
        }
        return (personalPrediction.word, .personal)
    }
}
