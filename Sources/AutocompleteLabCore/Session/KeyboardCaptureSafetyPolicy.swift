public enum KeyboardEventTapHandlingResult: Equatable, Sendable {
    case handled
    case replayOriginalKey(KeyboardCaptureReplayReason)
    case dropOriginalKey(KeyboardCaptureDropReason)

    public var didHandle: Bool {
        switch self {
        case .handled:
            true
        case .replayOriginalKey, .dropOriginalKey:
            false
        }
    }
}

public enum KeyboardCaptureReplayReason: String, Equatable, Sendable {
    case noVisibleSuggestion = "no-visible-suggestion"
    case focusChanged = "focus-changed"
    case staleAfterTyping = "stale-after-typing"
    case unsupportedAction = "unsupported-action"
    case passThroughAction = "pass-through-action"
    case undoUnavailable = "undo-unavailable"
    case acceptanceTargetChanged = "acceptance-target-changed"
}

public enum KeyboardCaptureDropReason: String, Equatable, Sendable {
    case suppressedAutorepeat = "suppressed-autorepeat"
    case missingAcceptedText = "missing-accepted-text"
    case acceptanceProofFailed = "acceptance-proof-failed"
    case insertionFailed = "insertion-failed"
    case unsafeAcceptedText = "unsafe-accepted-text"
}

public struct KeyboardCaptureSafetyPolicy: Equatable, Sendable {
    public init() {}

    public func handlingResult(
        forAcceptanceBlock reason: SuggestionAcceptanceBlockReason
    ) -> KeyboardEventTapHandlingResult {
        switch reason {
        case .appChanged,
             .fieldChanged,
             .selectedTextChanged,
             .textBeforeCursorChanged,
             .textAfterCursorChanged,
             .missingShownSnapshot,
             .missingCurrentSnapshot,
             .currentBecameSecure,
             .currentBecameSuppressedField,
             .promptTargetChanged,
             .targetFingerprintChanged:
            .replayOriginalKey(.acceptanceTargetChanged)
        }
    }

    public func handlingResult(
        forAcceptanceFailure reason: KeyboardCaptureDropReason
    ) -> KeyboardEventTapHandlingResult {
        .dropOriginalKey(reason)
    }
}

public struct KeyboardCaptureRepeatSuppressionPolicy: Equatable, Sendable {
    public let suppressDurationNanos: UInt64

    public init(suppressDurationNanos: UInt64 = 250_000_000) {
        self.suppressDurationNanos = suppressDurationNanos
    }

    public func shouldSuppressAutorepeat(
        key: AutocompleteKey,
        isAutorepeat: Bool,
        suppressedUntilNanos: UInt64?,
        nowNanos: UInt64
    ) -> Bool {
        guard key != .other,
              isAutorepeat,
              let suppressedUntilNanos else {
            return false
        }

        return suppressedUntilNanos > nowNanos
    }

    public func suppressionDeadline(
        shouldConsume: Bool,
        isAutorepeat: Bool,
        nowNanos: UInt64
    ) -> UInt64? {
        guard shouldConsume,
              !isAutorepeat else {
            return nil
        }

        return nowNanos + suppressDurationNanos
    }
}
