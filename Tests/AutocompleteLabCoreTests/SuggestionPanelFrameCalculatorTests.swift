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
        #expect(SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame))
    }

    @Test("Lifts inline ghost text without changing its horizontal placement")
    func liftsInlineGhostText() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 100, y: 800, width: 0, height: 20),
            textLineRect: CGRect(x: 80, y: 790, width: 20, height: 20),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            verticalAlignmentOffset: 7
        )

        #expect(frame.minX == 100)
        #expect(frame.minY == 797)
        #expect(frame.width == 166)
        #expect(frame.height == 20)
    }

    @Test("Spaces inline ghost text away from a zero-width caret")
    func spacesInlineGhostTextAfterCaret() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 100, y: 800, width: 0, height: 20),
            textLineRect: CGRect(x: 80, y: 790, width: 20, height: 20),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            horizontalAlignmentOffset: 3
        )

        #expect(frame.minX == 103)
        #expect(frame.minY == 790)
        #expect(frame.width == 166)
    }

    @Test("Keeps horizontal ghost spacing inside clipping bounds")
    func keepsHorizontalGhostSpacingInsideClippingBounds() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 350, y: 240, width: 0, height: 20),
            textSize: CGSize(width: 40, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
            clippingFrame: CGRect(x: 20, y: 180, width: 380, height: 80),
            horizontalAlignmentOffset: 3
        )

        #expect(frame.maxX <= 392)
    }

    @Test("Lifts profile-routed inline ghost text inside its boundary")
    func liftsProfileRoutedInlineGhostText() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            appBundleIdentifier: "com.openai.codex",
            caretRect: CGRect(x: 100, y: 790, width: 0, height: 20),
            boundaryFrame: CGRect(x: 20, y: 100, width: 800, height: 760),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            verticalAlignmentOffset: 7
        )

        #expect(frame.minX == 100)
        #expect(frame.minY == 797)
    }

    @Test("Keeps ghost text inside the screen")
    func keepsGhostTextInsideScreen() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1180, y: 10, width: 0, height: 20),
            textSize: CGSize(width: 200, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.maxX <= 1192)
        #expect(frame.minX == 1180)
        #expect(frame.minY >= 4)
        #expect(!SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame))
    }

    @Test("Hides inline ghost when less than one useful word can fit")
    func hidesInlineGhostWhenLessThanOneUsefulWordFits() {
        let crampedFrame = CGRect(x: 100, y: 100, width: 30, height: 20)
        let usefulFrame = CGRect(x: 100, y: 100, width: 40, height: 20)

        #expect(
            SuggestionPanelFrameCalculator.minimumUsefulInlineWordWidth == 40
        )
        #expect(!SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(crampedFrame))
        #expect(SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(usefulFrame))
    }

    @Test("Clips inline ghost instead of moving it before the caret")
    func clipsInlineGhostInsteadOfMovingBeforeCaret() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 390, y: 240, width: 0, height: 20),
            textSize: CGSize(width: 180, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
            clippingFrame: CGRect(x: 20, y: 180, width: 380, height: 80)
        )

        #expect(frame.minX == 390)
        #expect(frame.maxX <= 392)
        #expect(!SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame))
    }

    @Test("Keeps inline ghost text inside the focused editor bounds")
    func keepsInlineGhostTextInsideEditorBounds() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1265, y: 420, width: 0, height: 22),
            textLineRect: CGRect(x: 20, y: 415, width: 1245, height: 22),
            textSize: CGSize(width: 360, height: 22),
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 900),
            clippingFrame: CGRect(x: 0, y: 80, width: 1312, height: 740)
        )

        #expect(frame.minX >= 1264)
        #expect(frame.maxX <= 1304)
    }

    @Test("Suppresses inline ghost when less than a useful word fits")
    func suppressesInlineGhostWhenLessThanUsefulWordFits() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1268, y: 420, width: 0, height: 22),
            textLineRect: CGRect(x: 20, y: 415, width: 1248, height: 22),
            textSize: CGSize(width: 180, height: 22),
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 900),
            clippingFrame: CGRect(x: 0, y: 80, width: 1312, height: 740)
        )

        #expect(frame.width < 40)
        #expect(!SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame))
    }

    @Test("Keeps inline ghost text inside negative-origin editor bounds")
    func keepsInlineGhostTextInsideNegativeOriginEditorBounds() {
        let screenFrame = CGRect(x: -1920, y: 300, width: 1920, height: 1080)
        let clippingFrame = CGRect(x: -1900, y: 1194, width: 713, height: 105)
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: -1380, y: 1195, width: 0, height: 20),
            textLineRect: CGRect(x: -1380, y: 1195, width: 0, height: 20),
            textSize: CGSize(width: 180, height: 20),
            screenFrame: screenFrame,
            clippingFrame: clippingFrame
        )

        #expect(frame.minX >= clippingFrame.minX)
        #expect(frame.maxX <= clippingFrame.maxX)
        #expect(frame.minY >= screenFrame.minY)
        #expect(frame.maxY <= screenFrame.maxY)
    }

    @Test("Keeps inline ghost text inside vertical editor clipping")
    func keepsInlineGhostTextInsideVerticalEditorClipping() {
        let clippingFrame = CGRect(x: 100, y: 300, width: 500, height: 42)
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 220, y: 260, width: 0, height: 20),
            textLineRect: CGRect(x: 120, y: 260, width: 100, height: 20),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 900, height: 700),
            clippingFrame: clippingFrame
        )

        #expect(frame.minY >= clippingFrame.minY + 4)
        #expect(frame.maxY <= clippingFrame.maxY - 4)
    }

    @Test("Keeps panel valid on narrow screens")
    func keepsPanelValidOnNarrowScreens() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 88, y: 20, width: 0, height: 18),
            textSize: CGSize(width: 500, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 96, height: 80)
        )

        #expect(frame.minX >= 8)
        #expect(frame.maxX <= 88)
        #expect(frame.minX >= 87)
        #expect(frame.width == 1)
        #expect(!SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame))
    }

    @Test("Keeps inline ghost inside an upper vertical display")
    func keepsInlineGhostInsideUpperVerticalDisplay() {
        let upperDisplay = CGRect(x: 0, y: 982, width: 1920, height: 1080)
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 620, y: 1_820, width: 0, height: 22),
            textLineRect: CGRect(x: 420, y: 1_812, width: 200, height: 22),
            textSize: CGSize(width: 220, height: 22),
            screenFrame: upperDisplay,
            clippingFrame: CGRect(x: 80, y: 1_060, width: 920, height: 820)
        )

        #expect(frame.minX == 620)
        #expect(frame.minY >= upperDisplay.minY + 4)
        #expect(frame.maxY <= upperDisplay.maxY - 4)
        #expect(frame.maxX <= 992)
    }

    @Test("Keeps inline panel valid inside cramped clipping bounds")
    func keepsInlinePanelValidInsideCrampedClippingBounds() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 38, y: 40, width: 0, height: 18),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 120, height: 100),
            clippingFrame: CGRect(x: 10, y: 10, width: 40, height: 60)
        )

        #expect(frame.minX >= 18)
        #expect(frame.maxX <= 42)
        #expect(frame.width > 0)
    }

    @Test("Mirror fallback anchors in the middle of large focused elements")
    func mirrorFallbackAnchorsInMiddleOfLargeFocusedElements() {
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 80, y: 600, width: 500, height: 220),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 88)
        #expect(frame.minY == 695)
        #expect(frame.width == 190)
    }

    @Test("Keeps floating mirror inside vertical editor clipping")
    func keepsFloatingMirrorInsideVerticalEditorClipping() {
        let clippingFrame = CGRect(x: 100, y: 300, width: 500, height: 60)
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 120, y: 260, width: 0, height: 22),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 900, height: 700),
            clippingFrame: clippingFrame
        )

        #expect(frame.minY >= clippingFrame.minY + 4)
        #expect(frame.maxY <= clippingFrame.maxY - 4)
    }

    @Test("Mirror fallback still follows small caret-like anchors")
    func mirrorFallbackFollowsSmallAnchors() {
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 80, y: 600, width: 0, height: 22),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 88)
        #expect(frame.maxY == 618)
        #expect(frame.width == 190)
    }

    @Test("Keeps mirror panel inside cramped clipping bounds")
    func keepsMirrorPanelInsideCrampedClippingBounds() {
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 22, y: 30, width: 0, height: 22),
            textSize: CGSize(width: 240, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 120, height: 100),
            clippingFrame: CGRect(x: 10, y: 10, width: 44, height: 70)
        )

        #expect(frame.minX >= 18)
        #expect(frame.maxX <= 46)
        #expect(frame.width > 0)
    }

    @Test("Skips refreshing identical panel presentations")
    func skipsIdenticalPanelPresentations() {
        let frame = CGRect(x: 100, y: 600, width: 180, height: 22)

        #expect(!SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make",
            nextFrame: frame.offsetBy(dx: 0.25, dy: -0.25),
            nextRenderMode: .inlineAdjacent
        ))

        #expect(SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make this",
            nextFrame: frame,
            nextRenderMode: .inlineAdjacent
        ))

        #expect(SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make",
            nextFrame: frame.offsetBy(dx: 2, dy: 0),
            nextRenderMode: .inlineAdjacent
        ))
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

    @Test("Wrapped line placement uses the current visual line")
    func wrappedLinePlacementUsesCurrentVisualLine() {
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            appBundleIdentifier: "com.apple.Notes",
            caretRect: CGRect(x: 540, y: 751, width: 0, height: 23),
            textLineRect: CGRect(x: 520, y: 751, width: 20, height: 23),
            boundaryFrame: CGRect(x: 500, y: 240, width: 820, height: 560),
            textSize: CGSize(width: 120, height: 23),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )

        #expect(decision.lineRectStatus == .used)
        #expect(decision.frame.minX == 540)
        #expect(decision.frame.minY == 751)
        #expect(decision.strategy == .clippedLineAnchored)
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
