import CoreGraphics
import Foundation

public enum CaretRectResolver {
    public static func resolve(
        reportedCaretRect: CGRect?,
        previousGlyphRect: CGRect?,
        nextGlyphRect: CGRect? = nil,
        isAfterNewline: Bool,
        minimumVerticalTolerance: CGFloat = 6,
        verticalToleranceMultiplier: CGFloat = 0.75
    ) -> CGRect? {
        let reportedCaretRect = reportedCaretRect?.finitePositiveHeightRect
        let previousGlyphRect = previousGlyphRect?.finitePositiveHeightRect
        let nextGlyphRect = nextGlyphRect?.finitePositiveHeightRect

        guard let reportedCaretRect else {
            return inferredCaretRect(
                previousGlyphRect: previousGlyphRect,
                nextGlyphRect: nextGlyphRect,
                isAfterNewline: isAfterNewline,
                reportedCaretRect: nil
            )
        }

        guard let previousGlyphRect, !isAfterNewline else {
            return reportedCaretRect
        }

        let expectedHeight = max(reportedCaretRect.height, previousGlyphRect.height, 1)
        let verticalTolerance = max(expectedHeight * verticalToleranceMultiplier, minimumVerticalTolerance)
        let horizontalTolerance = max(2, expectedHeight * 0.25)
        let sameRow = abs(reportedCaretRect.midY - previousGlyphRect.midY) <= verticalTolerance
        let staleWrappedRow = !sameRow
        let staleBeforeGlyph = sameRow && reportedCaretRect.maxX + horizontalTolerance < previousGlyphRect.maxX

        guard staleWrappedRow || staleBeforeGlyph else {
            return reportedCaretRect
        }

        return caretRect(after: previousGlyphRect, matching: reportedCaretRect)
    }

    private static func inferredCaretRect(
        previousGlyphRect: CGRect?,
        nextGlyphRect: CGRect?,
        isAfterNewline: Bool,
        reportedCaretRect: CGRect?
    ) -> CGRect? {
        if let previousGlyphRect, !isAfterNewline {
            return caretRect(after: previousGlyphRect, matching: reportedCaretRect)
        }

        if let nextGlyphRect {
            return caretRect(before: nextGlyphRect, matching: reportedCaretRect)
        }

        return reportedCaretRect
    }

    private static func caretRect(after glyphRect: CGRect, matching reportedCaretRect: CGRect?) -> CGRect {
        CGRect(
            x: glyphRect.maxX,
            y: glyphRect.minY,
            width: reportedCaretRect?.width ?? 0,
            height: max(reportedCaretRect?.height ?? 0, glyphRect.height)
        )
    }

    private static func caretRect(before glyphRect: CGRect, matching reportedCaretRect: CGRect?) -> CGRect {
        CGRect(
            x: glyphRect.minX,
            y: glyphRect.minY,
            width: reportedCaretRect?.width ?? 0,
            height: max(reportedCaretRect?.height ?? 0, glyphRect.height)
        )
    }
}

private extension CGRect {
    var finitePositiveHeightRect: CGRect? {
        guard origin.x.isFinite,
              origin.y.isFinite,
              size.width.isFinite,
              size.height.isFinite,
              height > 0 else {
            return nil
        }

        return self
    }
}
