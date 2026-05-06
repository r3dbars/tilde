import CoreGraphics
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
        #expect(store.profile(for: "com.apple.Notes")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.apple.Notes")?.fallbackInsertionMode == .axSelectedText)
        #expect(store.profile(for: "md.obsidian")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "md.obsidian")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "md.obsidian")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "md.obsidian")?.suppressesAfterInsertionFailure == false)
        #expect(store.profile(for: "md.obsidian")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "md.obsidian")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.apple.mail")?.displayName == "Mail")
        #expect(store.profile(for: "com.apple.mail")?.renderMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fallbackInsertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.apple.mail")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "com.apple.mail")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.google.Chrome")?.displayName == "Chrome")
        #expect(store.profile(for: "com.google.Chrome")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "com.google.Chrome")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.openai.codex")?.displayName == "Codex")
        #expect(store.profile(for: "com.openai.codex")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.openai.codex")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.openai.codex")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.openai.codex")?.fallbackInsertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.openai.codex")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.openai.codex")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.displayName == "Claude Code")
        #expect(store.profile(for: "com.anthropic.claude-code")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claude-code")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackInsertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.anthropic.claude-code")?.allowsDetachedSuggestions == false)
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
        #expect(profile.debugSummary.contains("insert=keyEvents"))
        #expect(profile.debugSummary.contains("fallback render=floatingMirror"))
        #expect(profile.debugSummary.contains("insert=axValueReplacement"))
        #expect(profile.debugSummary.contains("field=accessibilityElement"))
    }

    @Test("Insertion mode plans try primary then safe fallback")
    func insertionModePlansTryPrimaryThenFallback() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(InsertionModePlan.modes(for: textEdit) == [.axSelectedText, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: chrome) == [.keyEvents, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: codex) == [.keyEvents, .axThenKeyEvents])
        #expect(InsertionModePlan.modes(for: claudeCode) == [.keyEvents, .axThenKeyEvents])
        #expect(InsertionModePlan.modes(for: mail) == [])
    }

    @Test("Render mode plans fall back to mirror when inline bounds are unavailable")
    func renderModePlansFallbackToMirrorWhenInlineBoundsAreUnavailable() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
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
            for: codex,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
        #expect(RenderModePlan.effectiveMode(
            for: codex,
            supportsInlineSuggestions: false,
            hasMirrorAnchor: true
        ) == .floatingMirror)
        #expect(RenderModePlan.effectiveMode(
            for: claudeCode,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
        #expect(RenderModePlan.effectiveMode(
            for: claudeCode,
            supportsInlineSuggestions: false,
            hasMirrorAnchor: true
        ) == .floatingMirror)
        #expect(RenderModePlan.effectiveMode(
            for: mail,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == nil)
    }

    @Test("Render mode plans choose stable anchors for inline and mirror modes")
    func renderModePlansChooseStableAnchors() {
        let caret = CGRect(x: 10, y: 20, width: 0, height: 18)
        let element = CGRect(x: 8, y: 18, width: 240, height: 40)
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        #expect(RenderModePlan.anchorRect(
            for: .inlineAdjacent,
            caretRect: caret,
            elementRect: element,
            windowRect: window
        ) == caret)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: element,
            windowRect: window
        ) == element)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: nil,
            windowRect: window
        ) == window)
        #expect(RenderModePlan.anchorRect(
            for: .disabled,
            caretRect: caret,
            elementRect: element,
            windowRect: window
        ) == nil)
    }
}
