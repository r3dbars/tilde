import Foundation
import CoreGraphics
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Suggestion orchestrator")
struct SuggestionOrchestratorTests {
    @MainActor
    @Test("Beginning a request stores rich request metadata and allows its ticket")
    func beginRequestStoresRequestAndAllowsTicket() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            textAfterCursor: "?",
            appBundleIdentifier: "com.example.editor",
            fieldIdentityDescription: "field:compose",
            fieldKind: .multilineCompose,
            behaviorProfileID: .docsProse,
            documentTitleShape: DocumentTitleShape.from(windowTitle: "Design notes"),
            maxVisibleWords: 7,
            mode: .sentenceContinuation,
            suggestionID: "suggestion-1"
        )

        let orchestration = orchestrator.beginRequest(request)

        #expect(orchestration.suggestionID == "suggestion-1")
        #expect(orchestration.request == request)
        #expect(orchestration.ticket.request == request)
        #expect(orchestrator.currentRequest == request)
        #expect(orchestrator.allows(orchestration.ticket))
    }

    @MainActor
    @Test("Rich input builds request profile metadata and style sketch")
    func richInputBuildsRequestProfileMetadataAndStyleSketch() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        var styleStore = AcceptedTextStyleMemoryStore()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let context = makeContext(
            textBeforeCursor: "- Can we",
            textAfterCursor: "?",
            windowTitle: "Plan.md"
        )
        let styleKey = orchestrator.acceptedTextStyleKey(
            appBundleIdentifier: "com.example.editor",
            fieldKind: classification.kind,
            textBeforeCursor: context.textBeforeCursor
        )
        let sketch = styleStore.recordKeptText(" finish this.", key: styleKey)

        let orchestration = orchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: sketch,
            maxVisibleWords: 7,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .quiet
        ))

        #expect(styleKey.behaviorProfile == AutocompleteBehaviorProfileID.bullets.rawValue)
        #expect(orchestration.request.textBeforeCursor == "- Can we")
        #expect(orchestration.request.textAfterCursor == "?")
        #expect(orchestration.request.appBundleIdentifier == "com.example.editor")
        #expect(orchestration.request.fieldIdentityDescription == field.traceDescription)
        #expect(orchestration.request.fieldKind == .multilineCompose)
        #expect(orchestration.request.behaviorProfileID == .bullets)
        #expect(orchestration.request.acceptedTextStyleSketch == sketch)
        #expect(orchestration.request.documentTitleShape?.fileExtension == "md")
        #expect(orchestration.request.maxVisibleWords == 7)
        #expect(orchestration.request.mode == .phraseContinuation)
        #expect(orchestration.fieldIdentityDescription == field.traceDescription)
        #expect(orchestration.requestMetadata["behaviorProfile"] == "bullets")
        #expect(orchestration.requestMetadata["fieldKind"] == "multilineCompose")
        #expect(orchestration.requestMetadata["fieldKindReason"] == "test-compose")
        #expect(orchestration.requestMetadata["suggestionAggressiveness"] == "quiet")
        #expect(orchestration.requestMetadata["runtimeSessionCacheDecision"] == "reset")
        #expect(orchestration.requestMetadata["runtimeSessionCacheResetReason"] == "no-prior-request")
        #expect(orchestrator.allows(orchestration.ticket))
    }

    @MainActor
    @Test("Rich input records runtime session cache reuse metadata")
    func richInputRecordsRuntimeSessionCacheReuseMetadata() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")

        _ = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(textBeforeCursor: "The plan", textAfterCursor: ""),
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .normal
        ))
        let second = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(textBeforeCursor: "The plan is", textAfterCursor: ""),
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .normal
        ))

        #expect(second.runtimeSessionCacheDecision.canReuse)
        #expect(second.requestMetadata["runtimeSessionCacheEligible"] == "true")
        #expect(second.requestMetadata["runtimeSessionCacheDecision"] == "reuse")
        #expect(second.requestMetadata["runtimeSessionCacheKey"]?.contains(field.traceDescription) == true)
    }

    @MainActor
    @Test("A newer request blocks an older request ticket")
    func newerRequestBlocksOlderTicket() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let first = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "first")
        let second = CompletionRequest(textBeforeCursor: "Can we make", suggestionID: "second")

        let firstTicket = orchestrator.beginRequest(first).ticket
        let secondTicket = orchestrator.beginRequest(second).ticket

        #expect(!orchestrator.allows(firstTicket))
        #expect(orchestrator.allows(secondTicket))
        #expect(orchestrator.currentRequest == second)
    }

    @MainActor
    @Test("Field delivery guard blocks stale field results")
    func fieldDeliveryGuardBlocksStaleFieldResults() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "field")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let otherField = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 8
        )

        #expect(orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: field))
        #expect(!orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: otherField))
        #expect(!orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: nil))
    }

    @MainActor
    @Test("Invalidating clears the current request and blocks stale tickets")
    func invalidateClearsCurrentRequestAndBlocksTickets() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let ticket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we", suggestionID: "stale")
        ).ticket

        orchestrator.invalidate()

        #expect(orchestrator.currentRequest == nil)
        #expect(!orchestrator.allows(ticket))
    }

    @MainActor
    @Test("Fast word selection exposes candidate metadata")
    func fastWordSelectionExposesMetadata() {
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            wordCompletionRanker: WordCompletionCandidateRanker(staticWords: ["dictation"])
        )

        let selection = orchestrator.fastWordSelection(for: "dic", recentWords: [])

        #expect(selection.suggestion?.visibleText == "tation")
        #expect(selection.candidateCount == 1)
        #expect(selection.traceMetadata["candidateSelectionSource"] == "fast-word-completion")
        #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
    }

    @MainActor
    @Test("Suggestion calls delegate to the configured engine")
    func suggestionDelegatesToEngine() async throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            maxVisibleWords: 3,
            mode: .phraseContinuation
        )
        let partials = PartialRecorder()

        let suggestion = try await orchestrator.suggestion(for: request) { partial in
            partials.append(partial)
        }

        #expect(partials.visibleTexts == [" make"])
        #expect(suggestion?.visibleText == " make this feel")
    }

    @MainActor
    @Test("Updating the engine changes future suggestions")
    func updateEngineChangesFutureSuggestions() async throws {
        let orchestrator = SuggestionOrchestrator(engine: FixedCompletionEngine(text: " old path"))
        let request = CompletionRequest(textBeforeCursor: "Can we", maxVisibleWords: 3)

        let first = try await orchestrator.suggestion(for: request) { _ in }
        orchestrator.updateEngine(FixedCompletionEngine(text: " new path"))
        let second = try await orchestrator.suggestion(for: request) { _ in }

        #expect(first?.visibleText == " old path")
        #expect(second?.visibleText == " new path")
    }
}

