import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion repetition suppressor")
struct SuggestionRepetitionSuppressorTests {
    @Test("suppresses repeated phrase misses")
    func suppressesRepeatedPhraseMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 2)

        #expect(!suppressor.shouldSuppress(" What kind of laptop", mode: .phraseContinuation))
        suppressor.recordMiss("what kind of laptop", mode: .phraseContinuation)
        #expect(!suppressor.shouldSuppress("What kind of laptop?", mode: .phraseContinuation))
        suppressor.recordMiss("What kind of laptop?", mode: .phraseContinuation)
        #expect(suppressor.shouldSuppress(" what kind of laptop", mode: .phraseContinuation))
    }

    @Test("near duplicate typed-over misses suppress repeated bad phrases")
    func nearDuplicateTypedOverMissesSuppressRepeatedBadPhrases() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 2)

        suppressor.recordMiss("  What   kind of laptop?", mode: .phraseContinuation)
        suppressor.recordMiss("what kind of laptop", mode: .phraseContinuation)

        #expect(suppressor.shouldSuppress("WHAT kind of laptop!", mode: .phraseContinuation))
        #expect(suppressor.shouldSuppress("what \u{201C}kind\u{201D} of laptop\u{2026}", mode: .phraseContinuation))
    }

    @Test("suppresses tiny repeated word-completion misses")
    func suppressesTinyRepeatedWordCompletionMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("ng", mode: .wordCompletion)

        #expect(suppressor.shouldSuppress("ng", mode: .wordCompletion))
    }

    @Test("does not suppress substantial word completions")
    func doesNotSuppressSubstantialWordCompletions() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("tation", mode: .wordCompletion)

        #expect(!suppressor.shouldSuppress("tation", mode: .wordCompletion))
    }

    @Test("acceptance clears repeated phrase misses")
    func acceptanceClearsMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("keep going", mode: .phraseContinuation)
        #expect(suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
        suppressor.recordAcceptance("keep going", mode: .phraseContinuation)
        #expect(!suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
    }

    @Test("miss suppression is scoped by app")
    func missSuppressionIsScopedByApp() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("is", mode: .wordCompletion, scope: "com.openai.codex")

        #expect(suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.openai.codex"))
        #expect(!suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.apple.TextEdit"))

        suppressor.recordAcceptance("is", mode: .wordCompletion, scope: "com.apple.TextEdit")

        #expect(suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.openai.codex"))
    }
}
