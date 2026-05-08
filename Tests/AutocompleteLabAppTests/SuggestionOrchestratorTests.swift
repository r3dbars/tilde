import Foundation
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
