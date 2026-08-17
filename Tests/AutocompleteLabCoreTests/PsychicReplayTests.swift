import Testing
@testable import AutocompleteLabCore

@Suite("Psychic replay")
struct PsychicReplayTests {
    @Test("Top-one hit is both selected and oracle hit")
    func topOneHit() {
        let score = PsychicReplay.score(
            candidates: SuggestionCandidateSet([
                SuggestionCandidate(text: "bigger issue", source: .base),
                SuggestionCandidate(text: "need to", source: .personal),
            ]),
            golden: "bigger issue is onboarding"
        )
        #expect(score.gap == .hit)
        #expect(score.oracleRank == 1)
    }

    @Test("Hidden hit diagnoses ranking rather than generation")
    func rankingGap() {
        let score = PsychicReplay.score(
            candidates: SuggestionCandidateSet([
                SuggestionCandidate(text: "we should", source: .base),
                SuggestionCandidate(text: "the bigger issue", source: .personal),
            ]),
            golden: "the bigger issue is onboarding"
        )
        #expect(score.gap == .ranking)
        #expect(score.oracleRank == 2)
    }

    @Test("No matching future diagnoses generation")
    func generationGap() {
        let score = PsychicReplay.score(
            candidates: SuggestionCandidateSet([
                SuggestionCandidate(text: "sounds good", source: .base),
                SuggestionCandidate(text: "yep", source: .personal),
            ]),
            golden: "what time works"
        )
        #expect(score.gap == .generation)
        #expect(score.oracleRank == nil)
    }

    @Test("No candidates is silence, and K really bounds the oracle")
    func silenceAndBound() {
        #expect(PsychicReplay.score(candidates: SuggestionCandidateSet([]), golden: "hello").gap == .silence)
        let set = SuggestionCandidateSet([
            SuggestionCandidate(text: "wrong", source: .base),
            SuggestionCandidate(text: "right", source: .personal),
        ])
        #expect(PsychicReplay.score(candidates: set, golden: "right now", limit: 1).gap == .generation)
    }

    @Test("Aggregate tally separates imagination from selection")
    func tally() {
        var tally = PsychicReplayTally()
        tally.record(.init(gap: .hit, oracleRank: 1, candidateCount: 2))
        tally.record(.init(gap: .ranking, oracleRank: 2, candidateCount: 2))
        tally.record(.init(gap: .generation, oracleRank: nil, candidateCount: 2))
        tally.record(.init(gap: .silence, oracleRank: nil, candidateCount: 0))
        #expect(tally.boundaries == 4)
        #expect(tally.oracleHits == 2)
        #expect(tally.rankingGaps == 1)
        #expect(tally.generationGaps == 1)
        #expect(tally.silences == 1)
        #expect(tally.oracleRate() == 0.5)
        #expect(tally.selectionEfficiency() == 0.5)
    }
}
