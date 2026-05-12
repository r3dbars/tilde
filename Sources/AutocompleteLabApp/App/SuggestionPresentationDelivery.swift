import AutocompleteLabCore
import CoreGraphics
import Foundation

struct SuggestionPresentationDeliveryRequest {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let completionRequest: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let placement: PlacementHealthPresentation
    let latencyMilliseconds: Int
    let requestMetadata: [String: String]
    let geometryMetadata: [String: String]
    let learningMetadata: [String: String]
    let candidateSelectionMetadata: [String: String]
    let displayScoreMetadata: [String: String]
    let replacementMetadata: [String: String]
}

struct SuggestionPresentationDeliverySuccess: Equatable {
    let panelRect: CGRect
    let placement: PlacementHealthPresentation
}

enum SuggestionPresentationDeliveryFailure: Error, Equatable {
    case panelFrameUnusable

    var reason: String {
        switch self {
        case .panelFrameUnusable:
            return "panel-frame-unusable"
        }
    }
}

@MainActor
final class SuggestionPresentationDelivery {
    typealias PanelPresenter = @MainActor (
        _ text: String,
        _ anchorRect: CGRect,
        _ textLineRect: CGRect?,
        _ clippingRect: CGRect?,
        _ textStyle: FocusedTextStyle?,
        _ renderMode: SuggestionRenderMode
    ) -> CGRect?
    typealias FieldStatusPresenter = @MainActor (_ context: FocusedTextContext) -> Void

    private let panelPresenter: PanelPresenter
    private let fieldStatusPresenter: FieldStatusPresenter
    private let tracePayloadBuilder: SuggestionPresentationTracePayloadBuilder

    init(
        panelPresenter: @escaping PanelPresenter,
        fieldStatusPresenter: @escaping FieldStatusPresenter,
        tracePayloadBuilder: SuggestionPresentationTracePayloadBuilder = SuggestionPresentationTracePayloadBuilder()
    ) {
        self.panelPresenter = panelPresenter
        self.fieldStatusPresenter = fieldStatusPresenter
        self.tracePayloadBuilder = tracePayloadBuilder
    }

    func deliver(
        _ request: SuggestionPresentationDeliveryRequest
    ) -> Result<SuggestionPresentationDeliverySuccess, SuggestionPresentationDeliveryFailure> {
        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: request.placement,
            fallbackRenderMode: request.profile.fallbackRenderMode
        ) { placement in
            panelPresenter(
                request.suggestion.visibleText,
                placement.anchorRect,
                placement.renderMode == .inlineAdjacent ? placement.textLineRect : nil,
                placement.clippingRect,
                request.context.textStyle,
                placement.renderMode
            )
        }

        guard let panelRect = attempt.panelRect else {
            return .failure(.panelFrameUnusable)
        }

        fieldStatusPresenter(request.context)

        return .success(SuggestionPresentationDeliverySuccess(
            panelRect: panelRect,
            placement: attempt.placement
        ))
    }

    func tracePayload(
        for request: SuggestionPresentationDeliveryRequest,
        placement: PlacementHealthPresentation? = nil,
        panelRect: CGRect,
        screenshotCapture: TraceScreenshotCaptureResult
    ) -> SuggestionPresentationTracePayload {
        let placement = placement ?? request.placement
        return tracePayloadBuilder.presented(
            suggestionID: request.suggestionID,
            requestMode: request.completionRequest.mode.rawValue,
            renderMode: placement.renderMode.rawValue,
            visibleText: request.suggestion.visibleText,
            visibleWordCount: request.suggestion.visibleWordCount,
            latencyMilliseconds: request.latencyMilliseconds,
            anchorRect: placement.anchorRect,
            textLineRect: placement.textLineRect,
            panelRect: panelRect,
            clippingRect: placement.clippingRect,
            screenshotCaptureRect: screenshotCapture.rectDescription,
            requestMetadata: request.requestMetadata,
            geometryMetadata: request.geometryMetadata,
            learningMetadata: request.learningMetadata,
            placementMetadata: placement.metadata,
            candidateSelectionMetadata: request.candidateSelectionMetadata,
            displayScoreMetadata: request.displayScoreMetadata,
            replacementMetadata: request.replacementMetadata
        )
    }
}
