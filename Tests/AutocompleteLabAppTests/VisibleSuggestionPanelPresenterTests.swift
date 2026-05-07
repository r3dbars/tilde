import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Visible suggestion panel presenter")
struct VisibleSuggestionPanelPresenterTests {
    @Test("Refresh reuses the last placement with new text")
    func refreshReusesLastPlacementWithNewText() {
        let panel = FakeSuggestionPanel()
        let presenter = VisibleSuggestionPanelPresenter(panel: panel)

        _ = presenter.show(
            text: "first",
            near: CGRect(x: 10, y: 20, width: 1, height: 16),
            alignedTo: CGRect(x: 4, y: 20, width: 80, height: 16),
            boundedBy: CGRect(x: 0, y: 0, width: 200, height: 120),
            style: nil,
            renderMode: .inlineAdjacent
        )
        panel.showCalls.removeAll()

        let result = presenter.refresh(text: "second")

        #expect(result == .presented)
        #expect(panel.showCalls.count == 1)
        #expect(panel.showCalls[0].text == "second")
        #expect(panel.showCalls[0].anchorRect == CGRect(x: 10, y: 20, width: 1, height: 16))
        #expect(panel.showCalls[0].textLineRect == CGRect(x: 4, y: 20, width: 80, height: 16))
        #expect(panel.showCalls[0].clippingRect == CGRect(x: 0, y: 0, width: 200, height: 120))
    }

    @Test("Nudging offsets all tracked rects before refresh")
    func nudgingOffsetsAllTrackedRectsBeforeRefresh() {
        let panel = FakeSuggestionPanel()
        let presenter = VisibleSuggestionPanelPresenter(panel: panel)

        _ = presenter.show(
            text: "ghost",
            near: CGRect(x: 10, y: 20, width: 1, height: 16),
            alignedTo: CGRect(x: 4, y: 20, width: 80, height: 16),
            boundedBy: CGRect(x: 0, y: 0, width: 200, height: 120),
            style: nil,
            renderMode: .inlineAdjacent
        )
        panel.showCalls.removeAll()

        #expect(presenter.offsetPlacement(dx: 2, dy: -3))
        let result = presenter.refresh(text: "ghost")

        #expect(result == .presented)
        #expect(panel.showCalls[0].anchorRect == CGRect(x: 12, y: 17, width: 1, height: 16))
        #expect(panel.showCalls[0].textLineRect == CGRect(x: 6, y: 17, width: 80, height: 16))
        #expect(panel.showCalls[0].clippingRect == CGRect(x: 2, y: -3, width: 200, height: 120))
    }

    @Test("Hide clears placement")
    func hideClearsPlacement() {
        let panel = FakeSuggestionPanel()
        let presenter = VisibleSuggestionPanelPresenter(panel: panel)

        _ = presenter.show(
            text: "ghost",
            near: CGRect(x: 10, y: 20, width: 1, height: 16),
            alignedTo: nil,
            boundedBy: nil,
            style: nil,
            renderMode: .inlineAdjacent
        )
        presenter.hide()

        #expect(panel.hideCount == 1)
        #expect(presenter.refresh(text: "ghost") == .missingPlacement)
        #expect(!presenter.offsetPlacement(dx: 1, dy: 1))
    }
}

@MainActor
private final class FakeSuggestionPanel: SuggestionPanelPresenting {
    struct ShowCall {
        let text: String
        let anchorRect: CGRect
        let textLineRect: CGRect?
        let clippingRect: CGRect?
        let renderMode: SuggestionRenderMode
    }

    var showCalls: [ShowCall] = []
    var hideCount = 0
    var presentation = SuggestionPanelPresentation(
        accessibilityFrame: CGRect(x: 10, y: 20, width: 100, height: 20),
        appKitFrame: CGRect(x: 10, y: 20, width: 100, height: 20),
        accessibilityAnchorRect: CGRect(x: 10, y: 20, width: 1, height: 16),
        appKitAnchorRect: CGRect(x: 10, y: 20, width: 1, height: 16),
        appKitTextLineRect: nil,
        appKitClippingRect: nil,
        screenIdentifier: "test",
        screenFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        panelLevel: NSWindow.Level.statusBar.rawValue,
        ignoresMouseEvents: true
    )

    func show(
        text: String,
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) -> SuggestionPanelPresentation? {
        showCalls.append(ShowCall(
            text: text,
            anchorRect: anchorRect,
            textLineRect: textLineRect,
            clippingRect: clippingRect,
            renderMode: renderMode
        ))
        return presentation
    }

    func hide() {
        hideCount += 1
    }
}
