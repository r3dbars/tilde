import AppKit
import AutocompleteLabCore

@MainActor
protocol SuggestionPanelPresenting: AnyObject {
    func show(
        text: String,
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) -> SuggestionPanelPresentation?

    func hide()
}

extension SuggestionPanelController: SuggestionPanelPresenting {}

enum VisibleSuggestionPanelRefreshResult: Equatable {
    case presented
    case missingPlacement
    case panelFrameUnusable
}

@MainActor
final class VisibleSuggestionPanelPresenter {
    private let panel: SuggestionPanelPresenting
    private var placement: VisibleSuggestionPanelPlacement?

    init(panel: SuggestionPanelPresenting = SuggestionPanelController()) {
        self.panel = panel
    }

    func show(
        text: String,
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) -> SuggestionPanelPresentation? {
        placement = VisibleSuggestionPanelPlacement(
            anchorRect: anchorRect,
            textLineRect: textLineRect,
            clippingRect: clippingRect,
            style: style,
            renderMode: renderMode
        )
        return panel.show(
            text: text,
            near: anchorRect,
            alignedTo: textLineRect,
            boundedBy: clippingRect,
            style: style,
            renderMode: renderMode
        )
    }

    func updatePlacement(
        anchorRect: CGRect,
        textLineRect: CGRect?,
        clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) {
        placement = VisibleSuggestionPanelPlacement(
            anchorRect: anchorRect,
            textLineRect: textLineRect,
            clippingRect: clippingRect,
            style: style,
            renderMode: renderMode
        )
    }

    func refresh(text: String) -> VisibleSuggestionPanelRefreshResult {
        guard let placement else {
            return .missingPlacement
        }

        guard panel.show(
            text: text,
            near: placement.anchorRect,
            alignedTo: placement.textLineRect,
            boundedBy: placement.clippingRect,
            style: placement.style,
            renderMode: placement.renderMode
        ) != nil else {
            return .panelFrameUnusable
        }

        return .presented
    }

    func offsetPlacement(dx: CGFloat, dy: CGFloat) -> Bool {
        guard let placement else {
            return false
        }

        self.placement = placement.offsetBy(dx: dx, dy: dy)
        return true
    }

    func hide() {
        placement = nil
        panel.hide()
    }
}

private struct VisibleSuggestionPanelPlacement: Equatable {
    let anchorRect: CGRect
    let textLineRect: CGRect?
    let clippingRect: CGRect?
    let style: FocusedTextStyle?
    let renderMode: SuggestionRenderMode

    func offsetBy(dx: CGFloat, dy: CGFloat) -> VisibleSuggestionPanelPlacement {
        VisibleSuggestionPanelPlacement(
            anchorRect: anchorRect.offsetBy(dx: dx, dy: dy),
            textLineRect: textLineRect?.offsetBy(dx: dx, dy: dy),
            clippingRect: clippingRect?.offsetBy(dx: dx, dy: dy),
            style: style,
            renderMode: renderMode
        )
    }
}
