import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Intent futures live prompt integration")
struct IntentFuturesPromptIntegrationTests {
    @Test("Hint is inserted only before the live continuation marker")
    func insertsBeforeLastMarker() {
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "Can you send it tonight?")],
            referenceSnippets: []
        )
        let recipe = RawContinuationPrompt(textBeforeCursor: "I can ", register: .chat, scene: scene)
        let prompt = LlamaCompletionEngine.promptByAddingIntentFutures(
            to: recipe.prompt,
            scene: scene,
            textBeforeCursor: "I can "
        )

        let occurrences = prompt.components(separatedBy: "Likely response directions:").count - 1
        #expect(occurrences == 1)
        #expect(prompt.contains("Text: I can\nLikely response directions:"))
        #expect(prompt.hasSuffix("Continuation:"))
    }

    @Test("No reply scene preserves the original prompt byte for byte")
    func noScenePreservesPrompt() {
        let recipe = RawContinuationPrompt(textBeforeCursor: "hello there ", register: .prose, scene: nil)
        let prompt = LlamaCompletionEngine.promptByAddingIntentFutures(
            to: recipe.prompt,
            scene: nil,
            textBeforeCursor: "hello there "
        )
        #expect(prompt == recipe.prompt)
    }
}
