import Foundation

/// Aggregate-safe diagnosis for one replay boundary. It deliberately carries
/// no context, target, or candidate text, so callers can count these outcomes
/// without turning Personal History into telemetry.
public struct PsychicReplayScore: Equatable, Sendable {
    public enum Gap: String, Equatable, Sendable {
        /// The selected first candidate matched the user's natural continuation.
        case hit
        /// A hidden candidate matched, but the selected candidate did not.
        case ranking
        /// None of the generated candidates matched. Improve context/generation.
        case generation
        /// No candidate was generated at all.
        case silence
    }

    public let gap: Gap
    public let oracleRank: Int?
    public let candidateCount: Int

    public var oracleHit: Bool { oracleRank != nil }
    public var topOneHit: Bool { oracleRank == 1 }
}

/// Grades a candidate set against unassisted replay truth. "Oracle@K" asks a
/// crucial question before tuning the ranker: did Tilde imagine the right
/// future anywhere in its first K candidates?
public enum PsychicReplay {
    public static func score(
        candidates: SuggestionCandidateSet,
        golden: String,
        limit: Int = 8
    ) -> PsychicReplayScore {
        let bounded = Array(candidates.candidates.prefix(max(0, limit)))
        guard !bounded.isEmpty else {
            return PsychicReplayScore(gap: .silence, oracleRank: nil, candidateCount: 0)
        }
        let rank = bounded.firstIndex {
            PersonalReplayEval.exactMatchAtOne(suggestion: $0.text, golden: golden)
        }.map { $0 + 1 }
        let gap: PsychicReplayScore.Gap
        switch rank {
        case 1?: gap = .hit
        case .some: gap = .ranking
        case nil: gap = .generation
        }
        return PsychicReplayScore(gap: gap, oracleRank: rank, candidateCount: bounded.count)
    }
}

/// Count-only accumulator suitable for replay reports and menu diagnostics.
/// It intentionally cannot retain candidate or target text.
public struct PsychicReplayTally: Equatable, Sendable {
    public private(set) var boundaries = 0
    public private(set) var topOneHits = 0
    public private(set) var oracleHits = 0
    public private(set) var rankingGaps = 0
    public private(set) var generationGaps = 0
    public private(set) var silences = 0

    public init() {}

    public mutating func record(_ score: PsychicReplayScore) {
        boundaries += 1
        if score.topOneHit { topOneHits += 1 }
        if score.oracleHit { oracleHits += 1 }
        switch score.gap {
        case .hit: break
        case .ranking: rankingGaps += 1
        case .generation: generationGaps += 1
        case .silence: silences += 1
        }
    }

    public func oracleRate() -> Double {
        boundaries == 0 ? 0 : Double(oracleHits) / Double(boundaries)
    }

    public func selectionEfficiency() -> Double {
        oracleHits == 0 ? 0 : Double(topOneHits) / Double(oracleHits)
    }
}
