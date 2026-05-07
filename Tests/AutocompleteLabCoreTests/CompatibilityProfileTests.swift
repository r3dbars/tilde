import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility profiles")
struct CompatibilityProfileTests {
    @Test("MVP target apps are explicitly profiled")
    func targetAppsAreProfiled() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.profile(for: "com.apple.TextEdit")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.apple.TextEdit")?.supportLevel == .green)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.apple.Notes")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.apple.Notes")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.apple.Notes")?.fallbackInsertionMode == .disabled)
        #expect(store.profile(for: "com.apple.Notes")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "md.obsidian")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "md.obsidian")?.supportLevel == .yellow)
        #expect(store.profile(for: "md.obsidian")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "md.obsidian")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "md.obsidian")?.suppressesAfterInsertionFailure == false)
        #expect(store.profile(for: "md.obsidian")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "md.obsidian")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.apple.mail")?.displayName == "Mail")
        #expect(store.profile(for: "com.apple.mail")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.apple.mail")?.renderMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fallbackInsertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.apple.mail")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "com.apple.mail")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.google.Chrome")?.displayName == "Chrome")
        #expect(store.profile(for: "com.google.Chrome")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.google.Chrome")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.google.Chrome")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.openai.codex")?.displayName == "Codex")
        #expect(store.profile(for: "com.openai.codex")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.openai.codex")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.openai.codex")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.openai.codex")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.openai.codex")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "com.openai.codex")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.openai.codex")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.displayName == "Claude Code")
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.anthropic.claude-code")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claude-code")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackInsertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportsOneWordAcceptance == true)
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportsFullAcceptance == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.canPresentSuggestions == true)
        #expect(store.profile(for: "com.anthropic.claude-code")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.displayName == "Claude")
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fallbackInsertionMode == nil)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.allowsDetachedSuggestions == false)
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
        #expect(store.supportStatus(for: "com.apple.TextEdit").summary == "green: TextEdit")
        #expect(store.supportStatus(for: "com.apple.mail").summary == "diagnostics only: Mail")
    }

    @Test("Support status exposes user-facing stance copy")
    func supportStatusExposesUserFacingStanceCopy() {
        let store = CompatibilityProfileStore.mvp

        let green = store.supportStatus(for: "com.apple.TextEdit")
        #expect(green.supportLevel == .green)
        #expect(green.userFacingSummary == "Green: TextEdit")
        #expect(green.userFacingReason == "Verified inline suggestions and native text insertion.")
        #expect(green.menuText(appDisplayName: "TextEdit", isEnabled: true) == "TextEdit green on")
        #expect(green.canToggleSuggestions)

        let yellow = store.supportStatus(for: "com.apple.Notes")
        #expect(yellow.supportLevel == .yellow)
        #expect(yellow.userFacingSummary == "Yellow: Notes")
        #expect(
            yellow.userFacingReason
                == "Rich text can drift; display can fall back to floating, and insertion fails closed."
        )
        #expect(yellow.menuText(appDisplayName: "Notes", isEnabled: false) == "Notes yellow off")
        #expect(yellow.canToggleSuggestions)

        let diagnosticsOnly = store.supportStatus(for: "com.apple.mail")
        #expect(diagnosticsOnly.supportLevel == .diagnosticsOnly)
        #expect(diagnosticsOnly.userFacingSummary == "Diagnostics-only: Mail")
        #expect(diagnosticsOnly.menuText(appDisplayName: "Mail", isEnabled: true) == "Mail diagnostics-only")
        #expect(!diagnosticsOnly.canToggleSuggestions)

        let unsupported = store.supportStatus(for: "com.openai.atlas")
        #expect(unsupported.supportLevel == .unsupported)
        #expect(unsupported.userFacingSummary == "Unsupported: not tested yet")
        #expect(unsupported.userFacingReason == "No compatibility profile yet.")
        #expect(unsupported.menuText(appDisplayName: "Atlas", isEnabled: true) == "Atlas unsupported")
        #expect(!unsupported.canToggleSuggestions)
    }

    @Test("Profiles expose debug summaries with primary and fallback paths")
    func profilesExposeDebugSummaries() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(profile.debugSummary.contains("primary render=inlineAdjacent"))
        #expect(profile.debugSummary.contains("insert=keyEvents"))
        #expect(profile.debugSummary.contains("fallback render=floatingMirror"))
        #expect(profile.debugSummary.contains("insert=axValueReplacement"))
        #expect(profile.debugSummary.contains("field=accessibilityElement"))
    }

    @Test("Insertion mode plans try primary then safe fallback")
    func insertionModePlansTryPrimaryThenFallback() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
        let claude = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(InsertionModePlan.modes(for: textEdit) == [.axSelectedText, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: notes) == [.keyEvents])
        #expect(InsertionModePlan.modes(for: chrome) == [.keyEvents, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: codex) == [.axValueReplacement, .keyEvents])
        #expect(InsertionModePlan.modes(for: claudeCode) == [.keyEvents, .axThenKeyEvents])
        #expect(InsertionModePlan.modes(for: claude) == [.axValueReplacement])
        #expect(InsertionModePlan.modes(for: mail) == [])
    }

    @Test("Unproven real app profiles fail closed on risky affordances")
    func unprovenRealAppProfilesFailClosedOnRiskyAffordances() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))

        #expect(notes.allowsDetachedSuggestions == false)
        #expect(notes.fallbackInsertionMode == .disabled)
        #expect(claudeCode.supportsOneWordAcceptance == true)
        #expect(claudeCode.supportsFullAcceptance == false)
        #expect(claudeCode.canPresentSuggestions == true)
    }

    @Test("Insertion mode plans can skip failed primary modes")
    func insertionModePlansCanSkipFailedPrimaryModes() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(InsertionModePlan.modes(for: notes, skipping: [.keyEvents]) == [])
        #expect(InsertionModePlan.modes(for: chrome, skipping: [.keyEvents]) == [.axValueReplacement])
        #expect(InsertionModePlan.modes(for: chrome, skipping: [.keyEvents, .axValueReplacement]) == [])
    }

    @Test("Notes insertion fails closed to avoid rich text cursor drift")
    func notesInsertionFailsClosed() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))

        #expect(notes.insertionMode == .keyEvents)
        #expect(notes.fallbackInsertionMode == .disabled)
        #expect(InsertionModePlan.modes(for: notes) == [.keyEvents])
        #expect(InsertionModePlan.modes(for: notes, skipping: [.keyEvents]) == [])
    }

    @Test("Render mode plans fall back to mirror when inline bounds are unavailable")
    func renderModePlansFallbackToMirrorWhenInlineBoundsAreUnavailable() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
        let claude = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop"))
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
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
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
            for: claude,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
        #expect(RenderModePlan.effectiveMode(
            for: claude,
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
