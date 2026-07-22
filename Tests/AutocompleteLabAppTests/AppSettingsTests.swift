import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("App settings")
struct AppSettingsTests {
    @Test("Defaults are local first and default on")
    func defaultsAreLocalFirstAndDefaultOn() {
        let settings = AppSettings(defaults: isolatedDefaults())

        #expect(settings.suggestionsEnabled)
        #expect(settings.runtimeMode == .appOwnedLocalModel)
        #expect(settings.runtimeMode.menuTitle == "App-Owned Local Model")
    }

    @Test("Toggles flip and persist")
    func togglesFlipAndPersist() {
        let settings = AppSettings(defaults: isolatedDefaults())

        settings.toggleSuggestionsEnabled()
        settings.runtimeMode = .appOwnedLocalModel

        #expect(!settings.suggestionsEnabled)
        #expect(settings.runtimeMode == .appOwnedLocalModel)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AutocompleteLabAppTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
