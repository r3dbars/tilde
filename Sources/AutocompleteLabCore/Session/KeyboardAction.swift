import Foundation

public enum KeyboardAction: Equatable, Sendable {
    case acceptNextWord
    case acceptAllVisible
    case dismiss
    case passThrough
}

public enum AutocompleteKey: Equatable, Sendable {
    case tab
    case optionTab
    case backtick
    case escape
    case other
}

public enum AutocompletePhysicalKey: Equatable, Sendable {
    case tab
    case backtick
    case escape
    case other
}

public struct AutocompleteKeyModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public static let shift = AutocompleteKeyModifiers(rawValue: 1 << 0)
    public static let control = AutocompleteKeyModifiers(rawValue: 1 << 1)
    public static let option = AutocompleteKeyModifiers(rawValue: 1 << 2)
    public static let command = AutocompleteKeyModifiers(rawValue: 1 << 3)
    public static let function = AutocompleteKeyModifiers(rawValue: 1 << 4)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct AutocompleteKeyMapper: Equatable, Sendable {
    public init() {}

    public func key(
        physicalKey: AutocompletePhysicalKey,
        modifiers: AutocompleteKeyModifiers
    ) -> AutocompleteKey {
        switch physicalKey {
        case .tab:
            if modifiers.isEmpty {
                return .tab
            }

            if modifiers == .option {
                return .optionTab
            }

            return .other

        case .backtick:
            if modifiers.isEmpty || modifiers == .shift {
                return .backtick
            }

            return .other

        case .escape:
            return modifiers.isEmpty ? .escape : .other

        case .other:
            return .other
        }
    }
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
        case .optionTab:
            return .passThrough
        case .backtick:
            return .acceptAllVisible
        case .escape:
            return .dismiss
        case .other:
            return .passThrough
        }
    }
}
