import Foundation

public struct WordCompletionCandidateSelection: Equatable, Sendable {
    public let suggestion: CompletionSuggestion?
    public let candidateCount: Int
    public let topScore: Double?
    public let scoreMargin: Double?
    public let suppressionReason: String?

    public init(
        suggestion: CompletionSuggestion?,
        candidateCount: Int,
        topScore: Double?,
        scoreMargin: Double?,
        suppressionReason: String?
    ) {
        self.suggestion = suggestion
        self.candidateCount = candidateCount
        self.topScore = topScore
        self.scoreMargin = scoreMargin
        self.suppressionReason = suppressionReason
    }

    public var traceMetadata: [String: String] {
        [
            "candidateSelectionSource": "fast-word-completion",
            "cleanedCandidateCount": String(candidateCount),
            "candidateTopScore": Self.formatScore(topScore),
            "candidateScoreMargin": Self.formatScore(scoreMargin),
            "candidateSuppressionReason": suppressionReason ?? "none"
        ]
    }

    private static func formatScore(_ score: Double?) -> String {
        guard let score else {
            return "none"
        }

        return String(format: "%.3f", score)
    }
}

public struct WordCompletionCandidateRanker: Equatable, Sendable {
    public let staticWords: [String]

    public init(staticWords: [String] = Self.defaultWords) {
        self.staticWords = staticWords
    }

    public func suggestion(
        for textBeforeCursor: String,
        recentWords: [String] = []
    ) -> CompletionSuggestion? {
        selection(for: textBeforeCursor, recentWords: recentWords).suggestion
    }

    public func selection(
        for textBeforeCursor: String,
        recentWords: [String] = []
    ) -> WordCompletionCandidateSelection {
        guard let fragment = trailingFragment(in: textBeforeCursor),
              fragment.count >= 3,
              fragment.allSatisfy({ $0.isLetter }) else {
            return WordCompletionCandidateSelection(
                suggestion: nil,
                candidateCount: 0,
                topScore: nil,
                scoreMargin: nil,
                suppressionReason: "invalid-fragment"
            )
        }

        let normalizedFragment = fragment.lowercased()
        let candidates = rankedCandidates(
            fragment: normalizedFragment,
            recentWords: recentWords
        )

        guard let candidate = candidates.first,
              candidate.normalizedWord.count > normalizedFragment.count else {
            return WordCompletionCandidateSelection(
                suggestion: nil,
                candidateCount: candidates.count,
                topScore: candidates.first?.score,
                scoreMargin: scoreMargin(in: candidates),
                suppressionReason: "no-candidate"
            )
        }

        let suffix = String(candidate.normalizedWord.dropFirst(normalizedFragment.count))
        let competingCandidateCount = candidates.filter { $0.source == candidate.source }.count
        guard isUsefulSuffix(
            suffix,
            fragment: normalizedFragment,
            source: candidate.source,
            competingCandidateCount: competingCandidateCount
        ) else {
            return WordCompletionCandidateSelection(
                suggestion: nil,
                candidateCount: candidates.count,
                topScore: candidate.score,
                scoreMargin: scoreMargin(in: candidates),
                suppressionReason: "low-value-suffix"
            )
        }

        return WordCompletionCandidateSelection(
            suggestion: CompletionSuggestion(
                text: displaySuffix(for: candidate, fragment: fragment),
                maxVisibleWords: 1
            ),
            candidateCount: candidates.count,
            topScore: candidate.score,
            scoreMargin: scoreMargin(in: candidates),
            suppressionReason: nil
        )
    }

    private func rankedCandidates(fragment: String, recentWords: [String]) -> [Candidate] {
        let recent = recentWords
            .reversed()
            .compactMap(candidateWord)
            .filter { $0.normalized.hasPrefix(fragment) && $0.normalized.count > fragment.count }

        let staticMatches = staticWords
            .compactMap(candidateWord)
            .filter { $0.normalized.hasPrefix(fragment) && $0.normalized.count > fragment.count }

        var seen: Set<String> = []
        return (recent.enumerated().map { (index, word) in
            Candidate(normalizedWord: word.normalized, displayWord: word.display, source: .recent, priority: 0, index: index)
        }
            + staticMatches.enumerated().map { (index, word) in
                Candidate(normalizedWord: word.normalized, displayWord: word.display, source: .staticDictionary, priority: 1, index: index)
            })
            .filter { candidate in
                guard !seen.contains(candidate.normalizedWord) else {
                    return false
                }
                seen.insert(candidate.normalizedWord)
                return true
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }

                return lhs.index < rhs.index
            }
    }

    private func displaySuffix(for candidate: Candidate, fragment: String) -> String {
        let rawSuffix = String(candidate.displayWord.dropFirst(fragment.count))

        if fragment.allSatisfy({ $0.isUppercase }) {
            return rawSuffix.uppercased()
        }

        if fragment.allSatisfy({ $0.isLowercase }) {
            return rawSuffix.lowercased()
        }

        return rawSuffix
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
            if suffix.count <= 2 {
                return fragment.count >= 6
            }

            return true
        }

        if suffix == "ng" {
            return fragment.count >= 6
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

    private func candidateWord(_ word: String) -> (normalized: String, display: String)? {
        let display = word
            .trimmingCharacters(in: .punctuationCharacters)
        let normalized = display.lowercased()

        guard !display.isEmpty,
              normalized.allSatisfy({ $0.isLetter }) else {
            return nil
        }

        return (normalized, display)
    }

    private func scoreMargin(in candidates: [Candidate]) -> Double? {
        guard candidates.count > 1,
              let topScore = candidates.first?.score
        else {
            return nil
        }

        return topScore - candidates[1].score
    }

    public static let defaultWords = [
        "about", "accurate", "actually", "again", "also", "always", "app",
        "application", "around", "available", "because",
        "before", "being", "better", "between", "bring", "build", "change",
        "computer", "context", "conversation", "could",
        "decent", "decently", "definitely", "dictation", "different",
        "document", "everything",
        "fast",
        "first", "going", "hello", "help", "hey", "important",
        "instant", "interesting", "kind", "language", "launch",
        "make", "meaning", "need", "notes",
        "option", "people", "really",
        "reliable", "right", "should", "slow", "something",
        "system", "their", "there", "these", "thing",
        "think", "this", "trying", "typing", "understand", "want",
        "what", "when", "where", "which", "while", "window",
        "without", "working", "would", "writing"
    ]

    private static let ambiguousTwoLetterStaticFragments: Set<String> = [
        "ap", "co", "in", "re", "th"
    ]

    private struct Candidate: Equatable {
        let normalizedWord: String
        let displayWord: String
        let source: CandidateSource
        let priority: Int
        let index: Int

        var score: Double {
            switch source {
            case .recent:
                return max(0.800, 1.000 - (Double(index) * 0.020))
            case .staticDictionary:
                return max(0.500, 0.850 - (Double(index) * 0.010))
            }
        }
    }

    private enum CandidateSource: Equatable {
        case recent
        case staticDictionary
    }
}
