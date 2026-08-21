import AutocompleteLabCore
import Foundation

/// Every menu setting, the process that owns it, and its default.
///
/// The keyboard is a separate process, so its settings must be written to the
/// InlineGhost settings shared with the keyboard process.
struct TildeSettings {
    enum AppKey: String {
        case launchAtLogin = "LaunchAtLoginEnabled"
        case setupVersion = "SetupVersion"
        case screenRecordingRequested = "ScreenRecordingRequested"
        case localOCREvaluation = "LocalOCREvaluationEnabled"
    }

    static let currentSetupVersion = 2

    enum KeyboardKey: String {
        case suggestions = "GhostSuggestionsEnabled"
        case pausedUntil = "GhostPausedUntil"
        case personalHistory = "PersonalHistoryEnabled"
        case personalHistoryExcludedApps = "PersonalHistoryExcludedApps"
        case personalHistoryIdentifier = "PersonalHistoryIdentifier"
        case personalHistoryConsentIdentifier = "PersonalHistoryConsentIdentifier"
        case personalNextWordExperimentIdentifier = "PersonalNextWordExperimentIdentifier"
        case screenMemoryEnabled = "ScreenMemoryEnabled"
        case consensusShorteningEnabled = "ConsensusShorteningEnabled"
        case incrementalOCREnabled = "IncrementalOCREnabled"
    }

    static let keyboardSuiteName = PersonalHistorySettingsContract.keyboardSuiteName

    private let keyboard: UserDefaults
    private let app: UserDefaults

    init(
        keyboard: UserDefaults? = UserDefaults(suiteName: TildeSettings.keyboardSuiteName),
        app: UserDefaults = .standard
    ) {
        self.keyboard = keyboard ?? .standard
        self.app = app
    }

    var launchAtLoginEnabled: Bool {
        get { app.object(forKey: AppKey.launchAtLogin.rawValue) as? Bool ?? true }
        nonmutating set { app.set(newValue, forKey: AppKey.launchAtLogin.rawValue) }
    }

    var setupVersion: Int {
        get { app.integer(forKey: AppKey.setupVersion.rawValue) }
        nonmutating set { app.set(newValue, forKey: AppKey.setupVersion.rawValue) }
    }

    var screenRecordingRequested: Bool {
        get { app.bool(forKey: AppKey.screenRecordingRequested.rawValue) }
        nonmutating set { app.set(newValue, forKey: AppKey.screenRecordingRequested.rawValue) }
    }

    /// Development-only paired OCR corpus. Unlike product flags, this is
    /// deliberately off when absent because enabling it persists raw visible
    /// text and runs an additional full-frame OCR reference pass.
    var localOCREvaluationEnabled: Bool {
        get { app.bool(forKey: AppKey.localOCREvaluation.rawValue) }
        nonmutating set { app.set(newValue, forKey: AppKey.localOCREvaluation.rawValue) }
    }

    var suggestionsEnabled: Bool {
        get { flag(.suggestions) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.suggestions.rawValue) }
    }

    var personalHistoryEnabled: Bool {
        get { keyboard.bool(forKey: KeyboardKey.personalHistory.rawValue) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.personalHistory.rawValue) }
    }

    /// Off by default: token-level confidence over-trims greedy prose and the
    /// n_probs request costs latency — see LlamaCompletionEngine.evidence.
    var consensusShorteningEnabled: Bool {
        get { keyboard.bool(forKey: KeyboardKey.consensusShorteningEnabled.rawValue) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.consensusShorteningEnabled.rawValue) }
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

    /// The covenant's master toggle. On by default (2026-08-16 owner
    /// directive: Screen Memory is a first-class, required-permission
    /// feature, not an exotic opt-in) — like every other flag in this file,
    /// a fresh install with no persisted key reads `flag()`'s default of
    /// `true`. An existing install that explicitly turned this off keeps
    /// that choice: this changes the DEFAULT for installs that never set the
    /// key, not a forced flip of anyone's saved preference. Exclusions are
    /// deliberately NOT a separate key: the covenant requires them shared
    /// with Personal History, so callers read `personalHistoryExcludedApps`
    /// for both features.
    var screenMemoryEnabled: Bool {
        get { flag(.screenMemoryEnabled) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.screenMemoryEnabled.rawValue) }
    }

    /// Experiment arm for "OCR only the changed screen region" (2026-08-19):
    /// ON by default, same `flag()`/`screenMemoryEnabled`-style default-true
    /// semantics — a fresh install with no persisted key reads the default,
    /// an existing install's explicit choice persists. Setting this `false`
    /// restores today's always-full-OCR behavior exactly: `ScreenCaptureService`
    /// skips the luminance-grid sampling and `CaptureChangeDetector` entirely
    /// when this reads false, rather than merely ignoring their output, so
    /// disabling the experiment costs nothing extra either. `ocrScope` on
    /// `screen-capture-completed` is this experiment's measurement
    /// instrument regardless of which arm is live.
    var incrementalOCREnabled: Bool {
        get { flag(.incrementalOCREnabled) }
        nonmutating set { keyboard.set(newValue, forKey: KeyboardKey.incrementalOCREnabled.rawValue) }
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
