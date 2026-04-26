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
        let width = min(max(textSize.width + 6, minimumWidth), maximumWidth)
        let lineRect = textLineRect ?? caretRect
        let height = max(lineRect.height, textSize.height)
        let preferredX = caretRect.maxX
        let preferredY = lineRect.maxY - height

        let maxX = screenFrame.maxX - width - 8
        let maxY = screenFrame.maxY - height - 4

        return CGRect(
            x: min(max(preferredX, screenFrame.minX + 8), maxX),
            y: min(max(preferredY, screenFrame.minY + 4), maxY),
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
        let width = min(max(textSize.width + 10, minimumWidth), maximumWidth)
        let height = max(textSize.height, min(max(anchorRect.height, 20), 30))
        let preferredX = anchorRect.minX + 8
        let preferredY = anchorRect.maxY - height - 4

        let maxX = screenFrame.maxX - width - 8
        let maxY = screenFrame.maxY - height - 4

        return CGRect(
            x: min(max(preferredX, screenFrame.minX + 8), maxX),
            y: min(max(preferredY, screenFrame.minY + 4), maxY),
            width: width,
            height: height
        )
    }
}
