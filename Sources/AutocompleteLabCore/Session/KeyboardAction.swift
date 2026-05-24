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
    case disabled

    public var autocompleteKey: AutocompleteKey {
        switch self {
        case .backtick:
            .backtick
        case .optionTab:
            .optionTab
        case .disabled:
            .other
        }
    }

    public var displayName: String {
        switch self {
        case .backtick:
            "Backtick"
        case .optionTab:
            "Option-Tab"
        case .disabled:
            "Off"
        }
    }

    public var next: AcceptAllShortcut {
        switch self {
        case .backtick:
            .optionTab
        case .optionTab:
            .disabled
        case .disabled:
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

public struct KeyboardShortcutConflictContext: Equatable, Sendable {
    public let appDisplayName: String
    public let isAppEnabled: Bool
    public let canPresentSuggestions: Bool
    public let supportsFullAcceptance: Bool

    public init(
        appDisplayName: String,
        isAppEnabled: Bool,
        canPresentSuggestions: Bool,
        supportsFullAcceptance: Bool
    ) {
        self.appDisplayName = appDisplayName
        self.isAppEnabled = isAppEnabled
        self.canPresentSuggestions = canPresentSuggestions
        self.supportsFullAcceptance = supportsFullAcceptance
    }
}

public enum KeyboardShortcutConflictLevel: String, Equatable, Sendable {
    case none
    case warning
    case blocked
}

public struct KeyboardShortcutConflictEvaluation: Equatable, Sendable {
    public let level: KeyboardShortcutConflictLevel
    public let statusText: String
    public let detailText: String
    public let perAppProfileText: String

    public init(
        level: KeyboardShortcutConflictLevel,
        statusText: String,
        detailText: String,
        perAppProfileText: String
    ) {
        self.level = level
        self.statusText = statusText
        self.detailText = detailText
        self.perAppProfileText = perAppProfileText
    }
}

public struct KeyboardShortcutConflictPolicy: Equatable, Sendable {
    public init() {}

    public func evaluation(
        acceptAllShortcut: AcceptAllShortcut,
        context: KeyboardShortcutConflictContext?
    ) -> KeyboardShortcutConflictEvaluation {
        guard acceptAllShortcut != .disabled else {
            return KeyboardShortcutConflictEvaluation(
                level: .none,
                statusText: "Conflict check: whole-suggestion accept is off",
                detailText: "Tab still accepts the next word plus a space when suggestions are visible.",
                perAppProfileText: "Per-app profile: whole-suggestion accept is disabled."
            )
        }

        guard let context else {
            return KeyboardShortcutConflictEvaluation(
                level: .warning,
                statusText: "Conflict check: choose an app",
                detailText: "Open a writing app to check the shortcut against that app profile.",
                perAppProfileText: "Per-app profile: choose an app to check whole-suggestion accept."
            )
        }

        guard context.isAppEnabled else {
            return KeyboardShortcutConflictEvaluation(
                level: .blocked,
                statusText: "Conflict check: \(context.appDisplayName) is paused",
                detailText: "Whole-suggestion accept will not run while this app is paused.",
                perAppProfileText: "Per-app profile: \(context.appDisplayName) is paused."
            )
        }

        guard context.canPresentSuggestions else {
            return KeyboardShortcutConflictEvaluation(
                level: .blocked,
                statusText: "Conflict check: suggestions are off here",
                detailText: "This app profile does not allow visible suggestions.",
                perAppProfileText: "Per-app profile: \(context.appDisplayName) does not allow suggestions."
            )
        }

        guard context.supportsFullAcceptance else {
            return KeyboardShortcutConflictEvaluation(
                level: .blocked,
                statusText: "Conflict check: whole-suggestion accept is off in \(context.appDisplayName)",
                detailText: "Tab accepts one word plus a space, but whole-suggestion accept stays off for this app.",
                perAppProfileText: "Per-app profile: \(context.appDisplayName) allows Tab one-word accept only."
            )
        }

        if acceptAllShortcut == .optionTab {
            return KeyboardShortcutConflictEvaluation(
                level: .warning,
                statusText: "Conflict check: Option-Tab may overlap app shortcuts",
                detailText: "Backtick is quieter if Option-Tab already means something in this app.",
                perAppProfileText: "Per-app profile: \(context.appDisplayName) allows Tab one-word accept and whole-suggestion accept."
            )
        }

        return KeyboardShortcutConflictEvaluation(
            level: .none,
            statusText: "Conflict check: no known conflict in \(context.appDisplayName)",
            detailText: "Whole-suggestion accept is checked against the current app profile before it can run.",
            perAppProfileText: "Per-app profile: \(context.appDisplayName) allows Tab one-word accept and whole-suggestion accept."
        )
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
