import Foundation
import Testing

@Suite("Live suggestion wiring")
struct LiveSuggestionWiringTests {
    @Test("App delegate wires product predictors and display policies through the orchestrator")
    func appDelegateWiresProductPredictorsAndDisplayPolicies() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(appDelegate, contains: "private lazy var suggestionOrchestrator = SuggestionOrchestrator(")
        try require(appDelegate, contains: "wordCompletionRanker: wordCompletionRanker")
        try require(appDelegate, contains: "prefixFamilyCooldownPolicy: makePrefixFamilyCooldownPolicy()")
        try require(appDelegate, contains: "suggestionOrchestrator.beginRequest(SuggestionRequestInput(")
        try require(appDelegate, contains: "suggestionOrchestrator.startStreamingPresentation(suggestionID: suggestionID)")
        try require(appDelegate, contains: "suggestionOrchestrator.fastWordSelection(")
        try require(appDelegate, contains: "triggerReason: \"fast-word-completion\"")
        try require(appDelegate, contains: "suggestionOrchestrator.fastPhraseSelection(")
        try require(appDelegate, contains: "personalizationCoordinator.selection(")
        try require(appDelegate, contains: "personalContext: personalization.context")
        try require(appDelegate, contains: "personalWritingMemory: personalization.memory")
        try require(appDelegate, contains: "suggestionOrchestrator.fastPhraseFallbackLearningDecision(")
        try require(appDelegate, contains: "triggerReason: \"canned-bridge\"")
        try require(appDelegate, contains: "try await suggestionOrchestrator.suggestion(")
        try require(appDelegate, contains: "suggestionOrchestrator.shouldPresentStreamingPartial(")
        try require(appDelegate, contains: "suggestionOrchestrator.displayScoreDecision(")
        try require(appDelegate, contains: "suggestionOrchestrator.replacementDecision(")
        try require(appDelegate, contains: "suggestionOrchestrator.placementHealthPlan(")
        try require(appDelegate, contains: "suggestionOrchestrator.placementSuppressionResolution(")
    }

    @Test("Coverage manifest invokes public core reachability check")
    func coverageManifestInvokesPublicCoreReachabilityCheck() throws {
        let coverageCheck = try source("script/check_test_coverage_manifest.sh")

        try require(coverageCheck, contains: "./script/check_public_core_wiring.py")
    }

    @Test("App delegate advances the visible suggestion through the type-through state machine")
    func appDelegateAdvancesVisibleSuggestionThroughTypeThroughStateMachine() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(appDelegate, contains: "private let typeThroughPrefixStateMachine = TypeThroughPrefixStateMachine()")
        try require(appDelegate, contains: "private func advanceVisibleSuggestionForTypingProgressIfNeeded(")
        try require(appDelegate, contains: "typeThroughPrefixStateMachine.apply(")
        try require(appDelegate, contains: "to: &suggestionSession,")
        try require(appDelegate, contains: "case let .survived(survival):")
        try require(appDelegate, contains: "currentSuggestionState.displayedText = suggestionSession.visibleSuggestion?.visibleText")
        try require(appDelegate, contains: "\"Shown: typing through suggestion\"")
        try require(appDelegate, contains: "repositionVisibleSuggestion(context: context, profile: profile)")
        try require(appDelegate, contains: "reason: \"survived_typethrough\"")
        try require(appDelegate, contains: "passthroughTypingMatchObserver:")
        try require(appDelegate, contains: "observeOptimisticTypeThrough(transition)")
        try require(appDelegate, contains: "currentSuggestionState.invalidatedByUserKeyDown = false")
        try require(appDelegate, contains: "LateResultContextValidator().trimmedSuggestion(")
    }

    @Test("App delegate forwards capture-policy screenshot authorization to the trace logger")
    func appDelegateForwardsScreenshotPathAuthorization() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(
            appDelegate,
            contains: "screenshotPathAuthorized: screenshotCapture.screenshotPathAuthorized"
        )
    }

    @Test("Personal capture uses authoritative app support status before AX reads")
    func personalCaptureUsesAuthoritativeSupportStatus() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(
            appDelegate,
            contains: "supportStatus: profileStore.supportStatus(for: app.bundleIdentifier)"
        )
    }

    @Test("App delegate rearms cancelled suggestions after typing settles")
    func appDelegateRearmsCancelledSuggestionsAfterTypingSettles() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(appDelegate, contains: "suggestionIdleRetryState.consumeRetryIfReady(")
        try require(appDelegate, contains: "suggestionIdleRetryState.noteTextChange(")
        try require(appDelegate, contains: "suggestionIdleRetryState.noteTypingBurstSuppression(")
        try require(appDelegate, contains: "else if idleRetryReason != nil {")
        try require(appDelegate, contains: "? \"idle-retry\"")
    }

    @Test("App delegate preserves and rechecks transient Codex prompt targets")
    func appDelegatePreservesAndRechecksTransientCodexPromptTargets() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")

        try require(appDelegate, contains: "shouldDeferCodexPromptTargetInvalidation(")
        try require(appDelegate, contains: "\"codex-prompt-target-refresh-deferred\"")
        try require(appDelegate, contains: "scheduleCodexPromptPresentationRefreshRetry(")
        try require(appDelegate, contains: "codexPromptPresentationRetryTask?.cancel()")
        try require(appDelegate, contains: "canPreserveDuringAXCooldown(")
        try require(appDelegate, contains: "preservePendingRequest: shouldPreservePendingRequest")
        try require(appDelegate, contains: "codexPromptAXCooldownPresentationDelayMilliseconds(")
        try require(appDelegate, contains: "scheduleCodexPromptPresentationAfterAXCooldown(")
        try require(appDelegate, contains: "codex-prompt-presentation-deferred-for-ax-cooldown")
        try require(appDelegate, contains: "options: FocusedTextReadOptionsPolicy.options(for: frontmostApp, profile: profile)")
        try require(appDelegate, contains: "fieldStatusIndicator.hide()")
        try require(appDelegate, contains: "switch codexPromptPresentationPreparationPolicy.preparation(")
        try require(appDelegate, contains: "case let .deferForAXCooldown(delayMilliseconds):")
        try require(appDelegate, contains: "case .refreshFocusedContext:")
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
