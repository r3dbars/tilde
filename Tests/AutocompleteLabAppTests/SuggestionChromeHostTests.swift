import CoreGraphics
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Suggestion chrome host")
struct SuggestionChromeHostTests {
    @Test("status anchor prefers caret, then text line, element, and window")
    func statusAnchorPrefersMostSpecificGeometry() {
        let caret = CGRect(x: 1, y: 2, width: 3, height: 4)
        let line = CGRect(x: 5, y: 6, width: 7, height: 8)
        let element = CGRect(x: 9, y: 10, width: 11, height: 12)
        let window = CGRect(x: 13, y: 14, width: 15, height: 16)
        let context = makeContext(
            caretRect: caret,
            textLineRect: line,
            elementRect: element,
            windowRect: window
        )

        #expect(SuggestionChromeHost.statusAnchorRect(for: context) == caret)
    }

    @Test("status anchor falls back when caret geometry is unavailable")
    func statusAnchorFallsBackWhenCaretGeometryIsUnavailable() {
        let window = CGRect(x: 13, y: 14, width: 15, height: 16)
        let context = makeContext(
            caretRect: nil,
            textLineRect: nil,
            elementRect: nil,
            windowRect: window
        )

        #expect(SuggestionChromeHost.statusAnchorRect(for: context) == window)
    }

    private func makeContext(
        caretRect: CGRect?,
        textLineRect: CGRect?,
        elementRect: CGRect?,
        windowRect: CGRect?
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Untitled"),
            textBeforeCursor: "draft",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            windowIdentifier: 42,
            textLineRect: textLineRect,
            textStyle: nil,
            isSecure: false,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: true,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
    }
}
