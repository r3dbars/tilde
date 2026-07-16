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
        #expect(configuration?.model == .gemma4E4BItOptiQ)
        #expect(configuration?.maxGeneratedTokens == 20)
        #expect(configuration?.maxVisibleWords == 8)
        #expect(configuration?.reasoningEnabled == false)
        #expect(configuration?.promptTemplate == .chatInstruct)
        #expect(await runner.lastPrompt?.template == .chatInstruct)
        #expect(await runner.lastPrompt?.system.contains("Inline autocomplete") == true)
    }

    @Test("Runtime config allows the extended word slider")
    func runtimeConfigAllowsExtendedWordSlider() {
        let policy = CompletionModelPolicy(
            model: .qwen35FourB,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 16,
            maxGeneratedTokens: 48,
            maxVisibleWords: 20,
            debounceMilliseconds: 15,
            targetLatencyMilliseconds: 50,
            reasoningEnabled: false
        )
        let configuration = LocalCompletionRuntimeConfiguration(policy: policy)

        #expect(configuration.maxVisibleWords == 20)
        #expect(configuration.maxGeneratedTokens == 48)
    }

    @Test("Runtime config uses raw completion template for base small model")
    func runtimeConfigUsesRawTemplateForBaseSmallModel() async throws {
        let policy = CompletionModelPolicy(
            model: .qwen3Medium,
            runtimeOwnership: .appOwnedEmbedded,
            minimumMemoryGB: 8,
            maxGeneratedTokens: 16,
            maxVisibleWords: 5,
            debounceMilliseconds: 10,
            targetLatencyMilliseconds: 35,
            reasoningEnabled: false
        )
        let configuration = LocalCompletionRuntimeConfiguration(policy: policy)
        let runner = FakeLocalRunner(result: .success("simple and local"))
        let engine = LocalCompletionEngine(
            runner: runner,
            configuration: configuration
        )

        _ = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "The small model should stay", maxVisibleWords: 5)
        )

        let prompt = try #require(await runner.lastPrompt)
        #expect(await runner.lastConfiguration?.promptTemplate == .rawCompletion)
        #expect(prompt.template == .rawCompletion)
        #expect(prompt.system == "")
        #expect(prompt.rawPrompt == prompt.user)
        #expect(prompt.user.contains("Inline autocomplete"))
        #expect(prompt.user.contains("Before cursor:\nThe small model should stay"))
        #expect(!prompt.user.contains("System:"))
        #expect(!prompt.user.contains("Assistant:"))
    }

    @Test("Passes request mode to runtime runner")
    func passesRequestModeToRuntimeRunner() async throws {
        let runner = FakeLocalRunner(result: .success("tion"))
        let engine = LocalCompletionEngine(runner: runner)

        _ = try await engine.suggestion(
            for: CompletionRequest(
                textBeforeCursor: "The explanation needs a simple transi",
                maxVisibleWords: 1,
                mode: .wordCompletion
            )
        )

        #expect(await runner.lastMode == .wordCompletion)
        #expect(await runner.lastPrompt?.user.hasSuffix("Suffix:") == true)
    }

    @Test("Cleans runtime output and trims repeated typed prefix")
    func cleansAndTrimsRuntimeOutput() async throws {
        let runner = FakeLocalRunner(
            result: .success("<think>hidden chain</think>and keep moving forward\nbecause")
        )
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey and", maxVisibleWords: 4)
        )

        #expect(suggestion?.visibleText == " keep moving forward")
    }

    @Test("Ranks cleaned runtime candidates before display")
    func ranksCleanedRuntimeCandidatesBeforeDisplay() async throws {
        let runner = FakeLocalRunner(
            result: .success(
                """
                1. scheduling a meeting tomorrow
                2. checking the draft first
                """
            )
        )
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(
                textBeforeCursor: "Thanks for sending this over. I will start by",
                behaviorProfileID: .email,
                maxVisibleWords: 8
            )
        )

        #expect(suggestion?.visibleText == " checking the draft first")
    }

    @Test("Returns no suggestion when runtime fails without an explicit test fallback")
    func returnsNoSuggestionWhenRuntimeFailsWithoutExplicitFallback() async throws {
        let runner = FakeLocalRunner(result: .failure(FakeRuntimeError.failed))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
    }

    @Test("Returns no suggestion when runtime returns empty output")
    func returnsNoSuggestionWhenRuntimeReturnsEmptyOutput() async throws {
        let runner = FakeLocalRunner(result: .success("   "))
        let engine = LocalCompletionEngine(runner: runner)

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "can we", maxVisibleWords: 8)
        )

        #expect(suggestion == nil)
    }

    @Test("Does not fall back to mock suggestions for echoed context")
    func doesNotFallbackToMockSuggestionsForEchoedContext() async throws {
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

    @Test("Factory selects local Gemma bridge when app-owned runtime is executable")
    func factorySelectsLocalRuntimeWhenExecutableExists() {
        let factory = CompletionEngineFactory(runtimeExecutableURL: URL(fileURLWithPath: "/bin/echo"))

        #expect(factory.selection() == .localGemma4E2B)
    }
}

private actor FakeLocalRunner: LocalCompletionRuntimeRunner {
    private let result: Result<String, any Error>
    private(set) var lastPrompt: FormattedCompletionPrompt?
    private(set) var lastMode: CompletionRequestMode?
    private(set) var lastConfiguration: LocalCompletionRuntimeConfiguration?

    init(result: Result<String, any Error>) {
        self.result = result
    }

    func complete(
        prompt: FormattedCompletionPrompt,
        mode: CompletionRequestMode,
        configuration: LocalCompletionRuntimeConfiguration
    ) async throws -> String {
        lastPrompt = prompt
        lastMode = mode
        lastConfiguration = configuration
        return try result.get()
    }
}

private enum FakeRuntimeError: Error {
    case failed
}
