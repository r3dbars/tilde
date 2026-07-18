import Foundation

/// A small shared accumulator for annoyance, repetition, and eagerness signals.
///
/// The bucket stores only an aggregate score and its last update time. Callers choose
/// the half-life so the same decay semantics can be reused without sharing policy
/// thresholds or any user text.
public struct DecayingScoreBucket: Equatable, Sendable {
    public let score: Double
    public let updatedAt: Date?

    public init(score: Double = 0, updatedAt: Date? = nil) {
        self.score = max(0, score)
        self.updatedAt = updatedAt
    }

    public func decayedScore(
        at now: Date,
        halfLifeSeconds: TimeInterval
    ) -> Double {
        guard let updatedAt, halfLifeSeconds > 0 else {
            return score
        }

        let elapsedSeconds = max(0, now.timeIntervalSince(updatedAt))
        return score * pow(0.5, elapsedSeconds / halfLifeSeconds)
    }

    public func adding(
        _ delta: Double,
        multiplier: Double = 1,
        at now: Date,
        halfLifeSeconds: TimeInterval
    ) -> DecayingScoreBucket {
        DecayingScoreBucket(
            score: decayedScore(at: now, halfLifeSeconds: halfLifeSeconds) + delta * multiplier,
            updatedAt: now
        )
    }
}
