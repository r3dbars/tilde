import Testing
import AutocompleteLabCore
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

    @Test("Coordinator tracks only observer capable focused apps")
    func coordinatorTracksOnlyObserverCapableFocusedApps() throws {
        let coordinator = AccessibilityObserverCoordinator()
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(coordinator.observationMode(for: textEdit) == .observeFocusedApp)
        #expect(coordinator.observationMode(for: chrome) == .stopTrackingAll)
        #expect(coordinator.usesObserverUpdates(profile: textEdit, isTrackingFocusedApp: true))
        #expect(!coordinator.usesObserverUpdates(profile: textEdit, isTrackingFocusedApp: false))
        #expect(!coordinator.usesObserverUpdates(profile: chrome, isTrackingFocusedApp: true))
        #expect(!coordinator.usesObserverUpdates(profile: nil, isTrackingFocusedApp: true))
    }

    @Test("Coordinator ignores stale process events and labels routed events")
    func coordinatorIgnoresStaleProcessEventsAndLabelsRoutedEvents() throws {
        let coordinator = AccessibilityObserverCoordinator()
        let event = AccessibilityObserverEvent(
            processIdentifier: 42,
            bundleIdentifier: "com.apple.TextEdit",
            localizedAppName: "TextEdit",
            notificationName: "AXSelectedTextChanged",
            kind: .selectedTextChanged,
            elementIdentifier: 99
        )

        #expect(coordinator.eventDecision(for: event, frontmostProcessIdentifier: 7) == nil)

        let decision = try #require(coordinator.eventDecision(
            for: event,
            frontmostProcessIdentifier: 42
        ))
        #expect(decision.action == .refreshFocusedGeometry)
        #expect(decision.metadata["route"] == "refreshFocusedGeometry")
        #expect(decision.metadata["updateSource"] == "observer")
        #expect(decision.metadata["app"] == "com.apple.TextEdit")
    }
}
