import AutocompleteLabCore

enum AXManualAccessibilityWakeReason: String, Equatable, Sendable {
    case electronTreeHasNoTextNodes = "electron-tree-has-no-text-nodes"
}

struct AXManualAccessibilityWakeDecision: Equatable, Sendable {
    let shouldWake: Bool
    let reason: AXManualAccessibilityWakeReason?

    static let wakeElectronTree = AXManualAccessibilityWakeDecision(
        shouldWake: true,
        reason: .electronTreeHasNoTextNodes
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
        guard appFamily == .electron,
              !focusedReadReturnedContext,
              !treeHasTextNodes else {
            return .skip
        }

        return .wakeElectronTree
    }
}
