import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Decaying score bucket")
struct DecayingScoreBucketTests {
    @Test("Decays by half at the configured half life")
    func decaysByHalfAtConfiguredHalfLife() {
        let start = Date(timeIntervalSince1970: 1_000)
        let bucket = DecayingScoreBucket(score: 2, updatedAt: start)

        #expect(abs(bucket.decayedScore(at: start.addingTimeInterval(60), halfLifeSeconds: 60) - 1) < 0.0001)
    }

    @Test("Adding a signal decays the old score and records the new timestamp")
    func addingSignalDecaysOldScoreAndRecordsNewTimestamp() {
        let start = Date(timeIntervalSince1970: 1_000)
        let next = start.addingTimeInterval(60)
        let bucket = DecayingScoreBucket(score: 2, updatedAt: start)
            .adding(0.5, at: next, halfLifeSeconds: 60)

        #expect(abs(bucket.score - 1.5) < 0.0001)
        #expect(bucket.updatedAt == next)
    }

    @Test("Adding a negative signal clamps the score at zero")
    func addingNegativeSignalClampsAtZero() {
        let bucket = DecayingScoreBucket(score: 0.25)
            .adding(-1, at: Date(timeIntervalSince1970: 1), halfLifeSeconds: 60)

        #expect(bucket.score == 0)
    }
}
