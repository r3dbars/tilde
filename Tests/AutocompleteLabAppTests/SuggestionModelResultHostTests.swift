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
        #expect(source.contains("suggestionModelResultHost.handlePartial("))
        #expect(source.contains("suggestionModelResultHost.handleContinuationFailure("))
        #expect(!source.contains("let appModelResultMetadata = self.suggestionOrchestrator.appModelResultCandidateSelectionMetadata("))
    }

    // MARK: - handlePartial (merged from SuggestionStreamingPartialHost)

    @Test("Presents a useful current partial and reports its streaming metadata")
    func presentsUsefulPartial() throws {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "stream"
        )
        let fieldIdentity = Self.makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        var presented: (CompletionSuggestion, SuggestionStreamingPartialPresentation)?
        let host = hostWith(
            input: try makeHostAndInput().1,
            events: SuggestionModelResultTestEvents(),
            orchestrator: orchestrator,
            currentFieldIdentity: { fieldIdentity },
            presentStreamingPartial: { suggestion, presentation in
                presented = (suggestion, presentation)
            }
        )

        host.handlePartial(
            partialSuggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            suggestionID: "stream",
            request: request,
            context: Self.makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")),
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            renderMode: .inlineAdjacent,
            requestTicket: ticket,
            requestStartedAt: Date()
        )

        #expect(presented?.0.visibleText == " make steady progress")
        #expect(presented?.1.suggestionID == "stream")
        #expect(presented?.1.candidateSelectionMetadata["streamingPartialIndex"] == "1")
        #expect(presented?.1.latencyMilliseconds ?? -1 >= 0)
    }

    @Test("Drops a partial after the request field loses focus")
    func dropsStaleFieldPartial() throws {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "stream"
        )
        let requestField = Self.makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        var presentationCount = 0
        let host = hostWith(
            input: try makeHostAndInput().1,
            events: SuggestionModelResultTestEvents(),
            orchestrator: orchestrator,
            currentFieldIdentity: {
                FocusedFieldIdentity(
                    bundleIdentifier: "com.apple.Notes",
                    processIdentifier: 42,
                    elementIdentifier: 8
                )
            },
            presentStreamingPartial: { _, _ in presentationCount += 1 }
        )

        host.handlePartial(
            partialSuggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            suggestionID: "stream",
            request: request,
            context: Self.makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")),
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: requestField,
            renderMode: .inlineAdjacent,
            requestTicket: ticket,
            requestStartedAt: Date()
        )

        #expect(presentationCount == 0)
    }

    // MARK: - handleContinuationFailure (merged from SuggestionContinuationFailureHost)

    @Test("Hides a current request after a model continuation failure")
    func hidesCurrentRequestAfterFailure() throws {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = Self.makeFailureRequest()
        let fieldIdentity = Self.makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: request.suggestionID)

        let events = SuggestionModelResultTestEvents()
        let host = hostWith(
            input: try makeHostAndInput().1,
            events: events,
            orchestrator: orchestrator,
            currentSuggestionID: { request.suggestionID },
            currentFieldIdentity: { fieldIdentity },
            hasVisibleSuggestion: { false },
            repositionVisibleSuggestion: { _, _ in events.record("reposition") },
            hideSuggestion: { reason in events.record("hide:\(reason ?? "")") },
            updateKeyboardEventTapSnapshot: { events.record("keyboard") }
        )

        host.handleContinuationFailure(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: Self.makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(events.values == [
            "decision:\(SuggestionStatusText.notShown(reason: "engine-error"))",
            "hide:engine-error"
        ])
        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: "make steady progress", maxVisibleWords: 5),
            suggestionID: request.suggestionID,
            mode: request.mode,
            nowMilliseconds: 1
        ))
    }

    @Test("Keeps the visible instant phrase and refreshes native state after failure")
    func keepsVisibleInstantPhraseAfterFailure() throws {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = Self.makeFailureRequest()
        let fieldIdentity = Self.makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket

        let events = SuggestionModelResultTestEvents()
        let host = hostWith(
            input: try makeHostAndInput().1,
            events: events,
            orchestrator: orchestrator,
            currentSuggestionID: { request.suggestionID },
            currentFieldIdentity: { fieldIdentity },
            hasVisibleSuggestion: { true },
            repositionVisibleSuggestion: { _, _ in events.record("reposition") },
            hideSuggestion: { _ in events.record("hide") },
            updateKeyboardEventTapSnapshot: { events.record("keyboard") }
        )

        host.handleContinuationFailure(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: Self.makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(events.values == [
            "decision:Shown: kept instant phrase after model error",
            "reposition",
            "keyboard"
        ])
    }

    @Test("Leaves a stale field untouched after a model continuation failure")
    func leavesStaleFieldUntouched() throws {
        let orchestrator = SuggestionOrchestrator(engine: ModelResultTestCompletionEngine())
        let request = Self.makeFailureRequest()
        let fieldIdentity = Self.makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket

        var hideCalled = false
        let host = hostWith(
            input: try makeHostAndInput().1,
            events: SuggestionModelResultTestEvents(),
            orchestrator: orchestrator,
            currentSuggestionID: { request.suggestionID },
            currentFieldIdentity: {
                FocusedFieldIdentity(
                    bundleIdentifier: "com.apple.Notes",
                    processIdentifier: 42,
                    elementIdentifier: 8
                )
            },
            hasVisibleSuggestion: { true },
            hideSuggestion: { _ in hideCalled = true }
        )

        host.handleContinuationFailure(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: Self.makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(!hideCalled)
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
        presentSuggestion: @escaping (CompletionSuggestion, SuggestionModelResultPresentation) -> Void = { _, _ in },
        presentStreamingPartial: @escaping (CompletionSuggestion, SuggestionStreamingPartialPresentation) -> Void = { _, _ in },
        updateKeyboardEventTapSnapshot: @escaping () -> Void = {}
    ) -> SuggestionModelResultHost {
        SuggestionModelResultHost(
            dependencies: SuggestionModelResultHostDependencies(
                suggestionOrchestrator: orchestrator ?? SuggestionOrchestrator(engine: ModelResultTestCompletionEngine()),
                requestSchedulingPolicy: SuggestionRequestSchedulingPolicy(),
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
                presentSuggestion: presentSuggestion,
                presentStreamingPartial: presentStreamingPartial,
                updateKeyboardEventTapSnapshot: updateKeyboardEventTapSnapshot
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

    private static func makeFailureRequest() -> CompletionRequest {
        CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "failure"
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
