import Testing
@testable import AutocompleteLabCore

@Suite("App compatibility profile")
struct AppCompatibilityProfileTests {
    @Test("Selects known app profiles by bundle identifier")
    func selectsKnownProfiles() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "com.apple.TextEdit").id == "textedit")
        #expect(registry.profile(for: "com.apple.Notes").id == "notes")
        #expect(registry.profile(for: "com.openai.codex").id == "openai-composer")
        #expect(registry.profile(for: "com.google.Chrome").id == "browser-composer")
        #expect(registry.profile(for: "md.obsidian").id == "electron-editor")
    }

    @Test("Falls back for unknown apps")
    func fallsBackForUnknownApps() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "example.unknown.Writer").id == "fallback")
        #expect(registry.profile(for: nil).id == "fallback")
    }
}
