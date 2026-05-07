import CoreGraphics
import Foundation

public enum SuggestionAnchorSource: String, Equatable, Sendable {
    case caret
    case line
    case field
    case window
    case none
}

public enum SuggestionAnchorQuality: String, Equatable, Sendable {
    case trusted
    case usableFallback
    case diagnosticsOnly
    case invalid
}

public enum SuggestionAnchorReason: String, Equatable, Sendable {
    case caretBoundsTrusted
    case lineBoundsFallback
    case fieldBoundsFallback
    case windowBoundsDiagnostics
    case renderModeDisabled
    case missingAnchor
    case detachedAnchorDisallowed
    case windowAnchorDisallowed
}

public struct SuggestionAnchorDecision: Equatable, Sendable {
    public let source: SuggestionAnchorSource
    public let quality: SuggestionAnchorQuality
    public let reason: SuggestionAnchorReason
    public let rect: CGRect?

    public init(
        source: SuggestionAnchorSource,
        quality: SuggestionAnchorQuality,
        reason: SuggestionAnchorReason,
        rect: CGRect?
    ) {
        self.source = source
        self.quality = quality
        self.reason = reason
        self.rect = rect
    }

    public var canPresent: Bool {
        rect != nil && quality != .invalid && quality != .diagnosticsOnly
    }
}

public enum RenderModePlan {
    public static func effectiveMode(
        for profile: CompatibilityProfile,
        supportsInlineSuggestions: Bool,
        hasMirrorAnchor: Bool
    ) -> SuggestionRenderMode? {
        switch profile.renderMode {
        case .inlineAdjacent:
            if supportsInlineSuggestions {
                return .inlineAdjacent
            }

            if profile.fallbackRenderMode == .floatingMirror, hasMirrorAnchor {
                return .floatingMirror
            }

            return nil

        case .floatingMirror:
            return hasMirrorAnchor ? .floatingMirror : nil

        case .disabled:
            return nil
        }
    }

    public static func anchorDecision(
        for renderMode: SuggestionRenderMode,
        profile: CompatibilityProfile,
        caretRect: CGRect?,
        lineRect: CGRect? = nil,
        elementRect: CGRect?,
        windowRect: CGRect?,
        allowsWindowAnchor: Bool = false
    ) -> SuggestionAnchorDecision {
        anchorDecision(
            for: renderMode,
            caretRect: caretRect,
            lineRect: lineRect,
            elementRect: elementRect,
            windowRect: windowRect,
            allowsDetachedAnchors: profile.allowsDetachedSuggestions,
            allowsWindowAnchor: allowsWindowAnchor
        )
    }

    public static func anchorDecision(
        for renderMode: SuggestionRenderMode,
        caretRect: CGRect?,
        lineRect: CGRect? = nil,
        elementRect: CGRect?,
        windowRect: CGRect?,
        allowsDetachedAnchors: Bool = true,
        allowsWindowAnchor: Bool = false
    ) -> SuggestionAnchorDecision {
        guard renderMode != .disabled else {
            return SuggestionAnchorDecision(
                source: .none,
                quality: .invalid,
                reason: .renderModeDisabled,
                rect: nil
            )
        }

        if let caretRect {
            return SuggestionAnchorDecision(
                source: .caret,
                quality: .trusted,
                reason: .caretBoundsTrusted,
                rect: caretRect
            )
        }

        if let lineRect {
            return SuggestionAnchorDecision(
                source: .line,
                quality: .usableFallback,
                reason: .lineBoundsFallback,
                rect: lineRect
            )
        }

        if let elementRect {
            guard allowsDetachedAnchors else {
                return SuggestionAnchorDecision(
                    source: .none,
                    quality: .invalid,
                    reason: .detachedAnchorDisallowed,
                    rect: nil
                )
            }

            return SuggestionAnchorDecision(
                source: .field,
                quality: .usableFallback,
                reason: .fieldBoundsFallback,
                rect: elementRect
            )
        }

        if let windowRect {
            guard allowsWindowAnchor else {
                return SuggestionAnchorDecision(
                    source: .none,
                    quality: .invalid,
                    reason: .windowAnchorDisallowed,
                    rect: nil
                )
            }

            return SuggestionAnchorDecision(
                source: .window,
                quality: .diagnosticsOnly,
                reason: .windowBoundsDiagnostics,
                rect: windowRect
            )
        }

        return SuggestionAnchorDecision(
            source: .none,
            quality: .invalid,
            reason: .missingAnchor,
            rect: nil
        )
    }

    public static func anchorRect(
        for renderMode: SuggestionRenderMode,
        caretRect: CGRect?,
        elementRect: CGRect?,
        windowRect: CGRect?
    ) -> CGRect? {
        switch renderMode {
        case .inlineAdjacent:
            return caretRect
        case .floatingMirror:
            return elementRect ?? windowRect ?? caretRect
        case .disabled:
            return nil
        }
    }
}
