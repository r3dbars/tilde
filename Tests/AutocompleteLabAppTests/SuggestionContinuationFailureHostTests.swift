import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion continuation failure host")
struct SuggestionContinuationFailureHostTests {
    @Test("Hides a current request after a model continuation failure")
    func hidesCurrentRequestAfterFailure() throws {
        let orchestrator = SuggestionOrchestrator(engine: ContinuationFailureTestCompletionEngine())
        let request = makeRequest()
        let fieldIdentity = makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: request.suggestionID)

        var events: [String] = []
        let host = makeHost(
            orchestrator: orchestrator,
            currentSuggestionID: { request.suggestionID },
            currentFieldIdentity: { fieldIdentity },
            hasVisibleSuggestion: { false },
            setSuggestionDecision: { events.append("decision:\($0)") },
            repositionVisibleSuggestion: { _, _ in events.append("reposition") },
            updateKeyboardEventTapSnapshot: { events.append("keyboard") },
            hideSuggestion: { events.append("hide:\($0)") }
        )

        host.handle(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(events == [
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
        let orchestrator = SuggestionOrchestrator(engine: ContinuationFailureTestCompletionEngine())
        let request = makeRequest()
        let fieldIdentity = makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket

        var events: [String] = []
        let host = makeHost(
            orchestrator: orchestrator,
            currentSuggestionID: { request.suggestionID },
            currentFieldIdentity: { fieldIdentity },
            hasVisibleSuggestion: { true },
            setSuggestionDecision: { events.append("decision:\($0)") },
            repositionVisibleSuggestion: { _, _ in events.append("reposition") },
            updateKeyboardEventTapSnapshot: { events.append("keyboard") },
            hideSuggestion: { _ in events.append("hide") }
        )

        host.handle(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(events == [
            "decision:Shown: kept instant phrase after model error",
            "reposition",
            "keyboard"
        ])
    }

    @Test("Leaves a stale field untouched after a model continuation failure")
    func leavesStaleFieldUntouched() throws {
        let orchestrator = SuggestionOrchestrator(engine: ContinuationFailureTestCompletionEngine())
        let request = makeRequest()
        let fieldIdentity = makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket

        var hideCalled = false
        let host = makeHost(
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
            setSuggestionDecision: { _ in },
            repositionVisibleSuggestion: { _, _ in },
            updateKeyboardEventTapSnapshot: {},
            hideSuggestion: { _ in hideCalled = true }
        )

        host.handle(
            suggestionID: request.suggestionID,
            requestTicket: ticket,
            fieldIdentity: fieldIdentity,
            context: makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        )

        #expect(!hideCalled)
    }

    @Test("AppDelegate delegates continuation failure cleanup to the host")
    func appDelegateUsesContinuationFailureHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionContinuationFailureHost"))
        #expect(source.contains("suggestionContinuationFailureHost.handle("))
        #expect(!source.contains("shouldKeepVisibleSuggestionAfterModelContinuationFailure("))
    }

    private func makeHost(
        orchestrator: SuggestionOrchestrator,
        currentSuggestionID: @escaping () -> String?,
        currentFieldIdentity: @escaping () -> FocusedFieldIdentity?,
        hasVisibleSuggestion: @escaping () -> Bool,
        setSuggestionDecision: @escaping (String) -> Void,
        repositionVisibleSuggestion: @escaping (FocusedTextContext, CompatibilityProfile) -> Void,
        updateKeyboardEventTapSnapshot: @escaping () -> Void,
        hideSuggestion: @escaping (String) -> Void
    ) -> SuggestionContinuationFailureHost {
        SuggestionContinuationFailureHost(
            dependencies: SuggestionContinuationFailureHostDependencies(
                suggestionOrchestrator: orchestrator,
                currentSuggestionID: currentSuggestionID,
                currentFieldIdentity: currentFieldIdentity,
                hasVisibleSuggestion: hasVisibleSuggestion,
                setSuggestionDecision: setSuggestionDecision,
                repositionVisibleSuggestion: repositionVisibleSuggestion,
                updateKeyboardEventTapSnapshot: updateKeyboardEventTapSnapshot,
                hideSuggestion: hideSuggestion
            )
        )
    }

    private func makeRequest() -> CompletionRequest {
        CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "failure"
        )
    }

    private func makeFieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
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
}

private struct ContinuationFailureTestCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}
