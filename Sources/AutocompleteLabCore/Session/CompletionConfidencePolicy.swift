import Foundation

public enum CompletionConfidenceBucket: String, Equatable, Sendable {
    case high
    case medium
    case low
}

public struct CompletionConfidenceDecision: Equatable, Sendable {
    public let bucket: CompletionConfidenceBucket
    public let score: Int
    public let reasons: [String]

    public init(bucket: CompletionConfidenceBucket, score: Int, reasons: [String]) {
        self.bucket = bucket
        self.score = max(0, min(100, score))
        self.reasons = reasons
    }

    public var canDisplay: Bool {
        bucket != .low
    }
}

public struct CompletionConfidencePolicy: Equatable, Sendable {
    public let lowConfidenceThreshold: Int
    public let maximumDisplayLatencyMilliseconds: Int

    public init(
        lowConfidenceThreshold: Int = 60,
        maximumDisplayLatencyMilliseconds: Int = 2_000
    ) {
        self.lowConfidenceThreshold = max(0, min(100, lowConfidenceThreshold))
        self.maximumDisplayLatencyMilliseconds = max(1, maximumDisplayLatencyMilliseconds)
    }

    public func decision(
        suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        textBeforeCursor: String,
        latencyMilliseconds: Int,
        supportLevel: CompatibilitySupportLevel
    ) -> CompletionConfidenceDecision {
        var score = 100
        var reasons: [String] = []

        switch supportLevel {
        case .green:
            break
        case .yellow:
            score -= 12
            reasons.append("yellow-app-profile")
        case .diagnosticsOnly, .unsupported:
            score -= 100
            reasons.append("unsupported-app-profile")
        }

        if latencyMilliseconds > 1_000 {
            score -= 25
            reasons.append("slow-over-1000ms")
        } else if latencyMilliseconds > 500 {
            score -= 10
            reasons.append("slow-over-500ms")
        }

        let displayLatencyBudget = displayLatencyBudgetMilliseconds(
            suggestion: suggestion,
            mode: mode
        )
        if latencyMilliseconds > displayLatencyBudget {
            score -= 100
            reasons.append("too-slow-to-display")
        }

        if mode == .phraseContinuation {
            let wordCount = suggestion.visibleWordCount
            if suggestion.maxVisibleWords >= 5,
               wordCount < CompletionModelPolicy.preferredMinimumVisibleWords(
                   forVisibleWords: suggestion.maxVisibleWords
               ) {
                // A short-but-correct continuation beats an empty slot; nudge the
                // score instead of vetoing the suggestion outright.
                score -= 25
                reasons.append("too-short-daily-driver-phrase")
            }

            if suggestion.maxVisibleWords >= 8 {
                if wordCount > suggestion.maxVisibleWords {
                    score -= 45
                    reasons.append("too-many-visible-words")
                }
            } else if wordCount > 5 {
                score -= 45
                reasons.append("too-many-visible-words")
            } else if wordCount > 4 {
                score -= 35
                reasons.append("long-visible-suggestion")
            }

            let contextWords = textBeforeCursor
                .split(whereSeparator: { $0.isWhitespace })
                .count
            // Thin context lowers confidence but must not sink an otherwise clean
            // suggestion below the display threshold on its own: most real typing
            // starts from one or two words, and the old -55 made short replies
            // effectively suggestion-free.
            if contextWords < 2 {
                score -= 25
                reasons.append("thin-context")
            } else if contextWords < 4 {
                score -= 10
                reasons.append("thin-context")
            }
        }

        if looksGenericOrAssistantLike(suggestion.visibleText) {
            score -= 35
            reasons.append("generic-or-assistant-like")
        }

        let bucket: CompletionConfidenceBucket
        if score < lowConfidenceThreshold {
            bucket = .low
        } else if score < 80 {
            bucket = .medium
        } else {
            bucket = .high
        }

        return CompletionConfidenceDecision(bucket: bucket, score: score, reasons: reasons)
    }

    private func displayLatencyBudgetMilliseconds(
        suggestion: CompletionSuggestion,
        mode: CompletionRequestMode
    ) -> Int {
        guard mode == .phraseContinuation,
              suggestion.maxVisibleWords >= 8,
              suggestion.visibleWordCount >= CompletionModelPolicy.preferredMinimumVisibleWords(
                forVisibleWords: suggestion.maxVisibleWords
              )
        else {
            return maximumDisplayLatencyMilliseconds
        }

        return max(maximumDisplayLatencyMilliseconds, 1_000)
    }

    private func looksGenericOrAssistantLike(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return [
            "let me know",
            "i can help",
            "here is",
            "here are",
            "you should",
            "you can",
            "you could",
            "it's important",
            "it is important",
            "as an ai"
        ].contains { normalized.hasPrefix($0) }
    }
}
