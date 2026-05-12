import Foundation
import AutocompleteLabCore

@MainActor
final class AppSettings {
    enum RuntimeMode: String, CaseIterable {
        case appOwnedLocalModel = "gemmaLocalWithMockFallback"
        case mockOnly

        var menuTitle: String {
            switch self {
            case .appOwnedLocalModel:
                return "App-Owned Local Model"
            case .mockOnly:
                return "Mock Suggestions Only (Tests)"
            }
        }
    }

    private enum Key {
        static let suggestionsEnabled = "settings.suggestionsEnabled"
        static let enforceAllowlist = "settings.enforceAllowlist"
        static let suppressSecureFields = "settings.suppressSecureFields"
        static let suppressShortText = "settings.suppressShortText"
        static let suppressAfterNewline = "settings.suppressAfterNewline"
        static let runtimeMode = "settings.runtimeMode"
        static let minimumCharacters = "settings.minimumCharacters"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    var suggestionsEnabled: Bool {
        get { defaults.bool(forKey: Key.suggestionsEnabled) }
        set { defaults.set(newValue, forKey: Key.suggestionsEnabled) }
    }

    var enforceAllowlist: Bool {
        get { defaults.bool(forKey: Key.enforceAllowlist) }
        set { defaults.set(newValue, forKey: Key.enforceAllowlist) }
    }

    var suppressSecureFields: Bool {
        get { defaults.bool(forKey: Key.suppressSecureFields) }
        set { defaults.set(newValue, forKey: Key.suppressSecureFields) }
    }

    var suppressShortText: Bool {
        get { defaults.bool(forKey: Key.suppressShortText) }
        set { defaults.set(newValue, forKey: Key.suppressShortText) }
    }

    var suppressAfterNewline: Bool {
        get { defaults.bool(forKey: Key.suppressAfterNewline) }
        set { defaults.set(newValue, forKey: Key.suppressAfterNewline) }
    }

    var runtimeMode: RuntimeMode {
        get {
            let rawValue = defaults.string(forKey: Key.runtimeMode) ?? RuntimeMode.appOwnedLocalModel.rawValue
            return RuntimeMode(rawValue: rawValue) ?? .appOwnedLocalModel
        }
        set { defaults.set(newValue.rawValue, forKey: Key.runtimeMode) }
    }

    var minimumCharacters: Int {
        get { max(1, defaults.integer(forKey: Key.minimumCharacters)) }
        set { defaults.set(max(1, newValue), forKey: Key.minimumCharacters) }
    }

    func toggleSuggestionsEnabled() {
        suggestionsEnabled.toggle()
    }

    func toggleAllowlist() {
        enforceAllowlist.toggle()
    }

    func toggleSecureFieldSuppression() {
        suppressSecureFields.toggle()
    }

    func toggleShortTextSuppression() {
        suppressShortText.toggle()
    }

    func toggleAfterNewlineSuppression() {
        suppressAfterNewline.toggle()
    }

    func privacySettings(allowedBundleIdentifiers: Set<String>) -> SuggestionPrivacySettings {
        SuggestionPrivacySettings(
            isAppAllowlistEnabled: enforceAllowlist,
            allowedBundleIdentifiers: allowedBundleIdentifiers,
            suppressSecureFields: suppressSecureFields,
            minimumCharactersBeforeSuggestion: suppressShortText ? minimumCharacters : 1,
            suppressEmptyText: suppressShortText,
            suppressImmediatelyAfterNewline: suppressAfterNewline,
            debounceMilliseconds: CompletionModelPolicy.mvp.debounceMilliseconds,
            targetLatencyMilliseconds: CompletionModelPolicy.mvp.targetLatencyMilliseconds
        )
    }

    func compatibilityRoutingSettings() -> CompatibilityRoutingSettings {
        CompatibilityRoutingSettings(
            enforceKnownApps: enforceAllowlist,
            suppressSecureFields: suppressSecureFields,
            minimumCharactersBeforeSuggestion: suppressShortText ? minimumCharacters : 1,
            suppressEmptyText: suppressShortText,
            suppressImmediatelyAfterNewline: suppressAfterNewline
        )
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.suggestionsEnabled: true,
            Key.enforceAllowlist: true,
            Key.suppressSecureFields: true,
            Key.suppressShortText: true,
            Key.suppressAfterNewline: true,
            Key.runtimeMode: RuntimeMode.appOwnedLocalModel.rawValue,
            Key.minimumCharacters: 3
        ])
    }
}
