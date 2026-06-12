import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@MainActor
@Suite("App settings")
struct AppSettingsTests {
    @Test("Defaults are local first and open to normal apps")
    func defaultsAreLocalFirstAndOpenToNormalApps() {
        let settings = AppSettings(defaults: isolatedDefaults())

        #expect(settings.suggestionsEnabled)
        #expect(!settings.enforceAllowlist)
        #expect(settings.suppressSecureFields)
        #expect(settings.suppressShortText)
        #expect(settings.suppressAfterNewline)
        #expect(settings.runtimeMode == .appOwnedLocalModel)
        #expect(settings.minimumCharacters == 3)
        #expect(!settings.personalCaptureEnabled)
        #expect(settings.runtimeMode.menuTitle == "App-Owned Local Model")
    }

    @Test("Toggles and clamping flow into privacy settings")
    func togglesAndClampingFlowIntoPrivacySettings() {
        let settings = AppSettings(defaults: isolatedDefaults())

        settings.toggleAllowlist()
        settings.toggleSecureFieldSuppression()
        settings.toggleShortTextSuppression()
        settings.toggleAfterNewlineSuppression()
        settings.togglePersonalCapture()
        settings.minimumCharacters = 0
        settings.runtimeMode = .appOwnedLocalModel

        let privacy = settings.privacySettings(allowedBundleIdentifiers: ["com.apple.TextEdit"])
        let routing = settings.compatibilityRoutingSettings()

        #expect(settings.enforceAllowlist)
        #expect(!settings.suppressSecureFields)
        #expect(!settings.suppressShortText)
        #expect(!settings.suppressAfterNewline)
        #expect(settings.personalCaptureEnabled)
        #expect(settings.minimumCharacters == 1)
        #expect(settings.runtimeMode == .appOwnedLocalModel)
        #expect(settings.runtimeMode.menuTitle == "App-Owned Local Model")
        #expect(privacy.isAppAllowlistEnabled)
        #expect(privacy.minimumCharactersBeforeSuggestion == 1)
        #expect(!privacy.suppressEmptyText)
        #expect(!privacy.suppressImmediatelyAfterNewline)
        #expect(routing.enforceKnownApps)
        #expect(!routing.suppressSecureFields)
        #expect(routing.minimumCharactersBeforeSuggestion == 1)
    }

    @Test("Allowlist scope keeps universal fallback opt-in")
    func allowlistScopeKeepsUniversalFallbackOptIn() {
        let store = CompatibilityProfileStore.mvp

        #expect(AppDelegate.allowsProfileLookup(
            for: "com.apple.TextEdit",
            profileStore: store,
            enforceAllowlist: true
        ))
        #expect(!AppDelegate.allowsProfileLookup(
            for: "com.example.UnknownEditor",
            profileStore: store,
            enforceAllowlist: true
        ))
        #expect(AppDelegate.allowsProfileLookup(
            for: "com.example.UnknownEditor",
            profileStore: store,
            enforceAllowlist: false
        ))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AutocompleteLabAppTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
