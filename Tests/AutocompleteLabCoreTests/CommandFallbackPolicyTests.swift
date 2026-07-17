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
        #expect(decision.statusText == "Fallback: not needed; cursor placement is available.")
    }

    @Test("disabled apps pause fallback and unknown apps use inline")
    func disabledAppsPauseFallbackAndUnknownAppsUseInline() {
        let store = CompatibilityProfileStore.mvp
        let disabled = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: false
        )
        let unsupported = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.example.UnknownEditor"),
            isEnabled: true
        )

        #expect(disabled.availability == .unavailable)
        #expect(disabled.reason == .appDisabled)
        #expect(disabled.statusText == "Fallback: off while this app is paused.")
        #expect(unsupported.availability == .inlineAvailable)
        #expect(unsupported.reason == .inlineAvailable)
        #expect(unsupported.statusText == "Fallback: not needed; cursor placement is available.")
    }

    @Test("newly enabled apps use inline while sensitive fields stay unavailable")
    func newlyEnabledAppsUseInlineWhileSensitiveFieldsStayUnavailable() {
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

        #expect(mail.availability == .inlineAvailable)
        #expect(mail.reason == .inlineAvailable)
        #expect(mail.statusText == "Fallback: not needed; cursor placement is available.")
        #expect(searchField.availability == .unavailable)
        #expect(searchField.reason == .sensitiveField)
        #expect(searchField.statusText == "Fallback: unavailable in sensitive apps or fields.")
    }

    @Test("newly enabled browser profiles use inline")
    func newlyEnabledBrowserProfilesUseInline() {
        let store = CompatibilityProfileStore.mvp
        let safari = CommandFallbackPolicy().decision(
            supportStatus: store.supportStatus(for: "com.apple.Safari"),
            isEnabled: true
        )

        #expect(safari.availability == .inlineAvailable)
        #expect(safari.reason == .inlineAvailable)
        #expect(!safari.canCopyOnly)
        #expect(safari.statusText == "Fallback: not needed; cursor placement is available.")
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
