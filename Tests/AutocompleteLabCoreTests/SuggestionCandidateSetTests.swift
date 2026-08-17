import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion candidate set")
struct SuggestionCandidateSetTests {
    @Test("Keeps distinct experts in stable order")
    func stableOrder() {
        let set = SuggestionCandidateSet([
            SuggestionCandidate(text: "sounds good", source: .base),
            SuggestionCandidate(text: "yep", source: .personal, confidence: 1.4, support: 4),
        ])
        #expect(set.candidates.map(\.source) == [.base, .personal])
        #expect(set.first(from: .personal)?.text == "yep")
        #expect(set.first(from: .personal)?.confidence == 1)
        #expect(set.first(from: .personal)?.support == 4)
    }

    @Test("Drops empty and duplicate visible continuations")
    func deduplicates() {
        let set = SuggestionCandidateSet([
            SuggestionCandidate(text: "  ", source: .base),
            SuggestionCandidate(text: "Tomorrow", source: .base),
            SuggestionCandidate(text: " tomorrow ", source: .personal, support: 8),
        ])
        #expect(set.candidates.count == 1)
        #expect(set.candidates[0].source == .base)
        #expect(set.candidates[0].text == "Tomorrow")
    }

    @Test("Negative support and confidence are clamped")
    func clampsHints() {
        let candidate = SuggestionCandidate(text: "yep", source: .personal, confidence: -0.2, support: -3)
        #expect(candidate.confidence == 0)
        #expect(candidate.support == 0)
    }
}
