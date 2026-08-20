import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Tilde settings")
struct TildeSettingsTests {
    private func makeSettings() -> (TildeSettings, UserDefaults) {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        return (TildeSettings(keyboard: keyboard), keyboard)
    }

    @Test("Fresh keyboard settings enable suggestions")
    func absentKeysUseProductDefaults() {
        let (settings, _) = makeSettings()
        #expect(settings.suggestionsEnabled)
        #expect(settings.pausedUntil == nil)
        #expect(!settings.personalHistoryEnabled)
        #expect(settings.personalHistoryExcludedApps.isEmpty)
        // "Personal suggestions (experimental)" (docs/plans/road-to-paid.md
        // Phase 3) defaults OFF, unlike Screen Memory's ON default below —
        // a feel-it experiment should never turn itself on for anyone.
        #expect(!settings.personalSuggestionsServingEnabled)
        // 2026-08-16 owner directive: Screen Memory is a first-class,
        // required-permission feature, not an opt-in — a fresh install with
        // no persisted key must read ON, same as every other product
        // default in this file (`suggestionsEnabled` above).
        #expect(settings.screenMemoryEnabled)
        // 2026-08-19 experiment: "OCR only the changed screen region" is the
        // default-on arm, same default-true semantics as `screenMemoryEnabled`
        // above — a fresh install with no persisted key reads ON.
        #expect(settings.incrementalOCREnabled)
    }

    @Test("Launch at login defaults on and preserves an explicit choice")
    func launchAtLoginPreference() {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let appName = "tilde.tests.app.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        let app = UserDefaults(suiteName: appName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        app.removePersistentDomain(forName: appName)
        let settings = TildeSettings(keyboard: keyboard, app: app)

        #expect(settings.launchAtLoginEnabled)
        settings.launchAtLoginEnabled = false
        #expect(!settings.launchAtLoginEnabled)
        #expect(app.object(forKey: "LaunchAtLoginEnabled") as? Bool == false)
    }

    @Test("Setup progress stays in the app defaults domain")
    func setupProgress() {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let appName = "tilde.tests.app.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        let app = UserDefaults(suiteName: appName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        app.removePersistentDomain(forName: appName)
        let settings = TildeSettings(keyboard: keyboard, app: app)

        #expect(settings.setupVersion == 0)
        #expect(!settings.screenRecordingRequested)
        settings.setupVersion = TildeSettings.currentSetupVersion
        settings.screenRecordingRequested = true

        #expect(app.integer(forKey: "SetupVersion") == TildeSettings.currentSetupVersion)
        #expect(app.bool(forKey: "ScreenRecordingRequested"))
        #expect(keyboard.object(forKey: "SetupVersion") == nil)
    }

    @Test("Raw OCR evaluation defaults off and stays in the app domain")
    func localOCREvaluationPreference() {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let appName = "tilde.tests.app.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        let app = UserDefaults(suiteName: appName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        app.removePersistentDomain(forName: appName)
        let settings = TildeSettings(keyboard: keyboard, app: app)

        #expect(!settings.localOCREvaluationEnabled)
        settings.localOCREvaluationEnabled = true
        #expect(settings.localOCREvaluationEnabled)
        #expect(app.object(forKey: "LocalOCREvaluationEnabled") as? Bool == true)
        #expect(keyboard.object(forKey: "LocalOCREvaluationEnabled") == nil)
    }

    @Test("Incremental OCR's toggle lands in the keyboard domain, on by default, explicitly settable either way")
    func incrementalOCRToggle() {
        let (settings, keyboard) = makeSettings()
        #expect(settings.incrementalOCREnabled)
        settings.incrementalOCREnabled = false
        #expect(!settings.incrementalOCREnabled)
        #expect(keyboard.object(forKey: "IncrementalOCREnabled") as? Bool == false)
        settings.incrementalOCREnabled = true
        #expect(settings.incrementalOCREnabled)
    }

    @Test("An existing install that explicitly turned incremental OCR off keeps that choice")
    func incrementalOCRExplicitOffPersists() {
        let (settings, keyboard) = makeSettings()
        keyboard.set(false, forKey: "IncrementalOCREnabled")
        #expect(!settings.incrementalOCREnabled)
    }

