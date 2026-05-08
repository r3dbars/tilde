public enum SuggestionAcceptanceBlockReason: String, Equatable, Sendable {
    case appChanged = "app-changed-before-accept"
    case fieldChanged = "field-changed-before-accept"
    case selectedTextChanged = "selected-text-changed-before-accept"
    case textBeforeCursorChanged = "text-before-cursor-changed-before-accept"
    case textAfterCursorChanged = "text-after-cursor-changed-before-accept"
    case missingShownSnapshot = "missing-shown-snapshot-before-accept"
    case missingCurrentSnapshot = "missing-current-snapshot-before-accept"
    case currentBecameSecure = "secure-field-before-accept"
    case promptTargetChanged = "prompt-target-changed-before-accept"

    public var isFocusMismatch: Bool {
        switch self {
        case .appChanged, .fieldChanged, .selectedTextChanged:
            true
        case .textBeforeCursorChanged,
             .textAfterCursorChanged,
             .missingShownSnapshot,
             .missingCurrentSnapshot,
             .currentBecameSecure,
             .promptTargetChanged:
            false
        }
    }
}

public enum SuggestionAcceptanceDecision: Equatable, Sendable {
    case allow
    case block(SuggestionAcceptanceBlockReason)

    public var canAccept: Bool {
        self == .allow
    }

    public var blockReason: SuggestionAcceptanceBlockReason? {
        guard case let .block(reason) = self else {
            return nil
        }
        return reason
    }
}

public struct SuggestionAcceptanceSnapshot: Equatable, Sendable {
    public let fieldIdentity: FocusedFieldIdentity
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let selectedTextLength: Int

    public init(
        fieldIdentity: FocusedFieldIdentity,
        textBeforeCursor: String,
        textAfterCursor: String,
        selectedTextLength: Int
    ) {
        self.fieldIdentity = fieldIdentity
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.selectedTextLength = max(0, selectedTextLength)
    }

    public init(snapshot: FocusedTextSnapshot, selectedTextLength: Int) {
        self.init(
            fieldIdentity: snapshot.fieldIdentity,
            textBeforeCursor: snapshot.textBeforeCursor,
            textAfterCursor: snapshot.textAfterCursor,
            selectedTextLength: selectedTextLength
        )
    }

    public var focusedTextSnapshot: FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
    }
}

public struct SuggestionAcceptanceGuard: Equatable, Sendable {
    public init() {}

    public func decision(
        shown: SuggestionAcceptanceSnapshot?,
        current: SuggestionAcceptanceSnapshot?
    ) -> SuggestionAcceptanceDecision {
        guard let shown else {
            return .block(.missingShownSnapshot)
        }

        guard let current else {
            return .block(.missingCurrentSnapshot)
        }

        if shown.fieldIdentity.bundleIdentifier != current.fieldIdentity.bundleIdentifier
            || shown.fieldIdentity.processIdentifier != current.fieldIdentity.processIdentifier {
            return .block(.appChanged)
        }

        if shown.fieldIdentity.elementIdentifier != current.fieldIdentity.elementIdentifier {
            return .block(.fieldChanged)
        }

        if shown.selectedTextLength != current.selectedTextLength || current.selectedTextLength > 0 {
            return .block(.selectedTextChanged)
        }

        if shown.textBeforeCursor != current.textBeforeCursor {
            return .block(.textBeforeCursorChanged)
        }

        if shown.textAfterCursor != current.textAfterCursor {
            return .block(.textAfterCursorChanged)
        }

        return .allow
    }
}
