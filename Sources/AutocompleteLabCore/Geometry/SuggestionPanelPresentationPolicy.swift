import CoreGraphics

public struct SuggestionPanelPresentationAttempt: Equatable {
    public let placement: PlacementHealthPresentation
    public let panelRect: CGRect?
    public let failureReason: String?

    public init(
        placement: PlacementHealthPresentation,
        panelRect: CGRect?,
        failureReason: String?
    ) {
        self.placement = placement
        self.panelRect = panelRect
        self.failureReason = failureReason
    }

    public var didPresent: Bool {
        panelRect != nil
    }
}

public enum SuggestionPanelPresentationPolicy {
    public static let panelFrameUnusableReason = "panel-frame-unusable"

    public static func attempt(
        initialPlacement: PlacementHealthPresentation,
        fallbackRenderMode: SuggestionRenderMode?,
        show: (PlacementHealthPresentation) -> CGRect?
    ) -> SuggestionPanelPresentationAttempt {
        if let panelRect = show(initialPlacement) {
            return SuggestionPanelPresentationAttempt(
                placement: initialPlacement,
                panelRect: panelRect,
                failureReason: nil
            )
        }

        guard let fallbackPlacement = initialPlacement.mirrorFallbackForCrampedInlineFrame(
            fallbackRenderMode: fallbackRenderMode
        ) else {
            return SuggestionPanelPresentationAttempt(
                placement: initialPlacement,
                panelRect: nil,
                failureReason: panelFrameUnusableReason
            )
        }

        if let panelRect = show(fallbackPlacement) {
            return SuggestionPanelPresentationAttempt(
                placement: fallbackPlacement,
                panelRect: panelRect,
                failureReason: nil
            )
        }

        return SuggestionPanelPresentationAttempt(
            placement: fallbackPlacement,
            panelRect: nil,
            failureReason: fallbackPlacement.reason.rawValue
        )
    }
}
