import Foundation
import AutocompleteLabCore

@MainActor
final class SuggestionOrchestrator {
    private let engineBox: CompletionEngineBox
    private let wordCompletionRanker: WordCompletionCandidateRanker
    private var requestGate = SuggestionRequestGate()
    private var currentRequestStorage: CompletionRequest?

    init(
        engine: any CompletionEngine,
        wordCompletionRanker: WordCompletionCandidateRanker = WordCompletionCandidateRanker()
    ) {
        self.engineBox = CompletionEngineBox(engine: engine)
        self.wordCompletionRanker = wordCompletionRanker
    }

    var currentRequest: CompletionRequest? {
        currentRequestStorage
    }

    var requestGateSnapshot: SuggestionRequestGate {
        requestGate
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
        return beginRequest(request)
    }

    func beginRequest(_ request: CompletionRequest) -> SuggestionOrchestration {
        currentRequestStorage = request
        return SuggestionOrchestration(
            suggestionID: request.suggestionID,
            request: request,
            ticket: requestGate.issue(request: request),
            startedAt: Date()
        )
    }

    func allows(_ ticket: SuggestionRequestTicket) -> Bool {
        requestGate.allows(ticket, currentRequest: currentRequestStorage)
    }

    func allows(
        _ ticket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        allows(ticket) && currentFieldIdentity == fieldIdentity
    }

    func invalidate() {
        currentRequestStorage = nil
        requestGate.invalidate()
    }

    func updateEngine(_ engine: any CompletionEngine) {
        engineBox.update(engine)
    }

    nonisolated func fastWordSuggestion(
        for textBeforeCursor: String,
        recentWords: [String]
    ) -> CompletionSuggestion? {
        fastWordSelection(
            for: textBeforeCursor,
            recentWords: recentWords
        ).suggestion
    }

    nonisolated func fastWordSelection(
        for textBeforeCursor: String,
        recentWords: [String]
    ) -> WordCompletionCandidateSelection {
        wordCompletionRanker.selection(
            for: textBeforeCursor,
            recentWords: recentWords
        )
    }

    nonisolated func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let engine = engineBox.current()
        return try await engine.suggestion(
            for: request,
            onPartialSuggestion: onPartialSuggestion
        )
    }
}

private final class CompletionEngineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: any CompletionEngine

    init(engine: any CompletionEngine) {
        self.engine = engine
    }

    func current() -> any CompletionEngine {
        lock.withLock {
            engine
        }
    }

    func update(_ engine: any CompletionEngine) {
        lock.withLock {
            self.engine = engine
        }
    }
}

struct SuggestionOrchestration: Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let ticket: SuggestionRequestTicket
    let startedAt: Date
}
