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
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        let staticMatches = staticWords
            .map { normalize($0) }
            .filter { $0.hasPrefix(fragment) && $0.count > fragment.count }

        var seen: Set<String> = []
        return (recent + staticMatches)
            .filter { word in
                guard !seen.contains(word) else {
                    return false
                }
                seen.insert(word)
                return true
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }

                return lhs.count < rhs.count
            }
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
        "autocomplete", "available", "because", "completion", "computer", "context",
        "conversation", "diagnostics", "dictation", "different", "document",
        "evaluation", "fantastic", "important", "inference", "instant",
        "interesting", "language", "meaning", "model", "obsidian", "option",
        "prediction", "prompt", "reliable", "suggestion", "transcripted",
        "tracing", "typing", "understand", "verification", "window", "writing"
    ]
}
