import CoreGraphics
import Foundation

public enum SyntheticCaretEstimator {
    private static let maxMeasuredCharacters = 4_000

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
        centerSingleLineWhenTall: Bool = false,
        measuredCurrentLineRect: CGRect? = nil,
        widthOfText: (String) -> CGFloat
    ) -> CGRect? {
        guard elementRect.width > 80, elementRect.height > 20 else {
            return nil
        }
        guard Self.hasSharedCoordinateSpace(elementRect: elementRect, windowRect: windowRect) else {
            return nil
        }

        let lineHeight = max(rawLineHeight, 20)

        // A real on-screen rect for the caret's line beats any width estimate:
        // the estimate multiplies a guessed font by the whole line, so its
        // error grows with every character, while the measured rect is truth.
        if let measured = usableMeasuredCurrentLineRect(
            measuredCurrentLineRect,
            elementRect: elementRect,
            lineHeight: lineHeight
        ) {
            let caretHeight = max(min(measured.height, lineHeight * 1.5), 16)
            let upperX = max(elementRect.minX, elementRect.maxX - horizontalPadding)
            let preferredX = measured.maxX + inlineGap
            let y = clampedCaretY(
                measured.minY,
                caretHeight: caretHeight,
                elementRect: elementRect,
                windowRect: windowRect
            )
            return CGRect(
                x: min(max(preferredX, elementRect.minX), upperX),
                y: y,
                width: 0,
                height: caretHeight
            )
        }

        let maxLineWidth = max(40, elementRect.width - (horizontalPadding * 2))
        let visualLines = wrappedVisualLines(
            for: boundedTextBeforeCursor(textBeforeCursor),
            maxLineWidth: maxLineWidth,
            widthOfText: widthOfText
        )
        let currentLine = visualLines.last ?? ""
        let lineIndex = max(0, visualLines.count - 1)
        let currentLineWidth = min(widthOfText(currentLine), maxLineWidth)
        let caretHeight = max(lineHeight, 16)
        let preferredY: CGFloat
        if centerSingleLineWhenTall,
           visualLines.count == 1,
           elementRect.height >= lineHeight * 2 {
            preferredY = elementRect.midY - (caretHeight / 2)
        } else {
            preferredY = elementRect.minY
                + verticalPadding
                - (lineHeight * baselineLiftFactor)
                + (lineHeight * inlineVerticalDropFactor)
                + (CGFloat(lineIndex) * lineHeight)
        }
        let y = clampedCaretY(
            preferredY,
            caretHeight: caretHeight,
            elementRect: elementRect,
            windowRect: windowRect
        )
        let lowerX = elementRect.minX + horizontalPadding
        let upperX = max(lowerX, elementRect.maxX - horizontalPadding)
        let preferredX = lowerX + currentLineWidth + inlineGap

        return CGRect(
            x: min(max(preferredX, lowerX), upperX),
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

    private static func usableMeasuredCurrentLineRect(
        _ rect: CGRect?,
        elementRect: CGRect,
        lineHeight: CGFloat
    ) -> CGRect? {
        guard let rect,
              rect.isFinitePlacementRect,
              rect.width >= 1,
              rect.height >= 8,
              rect.height <= lineHeight * 3,
              elementRect.insetBy(dx: -24, dy: -24).intersects(rect) else {
            return nil
        }

        return rect
    }

    private static func boundedTextBeforeCursor(_ text: String) -> String {
        guard text.count > maxMeasuredCharacters else {
            return text
        }

        let paragraphStart = text.lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let currentParagraph = text[paragraphStart...]
        guard currentParagraph.count > maxMeasuredCharacters else {
            return String(currentParagraph)
        }

        let start = currentParagraph.index(currentParagraph.endIndex, offsetBy: -maxMeasuredCharacters)
        return String(currentParagraph[start...])
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

    private static func hasSharedCoordinateSpace(elementRect: CGRect, windowRect: CGRect?) -> Bool {
        guard let windowRect else {
            return true
        }

        guard elementRect.isFinitePlacementRect,
              windowRect.isFinitePlacementRect else {
            return false
        }

        let tolerance: CGFloat = 24
        return windowRect
            .insetBy(dx: -tolerance, dy: -tolerance)
            .intersects(elementRect)
    }
}

private extension CGRect {
    var isFinitePlacementRect: Bool {
        minX.isFinite
            && minY.isFinite
            && maxX.isFinite
            && maxY.isFinite
            && width.isFinite
            && height.isFinite
            && !isNull
    }
}
