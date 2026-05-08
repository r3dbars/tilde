import CoreGraphics
import Foundation

struct SuggestionPresentationTracePayload: Equatable {
    let rawTraceMetadata: [String: String]
    let diagnosticsMetadata: [String: String]
}

struct SuggestionPresentationTracePayloadBuilder {
    func presented(
        suggestionID: String,
        requestMode: String,
        renderMode: String,
        visibleText: String,
        visibleWordCount: Int,
        latencyMilliseconds: Int,
        anchorRect: CGRect,
        textLineRect: CGRect?,
        panelRect: CGRect,
        clippingRect: CGRect?,
        screenshotCaptureRect: String,
        requestMetadata: [String: String],
        geometryMetadata: [String: String],
        learningMetadata: [String: String],
        placementMetadata: [String: String],
        candidateSelectionMetadata: [String: String],
        displayScoreMetadata: [String: String],
        replacementMetadata: [String: String]
    ) -> SuggestionPresentationTracePayload {
        let presentationMetadata = [
            "effectiveRenderMode": renderMode,
            "visibleChars": String(visibleText.count),
            "visibleWords": String(visibleWordCount),
            "anchorRect": compactRectDescription(anchorRect),
            "textLineRect": textLineRect.map(compactRectDescription) ?? "none",
            "suggestionPanelRect": compactRectDescription(panelRect),
            "clippingRect": clippingRect.map(compactRectDescription) ?? "none",
            "screenshotCaptureRect": screenshotCaptureRect
        ]

        let rawTraceMetadata = presentationMetadata
            .merging(requestMetadata) { current, _ in current }
            .merging(geometryMetadata) { current, _ in current }
            .merging(learningMetadata) { current, _ in current }
            .merging(placementMetadata) { current, _ in current }
            .merging(candidateSelectionMetadata) { current, _ in current }
            .merging(displayScoreMetadata) { current, _ in current }
            .merging(replacementMetadata) { current, _ in current }

        let diagnosticsMetadata = presentationMetadata
            .merging([
                "requestMode": requestMode,
                "traceID": String(suggestionID.prefix(8)),
                "suggestionID": suggestionID,
                "latencyMilliseconds": String(latencyMilliseconds)
            ]) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
            .merging(learningMetadata) { current, _ in current }
            .merging(placementMetadata) { current, _ in current }
            .merging(candidateSelectionMetadata) { current, _ in current }
            .merging(displayScoreMetadata) { current, _ in current }
            .merging(replacementMetadata) { current, _ in current }

        return SuggestionPresentationTracePayload(
            rawTraceMetadata: rawTraceMetadata,
            diagnosticsMetadata: diagnosticsMetadata
        )
    }

    private func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
