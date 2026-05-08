import Foundation

public enum KeyboardAction: Equatable, Sendable {
    case acceptNextWord
    case acceptAllVisible
    case undoAcceptedInsertion
    case dismiss
    case passThrough

    public var diagnosticName: String {
        switch self {
        case .acceptNextWord:
            "acceptNextWord"
        case .acceptAllVisible:
            "acceptAllVisible"
        case .undoAcceptedInsertion:
            "undoAcceptedInsertion"
        case .dismiss:
            "dismiss"
        case .passThrough:
            "passThrough"
        }
    }

    public var insertsSuggestionText: Bool {
        switch self {
        case .acceptNextWord, .acceptAllVisible:
            true
        case .undoAcceptedInsertion, .dismiss, .passThrough:
            false
        }
    }
}

public enum AutocompleteKey: Equatable, Sendable {
    case tab
    case optionTab
    case backtick
    case commandZ
    case escape
    case other

    public var diagnosticName: String {
        switch self {
        case .tab:
            "tab"
        case .optionTab:
            "optionTab"
        case .backtick:
            "backtick"
        case .commandZ:
            "commandZ"
        case .escape:
            "escape"
        case .other:
            "other"
        }
    }
}

public enum AcceptAllShortcut: String, CaseIterable, Equatable, Sendable {
    case backtick
    case optionTab

    public var autocompleteKey: AutocompleteKey {
        switch self {
        case .backtick:
            .backtick
        case .optionTab:
            .optionTab
        }
    }

    public var displayName: String {
        switch self {
        case .backtick:
            "Backtick"
        case .optionTab:
            "Option-Tab"
        }
    }

    public var next: AcceptAllShortcut {
        switch self {
        case .backtick:
            .optionTab
        case .optionTab:
            .backtick
        }
    }
}

public struct KeyboardShortcutConfiguration: Equatable, Sendable {
    public var acceptAllShortcut: AcceptAllShortcut

    public init(acceptAllShortcut: AcceptAllShortcut = .backtick) {
        self.acceptAllShortcut = acceptAllShortcut
    }

    public static let `default` = KeyboardShortcutConfiguration()

    public init(persistedAcceptAllShortcutRawValue: String?) {
        self.acceptAllShortcut = persistedAcceptAllShortcutRawValue
            .flatMap(AcceptAllShortcut.init(rawValue:)) ?? .backtick
    }
}

public enum AutocompletePhysicalKey: Equatable, Sendable {
    case tab
    case backtick
    case z
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

        case .z:
            return modifiers == .command ? .commandZ : .other

        case .escape:
            return modifiers.isEmpty ? .escape : .other

        case .other:
            return .other
        }
    }
}

public struct KeyboardActionRouter: Equatable, Sendable {
    public var shortcutConfiguration: KeyboardShortcutConfiguration

    public init(shortcutConfiguration: KeyboardShortcutConfiguration = .default) {
        self.shortcutConfiguration = shortcutConfiguration
    }

    public func action(
        for key: AutocompleteKey,
        hasVisibleSuggestion: Bool,
        hasPendingAcceptedInsertionUndo: Bool = false
    ) -> KeyboardAction {
        if key == .commandZ, hasPendingAcceptedInsertionUndo {
            return .undoAcceptedInsertion
        }

        guard hasVisibleSuggestion else {
            return .passThrough
        }

        switch key {
        case .tab:
            return .acceptNextWord
        case .optionTab:
            return shortcutConfiguration.acceptAllShortcut == .optionTab ? .acceptAllVisible : .passThrough
        case .backtick:
            return shortcutConfiguration.acceptAllShortcut == .backtick ? .acceptAllVisible : .passThrough
        case .commandZ:
            return .passThrough
        case .escape:
            return .dismiss
        case .other:
            return .passThrough
        }
    }
}
