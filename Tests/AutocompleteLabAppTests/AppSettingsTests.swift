import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("App settings")
struct AppSettingsTests {
    @Test("Defaults are local first and allowlisted")
    func defaultsAreLocalFirstAndAllowlisted() {
        let settings = AppSettings(defaults: isolatedDefaults())

        #expect(settings.suggestionsEnabled)
        #expect(settings.enforceAllowlist)
        #expect(settings.suppressSecureFields)
        #expect(settings.suppressShortText)
        #expect(settings.suppressAfterNewline)
        #expect(settings.runtimeMode == .gemmaLocalWithMockFallback)
        #expect(settings.minimumCharacters == 3)
        #expect(settings.runtimeMode.menuTitle == "Gemma 4 E2B + Mock Fallback")
    }

    @Test("Toggles and clamping flow into privacy settings")
    func togglesAndClampingFlowIntoPrivacySettings() {
        let settings = AppSettings(defaults: isolatedDefaults())

        settings.toggleAllowlist()
        settings.toggleSecureFieldSuppression()
        settings.toggleShortTextSuppression()
        settings.toggleAfterNewlineSuppression()
        settings.minimumCharacters = 0
        settings.runtimeMode = .mockOnly

        let privacy = settings.privacySettings(allowedBundleIdentifiers: ["com.apple.TextEdit"])
        let routing = settings.compatibilityRoutingSettings()

        #expect(!settings.enforceAllowlist)
        #expect(!settings.suppressSecureFields)
        #expect(!settings.suppressShortText)
        #expect(!settings.suppressAfterNewline)
        #expect(settings.minimumCharacters == 1)
        #expect(settings.runtimeMode == .mockOnly)
        #expect(settings.runtimeMode.menuTitle == "Mock Suggestions Only")
        #expect(!privacy.isAppAllowlistEnabled)
        #expect(privacy.minimumCharactersBeforeSuggestion == 1)
        #expect(!privacy.suppressEmptyText)
        #expect(!privacy.suppressImmediatelyAfterNewline)
        #expect(!routing.enforceKnownApps)
        #expect(!routing.suppressSecureFields)
        #expect(routing.minimumCharactersBeforeSuggestion == 1)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AutocompleteLabAppTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
