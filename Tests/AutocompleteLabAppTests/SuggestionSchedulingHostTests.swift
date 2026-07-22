import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion scheduling host")
struct SuggestionSchedulingHostTests {
    @Test("AppDelegate delegates request scheduling and preserves fast-path gates")
    func appDelegateUsesSuggestionSchedulingHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var suggestionSchedulingHost"))
        #expect(appDelegate.contains("suggestionSchedulingHost.scheduleSuggestion("))
        #expect(host.contains("disablesWordCompletionForProof"))
        #expect(host.contains("suggestionOrchestrator.fastWordSelection("))
        #expect(host.contains("suggestionOrchestrator.fastPhraseSelection("))
        #expect(host.contains("scheduleModelExecution("))
    }

    @Test("Assembles a request and keeps the instant-word latency contract")
    func assemblesInstantWordRequest() throws {
        let host = makeHost()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )

        let preparation = host.prepare(
            context: makeContext(),
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: field,
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            renderMode: .inlineAdjacent,
            delayMilliseconds: 500,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            typingBurstDecision: .idle,
            visiblePageContext: nil,
            triggerReason: "test"
        )

        #expect(preparation.orchestration.request.mode == .wordCompletion)
        #expect(preparation.orchestration.request.appBundleIdentifier == "com.apple.TextEdit")
        #expect(preparation.orchestration.request.maxVisibleWords == 3)
        #expect(preparation.requestSchedule.scheduledDelayMilliseconds == 0)
        #expect(preparation.requestSchedule.resultLatencyBudgetMilliseconds == 1_200)
        #expect(preparation.requestMetadata["suggestionTimingLane"] == "instantWord")
    }

    @Test("Uses the floating presentation floor for delayed continuation requests")
    func assemblesFloatingContinuationRequest() throws {
        let host = makeHost()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )

        let preparation = host.prepare(
            context: makeContext(),
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: field,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
            renderMode: .floatingMirror,
            delayMilliseconds: 0,
            timingLane: .pausePhrase,
            requestMode: .phraseContinuation,
            typingBurstDecision: .burst(insertedCharacterCount: 2, eventCount: 2),
            visiblePageContext: nil,
            triggerReason: "test"
        )

        #expect(preparation.requestSchedule.scheduledDelayMilliseconds == 60)
        #expect(preparation.requestSchedule.resultLatencyBudgetMilliseconds == 2_000)
        #expect(preparation.orchestration.request.maxVisibleWords == 3)
        #expect(preparation.requestMetadata["suggestionTimingLane"] == "pausePhrase")
    }

    @Test("Executes the scheduled request and forwards the final result")
    func forwardsFinalResult() async throws {
        let events = TestEvents()
        let orchestrator = SuggestionOrchestrator(engine: RequestExecutionTestEngine(shouldThrow: false))
        let scheduler = SuggestionRequestScheduler()
        let host = makeHost(
            suggestionOrchestrator: orchestrator,
            scheduler: scheduler,
            handlePartial: { _, _ in events.values.append("partial") },
            handleFinal: { suggestion, _ in events.values.append(suggestion == nil ? "final-empty" : "final") },
            handleFailure: { _ in events.values.append("failure") }
        )

        host.scheduleModelExecution(input: try makeExecutionInput())
        for _ in 0..<50 where events.values.isEmpty {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(events.values == ["final"])
        #expect(!scheduler.hasPendingRequest)
    }

    @Test("Forwards a model execution failure without deciding its UI outcome")
    func forwardsFailure() async throws {
        let events = TestEvents()
        let orchestrator = SuggestionOrchestrator(engine: RequestExecutionTestEngine(shouldThrow: true))
        let host = makeHost(
            suggestionOrchestrator: orchestrator,
            handlePartial: { _, _ in events.values.append("partial") },
            handleFinal: { _, _ in events.values.append("final") },
            handleFailure: { _ in events.values.append("failure") }
        )

        host.scheduleModelExecution(input: try makeExecutionInput())
        for _ in 0..<50 where events.values.isEmpty {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(events.values == ["failure"])
    }

    // MARK: - Test fixtures

    private func makeHost(
        suggestionOrchestrator: SuggestionOrchestrator = SuggestionOrchestrator(engine: PreparationTestCompletionEngine()),
        scheduler: SuggestionRequestScheduler = SuggestionRequestScheduler(),
        handlePartial: @escaping @MainActor @Sendable (CompletionSuggestion, SuggestionModelResultInput) -> Void = { _, _ in },
        handleFinal: @escaping @MainActor @Sendable (CompletionSuggestion?, SuggestionModelResultInput) -> Void = { _, _ in },
        handleFailure: @escaping @MainActor @Sendable (SuggestionModelResultInput) -> Void = { _ in }
    ) -> SuggestionSchedulingHost {
        SuggestionSchedulingHost(
            dependencies: SuggestionSchedulingHostDependencies(
                cancelPrefixCooldownRetry: {},
                setLastRequestedTextBeforeCursor: { _ in },
                suggestionOrchestrator: suggestionOrchestrator,
                runtimeProofOptions: RuntimeProofOptions(),
                activeAppProofBundleIdentifiers: [],
                recentWordMemoryWords: { _ in [] },
                suggestionSession: SuggestionSessionHost(),
                currentSuggestionID: { nil },
                acceptedAndKeptSignal: { _, _, _ in fatalError("not exercised by this test") },
                acceptedAndKeptLearning: { AcceptedAndKeptLearningStore() },
                shouldAskModelForWordCompletionFallback: { _ in false },
                shouldUsePredictiveWordFallback: { _, _ in false },
                shouldUsePredictivePhraseFallback: { _, _, _ in false },
                triggerPolicy: { _ in SuggestionTriggerPolicy() },
                suggestionTypingBurstSuppressionHost: SuggestionTypingBurstSuppressionHost(
                    dependencies: SuggestionTypingBurstSuppressionHostDependencies(
                        cancelIdleRetry: {},
                        setSuggestionDecision: { _ in },
                        showFieldStatusIndicator: { _, _ in },
                        recordSuggestionEvent: { _, _, _, _ in },
                        recordBlockedSuggestionEvent: { _, _, _, _, _ in },
                        repositionVisibleSuggestion: { _, _ in },
                        updateKeyboardEventTapSnapshot: {},
                        noteTypingBurstSuppression: { _, _, _ in },
                        hideSuggestion: { _, _ in }
                    )
                ),
                suggestionIdleRetryState: SuggestionIdleRetryStateHost(),
                recordSuggestionEvent: { _, _, _, _ in },
                recordAnnoyanceSignal: { _, _, _, _, _ in },
                annoyanceContext: { _, _, _, _ in fatalError("not exercised by this test") },
                setSuggestionDecision: { _ in },
                repositionVisibleSuggestion: { _, _ in },
                hideSuggestion: {},
                presentSuggestion: { _, _, _, _, _, _, _, _, _, _, _, _ in },
                acceptedTextStyleSketch: { _ in nil },
                suggestionTuning: { SuggestionTuning(maxVisibleWords: 3) },
                requestSchedulingPolicy: SuggestionRequestSchedulingPolicy(),
                scheduler: scheduler,
                handlePartial: handlePartial,
                handleFinal: handleFinal,
                handleFailure: handleFailure,
                cancelScheduledPendingRequest: { false },
                clearStreamingPresentations: {},
                invalidateOrchestratorRequest: {}
            )
        )
    }

    private func makeContext() -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Test"),
            textBeforeCursor: "draft",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
            elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            windowIdentifier: 42,
            textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
            textStyle: nil,
            isSecure: false,
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: true,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
    }

    private func makeExecutionInput() throws -> SuggestionModelResultInput {
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "execution"
        )
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        return SuggestionModelResultInput(
            suggestionID: request.suggestionID,
            request: request,
            context: makeContext(),
            profile: profile,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
            fieldIdentityDescription: fieldIdentity.traceDescription,
            renderMode: .inlineAdjacent,
            requestMetadata: [:],
            requestSchedule: SuggestionRequestSchedule(
                policyDelayMilliseconds: 0,
                scheduledDelayMilliseconds: 0,
                resultLatencyBudgetMilliseconds: 2_000,
                reason: "test"
            ),
            requestTicket: SuggestionRequestTicket(generation: 1, request: request),
            requestStartedAt: Date()
        )
    }
}

@MainActor
private final class TestEvents {
    var values: [String] = []
}

private struct PreparationTestCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}

private struct RequestExecutionTestEngine: CompletionEngine {
    let shouldThrow: Bool

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        if shouldThrow {
            throw TestError.failed
        }

        return CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5)
    }
}

private enum TestError: Error {
    case failed
}
