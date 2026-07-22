import Foundation

/// The single decision surface for a candidate that might reach the user.
///
/// Confidence, scored utility, latency, and command fallback remain individually
/// testable, but the app asks this policy for the final good-and-fast-enough
/// answer. This keeps the safety rules in core while native code owns only the
/// presentation and placement plumbing.
public struct GoodAndFastEnoughDecision: Equatable, Sendable {
    public let decision: DisplayScoreDecision
    public let confidence: CompletionConfidenceDecision
    public let latencyBudgetMilliseconds: Int
    public let measuredLatencyMilliseconds: Int
    public let metadata: [String: String]

    public init(
        decision: DisplayScoreDecision,
        confidence: CompletionConfidenceDecision,
        latencyBudgetMilliseconds: Int,
        measuredLatencyMilliseconds: Int,
        metadata: [String: String]
    ) {
        self.decision = decision
        self.confidence = confidence
        self.latencyBudgetMilliseconds = max(1, latencyBudgetMilliseconds)
        self.measuredLatencyMilliseconds = max(0, measuredLatencyMilliseconds)
        self.metadata = metadata
    }

    public var shouldDisplay: Bool {
        decision.shouldDisplay
    }
}

public struct GoodAndFastEnoughPolicy: Equatable, Sendable {
    /// Owned as a private implementation detail: nothing outside this policy
    /// constructs a custom confidence scorer, so the thresholds that used to be
    /// a separate public policy type live here instead of being threaded
    /// through a second public initializer parameter.
    private let completionConfidencePolicy = CompletionConfidencePolicy()
    public let commandFallbackPolicy: CommandFallbackPolicy

    public var maximumDisplayLatencyMilliseconds: Int {
        completionConfidencePolicy.maximumDisplayLatencyMilliseconds
    }

    public init(
        commandFallbackPolicy: CommandFallbackPolicy = CommandFallbackPolicy()
    ) {
        self.commandFallbackPolicy = commandFallbackPolicy
    }

    public func decision(
        suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        textBeforeCursor: String,
        supportLevel: CompatibilitySupportLevel,
        score: DisplayScore,
        displayScorePolicy: DisplayScorePolicy,
        latencyMilliseconds: Int,
        latencyBudgetMilliseconds: Int? = nil,
        latencyForBudgetMilliseconds: Int? = nil,
        enforceLatencyCeiling: Bool = true,
        allowLatencyBypass: Bool = false,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> GoodAndFastEnoughDecision {
        let budget = max(1, latencyBudgetMilliseconds ?? maximumDisplayLatencyMilliseconds)
        let measuredLatency = max(0, latencyForBudgetMilliseconds ?? latencyMilliseconds)
        let confidence = completionConfidencePolicy.decision(
            suggestion: suggestion,
            mode: mode,
            textBeforeCursor: textBeforeCursor,
            latencyMilliseconds: latencyMilliseconds,
            supportLevel: supportLevel
        )
        let scoredDecision = displayScorePolicy.decision(
            for: score,
            mode: mode,
            behaviorProfileID: behaviorProfileID
        )

        var metadata = scoredDecision.metadata
        metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
        metadata["completionConfidenceScore"] = String(confidence.score)
        metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
        metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
        metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)

        if enforceLatencyCeiling,
           !allowLatencyBypass,
           measuredLatency > budget {
            let suppression = DisplayScoreSuppression(
                reason: .tooSlowToDisplay,
                trace: scoredDecision.trace
            )
            metadata = suppression.metadata
            metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
            metadata["completionConfidenceScore"] = String(confidence.score)
            metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
            metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
            metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)
            return GoodAndFastEnoughDecision(
                decision: .suppress(suppression),
                confidence: confidence,
                latencyBudgetMilliseconds: budget,
                measuredLatencyMilliseconds: measuredLatency,
                metadata: metadata
            )
        }

        let suppressLowConfidence = !confidence.canDisplay
            && (!allowLatencyBypass || !confidence.reasons.contains("late-context-validation-required"))
        if suppressLowConfidence {
            let suppression = DisplayScoreSuppression(
                reason: .lowConfidence,
                trace: scoredDecision.trace
            )
            metadata = suppression.metadata
            metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
            metadata["completionConfidenceScore"] = String(confidence.score)
            metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
            metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
            metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)
            return GoodAndFastEnoughDecision(
                decision: .suppress(suppression),
                confidence: confidence,
                latencyBudgetMilliseconds: budget,
                measuredLatencyMilliseconds: measuredLatency,
                metadata: metadata
            )
        }

        return GoodAndFastEnoughDecision(
            decision: scoredDecision,
            confidence: confidence,
            latencyBudgetMilliseconds: budget,
            measuredLatencyMilliseconds: measuredLatency,
            metadata: metadata
        )
    }

    public func fallbackDecision(
        supportStatus: CompatibilitySupportStatus,
        isEnabled: Bool,
        fieldKind: AXFieldKind? = nil,
        allowsLowConfidencePlacement: Bool? = nil,
        hasCurrentApp: Bool = true
    ) -> CommandFallbackDecision {
        commandFallbackPolicy.decision(
            supportStatus: supportStatus,
            isEnabled: isEnabled,
            fieldKind: fieldKind,
            allowsLowConfidencePlacement: allowsLowConfidencePlacement,
            hasCurrentApp: hasCurrentApp
        )
    }
}

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

/// The confidence scorer behind `GoodAndFastEnoughPolicy`. This used to be a
/// standalone public policy type; nothing outside `GoodAndFastEnoughPolicy`
/// ever constructed one with non-default thresholds, so it is now a plain
/// internal component instead of a second public gate with its own API.
struct CompletionConfidencePolicy: Equatable, Sendable {
    let lowConfidenceThreshold: Int
    let maximumDisplayLatencyMilliseconds: Int

    init(
        lowConfidenceThreshold: Int = 60,
        maximumDisplayLatencyMilliseconds: Int = 2_000
    ) {
        self.lowConfidenceThreshold = max(0, min(100, lowConfidenceThreshold))
        self.maximumDisplayLatencyMilliseconds = max(1, maximumDisplayLatencyMilliseconds)
    }

    func decision(
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

        if latencyMilliseconds > maximumDisplayLatencyMilliseconds {
            reasons.append("late-context-validation-required")
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
