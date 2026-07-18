public struct KeyboardEventTapConsumptionInput: Equatable, Sendable {
    public let key: AutocompleteKey
    public let hasVisibleSuggestion: Bool
    public let supportsOneWordAcceptance: Bool
    public let supportsFullAcceptance: Bool
    public let isInvalidatedByUserTyping: Bool
    public let hasPendingAcceptedInsertionUndo: Bool
    public let acceptAllShortcut: AcceptAllShortcut
    public let isAutorepeat: Bool
    public let visibleSuggestionID: String?
    public let keyDownSuggestionID: String?

    public init(
        key: AutocompleteKey,
        hasVisibleSuggestion: Bool,
        supportsOneWordAcceptance: Bool,
        supportsFullAcceptance: Bool,
        isInvalidatedByUserTyping: Bool,
        hasPendingAcceptedInsertionUndo: Bool = false,
        acceptAllShortcut: AcceptAllShortcut,
        isAutorepeat: Bool = false,
        visibleSuggestionID: String? = nil,
        keyDownSuggestionID: String? = nil
    ) {
        self.key = key
        self.hasVisibleSuggestion = hasVisibleSuggestion
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.isInvalidatedByUserTyping = isInvalidatedByUserTyping
        self.hasPendingAcceptedInsertionUndo = hasPendingAcceptedInsertionUndo
        self.acceptAllShortcut = acceptAllShortcut
        self.isAutorepeat = isAutorepeat
        self.visibleSuggestionID = visibleSuggestionID
        self.keyDownSuggestionID = keyDownSuggestionID
    }
}

public struct KeyboardEventTapConsumptionPolicy: Equatable, Sendable {
    public init() {}

    public func shouldCaptureKeys(
        isTrustedForAccessibility: Bool,
        hasVisibleSuggestion: Bool,
        controlState: SuggestionControlState = .running
    ) -> Bool {
        isTrustedForAccessibility
            && hasVisibleSuggestion
            && controlState == .running
    }

    public func shouldStopKeyboardCapture(
        hasVisibleSuggestion: Bool,
        isSuggestionPanelVisible: Bool,
        hasPendingAcceptedInsertionUndo: Bool
    ) -> Bool {
        !hasVisibleSuggestion
            && !isSuggestionPanelVisible
            && !hasPendingAcceptedInsertionUndo
    }

    public func shouldConsume(_ input: KeyboardEventTapConsumptionInput) -> Bool {
        if input.key == .controlBacktick {
            return true
        }

        if input.key == .commandZ {
            return input.hasPendingAcceptedInsertionUndo
                && !input.isInvalidatedByUserTyping
        }

        guard input.hasVisibleSuggestion,
              !input.isInvalidatedByUserTyping else {
            return false
        }

        if input.isAutorepeat,
           shouldProtectAcceptanceIdentity(for: input.key),
           input.visibleSuggestionID != input.keyDownSuggestionID {
            return false
        }

        switch input.key {
        case .tab:
            return input.supportsOneWordAcceptance
        case .shiftTab:
            return input.supportsFullAcceptance && input.acceptAllShortcut == .shiftTab
        case .backtick:
            return false
        case .controlBacktick:
            return true
        case .escape:
            return true
        case .optionTab:
            return input.supportsFullAcceptance && input.acceptAllShortcut == .optionTab
        case .commandZ:
            return false
        case .other:
            return false
        }
    }

    private func shouldProtectAcceptanceIdentity(for key: AutocompleteKey) -> Bool {
        switch key {
        case .tab, .shiftTab, .optionTab:
            true
        case .backtick, .controlBacktick, .commandZ, .escape, .other:
            false
        }
    }

    public func shouldReplayUnhandledConsumedKey(_ key: AutocompleteKey) -> Bool {
        switch key {
        case .tab, .shiftTab, .controlBacktick, .optionTab, .escape:
            false
        case .backtick, .commandZ, .other:
            true
        }
    }
}
