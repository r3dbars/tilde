import Foundation

public struct WordCompletionCandidateRanker: Equatable, Sendable {
    public let staticWords: [String]

    public init(staticWords: [String] = Self.defaultWords) {
        self.staticWords = staticWords
    }

    public func suggestion(
        for textBeforeCursor: String,
        recentWords: [String] = []
    ) -> CompletionSuggestion? {
        guard let fragment = trailingFragment(in: textBeforeCursor),
              fragment.count >= 2,
              fragment.allSatisfy({ $0.isLetter }) else {
            return nil
        }

        let normalizedFragment = fragment.lowercased()
        let candidates = rankedCandidates(
            fragment: normalizedFragment,
            recentWords: recentWords
        )

        guard let candidate = candidates.first,
              candidate.word.count > normalizedFragment.count else {
            return nil
        }

        let suffix = String(candidate.word.dropFirst(normalizedFragment.count))
        let competingCandidateCount = candidates.filter { $0.source == candidate.source }.count
        guard isUsefulSuffix(
            suffix,
            fragment: normalizedFragment,
            source: candidate.source,
            competingCandidateCount: competingCandidateCount
        ) else {
            return nil
        }

        return CompletionSuggestion(text: suffix, maxVisibleWords: 1)
    }

    private func rankedCandidates(fragment: String, recentWords: [String]) -> [Candidate] {
        let recent = recentWords
            .reversed()
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        let staticMatches = staticWords
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        var seen: Set<String> = []
        return (recent.enumerated().map { (index, word) in Candidate(word: word, source: .recent, priority: 0, index: index) }
            + staticMatches.enumerated().map { (index, word) in Candidate(word: word, source: .staticDictionary, priority: 1, index: index) })
            .filter { candidate in
                guard !seen.contains(candidate.word) else {
                    return false
                }
                seen.insert(candidate.word)
                return true
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }

                return lhs.index < rhs.index
            }
    }

    private func isUsefulSuffix(
        _ suffix: String,
        fragment: String,
        source: CandidateSource,
        competingCandidateCount: Int
    ) -> Bool {
        guard !suffix.isEmpty else {
            return false
        }

        if source == .recent {
            if suffix.count == 1 {
                return fragment.count >= 5
            }

            return true
        }

        if source == .staticDictionary,
           Self.ambiguousTwoLetterStaticFragments.contains(fragment),
           competingCandidateCount > 1 {
            return false
        }

        if suffix.count <= 2,
           fragment.count >= 3,
           competingCandidateCount >= 3 {
            return false
        }

        if suffix.count == 1 {
            return fragment.count >= 5
        }

        if suffix == "ing" {
            return fragment.count >= 5
        }

        return true
    }

    private func trailingFragment(in text: String) -> String? {
        guard let last = text.last, last.isLetter else {
            return nil
        }

        return text.split(whereSeparator: { !$0.isLetter }).last.map(String.init)
    }

    private func normalize(_ word: String) -> String {
        word
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }

    public static let defaultWords = [
        "about", "accurate", "actually", "again", "also", "always", "app",
        "application", "around", "autocomplete", "available", "because",
        "before", "being", "better", "between", "bring", "build", "change",
        "codex", "completion", "computer", "context", "conversation", "could",
        "decent", "decently", "debugging", "definitely", "diagnostics", "dictation", "different",
        "document", "dogfooding", "everything", "evaluation", "fantastic",
        "fast",
        "first", "going", "great", "hello", "help", "hey", "important", "inference", "insert",
        "insertion", "instant", "interesting", "kind", "language", "launch",
        "logs", "make", "meaning", "model", "need", "notes", "obsidian",
        "option", "people", "placement", "prediction", "prompt", "really",
        "relaunch", "reliable", "retry", "right", "should", "slow", "something", "super",
        "suggestion", "system", "test", "testing", "their", "there", "these", "thing",
        "think", "this", "trying", "typing", "trace", "tracing",
        "transcripted", "understand", "version", "want",
        "verification", "what", "when", "where", "which", "while", "window",
        "without", "working", "would", "writing"
    ]

    private static let ambiguousTwoLetterStaticFragments: Set<String> = [
        "ap", "co", "in", "re", "th"
    ]

    private struct Candidate: Equatable {
        let word: String
        let source: CandidateSource
        let priority: Int
        let index: Int
    }

    private enum CandidateSource: Equatable {
        case recent
        case staticDictionary
    }
}
