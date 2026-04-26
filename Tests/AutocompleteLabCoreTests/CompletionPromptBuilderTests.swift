import Testing
@testable import AutocompleteLabCore

@Suite("Completion prompt builder")
struct CompletionPromptBuilderTests {
    @Test("Prompt asks for a tiny continuation only")
    func promptAsksForTinyContinuationOnly() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "I think we should"))

        #expect(prompt.system.contains("next 5 words or fewer"))
        #expect(prompt.system.contains("inline autocomplete engine"))
        #expect(prompt.system.contains("No explanation"))
        #expect(prompt.system.contains("No reasoning"))
        #expect(prompt.user.contains("Text before cursor:\nI think we should"))
        #expect(prompt.user.hasSuffix("Autocomplete continuation:"))
    }

    @Test("Prompt trims long context from the left")
    func promptTrimsLongContext() {
        let builder = CompletionPromptBuilder(maxContextCharacters: 120)
        let longText = String(repeating: "a", count: 200)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: longText))

        #expect(prompt.user.contains(String(repeating: "a", count: 120)))
        #expect(!prompt.user.contains(String(repeating: "a", count: 121)))
    }
}
