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

        guard let word = candidates.first,
              word.count > normalizedFragment.count else {
            return nil
        }

        let suffix = String(word.dropFirst(normalizedFragment.count))
        guard !suffix.isEmpty else {
            return nil
        }

        return CompletionSuggestion(text: suffix, maxVisibleWords: 1)
    }

    private func rankedCandidates(fragment: String, recentWords: [String]) -> [String] {
        let recent = recentWords
            .reversed()
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        let staticMatches = staticWords
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        var seen: Set<String> = []
        return (recent.enumerated().map { (index, word) in (word: word, priority: 0, index: index) }
            + staticMatches.enumerated().map { (index, word) in (word: word, priority: 1, index: index) })
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
            .map(\.word)
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
        "debugging", "definitely", "diagnostics", "dictation", "different",
        "document", "dogfooding", "everything", "evaluation", "fantastic",
        "first", "going", "great", "important", "inference", "insert",
        "insertion", "instant", "interesting", "kind", "language", "launch",
        "logs", "make", "meaning", "model", "need", "notes", "obsidian",
        "option", "people", "placement", "prediction", "prompt", "really",
        "relaunch", "reliable", "retry", "right", "something", "suggestion",
        "system", "test", "testing", "their", "there", "these", "thing",
        "think", "this", "trace", "transcripted", "tracing", "trying",
        "typing", "understand", "version",
        "verification", "what", "when", "where", "which", "while", "window",
        "without", "working", "would", "writing"
    ]
}
