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

        let nextWord = session.nextWordAcceptance()
        #expect(nextWord == " we")
        #expect(session.visibleSuggestion?.visibleText == " we should ship this")
        session.commitNextWordAcceptance(nextWord ?? "")

        let remaining = session.allVisibleAcceptance()
        #expect(remaining == " should ship this")
        session.commitAllVisibleAcceptance(remaining ?? "")
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

    @Test("Mock engine avoids repeating the word the user just typed")
    func mockSuggestionAvoidsRepeatingLastTypedWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey and", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " keep moving")
    }

    @Test("Mock engine completes only the missing part of a typed word")
    func mockSuggestionCompletesMissingWordSuffix() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey a", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == "nd keep moving")
    }

    @Test("Word completion mode completes only the current word")
    func wordCompletionModeCompletesOnlyCurrentWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "dic", maxVisibleWords: 8, mode: .wordCompletion)
        )

        #expect(suggestion?.visibleText == "tation")
    }
}
