import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion panel presentation policy")
struct SuggestionPanelPresentationPolicyTests {
    @Test("Keeps initial placement when the panel renders")
    func keepsInitialPlacementWhenPanelRenders() {
        let initial = inlinePlacement()
        var shown: [SuggestionRenderMode] = []

        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: initial,
            fallbackRenderMode: .floatingMirror
        ) { placement in
            shown.append(placement.renderMode)
            return CGRect(x: 140, y: 220, width: 160, height: 22)
        }

        #expect(attempt.didPresent)
        #expect(attempt.placement == initial)
        #expect(attempt.failureReason == nil)
        #expect(shown == [.inlineAdjacent])
    }

    @Test("Falls back to mirror when inline frame cannot render")
    func fallsBackToMirrorWhenInlineFrameCannotRender() {
        let initial = inlinePlacement()
        var shown: [SuggestionRenderMode] = []

        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: initial,
            fallbackRenderMode: .floatingMirror
        ) { placement in
            shown.append(placement.renderMode)
            if placement.renderMode == .inlineAdjacent {
                return nil
            }

            return CGRect(x: 148, y: 218, width: 180, height: 24)
        }

        #expect(attempt.didPresent)
        #expect(attempt.placement.renderMode == .floatingMirror)
        #expect(attempt.placement.reason == .inlineRoomTooSmall)
        #expect(attempt.failureReason == nil)
        #expect(shown == [.inlineAdjacent, .floatingMirror])
    }

    @Test("Reports unusable panel when no fallback is allowed")
    func reportsUnusablePanelWhenNoFallbackIsAllowed() {
        let initial = inlinePlacement()

        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: initial,
            fallbackRenderMode: nil
        ) { _ in nil }

        #expect(!attempt.didPresent)
        #expect(attempt.placement == initial)
        #expect(attempt.failureReason == SuggestionPanelPresentationPolicy.panelFrameUnusableReason)
    }

    @Test("Reports cramped inline reason when fallback cannot render")
    func reportsCrampedInlineReasonWhenFallbackCannotRender() {
        let initial = inlinePlacement()
        var shown: [SuggestionRenderMode] = []

        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: initial,
            fallbackRenderMode: .floatingMirror
        ) { placement in
            shown.append(placement.renderMode)
            return nil
        }

        #expect(!attempt.didPresent)
        #expect(attempt.placement.renderMode == .floatingMirror)
        #expect(attempt.placement.reason == .inlineRoomTooSmall)
        #expect(attempt.failureReason == "inline-room-too-small")
        #expect(shown == [.inlineAdjacent, .floatingMirror])
    }
}

private func inlinePlacement() -> PlacementHealthPresentation {
    PlacementHealthPresentation(
        requestedRenderMode: .inlineAdjacent,
        renderMode: .inlineAdjacent,
        anchorRect: CGRect(x: 140, y: 220, width: 0, height: 22),
        anchorSource: .caret,
        textLineRect: CGRect(x: 80, y: 220, width: 60, height: 22),
        clippingRect: CGRect(x: 80, y: 180, width: 520, height: 160),
        reason: .healthy
    )
}
