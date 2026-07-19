import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
    public static let minimumUsefulInlineWordWidth: CGFloat = 40

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

    public static func isUsableInlineGhostFrame(
        _ frame: CGRect,
        minimumVisibleWidth: CGFloat = minimumUsefulInlineWordWidth
    ) -> Bool {
        frame.minX.isFinite
            && frame.minY.isFinite
            && frame.maxX.isFinite
            && frame.maxY.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
            && !frame.isNull
            && frame.width >= minimumVisibleWidth
            && frame.height >= 1
    }

    public static func inlineGhostFrame(
        appBundleIdentifier: String? = nil,
        caretRect: CGRect,
        textLineRect: CGRect? = nil,
        boundaryFrame: CGRect? = nil,
        textSize: CGSize,
        screenFrame: CGRect,
        clippingFrame: CGRect? = nil,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420,
        horizontalAlignmentOffset: CGFloat = 0,
        verticalAlignmentOffset: CGFloat = 0
    ) -> CGRect {
        if appBundleIdentifier != nil || boundaryFrame != nil {
            let frame = inlineGhostPlacement(
                appBundleIdentifier: appBundleIdentifier,
                caretRect: caretRect,
                textLineRect: textLineRect,
                boundaryFrame: boundaryFrame ?? clippingFrame,
                textSize: textSize,
                screenFrame: screenFrame,
                minimumWidth: minimumWidth,
                maximumWidth: maximumWidth
            ).frame
            let horizontallyAlignedFrame = horizontallyAlignedInlineFrame(
                frame,
                offset: horizontalAlignmentOffset,
                screenFrame: screenFrame,
                clippingFrame: boundaryFrame ?? clippingFrame
            )
            return verticallyAlignedInlineFrame(
                horizontallyAlignedFrame,
                offset: verticalAlignmentOffset,
                screenFrame: screenFrame,
                clippingFrame: boundaryFrame ?? clippingFrame
            )
        }

        let lineRect = textLineRect ?? caretRect
        let height = max(lineRect.height, textSize.height)
        let horizontalBounds = horizontalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let verticalBounds = verticalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let preferredWidth = textSize.width + 6
        let preferredX = inlineOriginAfterCaret(
            caretX: caretRect.maxX,
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

        let frame = CGRect(
            x: preferredX,
            y: clampedOrigin(
                preferred: preferredY,
                length: height,
                lowerBound: verticalBounds.lower,
                upperBound: verticalBounds.upper
            ),
            width: width,
            height: height
        )
        let horizontallyAlignedFrame = horizontallyAlignedInlineFrame(
            frame,
            offset: horizontalAlignmentOffset,
            screenFrame: screenFrame,
            clippingFrame: clippingFrame
        )
        return verticallyAlignedInlineFrame(
            horizontallyAlignedFrame,
            offset: verticalAlignmentOffset,
            screenFrame: screenFrame,
            clippingFrame: clippingFrame
        )
    }

    private static func horizontallyAlignedInlineFrame(
        _ frame: CGRect,
        offset: CGFloat,
        screenFrame: CGRect,
        clippingFrame: CGRect?
    ) -> CGRect {
        guard offset != 0 else {
            return frame
        }
        let bounds = horizontalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        return CGRect(
            x: clampedOrigin(
                preferred: frame.minX + offset,
                length: frame.width,
                lowerBound: bounds.lower,
                upperBound: bounds.upper
            ),
            y: frame.minY,
            width: frame.width,
            height: frame.height
        )
    }

    private static func verticallyAlignedInlineFrame(
        _ frame: CGRect,
        offset: CGFloat,
        screenFrame: CGRect,
        clippingFrame: CGRect?
    ) -> CGRect {
        guard offset != 0 else {
            return frame
        }
        let bounds = verticalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        return CGRect(
            x: frame.minX,
            y: clampedOrigin(
                preferred: frame.minY + offset,
                length: frame.height,
                lowerBound: bounds.lower,
                upperBound: bounds.upper
            ),
            width: frame.width,
            height: frame.height
        )
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

    public static func floatingMirrorFrame(
        anchorRect: CGRect,
        textSize: CGSize,
        screenFrame: CGRect,
        clippingFrame: CGRect? = nil,
        minimumWidth: CGFloat = 72,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let horizontalBounds = horizontalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let verticalBounds = verticalBounds(screenFrame: screenFrame, clippingFrame: clippingFrame)
        let width = panelWidth(
            preferredWidth: textSize.width + 10,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            availableWidth: horizontalBounds.upper - horizontalBounds.lower
        )
        let height = max(textSize.height, min(max(anchorRect.height, 20), 30))
        let preferredX = anchorRect.minX + 8
        let isWholeEditorAnchor = anchorRect.height > 80
        let preferredY = isWholeEditorAnchor
            ? anchorRect.midY - (height / 2)
            : anchorRect.maxY - height - 4

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
                lowerBound: verticalBounds.lower,
                upperBound: verticalBounds.upper
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

    private static func verticalBounds(
        screenFrame: CGRect,
        clippingFrame: CGRect?,
        verticalMargin: CGFloat = 4
    ) -> (lower: CGFloat, upper: CGFloat) {
        let screenLower = screenFrame.minY + verticalMargin
        let screenUpper = screenFrame.maxY - verticalMargin

        guard let clippingFrame else {
            return (screenLower, max(screenLower + 1, screenUpper))
        }

        let lower = max(screenLower, clippingFrame.minY + verticalMargin)
        let upper = min(screenUpper, clippingFrame.maxY - verticalMargin)
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

    private static func inlineOriginAfterCaret(
        caretX: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        let lastUsableOrigin = max(lowerBound, upperBound - 1)
        return min(max(caretX, lowerBound), lastUsableOrigin)
    }
}
