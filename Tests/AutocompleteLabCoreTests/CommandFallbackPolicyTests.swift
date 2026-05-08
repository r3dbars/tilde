import Testing
@testable import AutocompleteLabCore

@Suite("Command fallback policy")
struct CommandFallbackPolicyTests {
    @Test("green enabled apps use inline instead of command fallback")
    func greenEnabledAppsUseInlineInsteadOfCommandFallback() {
        let store = CompatibilityProfileStore.mvp
        let decision = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true
        )

        #expect(decision.availability == .inlineAvailable)
        #expect(decision.reason == .inlineAvailable)
        #expect(!decision.canCopyOnly)
        #expect(decision.statusText == "Fallback: not needed; inline is available.")
    }

    @Test("disabled and unsupported apps do not offer fallback helpers")
    func disabledAndUnsupportedAppsDoNotOfferFallbackHelpers() {
        let store = CompatibilityProfileStore.mvp
        let disabled = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: false
        )
        let unsupported = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.openai.atlas"),
            isEnabled: true
        )

        #expect(disabled.availability == .unavailable)
        #expect(disabled.reason == .appDisabled)
        #expect(disabled.statusText == "Fallback: off because this app is disabled.")
        #expect(unsupported.availability == .unavailable)
        #expect(unsupported.reason == .unsupportedApp)
        #expect(unsupported.statusText == "Fallback: unavailable until this app has a profile.")
    }

    @Test("sensitive apps and fields do not offer copy-only fallback")
    func sensitiveAppsAndFieldsDoNotOfferCopyOnlyFallback() {
        let store = CompatibilityProfileStore.mvp
        let mail = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.mail"),
            isEnabled: true
        )
        let searchField = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            fieldKind: .search
        )

        #expect(mail.availability == .unavailable)
        #expect(mail.reason == .sensitiveApp)
        #expect(mail.statusText == "Fallback: unavailable in sensitive apps or fields.")
        #expect(searchField.availability == .unavailable)
        #expect(searchField.reason == .sensitiveField)
        #expect(searchField.statusText == "Fallback: unavailable in sensitive apps or fields.")
    }

    @Test("non-sensitive diagnostics-only profiles can offer copy-only fallback")
    func nonSensitiveDiagnosticsOnlyProfilesCanOfferCopyOnlyFallback() {
        let store = CompatibilityProfileStore.mvp
        let safari = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.Safari"),
            isEnabled: true
        )

        #expect(safari.availability == .copyOnly)
        #expect(safari.reason == .diagnosticsOnlyProfile)
        #expect(safari.canCopyOnly)
        #expect(safari.statusText == "Fallback: copy-only; inline and auto-insert stay off until proof passes.")
    }

    @Test("yellow low-confidence placement falls back to copy-only")
    func yellowLowConfidencePlacementFallsBackToCopyOnly() {
        let store = CompatibilityProfileStore.mvp
        let chrome = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.google.Chrome"),
            isEnabled: true,
            allowsLowConfidencePlacement: false
        )

        #expect(chrome.availability == .copyOnly)
        #expect(chrome.reason == .untrustedPlacement)
        #expect(chrome.canCopyOnly)
        #expect(
            chrome.detailText
                == "When placement is untrusted, the app can fall back to copy-only instead of showing detached ghost text."
        )
    }
}
