import Foundation

public enum KeyboardAction: Equatable, Sendable {
    case acceptNextWord
    case acceptAllVisible
    case dismiss
    case passThrough
}

public enum AutocompleteKey: Equatable, Sendable {
    case tab
    case backtick
    case escape
    case other
}

public struct KeyboardActionRouter: Equatable, Sendable {
    public init() {}

    public func action(for key: AutocompleteKey, hasVisibleSuggestion: Bool) -> KeyboardAction {
        guard hasVisibleSuggestion else {
            return .passThrough
        }

        switch key {
        case .tab:
            return .acceptNextWord
        case .backtick:
            return .acceptAllVisible
        case .escape:
            return .dismiss
        case .other:
            return .passThrough
        }
    }
}
