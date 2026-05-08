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
        #expect(presentation.metadata["placementSelfHealingAction"] == "none")
        #expect(presentation.metadata["placementConfidenceScore"] == "1.00")
        #expect(presentation.metadata["placementConfidenceBand"] == "high")
    }

    @Test("Synthetic inline caret placement is medium confidence")
    func syntheticInlineCaretPlacementIsMediumConfidence() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            caretIsSynthetic: true,
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to present")
            return
        }

        #expect(presentation.renderMode == .inlineAdjacent)
        #expect(presentation.anchorSource == .syntheticCaret)
        #expect(presentation.reason == .healthy)
        #expect(presentation.metadata["placementAnchorSource"] == "synthetic-caret")
        #expect(presentation.metadata["placementConfidenceScore"] == "0.70")
        #expect(presentation.metadata["placementConfidenceBand"] == "medium")
    }

    @Test("Drops stale text line rects far from the caret")
    func dropsStaleTextLineRectsFarFromCaret() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 80, y: 320, width: 60, height: 22),
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to present")
            return
        }

        #expect(presentation.textLineRect == nil)
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
        #expect(presentation.metadata["placementSelfHealingAction"] == "fallback-floating-mirror")
        #expect(presentation.metadata["placementConfidenceScore"] == "0.40")
        #expect(presentation.metadata["placementConfidenceBand"] == "low")
    }

    @Test("Cramped inline frames can fall back to mirror on the same caret")
    func crampedInlineFramesCanFallbackToMirrorOnSameCaret() throws {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 80, y: 220, width: 60, height: 22),
            allowsDetachedSuggestions: false
        )

        guard case let .present(inline) = plan else {
            Issue.record("Expected inline placement to present before frame sizing")
            return
        }

        let fallback = try #require(
            inline.mirrorFallbackForCrampedInlineFrame(fallbackRenderMode: .floatingMirror)
        )

        #expect(fallback.requestedRenderMode == .inlineAdjacent)
        #expect(fallback.renderMode == .floatingMirror)
        #expect(fallback.anchorRect == inline.anchorRect)
        #expect(fallback.anchorSource == .caret)
        #expect(fallback.textLineRect == nil)
        #expect(fallback.reason == .inlineRoomTooSmall)
        #expect(fallback.metadata["placementHealthReason"] == "inline-room-too-small")
        #expect(fallback.metadata["placementSelfHealingAction"] == "fallback-floating-mirror")
        #expect(fallback.metadata["placementConfidenceBand"] == "medium")
    }

    @Test("Cramped inline fallback only runs when mirror fallback exists")
    func crampedInlineFallbackOnlyRunsWhenMirrorFallbackExists() throws {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: nil,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 80, y: 220, width: 60, height: 22),
            allowsDetachedSuggestions: false
        )

        guard case let .present(inline) = plan else {
            Issue.record("Expected inline placement to present before frame sizing")
            return
        }

        #expect(inline.mirrorFallbackForCrampedInlineFrame(fallbackRenderMode: nil) == nil)
        #expect(inline.mirrorFallbackForCrampedInlineFrame(fallbackRenderMode: .disabled) == nil)
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
        #expect(suppression.metadata["placementSelfHealingAction"] == "suppress")
        #expect(suppression.metadata["placementConfidenceScore"] == "0.00")
        #expect(suppression.metadata["placementConfidenceBand"] == "none")
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

    @Test("Synthetic impossible caret cannot be high confidence")
    func syntheticImpossibleCaretCannotBeHighConfidence() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: -4000, y: 900, width: 0, height: 22),
            elementRect: CGRect(x: -1900, y: 81, width: 713, height: 105),
            windowRect: CGRect(x: -1924, y: 57, width: 761, height: 153),
            textLineRect: nil,
            caretIsSynthetic: true,
            allowsDetachedSuggestions: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to fall back instead of presenting synthetic inline")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorSource == .element)
        #expect(presentation.reason == .caretOutsideFocusedBounds)
        #expect(presentation.metadata["placementConfidenceBand"] == "low")
    }

    @Test("Suppresses low confidence placement unless it is trusted")
    func suppressesLowConfidencePlacementUnlessTrusted() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: true,
            trustPolicy: PlacementTrustPolicy(
                allowsLowConfidencePlacement: false,
                allowsSyntheticCaretPlacement: true
            )
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected low-confidence fallback placement to suppress")
            return
        }

        #expect(suppression.reason == .lowConfidencePlacement)
        #expect(suppression.metadata["placementSelfHealingAction"] == "suppress")
    }

    @Test("Keeps low confidence placement when explicitly trusted")
    func keepsLowConfidencePlacementWhenExplicitlyTrusted() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: true,
            trustPolicy: PlacementTrustPolicy(
                allowsLowConfidencePlacement: true,
                allowsSyntheticCaretPlacement: false
            )
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected explicitly trusted low-confidence fallback to present")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorSource == .element)
        #expect(presentation.isLowConfidence)
    }

    @Test("Suppresses synthetic caret placement unless it is trusted")
    func suppressesSyntheticCaretPlacementUnlessTrusted() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: .floatingMirror,
            caretRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            elementRect: CGRect(x: 80, y: 180, width: 520, height: 160),
            windowRect: CGRect(x: 40, y: 120, width: 640, height: 360),
            textLineRect: CGRect(x: 140, y: 220, width: 0, height: 22),
            caretIsSynthetic: true,
            allowsDetachedSuggestions: true,
            trustPolicy: PlacementTrustPolicy(
                allowsLowConfidencePlacement: true,
                allowsSyntheticCaretPlacement: false
            )
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected untrusted synthetic caret placement to suppress")
            return
        }

        #expect(suppression.reason == .untrustedSyntheticCaret)
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

    @Test("Suppresses detached mirror anchors unless trusted")
    func suppressesDetachedMirrorAnchorsUnlessTrusted() {
        let plan = PlacementHealth.plan(
            requestedRenderMode: .floatingMirror,
            fallbackRenderMode: .floatingMirror,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: nil,
            allowsDetachedSuggestions: true,
            trustPolicy: PlacementTrustPolicy(
                allowsLowConfidencePlacement: true,
                allowsSyntheticCaretPlacement: true,
                allowsDetachedAnchorPlacement: false
            )
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected untrusted detached mirror placement to suppress")
            return
        }

        #expect(suppression.reason == .untrustedDetachedAnchor)
        #expect(suppression.metadata["placementHealthReason"] == "untrusted-detached-anchor")
        #expect(suppression.metadata["placementSelfHealingAction"] == "suppress")
    }

    @Test("Keeps non-detached mirror placement on the caret")
    func keepsNonDetachedMirrorPlacementOnCaret() {
        let caret = CGRect(x: 320, y: 260, width: 0, height: 22)
        let plan = PlacementHealth.plan(
            requestedRenderMode: .floatingMirror,
            fallbackRenderMode: .floatingMirror,
            caretRect: caret,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: nil,
            allowsDetachedSuggestions: false
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected placement to present")
            return
        }

        #expect(presentation.renderMode == .floatingMirror)
        #expect(presentation.anchorRect == caret)
        #expect(presentation.anchorSource == .caret)
        #expect(presentation.reason == .healthy)
        #expect(presentation.metadata["placementConfidenceScore"] == "0.80")
        #expect(presentation.metadata["placementConfidenceBand"] == "high")
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
