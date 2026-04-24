import CoreGraphics
import Foundation

public enum SuggestionPanelFrameCalculator {
    public static func inlineGhostFrame(
        caretRect: CGRect,
        textLineRect: CGRect? = nil,
        boundaryFrame: CGRect? = nil,
        textSize: CGSize,
        screenFrame: CGRect,
        minimumWidth: CGFloat = 40,
        maximumWidth: CGFloat = 420
    ) -> CGRect {
        let lineRect = textLineRect ?? caretRect
        let height = max(lineRect.height, textSize.height)
        let boundaryIntersection = boundaryFrame?.intersection(screenFrame)
        let boundsFrame = boundaryIntersection?.isNull == false ? boundaryIntersection! : screenFrame
        let preferredX = max(caretRect.maxX, boundsFrame.minX + 4, screenFrame.minX + 8)
        let preferredY = lineRect.maxY - height
        let rightEdge = min(boundsFrame.maxX - 4, screenFrame.maxX - 8)
        let availableWidth = max(0, rightEdge - preferredX)
        let desiredWidth = min(max(textSize.width + 6, minimumWidth), maximumWidth)
        let width = min(desiredWidth, availableWidth)

        let minY = max(boundsFrame.minY + 4, screenFrame.minY + 4)
        let upperY = min(boundsFrame.maxY - height - 4, screenFrame.maxY - height - 4)
        let maxY = max(minY, upperY)

        return CGRect(
            x: preferredX,
            y: min(max(preferredY, minY), maxY),
            width: width,
            height: height
        )
    }
}
