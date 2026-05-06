import CoreGraphics
import Foundation

public enum PlacementHealthReason: String, Equatable, Sendable {
    case healthy
    case disabled
    case missingAnchor = "missing-anchor"
    case missingCaret = "missing-caret"
    case invalidCaret = "invalid-caret"
    case invalidAnchor = "invalid-anchor"
    case caretOutsideFocusedBounds = "caret-outside-focused-bounds"
    case detachedSuggestionDisabled = "detached-suggestion-disabled"
    case missingFloatingFallback = "missing-floating-fallback"
}

public enum PlacementAnchorSource: String, Equatable, Sendable {
    case caret
    case element
    case window
}

public struct PlacementHealthPresentation: Equatable {
    public let requestedRenderMode: SuggestionRenderMode
    public let renderMode: SuggestionRenderMode
    public let anchorRect: CGRect
    public let anchorSource: PlacementAnchorSource
    public let textLineRect: CGRect?
    public let clippingRect: CGRect?
    public let reason: PlacementHealthReason

    public init(
        requestedRenderMode: SuggestionRenderMode,
        renderMode: SuggestionRenderMode,
        anchorRect: CGRect,
        anchorSource: PlacementAnchorSource,
        textLineRect: CGRect?,
        clippingRect: CGRect?,
        reason: PlacementHealthReason
    ) {
        self.requestedRenderMode = requestedRenderMode
        self.renderMode = renderMode
        self.anchorRect = anchorRect
        self.anchorSource = anchorSource
        self.textLineRect = textLineRect
        self.clippingRect = clippingRect
        self.reason = reason
    }

    public var isSelfHealing: Bool {
        reason != .healthy || requestedRenderMode != renderMode
    }

    public var metadata: [String: String] {
        [
            "placementRequestedRenderMode": requestedRenderMode.rawValue,
            "placementEffectiveRenderMode": renderMode.rawValue,
            "placementAnchorSource": anchorSource.rawValue,
            "placementHealthReason": reason.rawValue,
            "placementSelfHealingApplied": String(isSelfHealing)
        ]
    }
}

public struct PlacementHealthSuppression: Equatable {
    public let requestedRenderMode: SuggestionRenderMode
    public let reason: PlacementHealthReason

    public init(
        requestedRenderMode: SuggestionRenderMode,
        reason: PlacementHealthReason
    ) {
        self.requestedRenderMode = requestedRenderMode
        self.reason = reason
    }

    public var metadata: [String: String] {
        [
            "placementRequestedRenderMode": requestedRenderMode.rawValue,
            "placementHealthReason": reason.rawValue,
            "placementSelfHealingApplied": "false"
        ]
    }
}

public enum PlacementHealthPlan: Equatable {
    case present(PlacementHealthPresentation)
    case suppress(PlacementHealthSuppression)
}

public enum PlacementHealth {
    public static func plan(
        requestedRenderMode: SuggestionRenderMode,
        fallbackRenderMode: SuggestionRenderMode?,
        caretRect: CGRect?,
        elementRect: CGRect?,
        windowRect: CGRect?,
        textLineRect: CGRect?,
        allowsDetachedSuggestions: Bool
    ) -> PlacementHealthPlan {
        let validCaret = caretRect.flatMap(validCaretRect)
        let validElement = elementRect.flatMap(validContainerRect)
        let validWindow = windowRect.flatMap(validContainerRect)
        let clippingRect = validElement ?? validWindow

        switch requestedRenderMode {
        case .disabled:
            return suppress(requestedRenderMode, reason: .disabled)

        case .inlineAdjacent:
            guard let validCaret else {
                let reason: PlacementHealthReason = caretRect == nil ? .missingCaret : .invalidCaret
                return floatingFallback(
                    requestedRenderMode: requestedRenderMode,
                    fallbackRenderMode: fallbackRenderMode,
                    reason: reason,
                    elementRect: validElement,
                    windowRect: validWindow,
                    clippingRect: clippingRect,
                    allowsDetachedSuggestions: allowsDetachedSuggestions
                )
            }

            if let focusedBounds = validElement ?? validWindow,
               !caret(validCaret, isNear: focusedBounds) {
                return floatingFallback(
                    requestedRenderMode: requestedRenderMode,
                    fallbackRenderMode: fallbackRenderMode,
                    reason: .caretOutsideFocusedBounds,
                    elementRect: validElement,
                    windowRect: validWindow,
                    clippingRect: clippingRect,
                    allowsDetachedSuggestions: allowsDetachedSuggestions
                )
            }

            return .present(PlacementHealthPresentation(
                requestedRenderMode: requestedRenderMode,
                renderMode: .inlineAdjacent,
                anchorRect: validCaret,
                anchorSource: .caret,
                textLineRect: textLineRect.flatMap(validContainerRect),
                clippingRect: clippingRect,
                reason: .healthy
            ))

        case .floatingMirror:
            if !allowsDetachedSuggestions {
                guard let validCaret else {
                    return suppress(requestedRenderMode, reason: .detachedSuggestionDisabled)
                }

                return mirrorPresentation(
                    requestedRenderMode: requestedRenderMode,
                    anchorRect: validCaret,
                    anchorSource: .caret,
                    clippingRect: clippingRect,
                    reason: .healthy
                )
            }

            if let validElement {
                return mirrorPresentation(
                    requestedRenderMode: requestedRenderMode,
                    anchorRect: validElement,
                    anchorSource: .element,
                    clippingRect: clippingRect,
                    reason: .healthy
                )
            }

            if let validWindow {
                return mirrorPresentation(
                    requestedRenderMode: requestedRenderMode,
                    anchorRect: validWindow,
                    anchorSource: .window,
                    clippingRect: clippingRect,
                    reason: .healthy
                )
            }

            if let validCaret {
                return mirrorPresentation(
                    requestedRenderMode: requestedRenderMode,
                    anchorRect: validCaret,
                    anchorSource: .caret,
                    clippingRect: clippingRect,
                    reason: .healthy
                )
            }

            return suppress(
                requestedRenderMode,
                reason: elementRect == nil && windowRect == nil && caretRect == nil ? .missingAnchor : .invalidAnchor
            )
        }
    }

