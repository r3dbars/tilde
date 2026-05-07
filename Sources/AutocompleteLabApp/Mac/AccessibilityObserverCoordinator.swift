import AutocompleteLabCore
import Foundation

enum AccessibilityObservationMode: Equatable, Sendable {
    case observeFocusedApp
    case stopTrackingAll
}

struct AccessibilityObserverEventDecision: Equatable, Sendable {
    let action: AccessibilityObserverRouteAction
    let metadata: [String: String]
}

struct AccessibilityObserverCoordinator: Equatable, Sendable {
    var router: AccessibilityObserverEventRouter

    init(router: AccessibilityObserverEventRouter = AccessibilityObserverEventRouter()) {
        self.router = router
    }

    func usesObserverUpdates(
        profile: CompatibilityProfile?,
        isTrackingFocusedApp: Bool
    ) -> Bool {
        profile?.supportsObserverUpdates == true && isTrackingFocusedApp
    }

    func observationMode(for profile: CompatibilityProfile) -> AccessibilityObservationMode {
        profile.supportsObserverUpdates ? .observeFocusedApp : .stopTrackingAll
    }

    func eventDecision(
        for event: AccessibilityObserverEvent,
        frontmostProcessIdentifier: pid_t?
    ) -> AccessibilityObserverEventDecision? {
        guard frontmostProcessIdentifier == event.processIdentifier else {
            return nil
        }

        let action = router.route(event.kind)
        return AccessibilityObserverEventDecision(
            action: action,
            metadata: event.metadata
                .merging(["route": action.rawValue]) { current, _ in current }
        )
    }
}
