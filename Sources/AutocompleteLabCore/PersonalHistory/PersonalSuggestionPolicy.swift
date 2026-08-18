import Foundation

public enum PersonalSuggestionSource: String, Equatable, Sendable {
    case base
    case personal
    case agreed
}

public enum PersonalSuggestionPolicy {
    public static let maximumTailWords = 2

    /// The model was trained on `PersonalNextWordShadow`'s letter-run
    /// tokens ("don't" learned as `["don", "t"]`, never `["don't"]`), so
    /// serving must split context the same way — reusing that tokenizer
    /// rather than a second, looser word-splitter keeps the keys serving
    /// looks up in the model the keys the model actually has.
    public static func tailWords(
        fromContext context: String,
        maximumWords: Int = maximumTailWords
    ) -> [String] {
        let tokens = PersonalNextWordShadow.tokenize(context)
        return Array(tokens.suffix(maximumWords))
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

    /// Production adapter from the new arbiter back to the existing count-only
    /// source vocabulary. The server/UI contract stays stable while selection
    /// becomes a replaceable judge over explicit candidates.
    public static func apply(
        baseGhost: String,
        personalPrediction: PersonalNextWordPrediction?
    ) -> (text: String, source: PersonalSuggestionSource) {
        let set = candidateSet(baseGhost: baseGhost, personalPrediction: personalPrediction)
        let decision = SuggestionArbiter.choose(from: set)
        guard let chosen = decision.candidate else { return ("", .base) }
        switch decision.reason {
        case .expertsAgree:
            return (chosen.text, .agreed)
        case .personalEvidence:
            return (chosen.text, .personal)
        case .baseOnly, .baseFallback, .silence:
            return (chosen.text, .base)
        }
    }
}
