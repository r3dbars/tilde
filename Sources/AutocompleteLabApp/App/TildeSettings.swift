import AutocompleteLabCore
import Foundation

/// Every menu setting, the process that owns it, and its default.
///
/// The keyboard is a separate process, so its settings must be written to the
/// InlineGhost settings shared with the keyboard process.
struct TildeSettings {
    enum KeyboardKey: String {
        case suggestions = "GhostSuggestionsEnabled"
        case pausedUntil = "GhostPausedUntil"
        case personalHistory = "PersonalHistoryEnabled"
        case personalHistoryExcludedApps = "PersonalHistoryExcludedApps"
        case personalHistoryIdentifier = "PersonalHistoryIdentifier"
        case personalHistoryConsentIdentifier = "PersonalHistoryConsentIdentifier"
    }

    static let keyboardSuiteName = PersonalHistorySettingsContract.keyboardSuiteName

    private let keyboard: UserDefaults

    init(keyboard: UserDefaults? = UserDefaults(suiteName: TildeSettings.keyboardSuiteName)) {
        self.keyboard = keyboard ?? .standard
    }

    var suggestionsEnabled: Bool {
        get { flag(.suggestions) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.suggestions.rawValue) }
    }

    var personalHistoryEnabled: Bool {
        get { keyboard.bool(forKey: KeyboardKey.personalHistory.rawValue) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.personalHistory.rawValue) }
    }

    var personalHistoryExcludedApps: Set<String> {
        get {
            Set(PersonalHistoryCapturePolicy.normalizedExcludedApps(
                keyboard.stringArray(forKey: KeyboardKey.personalHistoryExcludedApps.rawValue) ?? []
            ))
        }
        nonmutating set {
            keyboard.set(
                PersonalHistoryCapturePolicy.normalizedExcludedApps(newValue),
                forKey: KeyboardKey.personalHistoryExcludedApps.rawValue
            )
        }
    }

    var personalHistoryIdentifier: String? {
        get {
            guard let value = keyboard.string(forKey: KeyboardKey.personalHistoryIdentifier.rawValue),
                  PersonalHistoryEvent.validIdentifier(value) else { return nil }
            return value
        }
        nonmutating set {
            keyboard.set(newValue, forKey: KeyboardKey.personalHistoryIdentifier.rawValue)
        }
    }

    var personalHistoryConsentIdentifier: String? {
        get {
            guard let value = keyboard.string(
                forKey: KeyboardKey.personalHistoryConsentIdentifier.rawValue
            ), PersonalHistoryEvent.validIdentifier(value) else { return nil }
            return value
        }
        nonmutating set {
            keyboard.set(newValue, forKey: KeyboardKey.personalHistoryConsentIdentifier.rawValue)
        }
    }

    var pausedUntil: Date? {
        let stamp = keyboard.double(forKey: KeyboardKey.pausedUntil.rawValue)
        guard stamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: stamp)
        return date > Date() ? date : nil
    }

    func pause(for interval: TimeInterval, now: Date = Date()) {
        keyboard.set(
            now.addingTimeInterval(interval).timeIntervalSince1970,
            forKey: KeyboardKey.pausedUntil.rawValue
        )
    }

    func resume() {
        keyboard.set(0, forKey: KeyboardKey.pausedUntil.rawValue)
    }

    private func flag(_ key: KeyboardKey) -> Bool {
        keyboard.object(forKey: key.rawValue) as? Bool ?? true
    }
}
