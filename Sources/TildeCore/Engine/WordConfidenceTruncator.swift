import Foundation

/// One streamed token piece paired with its emitted probability in `[0, 1]`.
public struct StreamedTokenProbability: Equatable, Sendable {
    public let piece: String
    public let probability: Double

    public init(piece: String, probability: Double) {
        self.piece = piece
        self.probability = min(1.0, max(1e-6, probability))
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
    public static let defaultTemperature = 3.8
    public static let defaultRiskPenalty = 0.45
    public static let earlyStopWordFloor = 0.04
    /// First-word geometric-mean probability gate calibrated on held-out
    /// personal writing: suppresses low-confidence guesses before they flash,
    /// lifting precision-when-shown while keeping healthy coverage.
    public static let defaultFirstWordFloor = 0.18

    struct WordConfidence: Equatable {
        let text: String
        let geometricMeanProbability: Double
    }

    /// Trims `suggestion` back to the optimal whole-phrase word boundary `n*`
    /// maximizing expected net saved characters, preventing shaky tail words
    /// from ruining an otherwise acceptable phrase.
    public static func trim(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        temperature: Double = defaultTemperature,
        riskPenalty: Double = defaultRiskPenalty,
        wordFloor: Double = earlyStopWordFloor
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
            let clauseBonus: Double = visibleWord.last.map { ".!?,".contains($0) } == true ? 4.0 : 0.0
            let expectedSaved = max(1.0, Double(cumulativeChars)) + clauseBonus
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

    /// Geometric-mean probability of the first visible word of `suggestion`,
    /// aligned strictly against `tokens`. Returns `nil` (fail-open) when
    /// probabilities are missing, unaligned, or the first visible token has no
    /// alphanumeric characters.
    public static func firstWordConfidence(
        for suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability]
    ) -> Double? {
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
        return aligned.first?.geometricMeanProbability
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

        func flushCurrent() {
            guard !currentText.isEmpty, !currentLogProbs.isEmpty else { return }
            let gm = exp(currentLogProbs.reduce(0, +) / Double(currentLogProbs.count))
            result.append(WordConfidence(text: currentText, geometricMeanProbability: gm))
            currentText = ""
            currentLogProbs = []
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
                        currentText += segment
                        currentLogProbs.append(logP)
                        segment = ""
                    }
                    flushCurrent()
                } else {
                    segment.append(ch)
                }
            }
            if !segment.isEmpty {
                currentText += segment
                currentLogProbs.append(logP)
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
