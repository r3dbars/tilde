import Foundation

/// One streamed token piece paired with its emitted probability in `[0, 1]`
/// and optional text-free top-k distribution metrics (`n_probs >= 2`).
public struct StreamedTokenProbability: Codable, Equatable, Sendable {
    public let piece: String
    public let probability: Double
    /// Top-1 minus top-2 probability in `[0, 1]`, or `nil` when fewer than two
    /// alternatives were returned.
    public let top1Margin: Double?
    /// Local Shannon entropy (nats, `>= 0`) over the returned top-k
    /// distribution plus remainder mass, or `nil` when unavailable.
    public let entropy: Double?
    /// Runner-up ratio `p_2 / max(p_1, 1e-6)` in `[0, 1]` (0 = runaway winner,
    /// 1 = dead tie), or `nil` when fewer than two alternatives were returned.
    public let runnerUpRatio: Double?

    public init(
        piece: String,
        probability: Double,
        top1Margin: Double? = nil,
        entropy: Double? = nil,
        runnerUpRatio: Double? = nil
    ) {
        self.piece = piece
        self.probability = min(1.0, max(1e-6, probability))
        self.top1Margin = top1Margin.flatMap { $0.isFinite ? min(1.0, max(0.0, $0)) : nil }
        self.entropy = entropy.flatMap { $0.isFinite ? max(0.0, $0) : nil }
        self.runnerUpRatio = runnerUpRatio.flatMap { $0.isFinite ? min(1.0, max(0.0, $0)) : nil }
    }

    /// Computes strictly text-free distribution metrics from top-k alternative
    /// probabilities (`n_probs >= 2`). Returns `nil` (fail-open) when fewer
    /// than two valid probabilities are available.
    public static func distributionMetrics(
        fromAlternativeProbabilities alternatives: [Double]
    ) -> (top1Margin: Double, entropy: Double, runnerUpRatio: Double)? {
        let valid = alternatives.filter { $0.isFinite && (0.0...1.0).contains($0) }
        guard valid.count >= 2 else { return nil }
        let sorted = valid.sorted(by: >)
        let top1 = sorted[0]
        let top2 = sorted[1]
        let margin = min(1.0, max(0.0, top1 - top2))
        let ratio = min(1.0, max(0.0, top2 / max(top1, 1e-6)))
        let totalMass = sorted.reduce(0.0, +)
        let remainder = max(0.0, 1.0 - totalMass)
        var entropy = 0.0
        for p in sorted where p > 0 {
            entropy -= p * log(p)
        }
        if remainder > 0 {
            entropy -= remainder * log(remainder)
        }
        return (margin, max(0.0, entropy), ratio)
    }
}

/// Strictly text-free word-level probability and margin summary aligned to a
/// candidate suggestion.
public struct WordConfidenceProfile: Equatable, Sendable {
    public let firstWordProbability: Double
    public let firstWordMargin: Double?
    public let firstWordEntropy: Double?
    public let firstWordRunnerUpRatio: Double?
    public let secondWordProbability: Double?
    public let secondWordMargin: Double?
    public let secondWordEntropy: Double?
    public let meanWordProbability: Double
    public let minimumWordProbability: Double
    public let meanWordMargin: Double?
    public let meanWordEntropy: Double?
    public let alignedWordCount: Int

    public init(
        firstWordProbability: Double,
        firstWordMargin: Double? = nil,
        firstWordEntropy: Double? = nil,
        firstWordRunnerUpRatio: Double? = nil,
        secondWordProbability: Double? = nil,
        secondWordMargin: Double? = nil,
        secondWordEntropy: Double? = nil,
        meanWordProbability: Double,
        minimumWordProbability: Double? = nil,
        meanWordMargin: Double? = nil,
        meanWordEntropy: Double? = nil,
        alignedWordCount: Int
    ) {
        self.firstWordProbability = firstWordProbability
        self.firstWordMargin = firstWordMargin
        self.firstWordEntropy = firstWordEntropy
        self.firstWordRunnerUpRatio = firstWordRunnerUpRatio
        self.secondWordProbability = secondWordProbability
        self.secondWordMargin = secondWordMargin
        self.secondWordEntropy = secondWordEntropy
        self.meanWordProbability = meanWordProbability
        self.minimumWordProbability = minimumWordProbability ?? firstWordProbability
        self.meanWordMargin = meanWordMargin
        self.meanWordEntropy = meanWordEntropy
        self.alignedWordCount = alignedWordCount
    }
}

