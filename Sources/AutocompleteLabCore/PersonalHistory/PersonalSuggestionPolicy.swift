import Foundation

public enum PersonalSuggestionSource: String, Equatable, Sendable {
    case base
    case personal
    case agreed
}

/// Conservative v1 selection policy. The important architectural change is
/// that serving now crosses a CandidateSet boundary: generation and selection
/// are separate concepts, so replay and future experts can inspect the same
/// alternatives without changing what the user sees.
public enum PersonalSuggestionPolicy {
    public static let maximumTailWords = 2

    public static func tailWords(
        fromContext context: String,
        maximumWords: Int = maximumTailWords
    ) -> [String] {
        let tokens = context.split(whereSeparator: \.isWhitespace)
        return tokens.suffix(maximumWords).map { PersonalReplayEval.normalizeWord($0) }
    }

    public static func candidateSet(
        baseGhost: String,
        personalPrediction: PersonalNextWordPrediction?
    ) -> SuggestionCandidateSet {
        var candidates = [SuggestionCandidate(text: baseGhost, source: .base)]
        if let personalPrediction {
            let confidence = personalPrediction.total > 0
                ? Double(personalPrediction.support) / Double(personalPrediction.total)
                : nil
            candidates.append(SuggestionCandidate(
                text: personalPrediction.word,
                source: .personal,
                confidence: confidence,
                support: personalPrediction.support
            ))
        }
        return SuggestionCandidateSet(candidates)
    }

    /// Keeps the pre-CandidateSet user-visible behavior byte-for-byte:
    /// personal disagreement serves one personal word; agreement keeps the
    /// longer base ghost; no personal evidence keeps base; base silence stays
    /// silent. Only the internal hand-off changed.
    public static func apply(
        baseGhost: String,
        personalPrediction: PersonalNextWordPrediction?
    ) -> (text: String, source: PersonalSuggestionSource) {
        let set = candidateSet(baseGhost: baseGhost, personalPrediction: personalPrediction)
        guard let base = set.first(from: .base) else { return ("", .base) }
        guard let personal = set.first(from: .personal) else { return (base.text, .base) }

        let normalizedPersonal = PersonalReplayEval.normalizeWord(personal.text)
        guard !normalizedPersonal.isEmpty,
              let baseFirstWord = base.text.split(whereSeparator: \.isWhitespace).first else {
            return (base.text, .base)
        }
        let normalizedBase = PersonalReplayEval.normalizeWord(baseFirstWord)
        if normalizedBase == normalizedPersonal {
            return (base.text, .agreed)
        }
        return (personal.text, .personal)
    }
}
