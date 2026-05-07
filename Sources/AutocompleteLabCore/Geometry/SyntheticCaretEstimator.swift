import CoreGraphics
import Foundation

public enum SyntheticCaretSource: String, Equatable, Sendable {
    case axTextAreaEstimate = "ax-textarea-estimate"
    case webAreaEstimate = "web-area-estimate"
    case electronTextAreaEstimate = "electron-textarea-estimate"
    case codeMirrorEstimate = "codemirror-estimate"
}

public struct SyntheticCaretEstimateInput: Equatable, Sendable {
    public let textBeforeCursor: String
    public let elementRect: CGRect
    public let windowRect: CGRect?
    public let lineHeight: CGFloat
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat
    public let baselineLiftRatio: CGFloat
    public let inlineVerticalDropRatio: CGFloat
    public let inlineGap: CGFloat
    public let minimumLineWidth: CGFloat
    public let minimumElementWidth: CGFloat
    public let minimumElementHeight: CGFloat

    public init(
        textBeforeCursor: String,
        elementRect: CGRect,
        windowRect: CGRect? = nil,
        lineHeight: CGFloat,
        horizontalPadding: CGFloat = 18,
        verticalPadding: CGFloat = 4,
        baselineLiftRatio: CGFloat = 0.85,
        inlineVerticalDropRatio: CGFloat = 0.85,
        inlineGap: CGFloat = 8,
        minimumLineWidth: CGFloat = 40,
        minimumElementWidth: CGFloat = 80,
        minimumElementHeight: CGFloat = 20
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.elementRect = elementRect
        self.windowRect = windowRect
        self.lineHeight = lineHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.baselineLiftRatio = baselineLiftRatio
        self.inlineVerticalDropRatio = inlineVerticalDropRatio
        self.inlineGap = inlineGap
        self.minimumLineWidth = minimumLineWidth
        self.minimumElementWidth = minimumElementWidth
        self.minimumElementHeight = minimumElementHeight
    }
}

public enum SyntheticCaretEligibility {
    public static func source(
        bundleIdentifier: String,
        role: String?,
        subrole: String?,
        elementRect: CGRect?,
        canReadValue: Bool,
        canReadSelectedTextRange: Bool
    ) -> SyntheticCaretSource? {
        guard canReadValue,
              canReadSelectedTextRange,
              let elementRect,
              elementRect.width > 80,
              elementRect.height > 20 else {
            return nil
        }

        let roles = Set([role, subrole].compactMap { $0 })
        if bundleIdentifier == "md.obsidian",
           roles.contains("AXTextArea") || roles.contains("AXGroup") {
            return .codeMirrorEstimate
        }

        if bundleIdentifier == "com.openai.codex",
           roles.contains("AXTextArea") {
            return .electronTextAreaEstimate
        }

        if bundleIdentifier == "com.google.Chrome",
           roles.contains("AXWebArea") || roles.contains("AXTextArea") {
            return .webAreaEstimate
        }

        if roles.contains("AXTextArea") {
            return .axTextAreaEstimate
        }

        if roles.contains("AXWebArea") {
            return .webAreaEstimate
        }

        return nil
    }
}

public enum SyntheticCaretEstimator {
    public static func estimate(
        input: SyntheticCaretEstimateInput,
        widthOf: (String) -> CGFloat
    ) -> CGRect? {
        guard input.elementRect.width > input.minimumElementWidth,
              input.elementRect.height > input.minimumElementHeight,
              input.lineHeight > 0 else {
            return nil
        }

        let lineHeight = max(input.lineHeight, 16)
        let maxLineWidth = max(
            input.minimumLineWidth,
            input.elementRect.width - (input.horizontalPadding * 2)
        )
        let visualLines = wrappedVisualLines(
            for: input.textBeforeCursor,
            maxLineWidth: maxLineWidth,
            widthOf: widthOf
        )
        let currentLine = visualLines.last ?? ""
        let currentLineWidth = min(widthOf(currentLine), maxLineWidth)
        let lineIndex = max(0, visualLines.count - 1)
        let preferredY = input.elementRect.minY
            + input.verticalPadding
            - (lineHeight * input.baselineLiftRatio)
            + (lineHeight * input.inlineVerticalDropRatio)
            + (CGFloat(lineIndex) * lineHeight)

        return CGRect(
            x: min(
                input.elementRect.minX + input.horizontalPadding + currentLineWidth + input.inlineGap,
                input.elementRect.maxX - input.horizontalPadding
            ),
            y: clampedCaretY(
                preferredY,
                caretHeight: lineHeight,
                elementRect: input.elementRect,
                windowRect: input.windowRect
            ),
            width: 0,
            height: lineHeight
        )
    }

    public static func wrappedVisualLines(
        for text: String,
        maxLineWidth: CGFloat,
        widthOf: (String) -> CGFloat
    ) -> [String] {
        var lines: [String] = []

        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            var current = ""

            for character in paragraph {
                let next = current + String(character)
                if !current.isEmpty, widthOf(next) > maxLineWidth {
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

    private static func clampedCaretY(
        _ preferredY: CGFloat,
        caretHeight: CGFloat,
        elementRect: CGRect,
        windowRect: CGRect?
    ) -> CGFloat {
        let boundingRect = windowRect ?? elementRect
        let upperPadding: CGFloat = 8
        let lowerPadding: CGFloat = 8
        let minY = min(
            elementRect.minY - (caretHeight * 1.25),
            boundingRect.maxY - caretHeight - lowerPadding
        )
        let maxY = max(elementRect.maxY + (caretHeight * 6), minY)
        let boundedMinY = max(boundingRect.minY + upperPadding, minY)
        let boundedMaxY = min(boundingRect.maxY - caretHeight - lowerPadding, maxY)

        guard boundedMaxY >= boundedMinY else {
            return preferredY
        }

        return min(max(preferredY, boundedMinY), boundedMaxY)
    }
}
