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

    @Test("does not suppress instant word completion")
    func doesNotSuppressWordCompletion() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("ing", mode: .wordCompletion)

        #expect(!suppressor.shouldSuppress("ing", mode: .wordCompletion))
    }

    @Test("acceptance clears repeated phrase misses")
    func acceptanceClearsMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("keep going", mode: .phraseContinuation)
        #expect(suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
        suppressor.recordAcceptance("keep going", mode: .phraseContinuation)
        #expect(!suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
    }
}
