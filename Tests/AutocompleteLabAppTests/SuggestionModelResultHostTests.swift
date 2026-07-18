import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion model result host")
struct SuggestionModelResultHostTests {
    @Test("Presents a current anchored model result with safe candidate metadata")
    func presentsCurrentModelResult() throws {
        let (orchestrator, input, events) = try makeHostAndInput()
        var presentation: SuggestionModelResultPresentation?
        let configuredHost = hostWith(
            input: input,
            events: events,
            orchestrator: orchestrator,
            presentSuggestion: { _, value in presentation = value }
        )

        configuredHost.handle(
            suggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            input: input
        )

        #expect(presentation?.suggestionID == input.suggestionID)
        #expect(presentation?.candidateSelectionMetadata["candidateSelectionSource"] == "app-model-result")
        #expect(presentation?.scheduledDelayMilliseconds == input.requestSchedule.scheduledDelayMilliseconds)
    }

    @Test("Suppresses a final result beyond the measured result budget")
    func suppressesLateResult() throws {
        let (orchestrator, baseInput, events) = try makeHostAndInput()
        let input = SuggestionModelResultInput(
            suggestionID: baseInput.suggestionID,
            request: baseInput.request,
            context: baseInput.context,
            profile: baseInput.profile,
            appBundleIdentifier: baseInput.appBundleIdentifier,
            fieldIdentity: baseInput.fieldIdentity,
            fieldClassification: baseInput.fieldClassification,
            fieldIdentityDescription: baseInput.fieldIdentityDescription,
            renderMode: baseInput.renderMode,
            requestMetadata: baseInput.requestMetadata,
            requestSchedule: SuggestionRequestSchedule(
                policyDelayMilliseconds: 0,
                scheduledDelayMilliseconds: 0,
                resultLatencyBudgetMilliseconds: 1_200,
                reason: "test"
            ),
            requestTicket: baseInput.requestTicket,
            requestStartedAt: Date(timeIntervalSinceNow: -1.3)
        )
        var hiddenReason: String?
        let host = hostWith(
            input: input,
            events: events,
            orchestrator: orchestrator,
            hideSuggestion: { reason in hiddenReason = reason }
        )

        host.handle(
            suggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            input: input
        )

        #expect(hiddenReason == "latency-budget-exceeded")
    }

    @Test("Keeps a visible streamed suggestion when the final model result is empty")
    func keepsVisibleStreamedSuggestionAfterEmptyResult() throws {
        let (orchestrator, input, events) = try makeHostAndInput()
        var repositioned = false
        let host = hostWith(
            input: input,
            events: events,
            orchestrator: orchestrator,
            hasVisibleSuggestion: { true },
            repositionVisibleSuggestion: { _, _ in repositioned = true }
        )

        host.handle(suggestion: nil, input: input)

        #expect(repositioned)
    }

    @Test("Blocks a final model result when no render anchor is available")
    func blocksMissingAnchor() throws {
        let (orchestrator, baseInput, events) = try makeHostAndInput()
        let context = FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Test"),
            textBeforeCursor: "draft",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: nil,
            windowRect: nil,
            windowIdentifier: 42,
            textLineRect: nil,
            textStyle: nil,
            isSecure: false,
            fieldClassification: baseInput.fieldClassification,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: true,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
        let input = SuggestionModelResultInput(
            suggestionID: baseInput.suggestionID,
            request: baseInput.request,
            context: context,
            profile: baseInput.profile,
            appBundleIdentifier: baseInput.appBundleIdentifier,
            fieldIdentity: baseInput.fieldIdentity,
            fieldClassification: baseInput.fieldClassification,
            fieldIdentityDescription: baseInput.fieldIdentityDescription,
            renderMode: baseInput.renderMode,
            requestMetadata: baseInput.requestMetadata,
            requestSchedule: baseInput.requestSchedule,
            requestTicket: baseInput.requestTicket,
            requestStartedAt: baseInput.requestStartedAt
        )
        var hidden = false
        let host = hostWith(
            input: input,
            events: events,
            orchestrator: orchestrator,
            hideSuggestion: { _ in hidden = true }
        )

        host.handle(
            suggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            input: input
        )

        #expect(hidden)
    }

    @Test("AppDelegate delegates final model-result handling to the host")
    func appDelegateUsesModelResultHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionModelResultHost"))
        #expect(source.contains("suggestionModelResultHost.handle("))
        #expect(!source.contains("let appModelResultMetadata = self.suggestionOrchestrator.appModelResultCandidateSelectionMetadata("))
    }

    private func makeHostAndInput() throws -> (
        SuggestionOrchestrator,
        SuggestionModelResultInput,
        SuggestionModelResultTestEvents
    ) {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "result"
        )
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let orchestration = orchestrator.beginRequest(request)
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let input = SuggestionModelResultInput(
            suggestionID: request.suggestionID,
            request: request,
            context: Self.makeContext(),
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
            requestTicket: orchestration.ticket,
            requestStartedAt: Date()
        )
        let events = SuggestionModelResultTestEvents()
        return (
            orchestrator,
            input,
            events
        )
    }

    private func hostWith(
        input: SuggestionModelResultInput,
        events: SuggestionModelResultTestEvents,
        orchestrator: SuggestionOrchestrator? = nil,
        currentSuggestionID: @escaping () -> String? = { "result" },
        currentFieldIdentity: @escaping () -> FocusedFieldIdentity? = {
            SuggestionModelResultHostTests.makeFieldIdentity()
        },
        hasVisibleSuggestion: @escaping () -> Bool = { false },
        repositionVisibleSuggestion: @escaping (FocusedTextContext, CompatibilityProfile) -> Void = { _, _ in },
        hideSuggestion: @escaping (String?) -> Void = { _ in },
        presentSuggestion: @escaping (CompletionSuggestion, SuggestionModelResultPresentation) -> Void = { _, _ in }
    ) -> SuggestionModelResultHost {
        SuggestionModelResultHost(
            dependencies: SuggestionModelResultHostDependencies(
                suggestionOrchestrator: orchestrator ?? SuggestionOrchestrator(engine: ModelResultTestCompletionEngine()),
                triggerTiming: SuggestionTriggerTimingPolicy(),
                currentSuggestionID: currentSuggestionID,
                currentFieldIdentity: currentFieldIdentity,
                hasVisibleSuggestion: hasVisibleSuggestion,
                recordSuggestionEvent: { event, _, _, _ in events.record(event) },
                setSuggestionDecision: { decision in events.record("decision:\(decision)") },
                repositionVisibleSuggestion: repositionVisibleSuggestion,
                hideSuggestion: hideSuggestion,
                annoyanceContext: { app, field, mode, kind in
                    AnnoyanceContext(
                        appBundleIdentifier: app,
                        fieldIdentifier: field?.traceDescription ?? "app",
                        requestMode: mode,
                        fieldKind: kind
                    )
                },
                recordAnnoyanceSignal: { signal, _, _, reason in events.record("annoyance:\(signal.rawValue):\(reason)") },
                presentSuggestion: presentSuggestion
            )
        )
    }

    private static func makeContext() -> FocusedTextContext {
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
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
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

    private static func makeFieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }
}

@MainActor
private final class SuggestionModelResultTestEvents {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

private struct ModelResultTestCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}
