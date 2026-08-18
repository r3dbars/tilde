import Foundation

/// Why the arbiter selected a candidate. Fixed vocabulary only; safe to count,
/// but candidate text itself remains private and must never be logged.
public enum SuggestionArbiterReason: String, Equatable, Sendable {
    case baseOnly
    case expertsAgree
    case personalEvidence
    case baseFallback
    case silence
}

public struct SuggestionArbiterDecision: Equatable, Sendable {
    public let candidate: SuggestionCandidate?
    public let reason: SuggestionArbiterReason
}

/// First real multi-expert judge. It is deliberately deterministic and
/// conservative so replay can sweep its thresholds before a learned ranker
/// replaces it.
public enum SuggestionArbiter {
    public static let minimumPersonalSupport = 2
    public static let minimumPersonalConfidence = 2.0 / 3.0

    public static func choose(from set: SuggestionCandidateSet) -> SuggestionArbiterDecision {
        guard let base = set.first(from: .base) else {
            // A specialist may never create a suggestion from base silence in
            // v1. Silence is a product decision, not an empty slot to fill.
            return .init(candidate: nil, reason: .silence)
        }
        guard let personal = set.first(from: .personal) else {
            return .init(candidate: base, reason: .baseOnly)
        }

        if firstWord(base.text) == firstWord(personal.text) {
            return .init(candidate: base, reason: .expertsAgree)
        }

        if personal.support >= minimumPersonalSupport,
           (personal.confidence ?? 0) >= minimumPersonalConfidence {
            return .init(candidate: personal, reason: .personalEvidence)
        }
        return .init(candidate: base, reason: .baseFallback)
    }

    private static func firstWord(_ text: String) -> String? {
        guard let word = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let normalized = PersonalReplayEval.normalizeWord(word)
        return normalized.isEmpty ? nil : normalized
    }
}
