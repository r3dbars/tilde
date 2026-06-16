import Foundation

public struct DocLocalNGramPhrasePredictor: Equatable, Sendable {
    public let minimumMatchWords: Int
    public let maximumMatchWords: Int

    public init(
        minimumMatchWords: Int = 2,
        maximumMatchWords: Int = 5
    ) {
        self.minimumMatchWords = max(1, minimumMatchWords)
        self.maximumMatchWords = max(self.minimumMatchWords, maximumMatchWords)
    }

    public func selection(
        for request: CompletionRequest,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        let localContextTexts = request.visiblePageContext.map { [$0.text] } ?? []
        return selection(
            for: request.textBeforeCursor,
            localContextTexts: localContextTexts,
            behaviorProfileID: request.behaviorProfileID,
            maxVisibleWords: request.maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        )
    }

    public func selection(
        for textBeforeCursor: String,
        localContextTexts: [String] = [],
        spokenContextTexts: [String] = [],
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(
            for: behaviorProfileID,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        ) else {
            return noSuggestion("unsupported-profile")
        }

        let clampedMaxWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        let currentTokens = Self.tokens(in: textBeforeCursor, source: .beforeCursor)
        guard currentTokens.count >= minimumMatchWords else {
            return noSuggestion("too-little-context")
        }

        guard let last = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).last,
              last.isLetter || last.isNumber else {
            return noSuggestion("not-word-boundary")
        }

        let corpora = sourceCorpora(
            textBeforeCursor: textBeforeCursor,
            localContextTexts: localContextTexts,
            spokenContextTexts: spokenContextTexts
        )
        guard !corpora.isEmpty else {
            return noSuggestion("empty-corpus")
        }

        let maxOrder = min(maximumMatchWords, currentTokens.count)
        var candidates: [DocLocalNGramCandidate] = []
        for order in stride(from: maxOrder, through: minimumMatchWords, by: -1) {
            let suffix = currentTokens.suffix(order).map(\.normalized)
            guard !suffix.isEmpty else {
                continue
            }

            for corpus in corpora {
                candidates.append(contentsOf: matchingCandidates(
                    matching: Array(suffix),
                    order: order,
                    corpus: corpus,
                    maxVisibleWords: clampedMaxWords
                ))
            }
        }

        guard let best = candidates.sorted(by: isBetterCandidate).first else {
            return noSuggestion("no-local-match")
        }

