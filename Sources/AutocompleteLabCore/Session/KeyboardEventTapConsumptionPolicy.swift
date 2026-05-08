public struct KeyboardEventTapConsumptionInput: Equatable, Sendable {
    public let key: AutocompleteKey
    public let hasVisibleSuggestion: Bool
    public let supportsOneWordAcceptance: Bool
    public let supportsFullAcceptance: Bool
    public let isInvalidatedByUserTyping: Bool
    public let acceptAllShortcut: AcceptAllShortcut

    public init(
        key: AutocompleteKey,
        hasVisibleSuggestion: Bool,
        supportsOneWordAcceptance: Bool,
        supportsFullAcceptance: Bool,
        isInvalidatedByUserTyping: Bool,
        acceptAllShortcut: AcceptAllShortcut
    ) {
        self.key = key
        self.hasVisibleSuggestion = hasVisibleSuggestion
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.isInvalidatedByUserTyping = isInvalidatedByUserTyping
        self.acceptAllShortcut = acceptAllShortcut
    }
}

public struct KeyboardEventTapConsumptionPolicy: Equatable, Sendable {
    public init() {}

    public func shouldConsume(_ input: KeyboardEventTapConsumptionInput) -> Bool {
        guard input.hasVisibleSuggestion,
              !input.isInvalidatedByUserTyping else {
            return false
        }

        switch input.key {
        case .tab:
            return input.supportsOneWordAcceptance
        case .backtick:
            return input.supportsFullAcceptance && input.acceptAllShortcut == .backtick
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
}
