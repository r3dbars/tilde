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
        clippingFrame: CGRect? = nil,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let lineRect = textLineRect ?? caretRect
        let height = max(lineRect.height, textSize.height)
        let horizontalBounds = horizontalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let preferredWidth = textSize.width + 6
        let preferredX = clampedOrigin(
            preferred: caretRect.maxX,
            length: min(minimumWidth, horizontalBounds.upper - horizontalBounds.lower),
            lowerBound: horizontalBounds.lower,
            upperBound: horizontalBounds.upper
        )
        let width = widthFromOrigin(
            preferredWidth: preferredWidth,
            originX: preferredX,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            upperBound: horizontalBounds.upper
        )
        let preferredY = lineRect.maxY - height

        return CGRect(
            x: preferredX,
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
        clippingFrame: CGRect? = nil,
        minimumWidth: CGFloat = 72,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let horizontalBounds = horizontalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let width = panelWidth(
            preferredWidth: textSize.width + 10,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            availableWidth: horizontalBounds.upper - horizontalBounds.lower
        )
        let height = max(textSize.height, min(max(anchorRect.height, 20), 30))
        let preferredX = anchorRect.minX + 8
        let preferredY = anchorRect.maxY - height - 4

        return CGRect(
            x: clampedOrigin(
                preferred: preferredX,
                length: width,
                lowerBound: horizontalBounds.lower,
                upperBound: horizontalBounds.upper
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
        availableWidth: CGFloat
    ) -> CGFloat {
        return min(max(preferredWidth, minimumWidth), maximumWidth, availableWidth)
    }

    private static func widthFromOrigin(
        preferredWidth: CGFloat,
        originX: CGFloat,
        minimumWidth: CGFloat,
        maximumWidth: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        let availableWidth = max(1, upperBound - originX)
        return panelWidth(
            preferredWidth: preferredWidth,
            minimumWidth: min(minimumWidth, availableWidth),
            maximumWidth: maximumWidth,
            availableWidth: availableWidth
        )
    }

    private static func horizontalBounds(
        screenFrame: CGRect,
        clippingFrame: CGRect?,
        horizontalMargin: CGFloat = 8
    ) -> (lower: CGFloat, upper: CGFloat) {
        let screenLower = screenFrame.minX + horizontalMargin
        let screenUpper = screenFrame.maxX - horizontalMargin

        guard let clippingFrame else {
            return (screenLower, max(screenLower + 1, screenUpper))
        }

        let lower = max(screenLower, clippingFrame.minX + horizontalMargin)
        let upper = min(screenUpper, clippingFrame.maxX - horizontalMargin)
        return (lower, max(lower + 1, upper))
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
