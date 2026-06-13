import Testing
@testable import AutocompleteLabCore

@Suite("App compatibility profile")
struct AppCompatibilityProfileTests {
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
        #expect(registry.profile(for: "notion.id").id == "notion-blocked")
        #expect(registry.profile(for: "com.apple.finder").id == "apple-search-fields")
        #expect(registry.profile(for: "com.apple.MobileSMS").id == "apple-messaging")
        #expect(registry.profile(for: "ru.keepcoder.Telegram").id == "chat-app")
        #expect(registry.profile(for: "com.tinyspeck.slackmacgap").id == "slack-blocked")
        #expect(registry.profile(for: "com.hnc.Discord").id == "discord-blocked")
        #expect(registry.profile(for: "com.hnc.DiscordPTB").id == "discord-blocked")
        #expect(registry.profile(for: "com.hnc.DiscordCanary").id == "discord-blocked")
        #expect(registry.profile(for: "com.microsoft.VSCode").id == "electron-editor")
        #expect(registry.profile(for: "com.googlecode.iterm2").id == "terminal")
    }

    @Test("High-value unproven collaboration apps stay blocked at the routing layer")
    func highValueUnprovenCollaborationAppsStayBlocked() {
        let registry = AppCompatibilityRegistry.default
        let blockedProfiles = [
            registry.profile(for: "notion.id"),
            registry.profile(for: "com.tinyspeck.slackmacgap"),
            registry.profile(for: "com.hnc.Discord")
        ]

        for profile in blockedProfiles {
            #expect(profile.defaultRung == .blocked)
            #expect(profile.textPath == .blocked)
            #expect(profile.acceptMode == .none)
        }
    }

    @Test("Falls back for unknown apps")
    func fallsBackForUnknownApps() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "example.unknown.Writer").id == "fallback")
        #expect(registry.profile(for: "example.unknown.Writer").defaultRung == .blocked)
        #expect(registry.profile(for: "example.unknown.Writer").textPath == .blocked)
        #expect(registry.profile(for: nil).id == "fallback")
    }

    @Test("Default profiles do not use clipboard fallback acceptance")
    func defaultProfilesDoNotUseClipboardFallback() {
        let clipboardProfiles = AppCompatibilityRegistry.defaultProfiles
            .filter { $0.acceptMode == .clipboardFallback }

        #expect(clipboardProfiles.isEmpty)
    }
}
