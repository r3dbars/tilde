import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Placement health")
struct PlacementHealthTests {
    @Test("Keeps healthy inline caret placement")
    func keepsHealthyInlineCaretPlacement() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 80, y: 220, width: 60, height: 22),
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to present")
            return
        }

        #expect(presentation.renderMode == .inlineAdjacent)
        #expect(presentation.anchorSource == .caret)
        #expect(presentation.reason == .healthy)
        #expect(!presentation.isSelfHealing)
        #expect(presentation.metadata["placementSelfHealingApplied"] == "false")
    }

    @Test("Falls back to mirror when inline caret is missing and detached anchors are allowed")
    func fallsBackToMirrorForMissingCaretWhenAllowed() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to heal to mirror")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorSource == .element)
        #expect(presentation.reason == .missingCaret)
        #expect(presentation.isSelfHealing)
        #expect(presentation.metadata["placementRequestedRenderMode"] == "inlineAdjacent")
        #expect(presentation.metadata["placementEffectiveRenderMode"] == "floatingMirror")
    }

    @Test("Suppresses missing inline caret when detached anchors are disabled")
    func suppressesMissingInlineCaretWhenDetachedDisabled() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: false
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected placement to suppress")
            return
        }

        #expect(suppression.reason == .detachedSuggestionDisabled)
    }

    @Test("Suppresses invalid inline caret when detached anchors are disabled")
    func suppressesInvalidInlineCaretWhenDetachedDisabled() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 120, y: 240, width: 0, height: 0),
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: false
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected placement to suppress")
            return
        }

        #expect(suppression.reason == .detachedSuggestionDisabled)
    }

    @Test("Falls back when caret is outside focused bounds")
    func fallsBackWhenCaretIsOutsideFocusedBounds() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 900, y: 900, width: 0, height: 22),
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to heal to mirror")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorSource == .element)
        #expect(presentation.reason == .caretOutsideFocusedBounds)
        #expect(presentation.isSelfHealing)
    }

    @Test("Keeps mirror placement on focused element anchor")
    func keepsMirrorPlacementOnFocusedElementAnchor() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .floatingMirror,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: nil,
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to present")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorSource == .element)
        #expect(presentation.reason == .healthy)
    }

    @Test("Suppresses floating mirror when all anchors are unusable")
    func suppressesMirrorWhenAllAnchorsAreUnusable() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .floatingMirror,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: CGFloat.nan, y: 200, width: 0, height: 22),
            elementRect: CGRect(x: 100, y: 200, width: 0, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: true
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected placement to suppress")
            return
        }

        #expect(suppression.reason == PlacementHealthReason.invalidAnchor)
    }
}
