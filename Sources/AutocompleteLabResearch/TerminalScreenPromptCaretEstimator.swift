import AutocompleteLabCore
import CoreGraphics
import Foundation

public enum TerminalScreenPromptCaretEstimator {
    public static func caretRect(
        promptAnchor: ClaudeCodeTerminalScreenPromptAnchor,
        elementRect: CGRect,
        windowRect: CGRect?,
        lineHeight rawLineHeight: CGFloat,
        horizontalPadding: CGFloat = 18,
        inlineGap: CGFloat = 8,
        widthOfText: (String) -> CGFloat
    ) -> CGRect? {
        guard promptAnchor.lineCount > 0,
              promptAnchor.lineIndex >= 0,
              promptAnchor.lineIndex < promptAnchor.lineCount,
              elementRect.width > 80,
              elementRect.height > 20 else {
            return nil
        }

        let rowStep = min(max(rawLineHeight, 20), 24)
        let caretHeight = max(rowStep, 22)
        let rowsAfterPrompt = max(0, promptAnchor.lineCount - promptAnchor.lineIndex - 1)
        let rowY = min(
            max(
                elementRect.maxY - caretHeight - (CGFloat(rowsAfterPrompt) * rowStep),
                elementRect.minY
            ),
            max(elementRect.minY, elementRect.maxY - caretHeight)
        )
        let promptRowRect = CGRect(
            x: elementRect.minX,
            y: rowY,
            width: elementRect.width,
            height: caretHeight
        )

        return SyntheticCaretEstimator.caretRect(
            textBeforeCursor: promptAnchor.promptLineInputText,
            elementRect: promptRowRect,
            windowRect: windowRect,
            lineHeight: caretHeight,
            horizontalPadding: horizontalPadding,
            verticalPadding: 0,
            inlineGap: inlineGap,
            centerSingleLineWhenTall: false,
            widthOfText: widthOfText
        )
    }
}
