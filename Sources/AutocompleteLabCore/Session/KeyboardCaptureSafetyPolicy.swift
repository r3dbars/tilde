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
    case acceptanceTargetChangedBeforeAccept = "acceptance-target-changed-before-accept"
    case secureFieldBeforeAccept = "secure-field-before-accept"
    case suppressedFieldBeforeAccept = "suppressed-field-before-accept"
    case promptTargetChangedBeforeAccept = "prompt-target-changed-before-accept"
}

public struct KeyboardCaptureSafetyPolicy: Equatable, Sendable {
    public init() {}

    public func handlingResult(
        forAcceptanceBlock reason: SuggestionAcceptanceBlockReason
    ) -> KeyboardEventTapHandlingResult {
        handlingResult(forAcceptanceBlock: reason, key: .other)
    }

    public func handlingResult(
        forAcceptanceBlock reason: SuggestionAcceptanceBlockReason,
        key: AutocompleteKey
    ) -> KeyboardEventTapHandlingResult {
        switch reason {
        case .appChanged,
             .fieldChanged,
             .selectedTextChanged,
             .textBeforeCursorChanged,
             .textAfterCursorChanged,
             .missingShownSnapshot,
             .missingCurrentSnapshot,
             .targetFingerprintChanged:
            if shouldDropConsumedAcceptKey(key) {
                .dropOriginalKey(.acceptanceTargetChangedBeforeAccept)
            } else {
                .replayOriginalKey(.acceptanceTargetChanged)
            }
        case .currentBecameSecure:
            .dropOriginalKey(.secureFieldBeforeAccept)
        case .currentBecameSuppressedField:
            .dropOriginalKey(.suppressedFieldBeforeAccept)
        case .promptTargetChanged:
            .dropOriginalKey(.promptTargetChangedBeforeAccept)
        }
    }

    public func handlingResultForFocusMismatch(
        key: AutocompleteKey
    ) -> KeyboardEventTapHandlingResult {
        if shouldDropConsumedAcceptKey(key) {
            .dropOriginalKey(.acceptanceTargetChangedBeforeAccept)
        } else {
            .replayOriginalKey(.focusChanged)
        }
    }

    public func handlingResult(
        forAcceptanceFailure reason: KeyboardCaptureDropReason
    ) -> KeyboardEventTapHandlingResult {
        .dropOriginalKey(reason)
    }

    private func shouldDropConsumedAcceptKey(_ key: AutocompleteKey) -> Bool {
        switch key {
        case .tab, .backtick, .controlBacktick, .optionTab:
            true
        case .commandZ, .escape, .other:
            false
        }
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
