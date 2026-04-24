import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion panel frame calculator")
struct SuggestionPanelFrameCalculatorTests {
    @Test("Places ghost text immediately after the caret")
    func placesGhostTextAfterCaret() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 100, y: 800, width: 0, height: 20),
            textLineRect: CGRect(x: 80, y: 790, width: 20, height: 20),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 100)
        #expect(frame.minY == 790)
        #expect(frame.width == 166)
    }

    @Test("Keeps ghost text inside the screen")
    func keepsGhostTextInsideScreen() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1180, y: 10, width: 0, height: 20),
            textSize: CGSize(width: 200, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.maxX <= 1192)
        #expect(frame.minY >= 4)
    }

    @Test("Keeps ghost text inside the focused text boundary")
    func keepsGhostTextInsideFocusedTextBoundary() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 900, y: 800, width: 0, height: 28),
            textLineRect: CGRect(x: 80, y: 790, width: 840, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 940, height: 760),
            textSize: CGSize(width: 300, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 900)
        #expect(frame.maxX <= 1016)
    }

    @Test("Falls back to the caret when an app reports the whole editor as the line")
    func ignoresOversizedLineRect() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 536, y: 204, width: 0, height: 28),
            textLineRect: CGRect(x: 468, y: 78, width: 1328, height: 172),
            boundaryFrame: CGRect(x: 468, y: 78, width: 1328, height: 172),
            textSize: CGSize(width: 110, height: 24),
            screenFrame: CGRect(x: 0, y: 0, width: 2048, height: 1152)
        )

        #expect(decision.frame.minX == 536)
        #expect(decision.frame.minY == 204)
        #expect(decision.frame.height == 28)
        #expect(decision.lineRectStatus == .tooTall)
        #expect(decision.strategy == .clippedCaretAnchored)
    }

    @Test("Falls back to the caret when the reported line is vertically detached")
    func ignoresDetachedLineRect() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 520, y: 612, width: 0, height: 22),
            textLineRect: CGRect(x: 490, y: 562, width: 360, height: 22),
            textSize: CGSize(width: 120, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(decision.frame.minX == 520)
        #expect(decision.frame.minY == 612)
        #expect(decision.frame.height == 22)
        #expect(decision.lineRectStatus == .verticallyDetached)
        #expect(decision.strategy == .caretAnchored)
    }

    @Test("OpenAI composer profile ignores line rects and anchors to the caret")
    func openAIComposerUsesCaretOnlyProfile() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            appBundleIdentifier: "com.openai.codex",
            caretRect: CGRect(x: 536, y: 204, width: 0, height: 28),
            textLineRect: CGRect(x: 510, y: 198, width: 360, height: 28),
            boundaryFrame: CGRect(x: 468, y: 78, width: 1328, height: 172),
            textSize: CGSize(width: 110, height: 24),
            screenFrame: CGRect(x: 0, y: 0, width: 2048, height: 1152)
        )

        #expect(decision.profileID == "openai-composer")
        #expect(decision.lineRectStatus == .ignoredByProfile)
        #expect(decision.frame.minX == 536)
        #expect(decision.frame.minY == 204)
        #expect(decision.strategy == .clippedCaretAnchored)
    }

    @Test("Ignores focused text boundaries when the caret is outside them")
    func ignoresBoundaryWhenCaretOutside() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 900, y: 800, width: 0, height: 28),
            textLineRect: CGRect(x: 890, y: 792, width: 120, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 300, height: 120),
            textSize: CGSize(width: 300, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(decision.boundaryStatus == .caretOutside)
        #expect(decision.frame.maxX <= 1192)
    }

    @Test("Marks placement hidden when clipping leaves no usable width")
    func marksNoRoomPlacement() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 1013, y: 800, width: 0, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 940, height: 760),
            textSize: CGSize(width: 300, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(decision.boundaryStatus == .used)
        #expect(decision.frame.width < 8)
        #expect(decision.strategy == .hiddenNoRoom)
    }
}
