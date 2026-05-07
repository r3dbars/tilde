import Foundation
import AutocompleteLabCore

@MainActor
final class SuggestionOrchestrator {
    private let engine: any CompletionEngine
    private let wordCompletionRanker: WordCompletionCandidateRanker
    private var requestGate = SuggestionRequestGate()
    private var currentRequest: CompletionRequest?

    init(
        engine: any CompletionEngine,
        wordCompletionRanker: WordCompletionCandidateRanker = WordCompletionCandidateRanker()
    ) {
        self.engine = engine
        self.wordCompletionRanker = wordCompletionRanker
    }

    func beginRequest(
        textBeforeCursor: String,
        textAfterCursor: String,
        appBundleIdentifier: String,
        maxVisibleWords: Int,
        requestMode: CompletionRequestMode
    ) -> SuggestionOrchestration {
        let suggestionID = UUID().uuidString
        let request = CompletionRequest(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            appBundleIdentifier: appBundleIdentifier,
            maxVisibleWords: maxVisibleWords,
            mode: requestMode,
            suggestionID: suggestionID
        )
        currentRequest = request

        return SuggestionOrchestration(
            suggestionID: suggestionID,
            request: request,
            ticket: requestGate.issue(request: request),
            startedAt: Date()
        )
    }

    func allows(_ ticket: SuggestionRequestTicket) -> Bool {
        requestGate.allows(ticket, currentRequest: currentRequest)
    }

    func invalidate() {
        currentRequest = nil
        requestGate.invalidate()
    }

    nonisolated func fastWordSuggestion(
        for textBeforeCursor: String,
        recentWords: [String]
    ) -> CompletionSuggestion? {
        wordCompletionRanker.suggestion(
            for: textBeforeCursor,
            recentWords: recentWords
        )
    }

    nonisolated func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        try await engine.suggestion(
            for: request,
            onPartialSuggestion: onPartialSuggestion
        )
    }
}

struct SuggestionOrchestration: Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let ticket: SuggestionRequestTicket
    let startedAt: Date
}
