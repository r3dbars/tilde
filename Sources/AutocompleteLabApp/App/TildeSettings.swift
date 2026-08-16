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
        case personalNextWordExperimentIdentifier = "PersonalNextWordExperimentIdentifier"
        case screenMemoryEnabled = "ScreenMemoryEnabled"
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

    var personalNextWordExperimentIdentifier: String? {
        get {
            guard let value = keyboard.string(
                forKey: KeyboardKey.personalNextWordExperimentIdentifier.rawValue
            ), PersonalHistoryEvent.validIdentifier(value) else { return nil }
            return value
        }
        nonmutating set {
            keyboard.set(newValue, forKey: KeyboardKey.personalNextWordExperimentIdentifier.rawValue)
        }
    }

    /// The covenant's master toggle: off by default, unlike every other flag
    /// in this file (`flag()` defaults missing keys to true — Screen Memory
    /// must not). Exclusions are deliberately NOT a separate key: the
    /// covenant requires them shared with Personal History, so callers read
    /// `personalHistoryExcludedApps` for both features.
    var screenMemoryEnabled: Bool {
        get { keyboard.bool(forKey: KeyboardKey.screenMemoryEnabled.rawValue) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.screenMemoryEnabled.rawValue) }
    }

    /// Screen Memory's full opt-in ships in Phase 5; until then its menu
    /// controls (StatusMenuHost) AND the capture engine itself (AppDelegate's
    /// `screenCaptureService`) are gated behind this SAME flag. Without that
    /// pairing, a persisted `ScreenMemoryEnabled=true` from an earlier dev
    /// session would keep capturing on every later production launch even
    /// though the toggle/status menu items that could turn it back off are
    /// hidden — capture running with no visible status or off switch, which
    /// the covenant's owner-visible-controls requirement forbids.
    ///
    /// Checked two ways, either one sufficient:
    ///   - `TILDE_SCREEN_MEMORY_DEV=1` in the environment, for a one-off
    ///     Terminal-launched run.
    ///   - The `ScreenMemoryDevMode` boolean in the app's own UserDefaults
    ///     suite (`defaults write bar.r3d.tilde ScreenMemoryDevMode -bool
    ///     true`), which persists across normal launches.
    /// The environment-only check (until 2026-08-16) silently failed for
    /// Tilde's actual deployment shape: it is an `LSUIElement` menu-bar app,
    /// normally launched by Finder/Dock/LaunchServices, none of which
    /// inherit a Terminal shell's exported environment — `launchctl setenv`
    /// did not reach it either. The owner set the env var, relaunched from
    /// Finder, and the "Screen Memory" menu item never appeared: the dev
    /// flag was unreachable outside a Terminal-launched run, with no visible
    /// sign of why. `UserDefaults.standard` for the app's own bundle
    /// identifier (`bar.r3d.tilde`) is a normal per-user preference that
    /// LaunchServices always loads regardless of launch path, so the
    /// `defaults write` form works everywhere the environment variable did
    /// not.
    static let screenMemoryDevModeDefaultsKey = "ScreenMemoryDevMode"

    static func screenMemoryDevModeEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        appDefaults: UserDefaults = .standard
    ) -> Bool {
        if environment["TILDE_SCREEN_MEMORY_DEV"] == "1" { return true }
        return appDefaults.bool(forKey: screenMemoryDevModeDefaultsKey)
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