/// Smart confidence-aware whole-phrase length selector.
///
/// Uses per-word geometric-mean token probability (so multi-subword words aren't
/// unfairly penalized) and picks the prefix length `n*` maximizing expected net
/// saved characters:
///   `E_n = (prod_{i=1}^n q_i) * (C_n + clauseBonus) - lambda * (1 - prod_{i=1}^n q_i)`
/// where `q_i = p_i^(1 / T)`.
///
/// Any word collapsing below `earlyStopWordFloor` terminates the prefix before
/// that word regardless of its character length. Fails open cleanly when token
/// probabilities are unavailable or cannot be aligned.
public enum WordConfidenceTruncator {
    /// Calibrated on held-out personal writing under a verified Qwen-9B judge
    /// and judge-free exact-prefix scoring: `T=1.0` with `clauseBonus=2.0`
    /// stops phrases before tail drift, cutting rejects in half with zero
    /// retraining.
    public static let defaultTemperature = 1.0
    public static let defaultClauseBonus = 2.0
    public static let defaultRiskPenalty = 0.45
    public static let earlyStopWordFloor = 0.04
    /// First-word geometric-mean probability floor calibrated jointly across
    /// open-ended prose and Certified Corpus V2 Dev alongside the
    /// scene-invariant `SuggestionQuietGate` (`0.10 / 0.50`): prevents two
    /// stacked gates from silencing open-ended prose while still stopping
    /// genuinely collapsed first words before they flash.
    public static let defaultFirstWordFloor = 0.10

    struct WordConfidence: Equatable {
        let text: String
        let geometricMeanProbability: Double
        let firstTokenMargin: Double?
        let firstTokenEntropy: Double?
        let firstTokenRunnerUpRatio: Double?
    }

    /// Trims `suggestion` back to the optimal whole-phrase word boundary `n*`
    /// maximizing expected net saved characters, preventing shaky tail words
    /// from ruining an otherwise acceptable phrase.
    public static func trim(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        temperature: Double = defaultTemperature,
        riskPenalty: Double = defaultRiskPenalty,
        wordFloor: Double = earlyStopWordFloor,
        clauseBonus: Double = defaultClauseBonus
    ) -> CompletionSuggestion {
        let visibleWords = CompletionContextWords.wordRanges(in: suggestion.visibleText)
        guard visibleWords.count >= 2, !tokens.isEmpty else { return suggestion }

        let tokenWords = wordConfidences(from: tokens)
        guard tokenWords.count >= 2 else { return suggestion }

        // Align visible words against emitted token words (strictly; fail open
        // rather than shifting mismatched probabilities across words).
        let aligned = align(visibleWords: visibleWords, in: suggestion.visibleText, to: tokenWords)
        guard aligned.count == visibleWords.count else { return suggestion }

        let safeTemp = max(0.5, temperature)
        var bestCount = 1
        var bestUtility = -Double.greatestFiniteMagnitude
        var cumulativeConfidence = 1.0
        var cumulativeChars = 0

        for (index, word) in aligned.enumerated() {
            let n = index + 1
            // Never retain a collapsed tail word even if it is long.
            if n >= 2, word.geometricMeanProbability < wordFloor {
                break
            }
            let visibleWord = String(suggestion.visibleText[visibleWords[index]])
            let calibrated = min(0.99, max(0.05, pow(word.geometricMeanProbability, 1.0 / safeTemp)))
            cumulativeConfidence *= calibrated
            cumulativeChars += visibleWord.count + (n > 1 ? 1 : 0)
            let appliedClauseBonus: Double = visibleWord.last.map { ".!?,".contains($0) } == true ? clauseBonus : 0.0
            let expectedSaved = max(1.0, Double(cumulativeChars)) + appliedClauseBonus
            let utility = cumulativeConfidence * expectedSaved - riskPenalty * (1.0 - cumulativeConfidence)
            if utility > bestUtility {
                bestUtility = utility
                bestCount = n
            }
            if visibleWord.last.map({ ".!?".contains($0) }) == true, n >= 2 {
                break
            }
        }

        guard bestCount < visibleWords.count else { return suggestion }
        let prefix = CompletionSuggestion.acceptedPrefix(
            in: suggestion.visibleText,
            wordLimit: bestCount
        )
        let repaired = RawContinuationPrompt.repairDanglingTail(prefix)
        let finalText = repaired.trimmingCharacters(in: .whitespaces).isEmpty ? prefix : repaired
        guard !finalText.trimmingCharacters(in: .whitespaces).isEmpty else { return suggestion }
        return CompletionSuggestion(
            text: finalText,
            maxVisibleWords: bestCount,
            repairsDanglingTail: true
        )
    }

