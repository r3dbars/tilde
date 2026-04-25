import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility profiles")
struct CompatibilityProfileTests {
    @Test("MVP target apps are explicitly profiled")
    func targetAppsAreProfiled() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.profile(for: "com.apple.TextEdit")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.apple.Notes")?.insertionMode == .axSelectedText)
        #expect(store.profile(for: "md.obsidian")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "md.obsidian")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.apple.mail")?.displayName == "Mail")
        #expect(store.profile(for: "com.apple.mail")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.apple.mail")?.allowsDescendantTextFallback == true)
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
    }
}
