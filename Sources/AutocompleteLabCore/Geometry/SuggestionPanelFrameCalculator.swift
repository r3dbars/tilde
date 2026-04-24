import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
    public static func inlineGhostFrame(
        appBundleIdentifier: String? = nil,
        caretRect: CGRect,
        textLineRect: CGRect? = nil,
        boundaryFrame: CGRect? = nil,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        inlineGhostPlacement(
            appBundleIdentifier: appBundleIdentifier,
            caretRect: caretRect,
            textLineRect: textLineRect,
            boundaryFrame: boundaryFrame,
            textSize: textSize,
            screenFrame: screenFrame,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth
        ).frame
    }

    public static func inlineGhostPlacement(
        appBundleIdentifier: String? = nil,
        caretRect: CGRect,
        textLineRect: CGRect? = nil,
        boundaryFrame: CGRect? = nil,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> InlineGhostPlacementDecision {
        InlineGhostPlacementResolver.resolve(
            InlineGhostPlacementRequest(
                appBundleIdentifier: appBundleIdentifier,
                caretRect: caretRect,
                textLineRect: textLineRect,
                boundaryFrame: boundaryFrame,
                textSize: textSize,
                screenFrame: screenFrame,
                minimumWidth: minimumWidth,
                maximumWidth: maximumWidth
            )
        )
    }
}
