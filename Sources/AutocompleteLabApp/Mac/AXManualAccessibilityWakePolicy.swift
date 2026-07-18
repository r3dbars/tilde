import AutocompleteLabCore

enum AXManualAccessibilityWakeReason: String, Equatable, Sendable {
    case chromiumBackedTreeHasNoTextNodes = "chromium-backed-tree-has-no-text-nodes"
}

struct AXManualAccessibilityWakeDecision: Equatable, Sendable {
    let shouldWake: Bool
    let reason: AXManualAccessibilityWakeReason?

    static let wakeChromiumBackedTree = AXManualAccessibilityWakeDecision(
        shouldWake: true,
        reason: .chromiumBackedTreeHasNoTextNodes
    )
    static let skip = AXManualAccessibilityWakeDecision(shouldWake: false, reason: nil)
}

enum AXManualAccessibilityWakePolicy {
    static let attributeName = "AXManualAccessibility"

    static func decision(
        appFamily: CompatibilityAppFamily,
        focusedReadReturnedContext: Bool,
        treeHasTextNodes: Bool
    ) -> AXManualAccessibilityWakeDecision {
        guard appFamily == .electron || appFamily == .customCanvas,
              !focusedReadReturnedContext,
              !treeHasTextNodes else {
            return .skip
        }

        return .wakeChromiumBackedTree
    }
}
