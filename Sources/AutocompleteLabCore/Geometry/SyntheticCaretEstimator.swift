import CoreGraphics
import Foundation

public enum SyntheticCaretEstimator {
    public static func caretRect(
        textBeforeCursor: String,
        elementRect: CGRect,
        windowRect: CGRect?,
        lineHeight rawLineHeight: CGFloat,
        horizontalPadding: CGFloat = 18,
        verticalPadding: CGFloat = 4,
        baselineLiftFactor: CGFloat = 0.85,
        inlineGap: CGFloat = 8,
        inlineVerticalDropFactor: CGFloat = 0.85,
        widthOfText: (String) -> CGFloat
    ) -> CGRect? {
        guard elementRect.width > 80, elementRect.height > 20 else {
            return nil
        }

        let lineHeight = max(rawLineHeight, 20)
        let maxLineWidth = max(40, elementRect.width - (horizontalPadding * 2))
        let visualLines = wrappedVisualLines(
            for: textBeforeCursor,
            maxLineWidth: maxLineWidth,
            widthOfText: widthOfText
        )
        let currentLine = visualLines.last ?? ""
        let lineIndex = max(0, visualLines.count - 1)
        let currentLineWidth = min(widthOfText(currentLine), maxLineWidth)
        let caretHeight = max(lineHeight, 16)
        let preferredY = elementRect.minY
            + verticalPadding
            - (lineHeight * baselineLiftFactor)
            + (lineHeight * inlineVerticalDropFactor)
            + (CGFloat(lineIndex) * lineHeight)
        let y = clampedCaretY(
            preferredY,
            caretHeight: caretHeight,
            elementRect: elementRect,
            windowRect: windowRect
        )

        return CGRect(
            x: min(
                elementRect.minX + horizontalPadding + currentLineWidth + inlineGap,
                elementRect.maxX - horizontalPadding
            ),
            y: y,
            width: 0,
            height: caretHeight
        )
    }

    public static func wrappedVisualLines(
        for text: String,
        maxLineWidth: CGFloat,
        widthOfText: (String) -> CGFloat
    ) -> [String] {
        var lines: [String] = []

        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            var current = ""

            for character in paragraph {
                let next = current + String(character)
                if !current.isEmpty, widthOfText(next) > maxLineWidth {
                    lines.append(current)
                    current = String(character)
                } else {
                    current = next
                }
            }

            lines.append(current)
        }

        return lines.isEmpty ? [""] : lines
    }

    public static func clampedCaretY(
        _ preferredY: CGFloat,
        caretHeight: CGFloat,
        elementRect: CGRect,
        windowRect: CGRect?
    ) -> CGFloat {
        let boundingRect = windowRect ?? elementRect
        let upperPadding: CGFloat = 8
        let lowerPadding: CGFloat = 8
        let minY = min(elementRect.minY - (caretHeight * 1.25), boundingRect.maxY - caretHeight - lowerPadding)
        let maxY = max(elementRect.maxY + (caretHeight * 6), minY)
        let boundedMinY = max(boundingRect.minY + upperPadding, minY)
        let boundedMaxY = min(boundingRect.maxY - caretHeight - lowerPadding, maxY)

        guard boundedMaxY >= boundedMinY else {
            return preferredY
        }

        return min(max(preferredY, boundedMinY), boundedMaxY)
    }
}
