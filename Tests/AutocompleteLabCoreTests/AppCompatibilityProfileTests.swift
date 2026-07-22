import Testing
@testable import AutocompleteLabCore

@Suite("App compatibility profile")
struct AppCompatibilityProfileTests {
    @Test("Fallback profile uses caret-only, unclipped placement")
    func fallbackProfileIsDefaultOn() {
        #expect(AppCompatibilityProfile.fallback.lineRectPolicy == .caretOnly)
        #expect(AppCompatibilityProfile.fallback.boundaryClipPolicy == .clipToFocusedTextElementWhenCaretInside)
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

    @Test("High-value unproven collaboration apps ignore the focused text element for placement")
    func highValueUnprovenCollaborationAppsIgnoreFocusedTextElement() {
        // These apps are actually blocked at the live gate (CompatibilityProfileStore,
        // exact bundle-id match, graduationDecision == .blocked) — this placement
        // registry only owns geometry tuning, so what it can meaningfully assert is
        // that these unreliable-AX targets don't try to clip placement to the
        // focused text element.
        let registry = AppCompatibilityRegistry.default
        let blockedProfiles = [
            registry.profile(for: "notion.id"),
            registry.profile(for: "com.tinyspeck.slackmacgap"),
            registry.profile(for: "com.hnc.Discord")
        ]

        for profile in blockedProfiles {
            #expect(profile.boundaryClipPolicy == .ignoreFocusedTextElement)
        }

        for bundleIdentifier in ["notion.id", "com.tinyspeck.slackmacgap", "com.hnc.Discord"] {
            #expect(CompatibilityProfileStore.mvp.profile(for: bundleIdentifier)?.graduationDecision == .blocked)
        }
    }

    @Test("Falls back for unknown apps")
    func fallsBackForUnknownApps() {
        let registry = AppCompatibilityRegistry.default

        #expect(registry.profile(for: "example.unknown.Writer").id == "fallback")
        #expect(registry.profile(for: "example.unknown.Writer").lineRectPolicy == .caretOnly)
        #expect(registry.profile(for: nil).id == "fallback")
    }
}
