import Testing
@testable import AutocompleteLabCore

@Suite("Completion quality eval")
struct CompletionQualityEvalTests {
    private struct EvalCase {
        let name: String
        let rawOutput: String
        let textBeforeCursor: String
        let mode: CompletionRequestMode
        let expectedVisibleText: String?
    }

    @Test("Keeps suggestions usable for the tight typing loop")
    func keepsSuggestionsUsableForTypingLoop() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 5)
        let cases = [
            EvalCase(
                name: "word suffix only",
                rawOutput: "hello and welcome",
                textBeforeCursor: "hello and w",
                mode: .wordCompletion,
                expectedVisibleText: "elcome"
            ),
            EvalCase(
                name: "word mode rejects phrase",
                rawOutput: "welcome home",
                textBeforeCursor: "hello and w",
                mode: .wordCompletion,
                expectedVisibleText: nil
            ),
            EvalCase(
                name: "phrase keeps leading space",
                rawOutput: "feel instant and calm",
                textBeforeCursor: "Make this",
                mode: .phraseContinuation,
                expectedVisibleText: " feel instant and calm"
            ),
            EvalCase(
                name: "assistant filler blocked",
                rawOutput: "That makes a lot of sense",
                textBeforeCursor: "I think",
                mode: .phraseContinuation,
                expectedVisibleText: nil
            ),
            EvalCase(
                name: "thinking stripped",
                rawOutput: "<think>explain the plan</think>keep moving",
                textBeforeCursor: "Let's",
                mode: .phraseContinuation,
                expectedVisibleText: " keep moving"
            ),
            EvalCase(
                name: "earlier context repeat blocked",
                rawOutput: "know you are ready",
                textBeforeCursor: "I know you are\n\nHey how are you",
                mode: .phraseContinuation,
                expectedVisibleText: nil
            )
        ]

        for evalCase in cases {
            let suggestion = cleaner.clean(
                evalCase.rawOutput,
                after: evalCase.textBeforeCursor,
                mode: evalCase.mode
            )
            #expect(
                suggestion?.visibleText == evalCase.expectedVisibleText,
                "Failed quality eval case: \(evalCase.name)"
            )
        }
    }
}
