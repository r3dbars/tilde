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
        #expect(frame.minY == 800)
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
        #expect(decision.lineRectStatus == .ignoredByProfile)
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
        #expect(decision.lineRectStatus == .ignoredByProfile)
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

    @Test("Notes profile uses a trusted glyph row for vertical placement")
    func notesProfileUsesTrustedGlyphRowVertically() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            appBundleIdentifier: "com.apple.Notes",
            caretRect: CGRect(x: 986, y: 751, width: 0, height: 23),
            textLineRect: CGRect(x: 974, y: 728, width: 12, height: 23),
            boundaryFrame: CGRect(x: 930, y: 240, width: 600, height: 560),
            textSize: CGSize(width: 34, height: 23),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )

        #expect(decision.profileID == "notes")
        #expect(decision.lineRectStatus == .used)
        #expect(decision.frame.minX == 986)
        #expect(decision.frame.minY == 728)
        #expect(decision.strategy == .clippedLineAnchored)
    }

    @Test("Notes profile rejects glyph rows from the previous wrapped line")
    func notesProfileRejectsPreviousWrappedLine() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            appBundleIdentifier: "com.apple.Notes",
            caretRect: CGRect(x: 540, y: 751, width: 0, height: 23),
            textLineRect: CGRect(x: 1240, y: 728, width: 12, height: 23),
            boundaryFrame: CGRect(x: 500, y: 240, width: 820, height: 560),
            textSize: CGSize(width: 34, height: 23),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )

        #expect(decision.profileID == "notes")
        #expect(decision.lineRectStatus == .horizontallyDetached)
        #expect(decision.frame.minX == 540)
        #expect(decision.frame.minY == 751)
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
        #expect(decision.strategy == .hiddenNoRoom)
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

    @Test("Marks placement hidden when the full suggestion would be clipped")
    func marksClippedSuggestionHidden() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 970, y: 800, width: 0, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 940, height: 760),
            textSize: CGSize(width: 80, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(decision.boundaryStatus == .used)
        #expect(decision.frame.width == 46)
        #expect(decision.strategy == .hiddenNoRoom)
    }

    @Test("Shows narrow panels when the full short suggestion still fits")
    func showsNarrowPanelForShortSuggestion() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            caretRect: CGRect(x: 996, y: 800, width: 0, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 940, height: 760),
            textSize: CGSize(width: 14, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(decision.boundaryStatus == .used)
        #expect(decision.frame.width == 20)
        #expect(decision.strategy == .clippedCaretAnchored)
    }

    @Test("Trust profile still rejects detached line rects but anchors to the caret")
    func trustProfileRejectsDetachedLineRect() {
        let registry = AppCompatibilityRegistry(
            profiles: [
                AppCompatibilityProfile(
                    id: "trust-test",
                    displayName: "Trust Test",
                    bundleIdentifierPrefixes: ["example.trust"],
                    lineRectPolicy: .trustAfterValidation
                )
            ]
        )
        let decision = InlineGhostPlacementResolver.resolve(
            InlineGhostPlacementRequest(
                appBundleIdentifier: "example.trust",
                caretRect: CGRect(x: 520, y: 612, width: 0, height: 22),
                textLineRect: CGRect(x: 490, y: 562, width: 360, height: 22),
                boundaryFrame: nil,
                textSize: CGSize(width: 120, height: 20),
                screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                minimumWidth: 40,
                maximumWidth: 420
            ),
            registry: registry
        )

        #expect(decision.lineRectStatus == .verticallyDetached)
        #expect(decision.frame.minY == 612)
        #expect(decision.strategy == .caretAnchored)
    }
}
