import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
    public static func inlineGhostFrame(
        caretRect: CGRect,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let width = min(max(textSize.width + 6, minimumWidth), maximumWidth)
        let height = max(caretRect.height, textSize.height)
        let preferredX = caretRect.maxX + 2
        let preferredY = caretRect.minY - (height * 0.08)

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
