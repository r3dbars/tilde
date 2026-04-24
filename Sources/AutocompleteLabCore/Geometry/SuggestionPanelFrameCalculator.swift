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
        let lineRect = trustedLineRect(
            textLineRect,
            caretRect: caretRect,
            textHeight: textSize.height
        )
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

    private static func trustedLineRect(
        _ textLineRect: CGRect?,
        caretRect: CGRect,
        textHeight: CGFloat
    ) -> CGRect {
        guard let textLineRect,
              textLineRect.isFinite,
              textLineRect.width >= 0,
              textLineRect.height > 0 else {
            return caretRect
        }

        let expectedLineHeight = max(caretRect.height, textHeight, 1)
        let maximumReasonableHeight = max(expectedLineHeight * 1.8, expectedLineHeight + 8)
        guard textLineRect.height <= maximumReasonableHeight else {
            return caretRect
        }

        let verticalTolerance = max(expectedLineHeight * 0.75, 6)
        guard abs(textLineRect.midY - caretRect.midY) <= verticalTolerance else {
            return caretRect
        }

        return textLineRect
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite &&
            origin.y.isFinite &&
            size.width.isFinite &&
            size.height.isFinite
    }
}
