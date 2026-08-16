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
        // Screen Memory covenant: the master toggle is off by default,
        // unlike suggestionsEnabled above — a fresh install must never
        // capture the screen before the user opts in.
        #expect(!settings.screenMemoryEnabled)
    }

    @Test("Screen Memory's toggle lands in the keyboard domain, off until explicitly set")
    func screenMemoryToggle() {
        let (settings, keyboard) = makeSettings()
        #expect(!settings.screenMemoryEnabled)
        settings.screenMemoryEnabled = true
        #expect(settings.screenMemoryEnabled)
        #expect(keyboard.object(forKey: "ScreenMemoryEnabled") as? Bool == true)
        settings.screenMemoryEnabled = false
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

    // MARK: - Screen Memory dev-mode flag

    private func makeAppDefaults() -> UserDefaults {
        let suiteName = "tilde.tests.app.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Absent everywhere: dev mode reads off")
    func devModeOffByDefault() {
        let appDefaults = makeAppDefaults()
        #expect(!TildeSettings.screenMemoryDevModeEnabled(environment: [:], appDefaults: appDefaults))
    }

    @Test("TILDE_SCREEN_MEMORY_DEV=1 in the environment turns dev mode on")
    func devModeOnViaEnvironment() {
        let appDefaults = makeAppDefaults()
        #expect(TildeSettings.screenMemoryDevModeEnabled(
            environment: ["TILDE_SCREEN_MEMORY_DEV": "1"],
            appDefaults: appDefaults
        ))
    }

    @Test("Any other environment value does not turn dev mode on")
    func devModeEnvironmentRequiresExactlyOne() {
        let appDefaults = makeAppDefaults()
        #expect(!TildeSettings.screenMemoryDevModeEnabled(
            environment: ["TILDE_SCREEN_MEMORY_DEV": "true"],
            appDefaults: appDefaults
        ))
        #expect(!TildeSettings.screenMemoryDevModeEnabled(
            environment: ["TILDE_SCREEN_MEMORY_DEV": "0"],
            appDefaults: appDefaults
        ))
    }

    /// The regression this exists to fix: `defaults write bar.r3d.tilde
    /// ScreenMemoryDevMode -bool true` must turn dev mode on with NO
    /// environment variable at all — a Finder/Dock/LaunchServices launch
    /// inherits no shell environment, so the env-var-only check left the
    /// dev flag unreachable outside a Terminal-launched run.
    @Test("ScreenMemoryDevMode=true in the app's own UserDefaults suite turns dev mode on, with no environment variable set")
    func devModeOnViaUserDefaults() {
        let appDefaults = makeAppDefaults()
        appDefaults.set(true, forKey: TildeSettings.screenMemoryDevModeDefaultsKey)
        #expect(TildeSettings.screenMemoryDevModeEnabled(environment: [:], appDefaults: appDefaults))
    }

    @Test("Either signal is sufficient: UserDefaults true with the environment variable absent, or vice versa")
    func devModeEitherSignalSuffices() {
        let envOnly = makeAppDefaults()
        #expect(TildeSettings.screenMemoryDevModeEnabled(
            environment: ["TILDE_SCREEN_MEMORY_DEV": "1"],
            appDefaults: envOnly
        ))

        let defaultsOnly = makeAppDefaults()
        defaultsOnly.set(true, forKey: TildeSettings.screenMemoryDevModeDefaultsKey)
        #expect(TildeSettings.screenMemoryDevModeEnabled(environment: [:], appDefaults: defaultsOnly))
    }

    @Test("ScreenMemoryDevMode explicitly false, with no environment variable, reads off")
    func devModeExplicitlyOff() {
        let appDefaults = makeAppDefaults()
        appDefaults.set(false, forKey: TildeSettings.screenMemoryDevModeDefaultsKey)
        #expect(!TildeSettings.screenMemoryDevModeEnabled(environment: [:], appDefaults: appDefaults))
    }

}
