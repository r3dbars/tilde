import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion streaming partial host")
struct SuggestionStreamingPartialHostTests {
    @Test("Presents a useful current partial and reports its streaming metadata")
    func presentsUsefulPartial() throws {
        let orchestrator = SuggestionOrchestrator(engine: StreamingPartialTestCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "stream"
        )
        let fieldIdentity = makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        var presented: (CompletionSuggestion, SuggestionStreamingPartialPresentation)?
        let host = SuggestionStreamingPartialHost(
            dependencies: SuggestionStreamingPartialHostDependencies(
                suggestionOrchestrator: orchestrator,
                currentFieldIdentity: { fieldIdentity },
                presentSuggestion: { suggestion, presentation in
                    presented = (suggestion, presentation)
                }
            )
        )

        host.handle(
            partialSuggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            suggestionID: "stream",
            request: request,
            context: makeContext(),
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
        let orchestrator = SuggestionOrchestrator(engine: StreamingPartialTestCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.apple.TextEdit",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "stream"
        )
        let requestField = makeFieldIdentity()
        let ticket = orchestrator.beginRequest(request).ticket
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        var presentationCount = 0
        let host = SuggestionStreamingPartialHost(
            dependencies: SuggestionStreamingPartialHostDependencies(
                suggestionOrchestrator: orchestrator,
                currentFieldIdentity: { FocusedFieldIdentity(
                    bundleIdentifier: "com.apple.Notes",
                    processIdentifier: 42,
                    elementIdentifier: 8
                ) },
                presentSuggestion: { _, _ in presentationCount += 1 }
            )
        )

        host.handle(
            partialSuggestion: CompletionSuggestion(text: " make steady progress", maxVisibleWords: 5),
            suggestionID: "stream",
            request: request,
            context: makeContext(),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")),
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: requestField,
            renderMode: .inlineAdjacent,
            requestTicket: ticket,
            requestStartedAt: Date()
        )

        #expect(presentationCount == 0)
    }

    @Test("AppDelegate delegates partial streaming to the host")
    func appDelegateUsesStreamingPartialHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionStreamingPartialHost"))
        #expect(source.contains("suggestionStreamingPartialHost.handle("))
        #expect(!source.contains("suggestionOrchestrator.shouldPresentStreamingPartial("))
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

private struct StreamingPartialTestCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}
