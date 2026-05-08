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
        #expect(configuration?.maxGeneratedTokens == 9)
        #expect(configuration?.maxVisibleWords == 3)
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

    @Test("Fails closed when runtime fails")
    func failsClosedWhenRuntimeFails() async throws {
        let runner = FakeLocalRunner(result: .failure(FakeRuntimeError.failed))
        let engine = LocalCompletionEngine(runner: runner)

        await #expect(throws: FakeRuntimeError.failed) {
            _ = try await engine.suggestion(
                for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
            )
        }
    }

    @Test("Suppresses suggestions when runtime returns empty output")
    func suppressesSuggestionsWhenRuntimeReturnsEmptyOutput() async throws {
        let runner = FakeLocalRunner(result: .success("   "))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "can we", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
    }

    @Test("Suppresses suggestions after empty output for completed unmatched word")
    func suppressesEmptyOutputAfterTrailingWhitespace() async throws {
        let runner = FakeLocalRunner(result: .success("   "))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I wrote test ", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
    }

    @Test("Suppresses suggestions when runtime echoes earlier context")
    func suppressesRuntimeOutputThatEchoesEarlierContext() async throws {
        let runner = FakeLocalRunner(result: .success("Hey. How are"))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey. How are we going to do th", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
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

    @Test("Factory selects unavailable when app-owned runtime is missing")
    func factorySelectsUnavailableForMissingRuntime() {
        let factory = CompletionEngineFactory(
            runtimeExecutableURL: URL(fileURLWithPath: "/tmp/autocomplete-lab-missing-runtime")
        )

        #expect(factory.selection() == .unavailable)
    }

    @Test("Factory suppresses suggestions when app-owned runtime is missing")
    func factorySuppressesSuggestionsForMissingRuntime() async throws {
        let factory = CompletionEngineFactory(
            runtimeExecutableURL: URL(fileURLWithPath: "/tmp/autocomplete-lab-missing-runtime")
        )

        let suggestion = try await factory.makeEngine().suggestion(
            for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
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
