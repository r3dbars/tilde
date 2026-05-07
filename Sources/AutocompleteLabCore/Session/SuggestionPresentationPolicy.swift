public struct SuggestionPresentationCapabilities: Equatable, Sendable {
    public let supportsInlineSuggestions: Bool
    public let hasElementRect: Bool
    public let hasWindowRect: Bool
    public let hasCaretRect: Bool

    public init(
        supportsInlineSuggestions: Bool,
        hasElementRect: Bool,
        hasWindowRect: Bool,
        hasCaretRect: Bool
    ) {
        self.supportsInlineSuggestions = supportsInlineSuggestions
        self.hasElementRect = hasElementRect
        self.hasWindowRect = hasWindowRect
        self.hasCaretRect = hasCaretRect
    }

    public var hasMirrorAnchor: Bool {
        hasElementRect || hasWindowRect
    }
}

public enum SuggestionPresentationSuppressionReason: String, Equatable, Sendable {
    case detachedSuggestionDisabled = "detached-suggestion-disabled"
}

public struct SuggestionPresentationPolicy: Equatable, Sendable {
    public init() {}

    public func baseRenderMode(
        for profile: CompatibilityProfile,
        capabilities: SuggestionPresentationCapabilities
    ) -> SuggestionRenderMode? {
        RenderModePlan.effectiveMode(
            for: profile,
            supportsInlineSuggestions: capabilities.supportsInlineSuggestions,
            hasMirrorAnchor: capabilities.hasMirrorAnchor
        )
    }

    public func suppressionReason(
        profile: CompatibilityProfile,
        renderMode: SuggestionRenderMode,
        capabilities: SuggestionPresentationCapabilities
    ) -> SuggestionPresentationSuppressionReason? {
        if renderMode == .floatingMirror,
           !capabilities.hasCaretRect,
           !profile.allowsDetachedSuggestions {
            return .detachedSuggestionDisabled
        }

        return nil
    }
}
