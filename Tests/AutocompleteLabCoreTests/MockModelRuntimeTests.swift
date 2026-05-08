import Foundation
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

    @Test("Runtime backed engine streams partial suggestions")
    func runtimeBackedEngineStreamsPartials() async throws {
        let runtime = MockModelRuntime()
        let engine = RuntimeBackedCompletionEngine(runtime: runtime)
        let partials = PartialCollector()

        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Can we"),
            onPartialSuggestion: { partial in
                partials.append(partial.visibleText)
            }
        )

        #expect(suggestion?.visibleText == " make this feel")
        #expect(partials.values == [" make this feel"])
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

    @Test("Runtime backed engine backs off after repeated runtime failures")
    func runtimeBackedEngineBacksOffAfterRepeatedFailures() async throws {
        let runtime = FailingModelRuntime()
        let clock = TestClock(milliseconds: 1_000)
        let engine = RuntimeBackedCompletionEngine(
            runtime: runtime,
            failureBackoffPolicy: RuntimeFailureBackoffPolicy(
                failureThreshold: 2,
                cooldownMilliseconds: 5_000
            ),
            nowMilliseconds: { clock.milliseconds }
        )

        await #expect(throws: LocalCompletionRuntimeError.self) {
            _ = try await engine.suggestion(for: CompletionRequest(textBeforeCursor: "I think"))
        }
        await #expect(throws: LocalCompletionRuntimeError.self) {
            _ = try await engine.suggestion(for: CompletionRequest(textBeforeCursor: "I think"))
        }

        let suppressed = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I think")
        )
        #expect(suppressed == nil)
        #expect(runtime.completeCallCount == 2)

        clock.milliseconds = 6_001
        await #expect(throws: LocalCompletionRuntimeError.self) {
            _ = try await engine.suggestion(for: CompletionRequest(textBeforeCursor: "I think"))
        }
        #expect(runtime.completeCallCount == 3)
    }
}

private final class PartialCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.withLock {
            storedValues
        }
    }

    func append(_ value: String) {
        lock.withLock {
            storedValues.append(value)
        }
    }
}

private final class FailingModelRuntime: ModelRuntime, @unchecked Sendable {
    private let lock = NSLock()
    private var storedCompleteCallCount = 0

    var completeCallCount: Int {
        lock.withLock {
            storedCompleteCallCount
        }
    }

    var state: LocalRuntimeState {
        get async {
            .ready(candidate: .mlx)
        }
    }

    func warm() async throws {}

    func cancel() {}

    func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        lock.withLock {
            storedCompleteCallCount += 1
        }
        throw LocalCompletionRuntimeError.invalidOutput
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedMilliseconds: Int

    init(milliseconds: Int) {
        self.storedMilliseconds = milliseconds
    }

    var milliseconds: Int {
        get {
            lock.withLock {
                storedMilliseconds
            }
        }
        set {
            lock.withLock {
                storedMilliseconds = newValue
            }
        }
    }
}
