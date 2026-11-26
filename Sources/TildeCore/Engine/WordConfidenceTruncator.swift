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
/// Fails open cleanly when token probabilities are unavailable (returning the
/// input suggestion untouched).
public enum WordConfidenceTruncator {
    public static let defaultTemperature = 2.5
    public static let defaultRiskPenalty = 1.2
    public static let earlyStopWordFloor = 0.06

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
        riskPenalty: Double = defaultRiskPenalty
    ) -> CompletionSuggestion {
        let visibleWords = CompletionContextWords.wordRanges(in: suggestion.visibleText)
        guard visibleWords.count >= 2, !tokens.isEmpty else { return suggestion }

        let tokenWords = wordConfidences(from: tokens)
        guard tokenWords.count >= 2 else { return suggestion }

        // Align visible words against emitted token words (skipping any trimmed leading echo).
        let aligned = align(visibleWords: visibleWords, in: suggestion.visibleText, to: tokenWords)
        guard aligned.count == visibleWords.count else { return suggestion }

        let safeTemp = max(0.5, temperature)
        var bestCount = 1
        var bestUtility = -Double.greatestFiniteMagnitude
        var cumulativeConfidence = 1.0
        var cumulativeChars = 0

        for (index, word) in aligned.enumerated() {
            let n = index + 1
            let calibrated = min(0.99, max(0.05, pow(word.geometricMeanProbability, 1.0 / safeTemp)))
            cumulativeConfidence *= calibrated
            cumulativeChars += word.text.count + (n > 1 ? 1 : 0)
            let clauseBonus: Double = word.text.last.map { ".!?,".contains($0) } == true ? 2.0 : 0.0
            let expectedSaved = max(0.0, Double(cumulativeChars - 1)) + clauseBonus
            let utility = cumulativeConfidence * expectedSaved - riskPenalty * (1.0 - cumulativeConfidence)
            if utility > bestUtility {
                bestUtility = utility
                bestCount = n
            }
            if word.text.last.map({ ".!?".contains($0) }) == true, n >= 2 {
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

    /// Returns `true` when streaming has already emitted at least one word and
    /// a subsequent complete word collapsed below `minimumWordProbability`,
    /// signaling the caller can stop paying for tail tokens early.
    public static func shouldStopStreamingEarly(
        tokens: [StreamedTokenProbability],
        minimumWordProbability: Double = earlyStopWordFloor
    ) -> Bool {
        let words = wordConfidences(from: tokens)
        // Require at least 2 completed words plus a following boundary so the
        // word being judged is finished (not mid-subword).
        guard words.count >= 3 else { return false }
        for word in words.dropFirst().dropLast() {
            if word.geometricMeanProbability < minimumWordProbability {
                return true
            }
        }
        return false
    }

    static func wordConfidences(from tokens: [StreamedTokenProbability]) -> [WordConfidence] {
        var result: [WordConfidence] = []
        var currentText = ""
        var currentLogProbs: [Double] = []
        var started = false

        for token in tokens {
            if token.piece.contains("\n") || token.piece.contains("\r") { break }
            let trimmed = token.piece.trimmingCharacters(in: .whitespaces)
            if !started {
                guard !trimmed.isEmpty else { continue }
                started = true
            }
            let startsWithWhitespace = token.piece.first?.isWhitespace == true
            if !currentText.isEmpty, startsWithWhitespace {
                let gm = exp(currentLogProbs.reduce(0, +) / Double(currentLogProbs.count))
                result.append(WordConfidence(text: currentText, geometricMeanProbability: gm))
                currentText = String(token.piece.drop(while: \.isWhitespace))
                currentLogProbs = currentText.isEmpty ? [] : [log(token.probability)]
            } else {
                let piece = currentText.isEmpty
                    ? String(token.piece.drop(while: \.isWhitespace))
                    : token.piece
                if !piece.isEmpty {
                    currentText += piece
                    currentLogProbs.append(log(token.probability))
                }
            }
        }
        if !currentText.isEmpty, !currentLogProbs.isEmpty {
            let gm = exp(currentLogProbs.reduce(0, +) / Double(currentLogProbs.count))
            result.append(WordConfidence(text: currentText, geometricMeanProbability: gm))
        }
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
        guard !targetNormalized.isEmpty else { return [] }
        let tokenNormalized = tokenWords.map { CompletionContextWords.normalized($0.text) }

        // Find the first subsequence match (handles trimmed leading echoes cleanly).
        if tokenNormalized.count >= targetNormalized.count {
            let maxStart = tokenNormalized.count - targetNormalized.count
            for start in 0...maxStart {
                let slice = Array(tokenNormalized[start..<(start + targetNormalized.count)])
                if slice == targetNormalized {
                    return Array(tokenWords[start..<(start + targetNormalized.count)])
                }
            }
        }
        // Fallback: align from the start when prefix-trimming altered only word 1's prefix.
        if tokenWords.count >= visibleWords.count {
            return Array(tokenWords.prefix(visibleWords.count))
        }
        return []
    }
}
