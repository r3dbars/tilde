import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion request execution host")
struct SuggestionRequestExecutionHostTests {
    @Test("Executes the scheduled request and forwards the final result")
    func forwardsFinalResult() async throws {
        let input = try makeInput()
        let scheduler = SuggestionRequestScheduler()
        let events = TestEvents()
        let orchestrator = SuggestionOrchestrator(engine: RequestExecutionTestEngine(shouldThrow: false))
        let host = SuggestionRequestExecutionHost(
            dependencies: SuggestionRequestExecutionHostDependencies(
                scheduler: scheduler,
                suggestionOrchestrator: orchestrator,
                handlePartial: { _, _ in events.values.append("partial") },
                handleFinal: { suggestion, _ in events.values.append(suggestion == nil ? "final-empty" : "final") },
                handleFailure: { _ in events.values.append("failure") }
            )
        )

        host.schedule(input: input)
        for _ in 0..<50 where events.values.isEmpty {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(events.values == ["final"])
        #expect(!scheduler.hasPendingRequest)
    }

    @Test("Forwards a model execution failure without deciding its UI outcome")
    func forwardsFailure() async throws {
        let input = try makeInput()
        let events = TestEvents()
        let orchestrator = SuggestionOrchestrator(engine: RequestExecutionTestEngine(shouldThrow: true))
        let host = SuggestionRequestExecutionHost(
            dependencies: SuggestionRequestExecutionHostDependencies(
                scheduler: SuggestionRequestScheduler(),
                suggestionOrchestrator: orchestrator,
                handlePartial: { _, _ in events.values.append("partial") },
                handleFinal: { _, _ in events.values.append("final") },
                handleFailure: { _ in events.values.append("failure") }
            )
        )

        host.schedule(input: input)
        for _ in 0..<50 where events.values.isEmpty {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(events.values == ["failure"])
    }

    @Test("AppDelegate delegates delayed model execution to the host")
    func appDelegateUsesExecutionHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let schedulingHost = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift"),
            encoding: .utf8
        )
        let source = appDelegate + schedulingHost

        #expect(source.contains("private lazy var suggestionRequestExecutionHost"))
        #expect(source.contains("suggestionRequestExecutionHost.schedule("))
        #expect(!source.contains("suggestionRequestScheduler.schedule("))
    }

    private func makeInput() throws -> SuggestionModelResultInput {
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
            context: FocusedTextContext(
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
                fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
                caretIsSynthetic: false,
                capabilities: FocusedTextCapabilities(
                    canReadValue: true,
                    canReadSelectedTextRange: true,
                    canReadBoundsForRange: true,
                    canReadAttributedText: false,
                    canSetSelectedText: true
                )
            ),
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