    private static func floatingFallback(
        requestedRenderMode: SuggestionRenderMode,
        fallbackRenderMode: SuggestionRenderMode?,
        reason: PlacementHealthReason,
        elementRect: CGRect?,
        windowRect: CGRect?,
        clippingRect: CGRect?,
        allowsDetachedSuggestions: Bool
    ) -> PlacementHealthPlan {
        guard fallbackRenderMode == .floatingMirror else {
            return suppress(requestedRenderMode, reason: .missingFloatingFallback)
        }

        guard allowsDetachedSuggestions else {
            return suppress(requestedRenderMode, reason: .detachedSuggestionDisabled)
        }

        if let elementRect {
            return mirrorPresentation(
                requestedRenderMode: requestedRenderMode,
                anchorRect: elementRect,
                anchorSource: .element,
                clippingRect: clippingRect,
                reason: reason
            )
        }

        if let windowRect {
            return mirrorPresentation(
                requestedRenderMode: requestedRenderMode,
                anchorRect: windowRect,
                anchorSource: .window,
                clippingRect: clippingRect,
                reason: reason
            )
        }

        return suppress(requestedRenderMode, reason: .missingAnchor)
    }

    private static func mirrorPresentation(
        requestedRenderMode: SuggestionRenderMode,
        anchorRect: CGRect,
        anchorSource: PlacementAnchorSource,
        clippingRect: CGRect?,
        reason: PlacementHealthReason
    ) -> PlacementHealthPlan {
        .present(PlacementHealthPresentation(
            requestedRenderMode: requestedRenderMode,
            renderMode: .floatingMirror,
            anchorRect: anchorRect,
            anchorSource: anchorSource,
            textLineRect: nil,
            clippingRect: clippingRect,
            reason: reason
        ))
    }

    private static func suppress(
        _ requestedRenderMode: SuggestionRenderMode,
        reason: PlacementHealthReason
    ) -> PlacementHealthPlan {
        .suppress(PlacementHealthSuppression(
            requestedRenderMode: requestedRenderMode,
            reason: reason
        ))
    }

    private static func validCaretRect(_ rect: CGRect) -> CGRect? {
        guard rect.isPlacementFinite,
              !rect.isNull,
              rect.width >= 0,
              rect.width <= max(80, rect.height * 4),
              rect.height >= 1,
              rect.height <= 240 else {
            return nil
        }

        return rect
    }

    private static func validContainerRect(_ rect: CGRect) -> CGRect? {
        guard rect.isPlacementFinite,
              !rect.isNull,
              rect.width >= 1,
              rect.height >= 1 else {
            return nil
        }

        return rect
    }

    private static func caret(_ caretRect: CGRect, isNear bounds: CGRect) -> Bool {
        let margin = max(24, min(160, max(caretRect.height * 3, bounds.height * 0.08)))
        let expandedBounds = bounds.insetBy(dx: -margin, dy: -margin)
        let caretPoint = CGPoint(x: caretRect.midX, y: caretRect.midY)

        return expandedBounds.contains(caretPoint)
    }
}

private extension CGRect {
    var isPlacementFinite: Bool {
        minX.isFinite
            && minY.isFinite
            && maxX.isFinite
            && maxY.isFinite
            && width.isFinite
            && height.isFinite
    }
}
