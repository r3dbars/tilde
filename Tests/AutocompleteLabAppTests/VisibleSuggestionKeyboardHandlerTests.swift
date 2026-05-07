import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Visible suggestion keyboard handler")
struct VisibleSuggestionKeyboardHandlerTests {
    @Test("No visible suggestion passes through and clears key suppression")
    func noVisibleSuggestionPassesThroughAndClearsSuppression() {
        var handler = VisibleSuggestionKeyboardHandler()
        var state = VisibleSuggestionState()
        let now = Date()
        handler.suppressKey(.tab, now: now)

        let hiddenPlan = handler.plan(
            for: .tab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &state,
            context: context(),
            now: now.addingTimeInterval(0.1)
        )
        let repeatPlan = handler.plan(
            for: .tab,
            isAutorepeat: true,
            didObservePassthroughKeyDown: false,
            state: &state,
            context: context(),
            now: now.addingTimeInterval(0.11)
        )

        #expect(hiddenPlan == .noVisibleSuggestion)
        #expect(repeatPlan == .noVisibleSuggestion)
    }

    @Test("Focus mismatch asks caller to hide and pass through")
    func focusMismatchHidesAndPassesThrough() {
        var handler = VisibleSuggestionKeyboardHandler()
        var state = visibleState()

        let plan = handler.plan(
            for: .tab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &state,
            context: context(focusedFieldMatchesCurrentSuggestion: false)
        )

        #expect(
            plan == .hideAndPassThrough(
                action: .passThrough,
                decision: "Blocked: focus changed",
                reason: "focus-changed"
            )
        )
    }

    @Test("Passthrough typing marks stale visible suggestion")
    func passthroughTypingMarksStaleVisibleSuggestion() {
        var handler = VisibleSuggestionKeyboardHandler()
        var state = visibleState()

        let plan = handler.plan(
            for: .tab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: true,
            state: &state,
            context: context()
        )

        #expect(state.isInvalidatedByUserKeyDown)
        #expect(
            plan == .hideAndPassThrough(
                action: .passThrough,
                decision: "Blocked: stale suggestion passed through",
                reason: "stale-after-keydown"
            )
        )
    }

    @Test("Unsupported one word acceptance passes through")
    func unsupportedOneWordAcceptancePassesThrough() {
        var handler = VisibleSuggestionKeyboardHandler()
        var state = visibleState()

        let plan = handler.plan(
            for: .tab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &state,
            context: context(supportsOneWordAcceptance: false)
        )

        #expect(
            plan == .passThrough(
                action: .acceptNextWord,
                reason: "unsupported-one-word",
                shouldRecord: true
            )
        )
    }

    @Test("Supported acceptance plans include visible text")
    func supportedAcceptancePlansIncludeVisibleText() {
        var handler = VisibleSuggestionKeyboardHandler()
        var nextWordState = visibleState()
        var allVisibleState = visibleState()

        let nextWordPlan = handler.plan(
            for: .tab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &nextWordState,
            context: context()
        )
        let allVisiblePlan = handler.plan(
            for: .backtick,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &allVisibleState,
            context: context()
        )

        #expect(nextWordPlan == .acceptNextWord(" world"))
        #expect(allVisiblePlan == .acceptAllVisible(" world again"))
    }

    @Test("Dismiss and pass-through keys are routed without accepting")
    func dismissAndPassThroughKeysRouteWithoutAccepting() {
        var handler = VisibleSuggestionKeyboardHandler()
        var escapeState = visibleState()
        var optionTabState = visibleState()

        let dismissPlan = handler.plan(
            for: .escape,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &escapeState,
            context: context()
        )
        let passThroughPlan = handler.plan(
            for: .optionTab,
            isAutorepeat: false,
            didObservePassthroughKeyDown: false,
            state: &optionTabState,
            context: context()
        )

        #expect(dismissPlan == .dismiss)
        #expect(
            passThroughPlan == .passThrough(
                action: .passThrough,
                reason: "pass-through",
                shouldRecord: true
            )
        )
    }

    @Test("Suppressed autorepeat is handled until the suppression window expires")
    func suppressedAutorepeatIsHandledUntilExpired() {
        var handler = VisibleSuggestionKeyboardHandler()
        let now = Date()
        handler.suppressKey(.tab, now: now)
        var suppressedState = visibleState()
        var expiredState = visibleState()

        let suppressedPlan = handler.plan(
            for: .tab,
            isAutorepeat: true,
            didObservePassthroughKeyDown: false,
            state: &suppressedState,
            context: context(),
            now: now.addingTimeInterval(0.1)
        )
        let expiredPlan = handler.plan(
            for: .tab,
            isAutorepeat: true,
            didObservePassthroughKeyDown: false,
            state: &expiredState,
            context: context(),
            now: now.addingTimeInterval(0.3)
        )

        #expect(suppressedPlan == .suppressAutorepeat)
        #expect(expiredPlan == .acceptNextWord(" world"))
    }

    private func visibleState() -> VisibleSuggestionState {
        var state = VisibleSuggestionState()
        state.present(
            CompletionSuggestion(text: " world again", maxVisibleWords: 3),
            suggestionID: "suggestion-1",
            appBundleIdentifier: "com.example.Editor",
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.example.Editor",
                processIdentifier: 42,
                elementIdentifier: 7
            ),
            requestMode: .phraseContinuation,
            textBeforeCursor: "hello"
        )
        return state
    }

    private func context(
        focusedFieldMatchesCurrentSuggestion: Bool = true,
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = true,
        shortcutConfiguration: KeyboardShortcutConfiguration = .default
    ) -> VisibleSuggestionKeyboardContext {
        VisibleSuggestionKeyboardContext(
            focusedFieldMatchesCurrentSuggestion: focusedFieldMatchesCurrentSuggestion,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            shortcutConfiguration: shortcutConfiguration
        )
    }
}
