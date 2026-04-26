import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility profiles")
struct CompatibilityProfileTests {
    @Test("MVP target apps are explicitly profiled")
    func targetAppsAreProfiled() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.profile(for: "com.apple.TextEdit")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.apple.Notes")?.insertionMode == .axSelectedText)
        #expect(store.profile(for: "com.apple.Notes")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "md.obsidian")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "md.obsidian")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "md.obsidian")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "md.obsidian")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.apple.mail")?.displayName == "Mail")
        #expect(store.profile(for: "com.apple.mail")?.renderMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fallbackInsertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.apple.mail")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "com.apple.mail")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.google.Chrome")?.displayName == "Chrome")
        #expect(store.profile(for: "com.google.Chrome")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "com.google.Chrome")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackInsertionMode == .keyEvents)
    }

    @Test("Denylisted apps are never allowed")
    func denylistedAppsAreBlocked() {
        let store = CompatibilityProfileStore.mvp

        #expect(!store.allows(bundleIdentifier: "com.apple.Terminal"))
        #expect(!store.allows(bundleIdentifier: "com.1password.1password"))
    }

    @Test("Unknown apps are not globally enabled during the MVP")
    func unknownAppsAreNotEnabled() {
        let store = CompatibilityProfileStore.mvp

        #expect(!store.allows(bundleIdentifier: "com.example.UnknownEditor"))
        #expect(!store.allows(bundleIdentifier: "com.openai.atlas"))
    }

    @Test("Support status explains unsupported and denylisted apps")
    func supportStatusExplainsBlockedApps() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.supportStatus(for: "com.apple.Terminal") == .denylisted)
        #expect(store.supportStatus(for: "com.openai.atlas") == .unsupported)
        #expect(store.supportStatus(for: "com.apple.TextEdit").summary == "supported: TextEdit")
        #expect(store.supportStatus(for: "com.apple.mail").summary == "diagnostics only: Mail")
    }

    @Test("Profiles expose debug summaries with primary and fallback paths")
    func profilesExposeDebugSummaries() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(profile.debugSummary.contains("primary render=floatingMirror"))
        #expect(profile.debugSummary.contains("insert=axValueReplacement"))
        #expect(profile.debugSummary.contains("fallback render=floatingMirror"))
        #expect(profile.debugSummary.contains("insert=keyEvents"))
        #expect(profile.debugSummary.contains("field=accessibilityElement"))
    }

    @Test("Insertion mode plans try primary then safe fallback")
    func insertionModePlansTryPrimaryThenFallback() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(InsertionModePlan.modes(for: textEdit) == [.axSelectedText, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: chrome) == [.axValueReplacement, .keyEvents])
        #expect(InsertionModePlan.modes(for: mail) == [])
    }

    @Test("Render mode plans fall back to mirror when inline bounds are unavailable")
    func renderModePlansFallbackToMirrorWhenInlineBoundsAreUnavailable() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(RenderModePlan.effectiveMode(
            for: textEdit,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
        #expect(RenderModePlan.effectiveMode(
            for: textEdit,
            supportsInlineSuggestions: false,
            hasMirrorAnchor: true
        ) == .floatingMirror)
        #expect(RenderModePlan.effectiveMode(
            for: chrome,
            supportsInlineSuggestions: false,
            hasMirrorAnchor: true
        ) == .floatingMirror)
        #expect(RenderModePlan.effectiveMode(
            for: mail,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == nil)
    }
}
