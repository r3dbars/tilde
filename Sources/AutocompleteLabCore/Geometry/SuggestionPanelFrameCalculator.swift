import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
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
}
