import CoreGraphics
import Foundation

public enum SuggestionGeometryInvalidationReason: String, Equatable, Sendable {
    case missingGeometry = "missing-geometry"
    case screenLayoutChanged = "screen-layout-changed"
    case fieldChanged = "field-changed"
    case caretChanged = "caret-changed"
    case textLineChanged = "text-line-changed"
    case elementChanged = "element-changed"
    case windowChanged = "window-changed"
}

public struct SuggestionGeometrySnapshot: Equatable, Sendable {
    public let fieldIdentity: FocusedFieldIdentity?
    public let screenLayoutFingerprint: String?
    public let caretRect: CGRect?
    public let textLineRect: CGRect?
    public let elementRect: CGRect?
    public let windowRect: CGRect?

    public init(
        fieldIdentity: FocusedFieldIdentity?,
        screenLayoutFingerprint: String?,
        caretRect: CGRect?,
        textLineRect: CGRect?,
        elementRect: CGRect?,
        windowRect: CGRect?
    ) {
        self.fieldIdentity = fieldIdentity
        self.screenLayoutFingerprint = screenLayoutFingerprint
        self.caretRect = caretRect
        self.textLineRect = textLineRect
        self.elementRect = elementRect
        self.windowRect = windowRect
    }
}

public struct SuggestionGeometryInvalidationDecision: Equatable, Sendable {
    public let shouldInvalidate: Bool
    public let reason: SuggestionGeometryInvalidationReason?

    public static let keep = SuggestionGeometryInvalidationDecision(
        shouldInvalidate: false,
        reason: nil
    )

    public static func invalidate(
        _ reason: SuggestionGeometryInvalidationReason
    ) -> SuggestionGeometryInvalidationDecision {
        SuggestionGeometryInvalidationDecision(
            shouldInvalidate: true,
            reason: reason
        )
    }

    public var metadata: [String: String] {
        guard shouldInvalidate, let reason else {
            return [
                "geometryInvalidated": "false",
                "geometryInvalidationReason": "none"
            ]
        }

        return [
            "geometryInvalidated": "true",
            "geometryInvalidationReason": reason.rawValue
        ]
    }
}

public struct SuggestionGeometryChangePolicy: Equatable, Sendable {
    public init() {}

    public func shouldInvalidateSuggestionState(
        hasVisibleSuggestion: Bool,
        hasPendingSuggestionRequest: Bool,
        previousScreenLayoutFingerprint: String?,
        currentScreenLayoutFingerprint: String?
    ) -> Bool {
        guard hasVisibleSuggestion || hasPendingSuggestionRequest else {
            return false
        }

        guard let previous = normalizedFingerprint(previousScreenLayoutFingerprint),
              let current = normalizedFingerprint(currentScreenLayoutFingerprint) else {
            return true
        }

        return previous != current
    }

    public func invalidationDecision(
        hasVisibleSuggestion: Bool,
        hasPendingSuggestionRequest: Bool,
        previousSnapshot: SuggestionGeometrySnapshot?,
        currentSnapshot: SuggestionGeometrySnapshot?,
        allowsCaretRectChange: Bool = false
    ) -> SuggestionGeometryInvalidationDecision {
        guard hasVisibleSuggestion || hasPendingSuggestionRequest else {
            return .keep
        }

        guard let previousSnapshot, let currentSnapshot else {
            return .invalidate(.missingGeometry)
        }

        guard let previousScreen = normalizedFingerprint(previousSnapshot.screenLayoutFingerprint),
              let currentScreen = normalizedFingerprint(currentSnapshot.screenLayoutFingerprint) else {
            return .invalidate(.screenLayoutChanged)
        }

        guard previousScreen == currentScreen else {
            return .invalidate(.screenLayoutChanged)
        }

        if previousSnapshot.fieldIdentity != currentSnapshot.fieldIdentity {
            return .invalidate(.fieldChanged)
        }

        if !allowsCaretRectChange,
           normalizedRect(previousSnapshot.caretRect) != normalizedRect(currentSnapshot.caretRect) {
            return .invalidate(.caretChanged)
        }

        if normalizedRect(previousSnapshot.textLineRect) != normalizedRect(currentSnapshot.textLineRect) {
            return .invalidate(.textLineChanged)
        }

        if normalizedRect(previousSnapshot.elementRect) != normalizedRect(currentSnapshot.elementRect) {
            return .invalidate(.elementChanged)
        }

        if normalizedRect(previousSnapshot.windowRect) != normalizedRect(currentSnapshot.windowRect) {
            return .invalidate(.windowChanged)
        }

        return .keep
    }

    private func normalizedFingerprint(_ fingerprint: String?) -> String? {
        guard let fingerprint = fingerprint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !fingerprint.isEmpty else {
            return nil
        }

        return fingerprint
    }

    private func normalizedRect(_ rect: CGRect?) -> GeometryFingerprint? {
        guard let rect,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite else {
            return nil
        }

        return GeometryFingerprint(
            x: Int((rect.origin.x * 2).rounded()),
            y: Int((rect.origin.y * 2).rounded()),
            width: Int((rect.width * 2).rounded()),
            height: Int((rect.height * 2).rounded())
        )
    }
}

private struct GeometryFingerprint: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}
