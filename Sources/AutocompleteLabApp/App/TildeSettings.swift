import Foundation

/// Every menu setting, the process that owns it, and its default.
///
/// The keyboard is a separate process, so its settings must be written to the
/// InlineGhost defaults suite. Suggestions and sounds start on.
struct TildeSettings {
    enum KeyboardKey: String, CaseIterable {
        case suggestions = "GhostSuggestionsEnabled"
        case sounds = "GhostSoundsEnabled"
        case pausedUntil = "GhostPausedUntil"
    }

    static let keyboardSuiteName = "bar.r3d.inputmethod.InlineGhost"

    private let keyboard: UserDefaults

    init(keyboard: UserDefaults? = UserDefaults(suiteName: TildeSettings.keyboardSuiteName)) {
        self.keyboard = keyboard ?? .standard
    }

    var suggestionsEnabled: Bool {
        get { flag(.suggestions) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.suggestions.rawValue) }
    }

    var soundsEnabled: Bool {
        get { flag(.sounds) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.sounds.rawValue) }
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
