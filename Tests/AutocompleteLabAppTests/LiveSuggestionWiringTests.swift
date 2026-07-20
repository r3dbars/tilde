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
        try require(suggestionWiring, contains: "personalizationCoordinator.selection(")
        try require(suggestionWiring, contains: "personalContext: personalization.context")
        try require(suggestionWiring, contains: "personalWritingMemory: personalization.memory")
        try require(suggestionWiring, contains: "\"instantPhraseAlwaysOn\": \"true\"")
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
        try require(suggestionPresentationWiring, contains: "reason: \"survived_typethrough\"")
        try require(suggestionPresentationWiring, contains: "passthroughTypingMatchObserver:")
        try require(suggestionPresentationWiring, contains: "observeOptimisticTypeThrough(transition)")
        try require(
            suggestionPresentationWiring,
            contains: "hideSuggestion(reason: \"optimistic-type-through-mismatch\")"
        )
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
        let triggerTimingHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionTriggerTimingHost.swift"
        )
        let suggestionTriggerWiring = appDelegate + triggerTimingHost

        try require(suggestionTriggerWiring, contains: "suggestionIdleRetryState.consumeRetryIfReady(")
        try require(suggestionTriggerWiring, contains: "suggestionIdleRetryState.noteTextChange(")
        try require(suggestionTriggerWiring, contains: "else if input.idleRetryReason != nil {")
        try require(suggestionTriggerWiring, contains: "? \"idle-retry\"")
    }

    @Test("Normal typing never enters a burst suppression path")
    func normalTypingNeverUsesBurstSuppression() throws {
        let sources = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
            + source("Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift")
            + source("Sources/AutocompleteLabApp/App/SuggestionTriggerTimingHost.swift")

        #expect(!sources.contains("typingBurst"))
        #expect(!sources.contains("typing-burst"))
    }

    @Test("Typing past an instant suggestion records the outcome without silencing future suggestions")
    func typedOverDoesNotCreateLiveSuppression() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let start = try #require(appDelegate.range(of: "private func recordTypedOverSuggestionIfNeeded("))
        let end = try #require(appDelegate.range(
            of: "private func advanceVisibleSuggestionForTypingProgressIfNeeded(",
            range: start.upperBound..<appDelegate.endIndex
        ))
        let typedOverHandler = appDelegate[start.lowerBound..<end.lowerBound]

        #expect(typedOverHandler.contains("suggestionTypedOver"))
        #expect(!typedOverHandler.contains("recordPrefixFamilyCooldown"))
        #expect(!typedOverHandler.contains("recordAnnoyanceSignal"))
    }

    @Test("Dogfood composers measure synthetic carets with the focused text style")
    func dogfoodComposersUseFocusedTextStyleForSyntheticCarets() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let start = try #require(appDelegate.range(
            of: "if PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(bundleIdentifier) {"
        ))
        let end = try #require(appDelegate.range(
            of: "guard bundleIdentifier == \"com.google.Chrome\" else {",
            range: start.upperBound..<appDelegate.endIndex
        ))
        let dogfoodTuning = appDelegate[start.lowerBound..<end.lowerBound]

        #expect(dogfoodTuning.contains("font: nil"))
        #expect(!dogfoodTuning.contains("ofSize: 15"))
    }

    @Test("App delegate preserves and rechecks transient Codex prompt targets")
    func appDelegatePreservesAndRechecksTransientCodexPromptTargets() throws {
        let appDelegate = try source("Sources/AutocompleteLabApp/App/AppDelegate.swift")
        let refreshHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionPresentationRefreshHost.swift"
        )
        let orchestrationHost = try source(
            "Sources/AutocompleteLabApp/App/SuggestionPresentationOrchestrationHost.swift"
        )
        let suggestionPresentationWiring = appDelegate + refreshHost + orchestrationHost

        try require(suggestionPresentationWiring, contains: "codexPromptTargetInvalidationResolution(")
        try require(suggestionPresentationWiring, contains: "promptTargetInvalidationResolution == .cancelAndRetry")
        try require(suggestionPresentationWiring, contains: "cancelAndRearmCodexPromptTargetWork(")
        try require(suggestionPresentationWiring, contains: "codex-prompt-target-refresh-quarantined")
        try require(suggestionPresentationWiring, contains: "\"presentation-refresh\"")
        try require(suggestionPresentationWiring, contains: "return (nil, \"quarantined-codex-prompt-target\")")
        try require(appDelegate, contains: "axHealthInvalidationResolution(")
        try require(appDelegate, contains: "rearmedTransientRequest")
        try require(appDelegate, contains: "\"codex-prompt-target-refresh-deferred\"")
        try require(appDelegate, contains: "scheduleCodexPromptPresentationRefreshRetry(")
        try require(appDelegate, contains: "codexPromptPresentationRetryHost.schedule(afterMilliseconds:")
        try require(appDelegate, contains: "codexPromptPresentationRetryHost.cancel()")
        try require(appDelegate, contains: "canPreserveDuringAXCooldown(")
        try require(appDelegate, contains: "preservePendingRequest: shouldPreservePendingRequest")
        try require(appDelegate, contains: "codexPromptAXCooldownPresentationDelayMilliseconds(")
        try require(appDelegate, contains: "scheduleCodexPromptPresentationAfterAXCooldown(")
        try require(appDelegate, contains: "codex-prompt-presentation-deferred-for-ax-cooldown")
        try require(appDelegate, contains: "options: FocusedTextReadOptionsPolicy.options(for: frontmostApp, profile: profile)")
        try require(appDelegate, contains: "return self.claudeCodeTerminalHostProofBlockReason(")
        try require(
            appDelegate,
            contains: "options: FocusedTextReadOptionsPolicy.options(\n                      for: frontmostApp,\n                      profile: profile\n                  )"
        )
        try require(appDelegate, contains: "suggestionChromeHost.hideFieldStatusIndicator()")
        try require(suggestionPresentationWiring, contains: "switch codexPromptTargetContinuityHost.presentationPreparationPolicy.preparation(")
        try require(suggestionPresentationWiring, contains: "case let .deferForAXCooldown(delayMilliseconds):")
        try require(suggestionPresentationWiring, contains: "case .refreshFocusedContext:")
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
