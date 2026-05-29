import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret estimator")
struct SyntheticCaretEstimatorTests {
    @Test("Returns nil for tiny editor bounds")
    func returnsNilForTinyEditorBounds() {
        #expect(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: CGRect(x: 0, y: 0, width: 60, height: 20),
            windowRect: nil,
            lineHeight: 20,
            widthOfText: fixedWidth
        ) == nil)
    }

    @Test("Places caret after current line text")
    func placesCaretAfterCurrentLineText() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: CGRect(x: 100, y: 200, width: 320, height: 80),
            windowRect: CGRect(x: 80, y: 160, width: 420, height: 220),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.origin.x == 186)
        #expect(caret.origin.y == 204)
        #expect(caret.width == 0)
        #expect(caret.height == 20)
    }

    @Test("Wraps long prompt text to later visual lines")
    func wrapsLongPromptTextToLaterVisualLines() throws {
        let shortCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "short",
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 160),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 300),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))
        let wrappedCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "this line should wrap",
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 160),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 300),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(wrappedCaret.origin.y > shortCaret.origin.y)
    }

    @Test("Can vertically center a single-line prompt in a tall composer")
    func canCenterSingleLinePromptInTallComposer() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we make this inst",
            elementRect: CGRect(x: 400, y: 670, width: 680, height: 64),
            windowRect: CGRect(x: 380, y: 640, width: 730, height: 120),
            lineHeight: 24,
            horizontalPadding: 14,
            inlineGap: 2,
            centerSingleLineWhenTall: true,
            widthOfText: fixedWidth
        ))

        #expect(caret.origin.x == 626)
        #expect(caret.origin.y == 690)
        #expect(caret.height == 24)
    }

    @Test("Clamps caret inside containing window")
    func clampsCaretInsideContainingWindow() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: String(repeating: "w", count: 80),
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 120),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 180),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.maxY <= 332)
    }

    @Test("Caps measured text for long prompts")
    func capsMeasuredTextForLongPrompts() throws {
        var measurementCount = 0
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: String(repeating: "w", count: 20_000),
            elementRect: CGRect(x: 100, y: 200, width: 240, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 320, height: 260),
            lineHeight: 20,
            widthOfText: { text in
                measurementCount += 1
                return CGFloat(text.count * 10)
            }
        ))

        #expect(caret.minX >= 100)
        #expect(measurementCount < 4_100)
    }

    @Test("Keeps negative-origin synthetic carets inside focused bounds")
    func keepsNegativeOriginSyntheticCaretsInsideFocusedBounds() throws {
        let elementRect = CGRect(x: -1900, y: 81, width: 713, height: 105)
        let windowRect = CGRect(x: -1924, y: 57, width: 761, height: 153)
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: String(repeating: "typing ", count: 84),
            elementRect: elementRect,
            windowRect: windowRect,
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.minX >= elementRect.minX)
        #expect(caret.maxX <= elementRect.maxX)
        #expect(caret.minY >= windowRect.minY)
        #expect(caret.maxY <= windowRect.maxY)
    }

    @Test("Rejects element and window rects from different coordinate spaces")
    func rejectsMixedCoordinateSpaces() {
        let caret = SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: CGRect(x: -1900, y: 81, width: 713, height: 105),
            windowRect: CGRect(x: 400, y: 400, width: 761, height: 153),
            lineHeight: 20,
            widthOfText: fixedWidth
        )

        #expect(caret == nil)
    }

    @Test("Places synthetic carets inside Chrome real editor rows")
    func placesSyntheticCaretsInsideChromeRealEditorRows() throws {
        let monacoCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Smoke proof feels inst",
            elementRect: CGRect(x: 858, y: 216, width: 654, height: 24),
            windowRect: CGRect(x: 760, y: 180, width: 776, height: 300),
            lineHeight: 20,
            horizontalPadding: 18,
            verticalPadding: 4,
            inlineGap: 44,
            widthOfText: fixedWidth
        ))

        #expect(monacoCaret.minX >= 858)
        #expect(monacoCaret.maxX <= 1512)
        #expect(monacoCaret.minY >= 180)
        #expect(monacoCaret.maxY <= 480)

        let proseMirrorCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Smoke proof feels inst",
            elementRect: CGRect(x: 784, y: 237, width: 728, height: 206),
            windowRect: CGRect(x: 760, y: 213, width: 776, height: 254),
            lineHeight: 20,
            horizontalPadding: 18,
            verticalPadding: 14,
            inlineGap: 8,
            widthOfText: fixedWidth
        ))

        #expect(proseMirrorCaret.minX >= 784)
        #expect(proseMirrorCaret.maxX <= 1512)
        #expect(proseMirrorCaret.minY >= 213)
        #expect(proseMirrorCaret.maxY <= 467)
    }

    @Test("Places synthetic carets in a derived Obsidian scrolled tail row")
    func placesSyntheticCaretsInDerivedObsidianScrolledTailRow() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Smoke proof feels",
            elementRect: CGRect(x: 901, y: 751, width: 320, height: 42),
            windowRect: CGRect(x: 0, y: 0, width: 1352, height: 878),
            lineHeight: 21,
            horizontalPadding: 18,
            verticalPadding: 4,
            inlineGap: 8,
            widthOfText: fixedWidth
        ))

        #expect(caret.minX > 1_050)
        #expect(caret.maxX <= 1_221)
        #expect(caret.minY >= 751)
        #expect(caret.maxY <= 793)
    }

    @Test("Places terminal screen prompt carets on the proof-marked prompt row")
    func placesTerminalScreenPromptCaretsOnProofMarkedPromptRow() throws {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Make this setting the feature con",
            promptLineInputText: "Make this setting the feature con",
            lineIndex: 34,
            lineCount: 38
        )
        let caret = try #require(TerminalScreenPromptCaretEstimator.caretRect(
            promptAnchor: anchor,
            elementRect: CGRect(x: 120, y: 60, width: 900, height: 760),
            windowRect: CGRect(x: 100, y: 40, width: 940, height: 800),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.minY >= 730)
        #expect(caret.minY < 780)
        #expect(caret.minX > 420)
        #expect(caret.maxX <= 1_020)
    }

    @Test("Bottom-aligns sparse terminal screen prompt rows instead of using the header area")
    func bottomAlignsSparseTerminalScreenPromptRows() throws {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Make this setting the feature con",
            promptLineInputText: "Make this setting the feature con",
            lineIndex: 4,
            lineCount: 5
        )
        let caret = try #require(TerminalScreenPromptCaretEstimator.caretRect(
            promptAnchor: anchor,
            elementRect: CGRect(x: 120, y: 60, width: 900, height: 760),
            windowRect: CGRect(x: 100, y: 40, width: 940, height: 800),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.minY >= 780)
        #expect(caret.minY <= 800)
    }

    @Test("Keeps terminal screen prompt carets stable when scrollback above the prompt changes")
    func keepsTerminalScreenPromptCaretsStableWhenScrollbackAbovePromptChanges() throws {
        let first = try #require(TerminalScreenPromptCaretEstimator.caretRect(
            promptAnchor: ClaudeCodeTerminalScreenPromptAnchor(
                inputText: "Make this setting the feature con",
                promptLineInputText: "Make this setting the feature con",
                lineIndex: 34,
                lineCount: 38
            ),
            elementRect: CGRect(x: 120, y: 60, width: 900, height: 760),
            windowRect: CGRect(x: 100, y: 40, width: 940, height: 800),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))
        let afterScrollbackChange = try #require(TerminalScreenPromptCaretEstimator.caretRect(
            promptAnchor: ClaudeCodeTerminalScreenPromptAnchor(
                inputText: "Make this setting the feature con",
                promptLineInputText: "Make this setting the feature con",
                lineIndex: 35,
                lineCount: 39
            ),
            elementRect: CGRect(x: 120, y: 60, width: 900, height: 760),
            windowRect: CGRect(x: 100, y: 40, width: 940, height: 800),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(afterScrollbackChange.origin.y == first.origin.y)
        #expect(afterScrollbackChange.height == first.height)
    }

    private func fixedWidth(_ text: String) -> CGFloat {
        CGFloat(text.count * 10)
    }
}
