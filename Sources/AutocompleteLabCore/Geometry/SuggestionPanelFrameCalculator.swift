import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
    public static func shouldRefreshPresentation(
        previousText: String?,
        previousFrame: CGRect?,
        previousRenderMode: SuggestionRenderMode?,
        nextText: String,
        nextFrame: CGRect,
        nextRenderMode: SuggestionRenderMode,
        movementTolerance: CGFloat = 0.5
    ) -> Bool {
        guard previousText == nextText,
              previousRenderMode == nextRenderMode,
              let previousFrame else {
            return true
        }

        return abs(previousFrame.minX - nextFrame.minX) > movementTolerance
            || abs(previousFrame.minY - nextFrame.minY) > movementTolerance
            || abs(previousFrame.width - nextFrame.width) > movementTolerance
            || abs(previousFrame.height - nextFrame.height) > movementTolerance
    }

    public static func inlineGhostFrame(
        caretRect: CGRect,
        textLineRect: CGRect? = nil,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let width = panelWidth(
            preferredWidth: textSize.width + 6,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            screenFrame: screenFrame
        )
        let lineRect = textLineRect ?? caretRect
        let height = max(lineRect.height, textSize.height)
        let preferredX = caretRect.maxX
        let preferredY = lineRect.maxY - height

        return CGRect(
            x: clampedOrigin(
                preferred: preferredX,
                length: width,
                lowerBound: screenFrame.minX + 8,
                upperBound: screenFrame.maxX - 8
            ),
            y: clampedOrigin(
                preferred: preferredY,
                length: height,
                lowerBound: screenFrame.minY + 4,
                upperBound: screenFrame.maxY - 4
            ),
            width: width,
            height: height
        )
    }

    public static func floatingMirrorFrame(
        anchorRect: CGRect,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 72,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let width = panelWidth(
            preferredWidth: textSize.width + 10,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            screenFrame: screenFrame
        )
        let height = max(textSize.height, min(max(anchorRect.height, 20), 30))
        let preferredX = anchorRect.minX + 8
        let preferredY = anchorRect.maxY - height - 4

        return CGRect(
            x: clampedOrigin(
                preferred: preferredX,
                length: width,
                lowerBound: screenFrame.minX + 8,
                upperBound: screenFrame.maxX - 8
            ),
            y: clampedOrigin(
                preferred: preferredY,
                length: height,
                lowerBound: screenFrame.minY + 4,
                upperBound: screenFrame.maxY - 4
            ),
            width: width,
            height: height
        )
    }

    private static func panelWidth(
        preferredWidth: CGFloat,
        minimumWidth: CGFloat,
        maximumWidth: CGFloat,
        screenFrame: CGRect,
        horizontalMargin: CGFloat = 8
    ) -> CGFloat {
        let availableWidth = max(1, screenFrame.width - (horizontalMargin * 2))
        return min(max(preferredWidth, minimumWidth), maximumWidth, availableWidth)
    }

    private static func clampedOrigin(
        preferred: CGFloat,
        length: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        let maxOrigin = max(lowerBound, upperBound - length)
        return min(max(preferred, lowerBound), maxOrigin)
    }
}