    /// Trims `suggestion` only before any tail word (word 2+) whose probability
    /// truly collapsed below `wordFloor` (default `0.04`). Safe for streaming
    /// partials: never cuts normal connector words like "to" or "the" while
    /// preventing garbage tail words from ever flashing on screen.
    public static func trimCollapsedTail(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        wordFloor: Double = earlyStopWordFloor
    ) -> (suggestion: CompletionSuggestion, collapsed: Bool) {
        let visibleWords = CompletionContextWords.wordRanges(in: suggestion.visibleText)
        guard visibleWords.count >= 2, !tokens.isEmpty else { return (suggestion, false) }
        let tokenWords = wordConfidences(from: tokens)
        guard tokenWords.count >= 2 else { return (suggestion, false) }
        let aligned = align(visibleWords: visibleWords, in: suggestion.visibleText, to: tokenWords)
        guard aligned.count == visibleWords.count else { return (suggestion, false) }

        for index in 1..<aligned.count where aligned[index].geometricMeanProbability < wordFloor {
            let prefix = CompletionSuggestion.acceptedPrefix(
                in: suggestion.visibleText,
                wordLimit: index
            )
            let repaired = RawContinuationPrompt.repairDanglingTail(prefix)
            let finalText = repaired.trimmingCharacters(in: .whitespaces).isEmpty ? prefix : repaired
            guard !finalText.trimmingCharacters(in: .whitespaces).isEmpty else {
                return (suggestion, true)
            }
            return (
                CompletionSuggestion(
                    text: finalText,
                    maxVisibleWords: index,
                    repairsDanglingTail: true
                ),
                true
            )
        }
        return (suggestion, false)
    }

