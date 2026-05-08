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

    func acceptedTextStyleKey(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        textBeforeCursor: String
    ) -> AcceptedTextStyleMemoryKey {
        AcceptedTextStyleMemoryKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind,
            behaviorProfileID: behaviorProfileID(
                appBundleIdentifier: appBundleIdentifier,
                fieldKind: fieldKind,
                textBeforeCursor: textBeforeCursor
            )
        )
    }

    func beginRequest(_ input: SuggestionRequestInput) -> SuggestionOrchestration {
        let suggestionID = UUID().uuidString
        let fieldIdentityDescription = input.fieldIdentity.traceDescription
        let request = CompletionRequest(
            textBeforeCursor: input.context.textBeforeCursor,
            textAfterCursor: input.context.textAfterCursor,
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentityDescription: fieldIdentityDescription,
            fieldKind: input.fieldClassification.kind,
            behaviorProfileID: behaviorProfileID(
                appBundleIdentifier: input.appBundleIdentifier,
                fieldKind: input.fieldClassification.kind,
                textBeforeCursor: input.context.textBeforeCursor
            ),
            acceptedTextStyleSketch: input.acceptedTextStyleSketch,
            documentTitleShape: DocumentTitleShape.from(windowTitle: input.context.fingerprint.windowTitle),
            maxVisibleWords: input.maxVisibleWords,
            mode: input.requestMode,
            suggestionID: suggestionID
        )
        return beginRequest(
            request,
            fieldClassification: input.fieldClassification,
            suggestionAggressiveness: input.suggestionAggressiveness
        )
    }

    func beginRequest(_ request: CompletionRequest) -> SuggestionOrchestration {
        beginRequest(
            request,
            fieldClassification: nil,
            suggestionAggressiveness: nil
        )
    }

    private func beginRequest(
        _ request: CompletionRequest,
        fieldClassification: AXFieldClassification?,
        suggestionAggressiveness: SuggestionAggressiveness?
    ) -> SuggestionOrchestration {
        let runtimeSessionCacheDecision = RuntimeSessionCachePolicy().decision(
            previous: currentRequestStorage,
            current: request
        )
        var requestMetadata = request.behaviorProfileTraceMetadata
            .merging(runtimeSessionCacheDecision.traceMetadata) { current, _ in current }
        if let fieldClassification {
            requestMetadata.merge(fieldClassification.traceMetadata) { current, _ in current }
        }
        if let suggestionAggressiveness {
            requestMetadata.merge(suggestionAggressiveness.traceMetadata) { current, _ in current }
        }

        currentRequestStorage = request
        return SuggestionOrchestration(
            suggestionID: request.suggestionID,
            request: request,
            ticket: requestGate.issue(request: request),
            startedAt: Date(),
            fieldIdentityDescription: request.fieldIdentityDescription ?? "",
            requestMetadata: requestMetadata,
            runtimeSessionCacheDecision: runtimeSessionCacheDecision
        )
    }

    private func behaviorProfileID(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        textBeforeCursor: String
    ) -> AutocompleteBehaviorProfileID {
        AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind,
            currentLineStructure: CurrentLineStructure.from(textBeforeCursor: textBeforeCursor)
        )).id
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
    let fieldIdentityDescription: String
    let requestMetadata: [String: String]
    let runtimeSessionCacheDecision: RuntimeSessionCacheDecision
}

struct SuggestionRequestInput: Sendable {
    let context: FocusedTextContext
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let acceptedTextStyleSketch: AcceptedTextStyleSketch?
    let maxVisibleWords: Int
    let requestMode: CompletionRequestMode
    let suggestionAggressiveness: SuggestionAggressiveness
}