private final class PartialRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var suggestions: [CompletionSuggestion] = []

    var visibleTexts: [String] {
        lock.withLock {
            suggestions.map(\.visibleText)
        }
    }

    func append(_ suggestion: CompletionSuggestion) {
        lock.withLock {
            suggestions.append(suggestion)
        }
    }
}

private struct EchoCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        CompletionSuggestion(text: " make this feel instant", maxVisibleWords: request.maxVisibleWords)
    }

    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        onPartialSuggestion(CompletionSuggestion(text: " make", maxVisibleWords: request.maxVisibleWords))
        return try await suggestion(for: request)
    }
}

private struct FixedCompletionEngine: CompletionEngine {
    let text: String

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        CompletionSuggestion(text: text, maxVisibleWords: request.maxVisibleWords)
    }
}

private func makeContext(
    textBeforeCursor: String,
    textAfterCursor: String,
    windowTitle: String? = nil
) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 7,
        role: "AXTextArea",
        subrole: nil,
        fingerprint: FocusedElementFingerprint(windowTitle: windowTitle),
        textBeforeCursor: textBeforeCursor,
        textAfterCursor: textAfterCursor,
        selectedTextLength: 0,
        caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect(x: 0, y: 0, width: 400, height: 200),
        windowRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        textLineRect: CGRect(x: 10, y: 10, width: 120, height: 18),
        textStyle: nil,
        isSecure: false,
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