        let suggestion = CompletionSuggestion(
            text: " \(best.continuation)",
            maxVisibleWords: clampedMaxWords
        )
        return CommonPhraseContinuationSelection(
            suggestion: suggestion,
            matchedContextSuffix: "order-\(best.order)-\(best.source.rawValue)",
            score: best.score,
            suppressionReason: nil,
            candidateSelectionSource: "doc-local-ngram",
            matchMetadataKey: "docLocalNGramMatch"
        )
    }

    public func traceMetadata(
        for selection: CommonPhraseContinuationSelection
    ) -> [String: String] {
        selection.traceMetadata
    }

    private func sourceCorpora(
        textBeforeCursor: String,
        localContextTexts: [String],
        spokenContextTexts: [String] = []
    ) -> [DocLocalNGramCorpus] {
        var corpora: [DocLocalNGramCorpus] = []
        let beforeCursorTokens = Self.tokens(in: textBeforeCursor, source: .beforeCursor)
        if beforeCursorTokens.count >= minimumMatchWords + 1 {
            corpora.append(DocLocalNGramCorpus(source: .beforeCursor, tokens: beforeCursorTokens))
        }

        let localContextTokens = localContextTexts
            .flatMap { Self.tokens(in: $0, source: .localContext) }
        if localContextTokens.count >= minimumMatchWords + 1 {
            corpora.append(DocLocalNGramCorpus(source: .localContext, tokens: localContextTokens))
        }

        // Spike: opt-in recent *spoken* transcript corpus (see
        // docs/product/spikes/voice-text-loop.md). Entries arrive already bounded
        // and are joined as separate lines so a continuation never bleeds across
        // two snapshots, and so a more recent entry earns a higher recency score.
        // This stays empty unless a caller opts in to recent spoken context, so
        // typed-only behavior is unchanged.
        let spokenContextTokens = Self.tokens(
            in: spokenContextTexts.joined(separator: "\n"),
            source: .spokenTranscript
        )
        if spokenContextTokens.count >= minimumMatchWords + 1 {
            corpora.append(DocLocalNGramCorpus(source: .spokenTranscript, tokens: spokenContextTokens))
        }

        return corpora
    }

    private func matchingCandidates(
        matching suffix: [String],
        order: Int,
        corpus: DocLocalNGramCorpus,
        maxVisibleWords: Int
    ) -> [DocLocalNGramCandidate] {
        guard corpus.tokens.count > order else {
            return []
        }

        let minimumContinuationWords = min(3, maxVisibleWords)
        let maximumStart = corpus.tokens.count - order - 1
        guard maximumStart >= 0 else {
            return []
        }

        var candidates: [DocLocalNGramCandidate] = []
        for start in 0...maximumStart {
            let matched = corpus.tokens[start..<(start + order)].map(\.normalized)
            guard matched == suffix else {
                continue
            }

            let continuationTokens = continuationTokens(
                in: corpus.tokens,
                after: start + order,
                maxVisibleWords: maxVisibleWords
            )
            guard continuationTokens.count >= minimumContinuationWords,
                  let firstContinuation = continuationTokens.first,
                  firstContinuation.normalized != suffix.last else {
                continue
            }

            let continuation = continuationTokens.map(\.display).joined(separator: " ")
            guard Self.isUsefulContinuation(continuationTokens) else {
                continue
            }

            candidates.append(DocLocalNGramCandidate(
                continuation: continuation,
                source: corpus.source,
                order: order,
                continuationWordCount: continuationTokens.count,
                startIndex: start,
                corpusTokenCount: corpus.tokens.count
            ))
        }

        return candidates
    }

    private func continuationTokens(
        in tokens: [DocLocalNGramToken],
        after start: Int,
        maxVisibleWords: Int
    ) -> [DocLocalNGramToken] {
        guard start < tokens.count else {
            return []
        }

        let line = tokens[start].lineIndex
        var continuation: [DocLocalNGramToken] = []
        for token in tokens[start...] {
            guard token.lineIndex == line else {
                break
            }
            continuation.append(token)
            if continuation.count >= maxVisibleWords {
                break
            }
        }
        return continuation
    }

    private func isBetterCandidate(
        _ lhs: DocLocalNGramCandidate,
        _ rhs: DocLocalNGramCandidate
    ) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order > rhs.order
        }
        if lhs.source != rhs.source {
            return lhs.source.rank < rhs.source.rank
        }
        if abs(lhs.score - rhs.score) > 0.0001 {
            return lhs.score > rhs.score
        }
        if lhs.startIndex != rhs.startIndex {
            return lhs.startIndex > rhs.startIndex
        }
        return lhs.continuation.count < rhs.continuation.count
    }

    private func noSuggestion(_ reason: String) -> CommonPhraseContinuationSelection {
        CommonPhraseContinuationSelection(
            suggestion: nil,
            matchedContextSuffix: nil,
            score: nil,
            suppressionReason: reason,
            candidateSelectionSource: "doc-local-ngram",
            matchMetadataKey: "docLocalNGramMatch"
        )
    }

    private func allowsPrediction(
        for behaviorProfileID: AutocompleteBehaviorProfileID?,
        allowsPromptAppPrediction: Bool
    ) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat):
            return allowsPromptAppPrediction
        case .some(.docsProse), .some(.notes), .some(.bullets), .none:
            return true
        case .some:
            return false
        }
    }

    private static func isUsefulContinuation(_ tokens: [DocLocalNGramToken]) -> Bool {
        let contentWords = tokens.filter { !stopWords.contains($0.normalized) }
        guard contentWords.count >= 2 else {
            return false
        }
        return tokens.allSatisfy { $0.display.count <= 48 }
    }

    private static func tokens(in text: String, source: DocLocalNGramSource) -> [DocLocalNGramToken] {
        var tokens: [DocLocalNGramToken] = []
        let lines = text.components(separatedBy: .newlines)
        for (lineIndex, rawLine) in lines.enumerated() {
            var current = ""
            func flush() {
                guard !current.isEmpty else {
                    return
                }
                tokens.append(DocLocalNGramToken(
                    display: current,
                    normalized: normalizedWord(current),
                    lineIndex: lineIndex,
                    source: source
                ))
                current = ""
            }

            for character in rawLine {
                if character.isLetter || character.isNumber {
                    current.append(character)
                } else {
                    flush()
                }
            }
            flush()
        }
        return tokens.filter { !$0.normalized.isEmpty }
    }

    private static func normalizedWord(_ word: String) -> String {
        let latin = word.applyingTransform(.toLatin, reverse: false) ?? word
        return latin
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
        "if", "in", "is", "it", "of", "on", "or", "that", "the", "this",
        "to", "we", "with"
    ]
}

private enum DocLocalNGramSource: String, Equatable, Sendable {
    case beforeCursor = "before-cursor"
    case localContext = "local-context"
    case spokenTranscript = "spoken-transcript"

    /// Precedence when two candidates tie on match length. Typed text the user
    /// can already see ranks above remembered local context, which ranks above
    /// the opt-in recent spoken corpus.
    var rank: Int {
        switch self {
        case .beforeCursor: return 0
        case .localContext: return 1
        case .spokenTranscript: return 2
        }
    }
}

private struct DocLocalNGramToken: Equatable, Sendable {
    let display: String
    let normalized: String
    let lineIndex: Int
    let source: DocLocalNGramSource
}

private struct DocLocalNGramCorpus: Equatable, Sendable {
    let source: DocLocalNGramSource
    let tokens: [DocLocalNGramToken]
}

private struct DocLocalNGramCandidate: Equatable, Sendable {
    let continuation: String
    let source: DocLocalNGramSource
    let order: Int
    let continuationWordCount: Int
    let startIndex: Int
    let corpusTokenCount: Int

    var score: Double {
        let orderScore = Double(order) * 0.08
        let lengthScore = min(0.12, Double(continuationWordCount) * 0.025)
        let recencyScore = corpusTokenCount > 0
            ? min(0.08, Double(startIndex) / Double(corpusTokenCount) * 0.08)
            : 0
        let sourceScore: Double
        switch source {
        case .beforeCursor: sourceScore = 0.05
        case .spokenTranscript: sourceScore = 0.03
        case .localContext: sourceScore = 0.02
        }
        return 0.45 + orderScore + lengthScore + recencyScore + sourceScore
    }
}