    /// Strictly aligned word-level confidence profile for `suggestion`,
    /// capturing word 1 and word 2 probabilities alongside first-token margin,
    /// entropy, and runner-up ratio. Returns `nil` (fail-open) when tokens are
    /// missing, unaligned, or the first visible word has no alphanumeric chars.
    public static func confidenceProfile(
        for suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability]
    ) -> WordConfidenceProfile? {
        guard !tokens.isEmpty else { return nil }
        let visibleWords = CompletionContextWords.wordRanges(in: suggestion.visibleText)
        guard !visibleWords.isEmpty else { return nil }
        let firstNormalized = CompletionContextWords.normalized(
            String(suggestion.visibleText[visibleWords[0]])
        )
        guard !firstNormalized.isEmpty else { return nil }
        let tokenWords = wordConfidences(from: tokens)
        guard !tokenWords.isEmpty else { return nil }
        let aligned = align(visibleWords: visibleWords, in: suggestion.visibleText, to: tokenWords)
        guard let first = aligned.first else { return nil }
        let second = aligned.count >= 2 ? aligned[1] : nil
        let meanWordProb = aligned.reduce(0.0) { $0 + $1.geometricMeanProbability } / Double(aligned.count)
        let minWordProb = aligned.map(\.geometricMeanProbability).min() ?? first.geometricMeanProbability
        let margins = aligned.compactMap(\.firstTokenMargin)
        let entropies = aligned.compactMap(\.firstTokenEntropy)
        let meanMargin = margins.isEmpty ? nil : margins.reduce(0.0, +) / Double(margins.count)
        let meanEntropy = entropies.isEmpty ? nil : entropies.reduce(0.0, +) / Double(entropies.count)
        return WordConfidenceProfile(
            firstWordProbability: first.geometricMeanProbability,
            firstWordMargin: first.firstTokenMargin,
            firstWordEntropy: first.firstTokenEntropy,
            firstWordRunnerUpRatio: first.firstTokenRunnerUpRatio,
            secondWordProbability: second?.geometricMeanProbability,
            secondWordMargin: second?.firstTokenMargin,
            secondWordEntropy: second?.firstTokenEntropy,
            meanWordProbability: meanWordProb,
            minimumWordProbability: minWordProb,
            meanWordMargin: meanMargin,
            meanWordEntropy: meanEntropy,
            alignedWordCount: aligned.count
        )
    }

    /// Geometric-mean probability of the first visible word of `suggestion`,
    /// aligned strictly against `tokens`. Returns `nil` (fail-open) when
    /// probabilities are missing, unaligned, or the first visible token has no
    /// alphanumeric characters.
    public static func firstWordConfidence(
        for suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability]
    ) -> Double? {
        confidenceProfile(for: suggestion, tokens: tokens)?.firstWordProbability
    }

    /// Returns `true` when `minimumProbability > 0` and the first visible word
    /// is aligned with a geometric-mean probability strictly below the floor.
    /// Always returns `false` (fail-open) when `tokens.isEmpty` or unaligned.
    public static func isFirstWordBelowFloor(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        minimumProbability: Double
    ) -> Bool {
        guard minimumProbability > 0,
              let confidence = firstWordConfidence(for: suggestion, tokens: tokens) else {
            return false
        }
        return confidence < minimumProbability
    }

    /// Returns `true` when streaming has already emitted at least one word and
    /// a subsequent completed word collapsed below `minimumWordProbability`,
    /// signaling the caller can stop paying for tail tokens early.
    public static func shouldStopStreamingEarly(
        tokens: [StreamedTokenProbability],
        minimumWordProbability: Double = earlyStopWordFloor
    ) -> Bool {
        let words = wordConfidences(from: tokens)
        guard words.count >= 3 else { return false }
        for word in words.dropFirst().dropLast() {
            if word.geometricMeanProbability < minimumWordProbability {
                return true
            }
        }
        return false
    }

    /// Groups streamed token probabilities into word-level geometric means.
    /// Properly splits internal/trailing whitespace (e.g. speculative multi-token
    /// frames) and preserves text preceding `\n` / `\r`.
    static func wordConfidences(from tokens: [StreamedTokenProbability]) -> [WordConfidence] {
        var result: [WordConfidence] = []
        var currentText = ""
        var currentLogProbs: [Double] = []
        var currentFirstMargin: Double?
        var currentFirstEntropy: Double?
        var currentFirstRunnerUpRatio: Double?

        func flushCurrent() {
            guard !currentText.isEmpty, !currentLogProbs.isEmpty else { return }
            let gm = exp(currentLogProbs.reduce(0, +) / Double(currentLogProbs.count))
            result.append(WordConfidence(
                text: currentText,
                geometricMeanProbability: gm,
                firstTokenMargin: currentFirstMargin,
                firstTokenEntropy: currentFirstEntropy,
                firstTokenRunnerUpRatio: currentFirstRunnerUpRatio
            ))
            currentText = ""
            currentLogProbs = []
            currentFirstMargin = nil
            currentFirstEntropy = nil
            currentFirstRunnerUpRatio = nil
        }

        func appendSegment(_ segment: String, logP: Double, token: StreamedTokenProbability) {
            if currentText.isEmpty {
                currentFirstMargin = token.top1Margin
                currentFirstEntropy = token.entropy
                currentFirstRunnerUpRatio = token.runnerUpRatio
            }
            currentText += segment
            currentLogProbs.append(logP)
        }

        for token in tokens {
            let logP = log(token.probability)
            var hitNewline = false
            var segment = ""
            for ch in token.piece {
                if ch == "\n" || ch == "\r" {
                    hitNewline = true
                    break
                }
                if ch.isWhitespace {
                    if !segment.isEmpty {
                        appendSegment(segment, logP: logP, token: token)
                        segment = ""
                    }
                    flushCurrent()
                } else {
                    segment.append(ch)
                }
            }
            if !segment.isEmpty {
                appendSegment(segment, logP: logP, token: token)
            }
            if hitNewline {
                flushCurrent()
                break
            }
        }
        flushCurrent()
        return result
    }

    private static func align(
        visibleWords: [Range<String.Index>],
        in text: String,
        to tokenWords: [WordConfidence]
    ) -> [WordConfidence] {
        let targetNormalized = visibleWords.map {
            CompletionContextWords.normalized(String(text[$0]))
        }
        guard !targetNormalized.isEmpty, tokenWords.count >= targetNormalized.count else { return [] }
        let tokenNormalized = tokenWords.map { CompletionContextWords.normalized($0.text) }
        let maxStart = tokenNormalized.count - targetNormalized.count

        // 1. Exact subsequence match (handles trimmed leading echoes cleanly).
        for start in 0...maxStart {
            if Array(tokenNormalized[start..<(start + targetNormalized.count)]) == targetNormalized {
                return Array(tokenWords[start..<(start + targetNormalized.count)])
            }
        }
        // 2. Mid-word suffix match on word 0 (e.g. token "writing" -> visible "ting")
        //    with exact matches for all remaining words. Guard non-empty word 0 so
        //    punctuation-only tokens cannot trivially match `hasSuffix("")`.
        if !targetNormalized[0].isEmpty {
            let tailTarget = Array(targetNormalized.dropFirst())
            for start in 0...maxStart {
                if tokenNormalized[start].hasSuffix(targetNormalized[0]),
                   Array(tokenNormalized[(start + 1)..<(start + targetNormalized.count)]) == tailTarget {
                    return Array(tokenWords[start..<(start + targetNormalized.count)])
                }
            }
        }
        // Fail open when unaligned rather than attaching shifted probabilities.
        return []
    }
}
