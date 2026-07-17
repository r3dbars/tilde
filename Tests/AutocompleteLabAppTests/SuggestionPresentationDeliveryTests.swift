import AutocompleteLabCore
import CoreGraphics
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion presentation delivery")
struct SuggestionPresentationDeliveryTests {
    @Test("Shows the panel and field status before trace recording")
    func showsPanelAndFieldStatusBeforeTraceRecording() throws {
        let store = DeliveryStore(panelRects: [CGRect(x: 40, y: 20, width: 120, height: 24)])
        let delivery = makeDelivery(store: store)
        let request = makeRequest()

        let result = delivery.deliver(request)
        let success = try #require(result.success)

        #expect(success.panelRect == CGRect(x: 40, y: 20, width: 120, height: 24))
        #expect(success.placement == request.placement)
        #expect(store.panelText == " finish this")
        #expect(store.panelAnchorRect == request.placement.anchorRect)
        #expect(store.panelTextLineRect == request.placement.textLineRect)
        #expect(store.panelClippingRect == request.placement.clippingRect)
        #expect(store.panelAppBundleIdentifier == request.profile.bundleIdentifier)
        #expect(store.panelBoundaryRect == request.context.elementRect)
        #expect(store.panelRenderMode == .inlineAdjacent)
        #expect(store.panelRenderModes == [.inlineAdjacent])
        #expect(store.fieldStatusContexts == [request.context])

        let payload = delivery.tracePayload(
            for: request,
            placement: success.placement,
            panelRect: success.panelRect,
            screenshotCapture: TraceScreenshotCaptureResult(
                path: "/tmp/suggestion.png",
                rectDescription: "x=10,y=10,w=150,h=40"
            )
        )
        #expect(payload.rawTraceMetadata["screenshotCaptureRect"] == "x=10,y=10,w=150,h=40")
        #expect(payload.rawTraceMetadata["request"] == "metadata")
        #expect(payload.rawTraceMetadata["geometry"] == "metadata")
        #expect(payload.rawTraceMetadata["learning"] == "metadata")
        #expect(payload.rawTraceMetadata["placementEffectiveRenderMode"] == "inlineAdjacent")
        #expect(payload.diagnosticsMetadata["traceID"] == "delivery")
    }

    @Test("Does not mark field shown when the panel frame is unusable")
    func doesNotMarkFieldShownWhenPanelFrameIsUnusable() throws {
        let store = DeliveryStore(panelRects: [nil, nil])
        let delivery = makeDelivery(store: store)

        let result = delivery.deliver(makeRequest())

        #expect(result.failure == .panelFrameUnusable)
        #expect(store.fieldStatusContexts.isEmpty)
    }

    @Test("Falls back to mirror when inline panel frame is unusable")
    func fallsBackToMirrorWhenInlinePanelFrameIsUnusable() throws {
        let store = DeliveryStore(panelRects: [
            nil,
            CGRect(x: 44, y: 18, width: 140, height: 26)
        ])
        let delivery = makeDelivery(store: store)
        let request = makeRequest()

        let result = delivery.deliver(request)
        let success = try #require(result.success)

        #expect(success.panelRect == CGRect(x: 44, y: 18, width: 140, height: 26))
        #expect(success.placement.renderMode == .floatingMirror)
        #expect(success.placement.reason == .inlineRoomTooSmall)
        #expect(store.panelRenderModes == [.inlineAdjacent, .floatingMirror])
        #expect(store.panelTextLineRects == [request.placement.textLineRect, nil])
        #expect(store.fieldStatusContexts == [request.context])

        let payload = delivery.tracePayload(
            for: request,
            placement: success.placement,
            panelRect: success.panelRect,
            screenshotCapture: TraceScreenshotCaptureResult(
                path: "/tmp/suggestion.png",
                rectDescription: "x=10,y=10,w=150,h=40"
            )
        )
        #expect(payload.rawTraceMetadata["placementEffectiveRenderMode"] == "floatingMirror")
        #expect(payload.rawTraceMetadata["placementHealthReason"] == "inline-room-too-small")
    }

    private func makeDelivery(store: DeliveryStore) -> SuggestionPresentationDelivery {
        SuggestionPresentationDelivery(
            panelPresenter: { text, anchorRect, textLineRect, clippingRect, appBundleIdentifier, boundaryRect, _, renderMode in
                store.panelText = text
                store.panelAnchorRect = anchorRect
                store.panelTextLineRect = textLineRect
                store.panelTextLineRects.append(textLineRect)
                store.panelClippingRect = clippingRect
                store.panelAppBundleIdentifier = appBundleIdentifier
                store.panelBoundaryRect = boundaryRect
                store.panelRenderMode = renderMode
                store.panelRenderModes.append(renderMode)
                return store.nextPanelRect()
            },
            fieldStatusPresenter: { context in
                store.fieldStatusContexts.append(context)
            }
        )
    }

    private func makeRequest() -> SuggestionPresentationDeliveryRequest {
        SuggestionPresentationDeliveryRequest(
            suggestion: CompletionSuggestion(text: " finish this", maxVisibleWords: 3),
            suggestionID: "delivery-1234",
            completionRequest: CompletionRequest(
                textBeforeCursor: "please",
                appBundleIdentifier: "com.apple.TextEdit",
                mode: .phraseContinuation,
                suggestionID: "delivery-1234"
            ),
            context: makeContext(),
            profile: CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!,
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.apple.TextEdit",
                processIdentifier: 42,
                elementIdentifier: 7
            ),
            placement: PlacementHealthPresentation(
                requestedRenderMode: .inlineAdjacent,
                renderMode: .inlineAdjacent,
                anchorRect: CGRect(x: 10, y: 10, width: 1, height: 18),
                anchorSource: .caret,
                textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
                clippingRect: CGRect(x: 0, y: 0, width: 500, height: 300),
                reason: .healthy
            ),
            latencyMilliseconds: 42,
            requestMetadata: ["request": "metadata"],
            geometryMetadata: ["geometry": "metadata"],
            learningMetadata: ["learning": "metadata"],
            candidateSelectionMetadata: ["candidate": "metadata"],
            displayScoreMetadata: ["display": "metadata"],
            replacementMetadata: ["replacement": "metadata"]
        )
    }

    private func makeContext() -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Untitled"),
            textBeforeCursor: "please",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
            elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            windowIdentifier: 42,
            textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
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

private final class DeliveryStore {
    private var panelRects: [CGRect?]
    var panelText = ""
    var panelAnchorRect: CGRect?
    var panelTextLineRect: CGRect?
    var panelTextLineRects: [CGRect?] = []
    var panelClippingRect: CGRect?
    var panelAppBundleIdentifier: String?
    var panelBoundaryRect: CGRect?
    var panelRenderMode: SuggestionRenderMode?
    var panelRenderModes: [SuggestionRenderMode] = []
    var fieldStatusContexts: [FocusedTextContext] = []

    init(panelRects: [CGRect?]) {
        self.panelRects = panelRects
    }

    func nextPanelRect() -> CGRect? {
        guard !panelRects.isEmpty else {
            return nil
        }

        return panelRects.removeFirst()
    }
}

private extension Result where Failure == SuggestionPresentationDeliveryFailure {
    var success: Success? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var failure: Failure? {
        if case let .failure(value) = self {
            return value
        }
        return nil
    }
}
