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

}