    @Test("Screen Memory's toggle lands in the keyboard domain, on by default, explicitly settable either way")
    func screenMemoryToggle() {
        let (settings, keyboard) = makeSettings()
        #expect(settings.screenMemoryEnabled)
        settings.screenMemoryEnabled = false
        #expect(!settings.screenMemoryEnabled)
        #expect(keyboard.object(forKey: "ScreenMemoryEnabled") as? Bool == false)
        settings.screenMemoryEnabled = true
        #expect(settings.screenMemoryEnabled)
    }

    @Test("An existing install that explicitly turned Screen Memory off keeps that choice — the changed default only affects fresh installs with no persisted key")
    func screenMemoryExplicitOffPersists() {
        let (settings, keyboard) = makeSettings()
        keyboard.set(false, forKey: "ScreenMemoryEnabled")
        #expect(!settings.screenMemoryEnabled)
    }

    @Test("Screen Memory shares its exclusion list with Personal History, per the covenant")
    func screenMemorySharesPersonalHistoryExclusions() {
        let (settings, _) = makeSettings()
        settings.personalHistoryExcludedApps = ["com.1password.1password"]
        // There is deliberately no separate `screenMemoryExcludedApps` —
        // Screen Memory reads the same set.
        #expect(settings.personalHistoryExcludedApps == ["com.1password.1password"])
    }

    @Test("Personal History controls stay in the keyboard domain")
    func personalHistorySettings() {
        let (settings, keyboard) = makeSettings()
        settings.personalHistoryEnabled = true
        settings.personalHistoryExcludedApps = ["com.example.Editor", "bad value"]
        settings.personalNextWordExperimentIdentifier = "experiment-id"

        #expect(settings.personalHistoryEnabled)
        #expect(settings.personalHistoryExcludedApps == ["com.example.Editor"])
        #expect(keyboard.object(forKey: "PersonalHistoryEnabled") as? Bool == true)
        #expect(keyboard.stringArray(forKey: "PersonalHistoryExcludedApps") == ["com.example.Editor"])
        #expect(settings.personalNextWordExperimentIdentifier == "experiment-id")
    }

    @Test("Personal suggestions serving toggle is explicitly settable and stays in the keyboard domain")
    func personalSuggestionsServingToggle() {
        let (settings, keyboard) = makeSettings()
        #expect(!settings.personalSuggestionsServingEnabled)
        settings.personalSuggestionsServingEnabled = true
        #expect(settings.personalSuggestionsServingEnabled)
        #expect(keyboard.object(forKey: "PersonalSuggestionsServingEnabled") as? Bool == true)
        settings.personalSuggestionsServingEnabled = false
        #expect(!settings.personalSuggestionsServingEnabled)
    }

    @Test("Keyboard settings stay in the keyboard defaults domain")
    func keyboardSettingsLandInKeyboardDomain() {
        let (settings, keyboard) = makeSettings()
        settings.suggestionsEnabled = false

        #expect(keyboard.object(forKey: "GhostSuggestionsEnabled") as? Bool == false)
    }

    @Test("Pause expires and resume clears it")
    func pauseLifecycle() {
        let (settings, keyboard) = makeSettings()
        settings.pause(for: 3600)
        #expect(settings.pausedUntil != nil)
        settings.resume()
        #expect(settings.pausedUntil == nil)

        keyboard.set(
            Date().addingTimeInterval(-60).timeIntervalSince1970,
            forKey: "GhostPausedUntil"
        )
        #expect(settings.pausedUntil == nil)
    }

    @Test("Settings describes the external Gemma 4 E2B model and formats progress")
    func modelPresentation() {
        #expect(TildeModelPresentation.name == "Gemma 4 E2B")
        #expect(TildeModelPresentation.approximateSize == "about 3.43 GB")
        #expect(TildeModelPresentation.description.contains("Gemma 4 E2B"))

        let progress = TildeModelDownloadProgress(
            receivedBytes: 640_000_000,
            totalBytes: 3_430_000_000
        )
        #expect(progress.fraction != nil)
        #expect(progress.fraction! > 0.18)
        #expect(progress.fraction! < 0.19)
        #expect(progress.detail.contains("of"))
    }
}
