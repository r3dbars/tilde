import Testing
@testable import AutocompleteLabApp

@Suite("Accessibility observer event routing")
struct AccessibilityObserverEventRoutingTests {
    @Test("Focus changes reclassify the focused context")
    func focusChangesReclassifyFocusedContext() {
        let router = AccessibilityObserverEventRouter()

        #expect(router.route(.focusedUIElementChanged) == .reclassifyFocusedContext)
        #expect(router.route(.focusedWindowChanged) == .reclassifyFocusedContext)
    }

    @Test("Text and window geometry changes refresh the current field")
    func textAndWindowChangesRefreshGeometry() {
        let router = AccessibilityObserverEventRouter()

        #expect(router.route(.selectedTextChanged) == .refreshFocusedGeometry)
        #expect(router.route(.valueChanged) == .refreshFocusedGeometry)
        #expect(router.route(.windowMoved) == .refreshFocusedGeometry)
        #expect(router.route(.windowResized) == .refreshFocusedGeometry)
    }

    @Test("Polling source uses observer-capable apps before watch polling")
    func pollingSourceUsesObserverCapableAppsBeforeWatchPolling() {
        let policy = FocusedTextUpdateSourcePolicy()

        #expect(policy.pollingSource(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            usesObserverUpdates: true,
            hasVisibleSuggestion: false
        ) == .idlePoll)
        #expect(policy.pollingSource(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            usesObserverUpdates: false,
            hasVisibleSuggestion: false
        ) == .watchPoll)
        #expect(policy.pollingSource(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            usesObserverUpdates: true,
            hasVisibleSuggestion: true
        ) == .activePoll)
        #expect(policy.pollingSource(
            isTrustedForAccessibility: false,
            hasSupportedProfile: true,
            usesObserverUpdates: true,
            hasVisibleSuggestion: true
        ) == .idlePoll)
    }

    @Test("Observer and manual updates beat queued polling work")
    func observerAndManualUpdatesBeatQueuedPollingWork() {
        let policy = FocusedTextUpdateSourcePolicy()

        #expect(policy.coalesced(.idlePoll, with: .watchPoll) == .watchPoll)
        #expect(policy.coalesced(.watchPoll, with: .observer) == .observer)
        #expect(policy.coalesced(.observer, with: .activePoll) == .observer)
        #expect(policy.coalesced(nil, with: .manualRefresh) == .manualRefresh)
    }
}
