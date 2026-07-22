import Testing
@testable import AutocompleteLabCore

// Locks the invariants recorded in docs/product/adr/0001-breadth-vs-depth.md.
//
// ADR-0001 decided that generic / broad autocomplete support is ON (as of
// 2026-06-13): apps with no custom profile fall through to the default-on
// generic fallback profile, and routing does not restrict itself to a
// known-apps allowlist. That breadth is only legitimate because a fixed set of
// safety guardrails holds REGARDLESS of breadth. This suite fails loudly if a
// future change flips the decision, or relaxes a guardrail, without first
// updating the ADR.
//
// If you are here because this suite failed: do not weaken the assertions to go
// green. Either you did not mean to change the covenant (revert), or you did —
// in which case supersede ADR-0001 and update this suite in the same change.
@Suite("ADR-0001 breadth vs depth invariants")
struct BreadthVsDepthADRTests {

    // MARK: Decision — broad support is ON

    @Test("Unprofiled apps resolve to the default-on generic fallback (broad support ON)")
    func unprofiledAppsResolveToDefaultOnFallback() throws {
        let store = CompatibilityProfileStore.mvp
        let profile = try #require(store.profile(for: "com.example.some-unprofiled-app"))

        // Identity of the broad-support profile.
        #expect(profile.displayName == "Generic App")

        // The decision of record: unprofiled apps can request, show, and accept
        // suggestions over the native Accessibility path — they are not rejected
        // as unsupported.
        #expect(profile.canPresentSuggestions)
        #expect(profile.supportsOneWordAcceptance)
        #expect(store.allows(bundleIdentifier: "com.example.some-unprofiled-app"))
    }

    // MARK: Guardrails — always on, regardless of breadth

    @Test("Sensitive apps stay denylisted regardless of breadth")
    func sensitiveAppsStayDenylisted() {
        let store = CompatibilityProfileStore.mvp

        // Password managers, system settings, and terminal emulators never fall
        // through to the generic rung.
        for bundleIdentifier in [
            "com.1password.1password",
            "com.apple.systemsettings",
            "com.apple.Terminal"
        ] {
            #expect(store.supportStatus(for: bundleIdentifier) == .denylisted)
            #expect(!store.allows(bundleIdentifier: bundleIdentifier))
        }
    }

    @Test("Guardrails win over breadth: secure fields are hard-blocked")
    func guardrailsWinOverBreadthForSecureFields() {
        // Even on the generic fallback rung, a secure field is blocked before
        // any suggestion is requested.
        let decision = CompletionActivationPolicy().decision(
            textBeforeCursor: "Hello there friend",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false
        )

        #expect(decision == .block(.secureField))
        #expect(!decision.canSuggest)
    }

    @Test("Send surfaces are never treated as not-a-prompt")
    func sendSurfacesAreNeverTreatedAsNotPrompt() throws {
        // Messages / Slack / Discord are sendable surfaces: Return can submit, so
        // they must never be downgraded to `.notPrompt` (the relaxed,
        // not-a-prompt-surface mode). They may be `.disabled`, `.clickOnly`, or
        // `.wordOnly` — anything except `.notPrompt`.
        let sendSurfaceBundleIdentifiers = [
            "com.apple.MobileSMS",       // Messages
            "com.tinyspeck.slackmacgap", // Slack
            "com.hnc.Discord"            // Discord
        ]

        let profiles = CompatibilityProfileStore.mvp.profiles

        for bundleIdentifier in sendSurfaceBundleIdentifiers {
            let profile = try #require(profiles[bundleIdentifier])
            #expect(profile.promptAppSafetyMode != .notPrompt)
            #expect(profile.promptAppSafetyMode.isPromptSurface)
        }
    }
}
