import Foundation

/// Every Tilde setting, its domain, and its default — in one place.
///
/// This type exists because the same bug shipped twice in one day: a switch
/// bound to a key nothing reads. The old settings window had three toggles
/// (`tilde.suggestionsEnabled`, `tilde.soundsEnabled`, `tilde.learningEnabled`)
/// that existed only in that file, so flipping them did nothing. Its
/// replacement then bound "Sounds" to `GhostSoundVolume` when the keyboard's
/// real gate is `GhostSoundsEnabled`. Both were invisible at runtime: the
/// checkmark moved, the behaviour did not.
///
/// Two rules encoded here:
///
/// 1. **Domains are not interchangeable.** The keyboard is a separate process;
///    its `UserDefaults.standard` is the suite `bar.r3d.inputmethod.InlineGhost`.
///    A keyboard setting written into the app's domain is a silent no-op.
/// 2. **Absent means the keyboard's registered default, not `false`.** The IME
///    calls `register(defaults:)` at launch, but a registration domain is
///    process-local — from the app the key simply looks unset. Reading with
///    `bool(forKey:)` would report "off" for a fresh install where the real
///    behaviour is "on".
///
/// `TildeSettingsTests` asserts every key below actually appears in the
/// keyboard's sources, so a toggle wired to a phantom key fails the build's
/// tests rather than shipping.
struct TildeSettings {

    /// Keys the KEYBOARD reads. Must live in the keyboard's own domain.
    enum KeyboardKey: String, CaseIterable {
        case suggestions = "GhostSuggestionsEnabled"
        case sounds = "GhostSoundsEnabled"
        case learning = "GhostUsageCaptureEnabled"
        case pausedUntil = "GhostPausedUntil"
    }

    /// Keys the APP reads, in the app's own domain.
    enum AppKey: String, CaseIterable {
        case screenAware = "VisiblePageContextEnabled"
    }

    static let keyboardSuiteName = "bar.r3d.inputmethod.InlineGhost"

    private let keyboard: UserDefaults
    private let app: UserDefaults

    init(keyboard: UserDefaults? = UserDefaults(suiteName: TildeSettings.keyboardSuiteName),
         app: UserDefaults = .standard) {
        self.keyboard = keyboard ?? .standard
        self.app = app
    }

    // MARK: - Keyboard settings (absent = the keyboard's registered default)

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

    /// When the writer paused Tilde, or nil if it is not currently paused.
    var pausedUntil: Date? {
        let stamp = keyboard.double(forKey: KeyboardKey.pausedUntil.rawValue)
        guard stamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: stamp)
        return date > Date() ? date : nil
    }

    func pause(for interval: TimeInterval, now: Date = Date()) {
        keyboard.set(now.addingTimeInterval(interval).timeIntervalSince1970,
                     forKey: KeyboardKey.pausedUntil.rawValue)
    }

    func resume() {
        keyboard.set(0, forKey: KeyboardKey.pausedUntil.rawValue)
    }

    private func flag(_ key: KeyboardKey) -> Bool {
        keyboard.object(forKey: key.rawValue) as? Bool ?? true
    }

    // MARK: - App settings

    var screenAware: Bool {
        get { app.bool(forKey: AppKey.screenAware.rawValue) }
        nonmutating set { app.set(newValue, forKey: AppKey.screenAware.rawValue) }
    }
}
