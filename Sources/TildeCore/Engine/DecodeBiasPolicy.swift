import Foundation

/// A single term and logit boost for decode-time biasing on `llama-server`.
public struct WeightedBiasTerm: Equatable, Hashable, Sendable {
    public let term: String
    public let weight: Double

    public init(term: String, weight: Double) {
        self.term = term
        self.weight = weight
    }
}

/// Pure deterministic policy for decode-time Word Nudge (`logit_bias`):
/// extracts salient, secret-scrubbed terms from the active Screen Memory scene
/// and merges them with non-mutating personal vocabulary terms.
///
/// Leaving the prompt bytes untouched keeps `llama-server`'s KV prefix cache
/// 100% warm (0 ms added prefill latency), while guiding the model away from
/// generic filler toward the exact names, topics, and terms in the active
/// conversation and the writer's own vocabulary.
public enum DecodeBiasPolicy {
    public static let defaultMaxTerms = 24
    public static let defaultMaxBias = 1.6
    public static let latestOtherTurnWeight = 1.35
    public static let earlierTurnWeight = 1.10
    public static let referenceSnippetWeight = 1.00
    public static let personalContextWeight = 0.65
    public static let personalLexiconWeight = 0.50

    private static let trailingEchoExclusionWindow = 6

    private static let stopwords: Set<String> = [
        "the", "and", "that", "have", "with", "this", "from", "they", "will",
        "would", "there", "their", "what", "about", "which", "when", "make",
        "like", "time", "just", "know", "take", "into", "year", "your", "good",
        "some", "could", "them", "other", "than", "then", "look", "only", "come",
        "over", "think", "also", "back", "after", "work", "first", "well", "even",
        "want", "because", "these", "give", "most", "were", "been", "being",
        "does", "yeah", "okay", "right", "really", "actually", "basically", "kind",
        "sort", "thing", "things", "going", "gonna", "getting", "mean", "said",
        "says", "sure", "here", "very", "much", "more", "still", "where", "should",
        "might", "must", "need", "lets", "made", "doing", "done", "having", "went",
        "came", "those", "onto", "around", "through", "before", "while", "during",
        "under", "above", "below", "between", "within", "without", "again",
        "further", "once", "both", "each", "such", "same", "pretty", "maybe",
        "little", "probably", "definitely", "totally", "something", "anything",
        "everything", "nothing", "dont", "didnt", "cant", "wont", "youre", "theyre",
    ]

    private static let contractionFragments: Set<String> = [
        "t", "s", "d", "m", "ll", "re", "ve",
    ]

    /// Extracts salient, secret-scrubbed terms from the active scene,
    /// prioritizing the newest incoming turn from the other speaker and
    /// excluding words already present in the writer's trailing typed context.
    public static func extractSceneTerms(
        scene: ScreenScene.Scene?,
        typed: PreparedTypedContext,
        maxTerms: Int = 16
    ) -> [WeightedBiasTerm] {
        guard let scene, maxTerms > 0 else { return [] }
        let trailingTyped = Set(typed.words.suffix(trailingEchoExclusionWindow))
        var weightsByFolded: [String: (surface: String, weight: Double, order: Int)] = [:]
        var nextOrder = 0

        func ingest(_ rawText: String, weight: Double) {
            let scrubbed = SecretRules.scrub(rawText, config: .forPersistence).clean
            for range in CompletionContextWords.wordRanges(in: scrubbed) {
                let rawToken = String(scrubbed[range])
                let cleanedSurface = rawToken.trimmingCharacters(in: .punctuationCharacters)
                let folded = CompletionContextWords.normalized(cleanedSurface)
                guard isEligibleBiasWord(folded), !trailingTyped.contains(folded) else { continue }
                if let existing = weightsByFolded[folded] {
                    if weight > existing.weight {
                        weightsByFolded[folded] = (cleanedSurface, weight, existing.order)
                    }
                } else {
                    weightsByFolded[folded] = (cleanedSurface, weight, nextOrder)
                    nextOrder += 1
                }
            }
        }

        // Newest incoming turns get highest priority so active names/topics win ties.
        let turns = scene.conversationTurns
        let newestOtherIndex = turns.lastIndex(where: { $0.speaker != .selfSpeaker })
        if let newestOtherIndex {
            ingest(turns[newestOtherIndex].text, weight: latestOtherTurnWeight)
        }
        for index in turns.indices.reversed() where index != newestOtherIndex {
            let turn = turns[index]
            // Prioritize other-speaker turns over self turns.
            let weight = turn.speaker == .selfSpeaker ? referenceSnippetWeight : earlierTurnWeight
            ingest(turn.text, weight: weight)
        }
        for snippet in scene.referenceSnippets {
            ingest(snippet, weight: referenceSnippetWeight)
        }

        return weightsByFolded.values
            .sorted { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
                return lhs.order < rhs.order
            }
            .prefix(maxTerms)
            .map { WeightedBiasTerm(term: $0.surface, weight: $0.weight) }
    }

    /// Merges scene terms and personal vocabulary terms deterministically,
    /// keeping the highest weight per case-folded term and clamping to `maxBias`.
    public static func merge(
        scene: [WeightedBiasTerm],
        personal: [WeightedBiasTerm],
        typed: PreparedTypedContext? = nil,
        maxTerms: Int = defaultMaxTerms,
        maxBias: Double = defaultMaxBias
    ) -> [WeightedBiasTerm] {
        guard maxTerms > 0, maxBias > 0 else { return [] }
        let trailingTyped = Set(typed?.words.suffix(trailingEchoExclusionWindow) ?? [])
        var merged: [String: (surface: String, weight: Double, order: Int)] = [:]
        var nextOrder = 0

        for entry in scene + personal {
            let surface = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let folded = CompletionContextWords.normalized(surface)
            guard isEligibleBiasWord(folded), !trailingTyped.contains(folded) else { continue }
            let clamped = min(maxBias, max(0.05, entry.weight))
            if let existing = merged[folded] {
                if clamped > existing.weight {
                    merged[folded] = (surface, clamped, existing.order)
                }
            } else {
                merged[folded] = (surface, clamped, nextOrder)
                nextOrder += 1
            }
        }

        return merged.values
            .sorted { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
                return lhs.order < rhs.order
            }
            .prefix(maxTerms)
            .map { WeightedBiasTerm(term: $0.surface, weight: ($0.weight * 100).rounded() / 100) }
    }

    /// Deterministic zero-cost guard against a nudged content word repeating
    /// awkwardly inside a short 2–5 word suggestion (e.g. "Thursday ... Thursday").
    /// Leaves function words and short words untouched.
    public static func trimRepeatedContentWord(_ continuation: String) -> String {
        let ranges = CompletionContextWords.wordRanges(in: continuation)
        guard ranges.count >= 2 else { return continuation }
        var seenContent = Set<String>()
        for range in ranges {
            let folded = CompletionContextWords.normalized(String(continuation[range]))
            guard isEligibleBiasWord(folded) else { continue }
            if !seenContent.insert(folded).inserted {
                var trimmed = String(continuation[..<range.lowerBound])
                while let last = trimmed.last,
                      last.isWhitespace || last == "," || last == ";" || last == ":" {
                    trimmed.removeLast()
                }
                return trimmed
            }
        }
        return continuation
    }

    public static func isEligibleBiasWord(_ folded: String) -> Bool {
        guard folded.count >= 4,
              folded.contains(where: \.isLetter),
              !folded.allSatisfy(\.isNumber),
              !stopwords.contains(folded),
              !contractionFragments.contains(folded) else {
            return false
        }
        return true
    }
}
