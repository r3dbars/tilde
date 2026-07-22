import Foundation
import Testing

@Suite("Live suggestion wiring")
struct LiveSuggestionWiringTests {
    @Test("App delegate wires product predictors and display policies through the orchestrator")
    func appDelegateWiresProductPredictorsAndDisplayPolicies() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let preparationHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionRequestPreparationHost.swift"
        )
        let streamingPartialHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionStreamingPartialHost.swift"
        )
        let requestExecutionHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionRequestExecutionHost.swift"
        )
        let schedulingHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift"
        )
        let presentationOrchestrationHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionPresentationOrchestrationHost.swift"
        )
        let suggestionWiring =
            appDelegate + preparationHost + streamingPartialHost + requestExecutionHost + schedulingHost + presentationOrchestrationHost

        try require(suggestionWiring, contains: "private lazy var suggestionOrchestrator = SuggestionOrchestrator(")
        try require(suggestionWiring, contains: "wordCompletionRanker: wordCompletionRanker")
        try require(suggestionWiring, contains: "suggestionAnnoyanceBackoffPolicy: makeSuggestionAnnoyanceBackoffPolicy()")
        try require(suggestionWiring, contains: "suggestionOrchestrator.beginRequest(SuggestionRequestInput(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.startStreamingPresentation(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.fastWordSelection(")
        try require(suggestionWiring, contains: "triggerReason: \"fast-word-completion\"")
        try require(suggestionWiring, contains: "suggestionOrchestrator.fastPhraseSelection(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.fastPhraseFallbackLearningDecision(")
        try require(suggestionWiring, contains: "triggerReason: \"canned-bridge\"")
        try require(suggestionWiring, contains: "try await suggestionOrchestrator.suggestion(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.shouldPresentStreamingPartial(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.displayScoreDecision(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.replacementDecision(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.placementHealthPlan(")
        try require(suggestionWiring, contains: "suggestionOrchestrator.placementSuppressionResolution(")
    }

    @Test("App delegate advances the visible suggestion through the type-through state machine")
    func appDelegateAdvancesVisibleSuggestionThroughTypeThroughStateMachine() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let preparationHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionPresentationPreparationHost.swift"
        )
        let suggestionPresentationWiring = appDelegate + preparationHost

        try require(suggestionPresentationWiring, contains: "private let typeThroughPrefixStateMachine = TypeThroughPrefixStateMachine()")
        try require(suggestionPresentationWiring, contains: "private func advanceVisibleSuggestionForTypingProgressIfNeeded(")
        try require(suggestionPresentationWiring, contains: "suggestionSession.applyTypeThrough(")
        try require(suggestionPresentationWiring, contains: "using: typeThroughPrefixStateMachine,")
        try require(suggestionPresentationWiring, contains: "case let .survived(survival):")
        try require(suggestionPresentationWiring, contains: "currentSuggestionState.displayedText = suggestionSession.visibleSuggestion?.visibleText")
        try require(suggestionPresentationWiring, contains: "\"Shown: typing through suggestion\"")
        try require(suggestionPresentationWiring, contains: "repositionVisibleSuggestion(context: context, profile: profile)")
        try require(suggestionPresentationWiring, contains: "passthroughTypingMatchObserver:")
        try require(suggestionPresentationWiring, contains: "observeOptimisticTypeThrough(transition)")
        try require(suggestionPresentationWiring, contains: "currentSuggestionState.invalidatedByUserKeyDown = false")
        try require(suggestionPresentationWiring, contains: "validator.validate(")
        try require(suggestionPresentationWiring, contains: "validator.trimmedSuggestion(")
    }

    @Test("App delegate forwards capture-policy screenshot authorization to the trace logger")
    func appDelegateForwardsScreenshotPathAuthorization() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let commitHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionPresentationCommitHost.swift"
        )

        try require(
            appDelegate + commitHost,
            contains: "screenshotPathAuthorized: screenshotCapture.screenshotPathAuthorized"
        )
    }

    @Test("App delegate rearms cancelled suggestions after typing settles")
    func appDelegateRearmsCancelledSuggestionsAfterTypingSettles() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let triggerTimingHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionTriggerTimingHost.swift"
        )
        let suggestionTriggerWiring = appDelegate + triggerTimingHost

        try require(suggestionTriggerWiring, contains: "suggestionIdleRetryState.consumeRetryIfReady(")
        try require(suggestionTriggerWiring, contains: "suggestionIdleRetryState.noteTextChange(")
        try require(suggestionTriggerWiring, contains: "suggestionIdleRetryState.noteTypingBurstSuppression(")
        try require(suggestionTriggerWiring, contains: "else if input.idleRetryReason != nil {")
        try require(suggestionTriggerWiring, contains: "? \"idle-retry\"")
    }

}

private func source(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func require(_ text: String, contains needle: String) throws {
    if !text.contains(needle) {
        Issue.record("Expected source to contain \(needle)")
    }
}
