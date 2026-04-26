import Foundation

public enum RenderModePlan {
    public static func effectiveMode(
        for profile: CompatibilityProfile,
        supportsInlineSuggestions: Bool,
        hasMirrorAnchor: Bool
    ) -> SuggestionRenderMode? {
        switch profile.renderMode {
        case .inlineAdjacent:
            if supportsInlineSuggestions {
                return .inlineAdjacent
            }

            if profile.fallbackRenderMode == .floatingMirror, hasMirrorAnchor {
                return .floatingMirror
            }

            return nil

        case .floatingMirror:
            return hasMirrorAnchor ? .floatingMirror : nil

        case .disabled:
            return nil
        }
    }
}
