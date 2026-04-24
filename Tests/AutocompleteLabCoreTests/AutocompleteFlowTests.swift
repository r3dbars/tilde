import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete flow")
struct AutocompleteFlowTests {
    @Test("Mock engine suggestion can be accepted word by word")
    func mockSuggestionCanBeAcceptedWordByWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
        )

        var session = SuggestionSession(visibleSuggestion: suggestion)

        #expect(session.acceptNextWord() == " we")
        #expect(session.acceptAllVisible() == " should ship this")
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Raw model output is cleaned before showing")
    func rawModelOutputIsCleanedBeforeShowing() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 4)
        let suggestion = cleaner.clean("<think>long reasoning</think>make it feel instant")

        var session = SuggestionSession(visibleSuggestion: suggestion)

        #expect(session.acceptAllVisible() == " make it feel instant")
        #expect(!session.hasVisibleSuggestion)
    }
}
