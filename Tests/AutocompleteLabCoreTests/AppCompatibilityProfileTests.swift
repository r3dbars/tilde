import Testing
@testable import AutocompleteLabCore

@Suite("App compatibility profile")
struct AppCompatibilityProfileTests {
    @Test("Fallback profile is default-on")
    func fallbackProfileIsDefaultOn() {
        #expect(AppCompatibilityProfile.fallback.defaultRung == .accept)
        #expect(AppCompatibilityProfile.fallback.textPath == .nativeAccessibility)
        #expect(AppCompatibilityProfile.fallback.acceptMode == .directAccessibility)
    }

    @Test("Selects known app profiles by bundle identifier")
    func selectsKnownProfiles() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "com.apple.TextEdit").id == "textedit")
        #expect(registry.profile(for: "com.apple.Notes").id == "notes")
        #expect(registry.profile(for: "com.apple.mail").id == "mail")
        #expect(registry.profile(for: "md.obsidian").id == "obsidian")
        #expect(registry.profile(for: "com.openai.codex").id == "openai-composer")
        #expect(registry.profile(for: "com.anthropic.claudefordesktop").id == "claude-desktop")
        #expect(registry.profile(for: "com.google.Chrome").id == "browser-composer")
        #expect(registry.profile(for: "notion.id").id == "notion")
        #expect(registry.profile(for: "com.apple.finder").id == "apple-search-fields")
        #expect(registry.profile(for: "com.apple.MobileSMS").id == "apple-messaging")
        #expect(registry.profile(for: "ru.keepcoder.Telegram").id == "chat-app")
        #expect(registry.profile(for: "com.tinyspeck.slackmacgap").id == "slack")
        #expect(registry.profile(for: "com.hnc.Discord").id == "discord")
        #expect(registry.profile(for: "com.hnc.DiscordPTB").id == "discord")
        #expect(registry.profile(for: "com.hnc.DiscordCanary").id == "discord")
        #expect(registry.profile(for: "com.microsoft.VSCode").id == "electron-editor")
        #expect(registry.profile(for: "com.googlecode.iterm2").id == "terminal")
    }

    @Test("High-value collaboration apps use the experimental Accessibility path")
    func highValueCollaborationAppsUseExperimentalAccessibility() {
        let registry = AppCompatibilityRegistry.default
        let enabledProfiles = [
            registry.profile(for: "notion.id"),
            registry.profile(for: "com.tinyspeck.slackmacgap"),
            registry.profile(for: "com.hnc.Discord")
        ]

        for profile in enabledProfiles {
            #expect(profile.defaultRung == .accept)
            #expect(profile.textPath == .nativeAccessibility)
            #expect(profile.acceptMode == .directAccessibility)
        }
    }

    @Test("Falls back for unknown apps")
    func fallsBackForUnknownApps() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "example.unknown.Writer").id == "fallback")
        #expect(registry.profile(for: "example.unknown.Writer").defaultRung == .accept)
        #expect(registry.profile(for: "example.unknown.Writer").textPath == .nativeAccessibility)
        #expect(registry.profile(for: nil).id == "fallback")
    }

    @Test("Default profiles do not use clipboard fallback acceptance")
    func defaultProfilesDoNotUseClipboardFallback() {
        let clipboardProfiles = AppCompatibilityRegistry.defaultProfiles
            .filter { $0.acceptMode == .clipboardFallback }

        #expect(clipboardProfiles.isEmpty)
    }
}
