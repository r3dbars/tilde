import Testing
@testable import AutocompleteLabCore

@Suite("Completion decoding strategy")
struct CompletionDecodingStrategyTests {
    @Test("Word and short completions stay deterministic")
    func shortCompletionsStayGreedy() {
        let policy = CompletionDecodingStrategyPolicy()

        #expect(policy.strategy(for: .wordCompletion, maxGeneratedTokens: 48).temperature == 0)
        #expect(policy.strategy(for: .phraseContinuation, maxGeneratedTokens: 12).sampleCount == 1)
    }

    @Test("Long continuation budgets use bounded best of two sampling")
    func longContinuationsUseBestOfTwo() {
        let strategy = CompletionDecodingStrategyPolicy().strategy(
            for: .phraseContinuation,
            maxGeneratedTokens: 32
        )

        #expect(strategy.temperature == 0.35)
        #expect(strategy.topP == 0.9)
        #expect(strategy.repetitionPenalty == 1.05)
        #expect(strategy.sampleCount == 2)
        #expect(strategy.identifier.contains("samples-2"))
        #expect(strategy.strategy(forSampleAt: 0).temperature == 0)
        #expect(strategy.strategy(forSampleAt: 1).temperature == 0.35)
    }
}
