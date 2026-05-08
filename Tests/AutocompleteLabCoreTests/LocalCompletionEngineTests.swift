import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Local completion engine")
struct LocalCompletionEngineTests {
    @Test("Uses MVP runtime config with short output and reasoning off")
    func usesMVPRuntimeConfig() async throws {
        let runner = FakeLocalRunner(result: .success(" keep it tiny"))
        let engine = LocalCompletionEngine(runner: runner)

        _ = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "The plan", maxVisibleWords: 8)
        )

        let configuration = await runner.lastConfiguration
        #expect(configuration?.model == .qwen35FourB)
        #expect(configuration?.maxGeneratedTokens == 10)
        #expect(configuration?.maxVisibleWords == 5)
        #expect(configuration?.reasoningEnabled == false)
    }

    @Test("Cleans runtime output and trims repeated typed prefix")
    func cleansAndTrimsRuntimeOutput() async throws {
        let runner = FakeLocalRunner(
            result: .success("<think>hidden chain</think>and keep moving today\nbecause")
        )
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey and", maxVisibleWords: 4)
        )

        #expect(suggestion?.visibleText == " keep moving today")
    }

    @Test("Falls back to mock when runtime fails")
    func fallsBackToMockWhenRuntimeFails() async throws {
        let runner = FakeLocalRunner(result: .failure(FakeRuntimeError.failed))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " we should ship this")
    }

    @Test("Falls back to mock when runtime returns empty output")
    func fallsBackToMockWhenRuntimeReturnsEmptyOutput() async throws {
        let runner = FakeLocalRunner(result: .success("   "))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "can we", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " make this feel instant")
    }

    @Test("Mock fallback keeps suggestions after a completed unmatched word")
    func mockFallbackSuggestsAfterTrailingWhitespace() async throws {
        let runner = FakeLocalRunner(result: .success("   "))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I wrote test ", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " and keep moving")
    }

    @Test("Falls back to mock when runtime echoes earlier context")
    func fallsBackToMockWhenRuntimeEchoesEarlierContext() async throws {
        let runner = FakeLocalRunner(result: .success("Hey. How are"))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey. How are we going to do th", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " and keep moving")
    }

    @Test("Keeps cleaned runtime suggestions for unmatched typo fragments")
    func keepsCleanedRuntimeSuggestionsForUnmatchedTypoFragments() async throws {
        let runner = FakeLocalRunner(result: .success("Hey that sounds"))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey\nHry", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " Hey that sounds")
    }

    @Test("Factory selects mock when app-owned runtime is missing")
    func factorySelectsMockForMissingRuntime() {
        let factory = CompletionEngineFactory(
            runtimeExecutableURL: URL(fileURLWithPath: "/tmp/autocomplete-lab-missing-runtime")
        )

        #expect(factory.selection() == .mockFallback)
    }

    @Test("Factory selects local Gemma bridge when app-owned runtime is executable")
    func factorySelectsLocalRuntimeWhenExecutableExists() {
        let factory = CompletionEngineFactory(runtimeExecutableURL: URL(fileURLWithPath: "/bin/echo"))

        #expect(factory.selection() == .localGemma4E2B)
    }
}

private actor FakeLocalRunner: LocalCompletionRuntimeRunner {
    private let result: Result<String, any Error>
    private(set) var lastPrompt: CompletionPrompt?
    private(set) var lastConfiguration: LocalCompletionRuntimeConfiguration?

    init(result: Result<String, any Error>) {
        self.result = result
    }

    func complete(
        prompt: CompletionPrompt,
        configuration: LocalCompletionRuntimeConfiguration
    ) async throws -> String {
        lastPrompt = prompt
        lastConfiguration = configuration
        return try result.get()
    }
}

private enum FakeRuntimeError: Error {
    case failed
}
