import AutocompleteLabCore
import Foundation

struct VisibleSuggestionKeyboardContext: Equatable {
    var focusedFieldMatchesCurrentSuggestion: Bool
    var supportsOneWordAcceptance: Bool
    var supportsFullAcceptance: Bool
    var shortcutConfiguration: KeyboardShortcutConfiguration

    init(
        focusedFieldMatchesCurrentSuggestion: Bool,
        supportsOneWordAcceptance: Bool,
        supportsFullAcceptance: Bool,
        shortcutConfiguration: KeyboardShortcutConfiguration
    ) {
        self.focusedFieldMatchesCurrentSuggestion = focusedFieldMatchesCurrentSuggestion
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.shortcutConfiguration = shortcutConfiguration
    }
}

enum VisibleSuggestionKeyboardPlan: Equatable {
    case noVisibleSuggestion
    case hideAndPassThrough(action: KeyboardAction, decision: String, reason: String)
    case suppressAutorepeat
    case acceptNextWord(String?)
    case acceptAllVisible(String?)
    case dismiss
    case passThrough(action: KeyboardAction, reason: String, shouldRecord: Bool)
}

struct VisibleSuggestionKeyboardHandler: Equatable {
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private let suppressionDuration: TimeInterval

    init(suppressionDuration: TimeInterval = 0.25) {
        self.suppressionDuration = suppressionDuration
    }

    mutating func plan(
        for key: AutocompleteKey,
        isAutorepeat: Bool,
        didObservePassthroughKeyDown: Bool,
        state: inout VisibleSuggestionState,
        context: VisibleSuggestionKeyboardContext,
        now: Date = Date()
    ) -> VisibleSuggestionKeyboardPlan {
        if didObservePassthroughKeyDown {
            state.markInvalidatedByUserKeyDown()
        }

        guard state.hasVisibleSuggestion else {
            suppressKeyUntil[key] = nil
            return .noVisibleSuggestion
        }

        guard context.focusedFieldMatchesCurrentSuggestion else {
            return .hideAndPassThrough(
                action: .passThrough,
                decision: "Blocked: focus changed",
                reason: "focus-changed"
            )
        }

        if state.isInvalidatedByUserKeyDown {
            return .hideAndPassThrough(
                action: .passThrough,
                decision: "Blocked: stale suggestion passed through",
                reason: "stale-after-keydown"
            )
        }

        if shouldSuppressKey(key, isAutorepeat: isAutorepeat, now: now) {
            return .suppressAutorepeat
        }

        let action = KeyboardActionRouter(
            shortcutConfiguration: context.shortcutConfiguration
        ).action(for: key, hasVisibleSuggestion: state.hasVisibleSuggestion)

        switch action {
        case .acceptNextWord:
            guard context.supportsOneWordAcceptance else {
                return .passThrough(
                    action: action,
                    reason: "unsupported-one-word",
                    shouldRecord: true
                )
            }
            return .acceptNextWord(state.nextWordAcceptance())

        case .acceptAllVisible:
            guard context.supportsFullAcceptance else {
                return .passThrough(
                    action: action,
                    reason: "unsupported-full",
                    shouldRecord: true
                )
            }
            return .acceptAllVisible(state.allVisibleAcceptance())

        case .dismiss:
            return .dismiss

        case .passThrough:
            return .passThrough(
                action: action,
                reason: "pass-through",
                shouldRecord: key != .other
            )
        }
    }

    mutating func suppressKey(_ key: AutocompleteKey, now: Date = Date()) {
        suppressKeyUntil[key] = now.addingTimeInterval(suppressionDuration)
    }

    private mutating func shouldSuppressKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool,
        now: Date
    ) -> Bool {
        guard isAutorepeat else {
            suppressKeyUntil[key] = nil
            return false
        }

        guard let until = suppressKeyUntil[key] else {
            return false
        }

        if until > now {
            return true
        }

        suppressKeyUntil[key] = nil
        return false
    }
}
