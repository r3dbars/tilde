import Foundation
import AutocompleteLabCore

@MainActor
final class AppSettings {
    enum RuntimeMode: String, CaseIterable {
        case appOwnedLocalModel

        var menuTitle: String {
            switch self {
            case .appOwnedLocalModel:
                return "App-Owned Local Model"
            }
        }
    }

    private enum Key {
        static let suggestionsEnabled = "settings.suggestionsEnabled"
        static let runtimeMode = "settings.runtimeMode"
        static let personalCaptureEnabled = "settings.personalCaptureEnabled"
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

    var runtimeMode: RuntimeMode {
        get {
            let rawValue = defaults.string(forKey: Key.runtimeMode) ?? RuntimeMode.appOwnedLocalModel.rawValue
            return RuntimeMode(rawValue: rawValue) ?? .appOwnedLocalModel
        }
        set { defaults.set(newValue.rawValue, forKey: Key.runtimeMode) }
    }

    var personalCaptureEnabled: Bool {
        get { defaults.bool(forKey: Key.personalCaptureEnabled) }
        set { defaults.set(newValue, forKey: Key.personalCaptureEnabled) }
    }

    func toggleSuggestionsEnabled() {
        suggestionsEnabled.toggle()
    }

    func togglePersonalCapture() {
        personalCaptureEnabled.toggle()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.suggestionsEnabled: true,
            Key.runtimeMode: RuntimeMode.appOwnedLocalModel.rawValue,
            Key.personalCaptureEnabled: false
        ])
    }
}
