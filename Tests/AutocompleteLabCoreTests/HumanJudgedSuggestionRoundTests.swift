import Testing
@testable import AutocompleteLabCore

@Suite("Human judged suggestion round")
struct HumanJudgedSuggestionRoundTests {
    @Test("Builds fifty shuffled blind pairs with a separate answer key")
    func buildsFiftyShuffledBlindPairs() throws {
        let round = try HumanJudgedSuggestionRound.makeRound(
            from: Self.seedPairs(count: 60),
            seed: 42
        )

        #expect(round.items.count == 50)
        #expect(round.answerKey.count == 50)
        #expect(round.blankJudgments.count == 50)
        #expect(!round.containsCompletedJudgments)
        #expect(round.items.map(\.itemID) == round.blankJudgments.map(\.itemID))
        #expect(round.items.map(\.itemID) == round.answerKey.map(\.itemID))
        #expect(round.items.first?.itemID == "round-001")
        #expect(round.items.last?.itemID == "round-050")
        #expect(round.blankJudgments.allSatisfy { $0.winner == nil && $0.reasonTags.isEmpty && $0.notes.isEmpty })
        #expect(round.answerKey.contains { $0.leftCandidateID.hasPrefix("challenger-") })
        #expect(round.answerKey.contains { $0.rightCandidateID.hasPrefix("challenger-") })
    }

    @Test("Round generation is deterministic for the same seed")
    func roundGenerationIsDeterministic() throws {
        let pairs = Self.seedPairs(count: 60)
        let first = try HumanJudgedSuggestionRound.makeRound(from: pairs, seed: 7)
        let second = try HumanJudgedSuggestionRound.makeRound(from: pairs, seed: 7)
        let different = try HumanJudgedSuggestionRound.makeRound(from: pairs, seed: 8)

        #expect(first == second)
        #expect(first != different)
    }

    @Test("Round generation requires enough distinct usable pairs")
    func roundGenerationRequiresEnoughDistinctPairs() {
        #expect(throws: HumanJudgedSuggestionRoundError.notEnoughPairs(required: 50, available: 49)) {
            _ = try HumanJudgedSuggestionRound.makeRound(from: Self.seedPairs(count: 49))
        }

        #expect(throws: HumanJudgedSuggestionRoundError.duplicatePairID("pair-001")) {
            var pairs = Self.seedPairs(count: 50)
            pairs[1] = HumanJudgedSuggestionPairSeed(
                pairID: "pair-001",
                caseID: "case-duplicate",
                textBeforeCursor: "Duplicate pair context",
                firstCandidate: HumanJudgedSuggestionCandidate(id: "candidate-a", visibleText: "first option"),
                secondCandidate: HumanJudgedSuggestionCandidate(id: "candidate-b", visibleText: "second option")
            )
            _ = try HumanJudgedSuggestionRound.makeRound(from: pairs)
        }
    }

    private static func seedPairs(count: Int) -> [HumanJudgedSuggestionPairSeed] {
        (1...count).map { index in
            let id = padded(index)
            return HumanJudgedSuggestionPairSeed(
                pairID: "pair-\(id)",
                caseID: "case-\(id)",
                textBeforeCursor: "Public-domain or disposable prompt \(index) should",
                firstCandidate: HumanJudgedSuggestionCandidate(
                    id: "baseline-\(id)",
                    visibleText: "finish cleanly \(index)"
                ),
                secondCandidate: HumanJudgedSuggestionCandidate(
                    id: "challenger-\(id)",
                    visibleText: "continue quietly \(index)"
                )
            )
        }
    }

    private static func padded(_ value: Int) -> String {
        if value < 10 {
            return "00\(value)"
        }
        if value < 100 {
            return "0\(value)"
        }
        return "\(value)"
    }
}
