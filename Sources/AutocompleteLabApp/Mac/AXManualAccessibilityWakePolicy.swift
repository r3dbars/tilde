import AutocompleteLabCore

enum AXManualAccessibilityWakeReason: String, Equatable, Sendable {
    case electronTreeHasNoTextNodes = "electron-tree-has-no-text-nodes"
    case electronFocusedElementUnavailable = "electron-focused-element-unavailable"
}

struct AXManualAccessibilityWakeDecision: Equatable, Sendable {
    let shouldWake: Bool
    let reason: AXManualAccessibilityWakeReason?

    static let wakeElectronTree = AXManualAccessibilityWakeDecision(
        shouldWake: true,
        reason: .electronTreeHasNoTextNodes
    )
    static let wakeElectronFocusedElement = AXManualAccessibilityWakeDecision(
        shouldWake: true,
        reason: .electronFocusedElementUnavailable
    )
    static let skip = AXManualAccessibilityWakeDecision(shouldWake: false, reason: nil)
}

enum AXManualAccessibilityWakePolicy {
    static let attributeName = "AXManualAccessibility"

    static func decision(
        appFamily: CompatibilityAppFamily,
        focusedReadReturnedContext: Bool,
        treeHasTextNodes: Bool,
        forceAfterMissingContext: Bool = false
    ) -> AXManualAccessibilityWakeDecision {
        guard appFamily == .electron,
              !focusedReadReturnedContext else {
            return .skip
        }

        if forceAfterMissingContext {
            return .wakeElectronFocusedElement
        }

        guard !treeHasTextNodes else {
            return .skip
        }

        return .wakeElectronTree
    }
}
