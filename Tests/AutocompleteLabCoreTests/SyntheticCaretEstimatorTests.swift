import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret estimator")
struct SyntheticCaretEstimatorTests {
    @Test("Estimates caret position on the current wrapped line")
    func estimatesCaretOnWrappedLine() throws {
        let input = SyntheticCaretEstimateInput(
            textBeforeCursor: "abcdefghijklmnop",
            elementRect: CGRect(x: 100, y: 500, width: 120, height: 120),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 900),
            lineHeight: 20,
            horizontalPadding: 10,
            verticalPadding: 4,
            inlineGap: 6
        )

        let caret = try #require(SyntheticCaretEstimator.estimate(input: input) { text in
            CGFloat(text.count * 10)
        })

        #expect(caret.minX == 176)
        #expect(caret.minY == 524)
        #expect(caret.height == 20)
    }

    @Test("Keeps synthetic caret inside cramped window bounds")
    func clampsSyntheticCaretToWindow() throws {
        let input = SyntheticCaretEstimateInput(
            textBeforeCursor: String(repeating: "x", count: 200),
            elementRect: CGRect(x: 20, y: 20, width: 110, height: 70),
            windowRect: CGRect(x: 0, y: 0, width: 160, height: 120),
            lineHeight: 22
        )

        let caret = try #require(SyntheticCaretEstimator.estimate(input: input) { text in
            CGFloat(text.count * 9)
        })

        #expect(caret.minY >= 8)
        #expect(caret.maxY <= 112)
        #expect(caret.maxX <= 112)
    }

    @Test("Shares one safe eligibility gate across app families")
    func selectsSyntheticCaretSources() {
        let rect = CGRect(x: 0, y: 0, width: 240, height: 80)

        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .electronTextAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .webAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "md.obsidian",
            role: "AXGroup",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .codeMirrorEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .axTextAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: false,
            canReadSelectedTextRange: true
        ) == nil)
    }

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

    private func fixedWidth(_ text: String) -> CGFloat {
        CGFloat(text.count * 10)
    }
}
