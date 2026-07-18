import AppKit
import AutocompleteLabCore
import CoreGraphics

@MainActor
final class SuggestionChromeHost {
    private let suggestionPanel: SuggestionPanelController
    private let fieldStatusIndicator: FieldStatusIndicatorController
    lazy var presentationDelivery = SuggestionPresentationDelivery(
        panelPresenter: { [weak self] text, anchorRect, textLineRect, clippingRect, textStyle, renderMode in
            self?.showSuggestion(
                text: text,
                near: anchorRect,
                alignedTo: textLineRect,
                boundedBy: clippingRect,
                style: textStyle,
                renderMode: renderMode
            )
        },
        fieldStatusPresenter: { [weak self] context in
            self?.showFieldStatusIndicator(.shown, context: context)
        }
    )

    init(
        suggestionPanel: SuggestionPanelController = SuggestionPanelController(),
        fieldStatusIndicator: FieldStatusIndicatorController = FieldStatusIndicatorController()
    ) {
        self.suggestionPanel = suggestionPanel
        self.fieldStatusIndicator = fieldStatusIndicator
    }

    var isSuggestionPanelVisible: Bool {
        suggestionPanel.isVisible
    }

    var isFieldStatusIndicatorVisible: Bool {
        fieldStatusIndicator.isVisible
    }

    @discardableResult
    func showSuggestion(
        text: String,
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) -> CGRect? {
        suggestionPanel.show(
            text: text,
            near: anchorRect,
            alignedTo: textLineRect,
            boundedBy: clippingRect,
            style: style,
            renderMode: renderMode
        )
    }

    func hideSuggestion() {
        suggestionPanel.hide()
    }

    func showFieldStatusIndicator(
        _ state: FieldStatusIndicatorState,
        context: FocusedTextContext
    ) {
        guard let anchorRect = Self.statusAnchorRect(for: context) else {
            hideFieldStatusIndicator()
            return
        }

        fieldStatusIndicator.show(
            state: state,
            near: anchorRect,
            fieldRect: context.elementRect
        )
    }

    func hideFieldStatusIndicator() {
        fieldStatusIndicator.hide()
    }

    nonisolated static func statusAnchorRect(for context: FocusedTextContext) -> CGRect? {
        context.caretRect
            ?? context.textLineRect
            ?? context.elementRect
            ?? context.windowRect
    }
}
