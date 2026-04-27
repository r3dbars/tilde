import Testing
@testable import AutocompleteLabCore

@Suite("Mock model runtime")
struct MockModelRuntimeTests {
    @Test("Runtime warms and completes through the model protocol")
    func runtimeWarmsAndCompletes() async throws {
        let runtime = MockModelRuntime()

        await #expect(runtime.state == .unavailable(reason: "Runtime has not been warmed."))
        try await runtime.warm()
        await #expect(runtime.state == .ready(candidate: .mock))

        let suggestion = try await runtime.complete(CompletionRequest(textBeforeCursor: "I think"))

        #expect(suggestion?.visibleText == " we should ship")
    }

    @Test("Runtime backed engine delegates to the model runtime")
    func runtimeBackedEngineDelegates() async throws {
        let runtime = MockModelRuntime()
        let engine = RuntimeBackedCompletionEngine(runtime: runtime)

        let suggestion = try await engine.suggestion(for: CompletionRequest(textBeforeCursor: "Can we"))

        #expect(await runtime.state == .ready(candidate: .mock))
        #expect(suggestion?.visibleText == " make this feel")
    }

    @Test("Canceling a warm runtime leaves it unavailable")
    func cancelingWarmRuntimeLeavesItUnavailable() async {
        let runtime = MockModelRuntime(warmDelayMilliseconds: 100)
        let warmTask = Task {
            try await runtime.warm()
        }

        try? await Task.sleep(for: .milliseconds(10))
        runtime.cancel()

        await #expect(throws: CancellationError.self) {
            try await warmTask.value
        }
        await #expect(runtime.state == .unavailable(reason: "Runtime was canceled."))
    }
}
