import Foundation

/// Every menu setting, the process that owns it, and its default.
///
/// The keyboard is a separate process, so its settings must be written to the
/// InlineGhost defaults suite. Suggestions and sounds start on; learning stores
/// writing context and therefore stays off until the user explicitly enables it.
struct TildeSettings {
    enum KeyboardKey: String, CaseIterable {
        case suggestions = "GhostSuggestionsEnabled"
        case sounds = "GhostSoundsEnabled"
        case learning = "GhostUsageCaptureEnabled"
        case pausedUntil = "GhostPausedUntil"
    }

    enum AppKey: String, CaseIterable {
        case screenAware = "VisiblePageContextEnabled"
    }

    static let keyboardSuiteName = "bar.r3d.inputmethod.InlineGhost"

    private let keyboard: UserDefaults
    private let app: UserDefaults

    init(
        keyboard: UserDefaults? = UserDefaults(suiteName: TildeSettings.keyboardSuiteName),
        app: UserDefaults = .standard
    ) {
        self.keyboard = keyboard ?? .standard
        self.app = app
    }

    var suggestionsEnabled: Bool {
        get { flag(.suggestions) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.suggestions.rawValue) }
    }

    var soundsEnabled: Bool {
        get { flag(.sounds) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.sounds.rawValue) }
    }

    var learningEnabled: Bool {
        get { flag(.learning) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.learning.rawValue) }
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
        keyboard.object(forKey: key.rawValue) as? Bool ?? (key != .learning)
    }

    var screenAware: Bool {
        get { app.bool(forKey: AppKey.screenAware.rawValue) }
        nonmutating set { app.set(newValue, forKey: AppKey.screenAware.rawValue) }
    }
}
