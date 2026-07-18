import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility profiles")
struct CompatibilityProfileTests {
    @Test("MVP target apps are explicitly profiled")
    func targetAppsAreProfiled() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.profile(for: "com.apple.TextEdit")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.apple.TextEdit")?.appFamily == .nativeAppKit)
        #expect(store.profile(for: "com.apple.TextEdit")?.supportLevel == .green)
        #expect(store.profile(for: "com.apple.TextEdit")?.graduationDecision == .supported)
        #expect(store.profile(for: "com.apple.TextEdit")?.supportsObserverUpdates == true)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.apple.TextEdit")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.apple.Notes")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.apple.Notes")?.appFamily == .swiftUIAppKit)
        #expect(store.profile(for: "com.apple.Notes")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.apple.Notes")?.graduationDecision == .supported)
        #expect(store.profile(for: "com.apple.Notes")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "com.apple.Notes")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "md.obsidian")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "md.obsidian")?.appFamily == .electron)
        #expect(store.profile(for: "md.obsidian")?.anchorLadder == [.caret])
        #expect(store.profile(for: "md.obsidian")?.supportLevel == .yellow)
        #expect(store.profile(for: "md.obsidian")?.graduationDecision == .supported)
        #expect(store.profile(for: "md.obsidian")?.insertionMode == .keyEvents)
        #expect(store.profile(for: "md.obsidian")?.fallbackRenderMode == nil)
        #expect(store.profile(for: "md.obsidian")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "md.obsidian")?.suppressesAfterInsertionFailure == false)
        #expect(store.profile(for: "md.obsidian")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "md.obsidian")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "md.obsidian")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "md.obsidian")?.allowsSyntheticCaretPlacement == true)
        #expect(store.profile(for: "com.apple.mail")?.displayName == "Mail")
        #expect(store.profile(for: "com.apple.mail")?.anchorLadder == [.none])
        #expect(store.profile(for: "com.apple.mail")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.apple.mail")?.graduationDecision == .diagnosticsOnly)
        #expect(store.profile(for: "com.apple.mail")?.renderMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fallbackInsertionMode == .disabled)
        #expect(store.profile(for: "com.apple.mail")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.apple.mail")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "com.apple.mail")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.apple.MobileSMS")?.displayName == "Messages")
        #expect(store.profile(for: "com.apple.MobileSMS")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.apple.MobileSMS")?.graduationDecision == .wordOnly)
        #expect(store.profile(for: "com.apple.MobileSMS")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "com.apple.MobileSMS")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.apple.MobileSMS")?.supportsOneWordAcceptance == true)
        #expect(store.profile(for: "com.apple.MobileSMS")?.supportsFullAcceptance == false)
        #expect(store.profile(for: "com.apple.MobileSMS")?.requiresNoSubmitAcceptanceProof == true)
        #expect(store.profile(for: "com.apple.MobileSMS")?.promptAppSafetyMode == .wordOnly)
        #expect(store.profile(for: "com.openai.atlas")?.displayName == "ChatGPT Atlas")
        #expect(store.profile(for: "com.openai.atlas")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.openai.atlas")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.openai.atlas")?.renderMode == .disabled)
        #expect(store.profile(for: "com.openai.atlas")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.openai.atlas")?.supportsOneWordAcceptance == false)
        #expect(store.profile(for: "com.openai.atlas")?.supportsFullAcceptance == false)
        #expect(store.profile(for: "com.openai.atlas")?.isSensitive == true)
        #expect(store.profile(for: "com.openai.atlas")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "com.openai.atlas")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.openai.chat")?.displayName == "ChatGPT")
        #expect(store.profile(for: "com.openai.chat")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.openai.chat")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.openai.chat")?.renderMode == .disabled)
        #expect(store.profile(for: "com.openai.chat")?.insertionMode == .disabled)
        #expect(store.profile(for: "com.openai.chat")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "com.openai.ChatGPT")?.displayName == "ChatGPT")
        #expect(store.profile(for: "com.openai.ChatGPT")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.openai.ChatGPT")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "com.google.Chrome")?.displayName == "Chrome")
        #expect(store.profile(for: "com.google.Chrome")?.appFamily == .chromium)
        #expect(store.profile(for: "com.google.Chrome")?.anchorLadder == [.caret, .field])
        #expect(store.profile(for: "com.google.Chrome")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.google.Chrome")?.graduationDecision == .supported)
        #expect(store.profile(for: "com.google.Chrome")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.google.Chrome")?.insertionMode == .axThenKeyEvents)
        #expect(store.profile(for: "com.google.Chrome")?.fallbackInsertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.google.Chrome")?.allowsDescendantTextFallback == true)
        #expect(store.profile(for: "com.google.Chrome")?.allowsSyntheticCaretPlacement == false)
        #expect(store.profile(for: "com.openai.codex")?.displayName == "Codex")
        #expect(store.profile(for: "com.openai.codex")?.appFamily == .customCanvas)
        #expect(store.profile(for: "com.openai.codex")?.allowsFieldAnchor == false)
        #expect(store.profile(for: "com.openai.codex")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.openai.codex")?.graduationDecision == .supported)
        #expect(store.profile(for: "com.openai.codex")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.openai.codex")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.openai.codex")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.openai.codex")?.fallbackInsertionMode == nil)
        #expect(store.profile(for: "com.openai.codex")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.openai.codex")?.anchorLadder == [.caret])
        #expect(store.profile(for: "com.openai.codex")?.supportsOneWordAcceptance == true)
        #expect(store.profile(for: "com.openai.codex")?.supportsFullAcceptance == true)
        #expect(store.profile(for: "com.openai.codex")?.requiresNoSubmitAcceptanceProof == false)
        #expect(store.profile(for: "com.openai.codex")?.canPresentSuggestions == true)
        #expect(store.profile(for: "com.openai.codex")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.openai.codex")?.isSensitive == false)
        #expect(store.profile(for: "com.openai.codex")?.promptAppSafetyMode == .wordOnly)
        #expect(store.profile(for: "com.anthropic.claude-code")?.displayName == "Claude Code")
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.anthropic.claude-code")?.graduationDecision == .wordOnly)
        #expect(store.profile(for: "com.anthropic.claude-code")?.renderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claude-code")?.insertionMode == .clipboardFallbackOptIn)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fallbackInsertionMode == .keyEvents)
        #expect(store.profile(for: "com.anthropic.claude-code")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.anthropic.claude-code")?.anchorLadder == [.caret])
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportsOneWordAcceptance == true)
        #expect(store.profile(for: "com.anthropic.claude-code")?.supportsFullAcceptance == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.canPresentSuggestions == true)
        #expect(store.profile(for: "com.anthropic.claude-code")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.isSensitive == false)
        #expect(store.profile(for: "com.anthropic.claude-code")?.promptAppSafetyMode == .wordOnly)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.displayName == "Claude")
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.supportLevel == .yellow)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.graduationDecision == .wordOnly)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.renderMode == .inlineAdjacent)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fallbackRenderMode == .floatingMirror)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.insertionMode == .axValueReplacement)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fallbackInsertionMode == nil)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.fieldIdentityMode == .stableBounds)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.supportsOneWordAcceptance == true)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.supportsFullAcceptance == false)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.requiresNoSubmitAcceptanceProof == true)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.canPresentSuggestions == true)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.suppressesAfterInsertionFailure == true)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.allowsDetachedSuggestions == false)
        #expect(store.profile(for: "com.anthropic.claudefordesktop")?.promptAppSafetyMode == .wordOnly)
        #expect(store.profile(for: "com.apple.Safari")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.apple.Safari")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.apple.Safari")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "com.tinyspeck.slackmacgap")?.appFamily == .electron)
        #expect(store.profile(for: "com.tinyspeck.slackmacgap")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.tinyspeck.slackmacgap")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "ru.keepcoder.Telegram")?.displayName == "Telegram")
        #expect(store.profile(for: "ru.keepcoder.Telegram")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "ru.keepcoder.Telegram")?.graduationDecision == .blocked)
        #expect(store.profile(for: "ru.keepcoder.Telegram")?.renderMode == .disabled)
        #expect(store.profile(for: "ru.keepcoder.Telegram")?.promptAppSafetyMode == .disabled)
        #expect(store.profile(for: "notion.id")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "notion.id")?.graduationDecision == .blocked)
        #expect(store.profile(for: "notion.id")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.hnc.Discord")?.supportLevel == .diagnosticsOnly)
        #expect(store.profile(for: "com.hnc.Discord")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.hnc.DiscordPTB")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.hnc.DiscordPTB")?.graduationDecision == .blocked)
        #expect(store.profile(for: "com.hnc.DiscordCanary")?.canPresentSuggestions == false)
        #expect(store.profile(for: "com.hnc.DiscordCanary")?.graduationDecision == .blocked)
        #expect(store.profiles["com.microsoft.VSCode"]?.anchorLadder == [.none])
        #expect(store.profiles["com.microsoft.VSCode"]?.graduationDecision == .blocked)
        #expect(store.profiles["com.todesktop.230313mzl4w4u92"]?.renderMode == .disabled)
        #expect(store.profiles["com.todesktop.230313mzl4w4u92"]?.graduationDecision == .blocked)
    }

    @Test("Denylisted apps are never allowed")
    func denylistedAppsAreBlocked() {
        let store = CompatibilityProfileStore.mvp

        #expect(!store.allows(bundleIdentifier: "com.apple.Terminal"))
        #expect(!store.allows(bundleIdentifier: "com.1password.1password"))
        #expect(!store.allows(bundleIdentifier: "com.apple.Passwords"))
    }

    @Test("Terminal hosts stay blocked outside explicit Claude proof")
    func terminalHostsStayBlockedOutsideExplicitClaudeProof() {
        let store = CompatibilityProfileStore.mvp

        for hostBundleIdentifier in ClaudeCodeTerminalHostProofPolicy.supportedTerminalHosts {
            #expect(store.supportStatus(for: hostBundleIdentifier) == .denylisted)
            #expect(!store.allows(bundleIdentifier: hostBundleIdentifier))
        }

        let proofProfile = ClaudeCodeTerminalHostProofPolicy.proofProfile
        #expect(proofProfile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier)
        #expect(proofProfile.insertionMode == .clipboardFallbackOptIn)
        #expect(proofProfile.requiresNoSubmitAcceptanceProof)
    }

    @Test("Highest-risk developer and system apps stay denylisted by default")
    func highestRiskDeveloperAndSystemAppsStayDenylisted() {
        let store = CompatibilityProfileStore.mvp
        let highRiskBundleIdentifiers = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCodeInsiders",
            "com.visualstudio.code.oss",
            "com.exafunction.windsurf",
            "com.jetbrains.intellij",
            "com.jetbrains.AppCode",
            "com.jetbrains.CLion",
            "com.jetbrains.PyCharm",
            "com.jetbrains.WebStorm",
            "com.jetbrains.RubyMine",
            "com.jetbrains.goland",
            "com.jetbrains.datagrip",
            "com.jetbrains.phpstorm",
            "com.jetbrains.rider",
            "com.jetbrains.DataSpell",
            "com.jetbrains.aqua",
            "com.jetbrains.gateway"
        ]

        for bundleIdentifier in highRiskBundleIdentifiers {
            #expect(store.supportStatus(for: bundleIdentifier) == .denylisted)
            #expect(!store.allows(bundleIdentifier: bundleIdentifier))
        }
    }

    @Test("Unknown apps use the default-on generic profile")
    func unknownAppsUseDefaultOnGenericProfile() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.allows(bundleIdentifier: "com.example.UnknownEditor"))
        #expect(store.profile(for: "com.example.UnknownEditor")?.displayName == "Generic App")
        #expect(store.profile(for: "com.example.UnknownEditor")?.bundleIdentifier == "com.example.UnknownEditor")
        #expect(!store.allows(bundleIdentifier: "com.openai.atlas"))
    }

    @Test("MVP profiles do not allow unknown field kinds by default")
    func mvpProfilesDoNotAllowUnknownFieldKindsByDefault() {
        for profile in CompatibilityProfileStore.mvp.profiles.values {
            #expect(!profile.allowsUnknownFieldKind)
        }
    }

    @Test("Support status explains unsupported and denylisted apps")
    func supportStatusExplainsBlockedApps() {
        let store = CompatibilityProfileStore.mvp

        #expect(store.supportStatus(for: "com.apple.Terminal").summary == "blocked: denylisted app")
        #expect(store.supportStatus(for: "com.openai.atlas").summary == "diagnostics only: ChatGPT Atlas")
        #expect(store.supportStatus(for: "com.example.UnknownEditor").summary == "yellow: Generic App")
        #expect(store.supportStatus(for: "com.apple.TextEdit").summary == "green: TextEdit")
        #expect(store.supportStatus(for: "com.apple.mail").summary == "diagnostics only: Mail")
    }

    @Test("Support status exposes user-facing stance copy")
    func supportStatusExposesUserFacingStanceCopy() {
        let store = CompatibilityProfileStore.mvp

        let green = store.supportStatus(for: "com.apple.TextEdit")
        #expect(green.supportLevel == .green)
        #expect(green.userFacingSummary == "Green: TextEdit")
        #expect(green.userFacingReason == "Verified suggestions near the cursor and native text insertion.")
        #expect(green.menuText(appDisplayName: "TextEdit", isEnabled: true) == "TextEdit green on")
        #expect(green.canToggleSuggestions)

        let yellow = store.supportStatus(for: "com.apple.Notes")
        #expect(yellow.supportLevel == .yellow)
        #expect(yellow.userFacingSummary == "Yellow: Notes")
        #expect(
            yellow.userFacingReason
                == "Rich text can drift; display can use a floating backup, and insertion fails closed."
        )
        #expect(yellow.menuText(appDisplayName: "Notes", isEnabled: false) == "Notes yellow off")
        #expect(yellow.canToggleSuggestions)

        let diagnosticsOnly = store.supportStatus(for: "com.apple.mail")
        #expect(diagnosticsOnly.supportLevel == .diagnosticsOnly)
        #expect(diagnosticsOnly.userFacingSummary == "Diagnostics-only: Mail")
        #expect(diagnosticsOnly.menuText(appDisplayName: "Mail", isEnabled: true) == "Mail diagnostics-only")
        #expect(!diagnosticsOnly.canToggleSuggestions)

        let atlas = store.supportStatus(for: "com.openai.atlas")
        #expect(atlas.supportLevel == .diagnosticsOnly)
        #expect(atlas.userFacingSummary == "Diagnostics-only: ChatGPT Atlas")
        #expect(atlas.userFacingReason == "Atlas can contain private browser text and prompt chats; no no-submit proof exists.")
        #expect(atlas.menuText(appDisplayName: "Atlas", isEnabled: true) == "Atlas diagnostics-only")
        #expect(!atlas.canToggleSuggestions)

        let chatGPT = store.supportStatus(for: "com.openai.chat")
        #expect(chatGPT.supportLevel == .diagnosticsOnly)
        #expect(chatGPT.userFacingSummary == "Diagnostics-only: ChatGPT")
        #expect(
            chatGPT.userFacingReason
                == "ChatGPT prompt composers can submit, attach context, and expose tools; no exact-version no-submit proof exists."
        )
        #expect(chatGPT.menuText(appDisplayName: "ChatGPT", isEnabled: true) == "ChatGPT diagnostics-only")
        #expect(!chatGPT.canToggleSuggestions)

        let generic = store.supportStatus(for: "com.example.UnknownEditor")
        #expect(generic.supportLevel == .yellow)
        #expect(generic.userFacingSummary == "Yellow: Generic App")
        #expect(generic.userFacingReason == "Default-on generic Accessibility path for apps without a custom profile.")
        #expect(generic.menuText(appDisplayName: "Unknown", isEnabled: true) == "Unknown yellow on")
        #expect(generic.canToggleSuggestions)

        let denylisted = store.supportStatus(for: "com.apple.dt.Xcode")
        #expect(denylisted == .denylisted)
        #expect(denylisted.userFacingSummary == "Blocked: high-risk app")
        #expect(denylisted.userFacingReason == "Blocked because this kind of app can expose secrets or shell input.")
        #expect(!denylisted.canToggleSuggestions)
    }

    @Test("Profiles expose debug summaries with primary and fallback paths")
    func profilesExposeDebugSummaries() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(profile.debugSummary.contains("primary render=inlineAdjacent"))
        #expect(profile.debugSummary.contains("support=yellow"))
        #expect(profile.debugSummary.contains("family=chromium"))
        #expect(profile.debugSummary.contains("insert=axThenKeyEvents"))
        #expect(profile.debugSummary.contains("fallback render=floatingMirror"))
        #expect(profile.debugSummary.contains("insert=axValueReplacement"))
        #expect(profile.debugSummary.contains("field=accessibilityElement"))
        #expect(profile.debugSummary.contains("anchors=caret>field"))
    }

    @Test("Insertion mode plans try primary then safe fallback")
    func insertionModePlansTryPrimaryThenFallback() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let obsidian = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
        let claude = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(InsertionModePlan.modes(for: textEdit) == [.axSelectedText, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: notes) == [.axThenKeyEvents, .keyEvents])
        #expect(InsertionModePlan.modes(for: chrome) == [.axThenKeyEvents, .axValueReplacement])
        #expect(InsertionModePlan.modes(for: obsidian) == [.keyEvents])
        #expect(InsertionModePlan.modes(for: codex) == [.axValueReplacement])
        #expect(InsertionModePlan.modes(for: claudeCode) == [.keyEvents])
        #expect(InsertionModePlan.modes(for: claude) == [.axValueReplacement])
        #expect(InsertionModePlan.modes(for: mail) == [])

        for profile in CompatibilityProfileStore.mvp.profiles.values {
            #expect(!InsertionModePlan.modes(for: profile).contains(.clipboardFallbackOptIn))
        }
    }

    @Test("Unproven real app profiles fail closed on risky affordances")
    func unprovenRealAppProfilesFailClosedOnRiskyAffordances() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))
        let claude = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop"))

        #expect(notes.allowsDetachedSuggestions == false)
        #expect(notes.fallbackInsertionMode == .keyEvents)
        #expect(codex.supportsOneWordAcceptance == true)
        #expect(codex.supportsFullAcceptance == true)
        #expect(codex.requiresNoSubmitAcceptanceProof == false)
        #expect(codex.canPresentSuggestions == true)
        #expect(claudeCode.supportsOneWordAcceptance == true)
        #expect(claudeCode.supportsFullAcceptance == false)
        #expect(claudeCode.requiresNoSubmitAcceptanceProof == true)
        #expect(claudeCode.canPresentSuggestions == true)
        #expect(claude.supportsOneWordAcceptance == true)
        #expect(claude.supportsFullAcceptance == false)
        #expect(claude.requiresNoSubmitAcceptanceProof == true)
        #expect(claude.canPresentSuggestions == true)

        #expect(codex.supportReason.contains("on for this installed app"))
        #expect(codex.notes.contains("one-word no-submit proof"))
        #expect(codex.notes.contains("full-accept no-submit proof"))
        #expect(codex.supportsFullAcceptance == true)
        #expect(codex.requiresNoSubmitAcceptanceProof == false)
        #expect(codex.allowsDetachedSuggestions == false)
        #expect(codex.allowsSyntheticCaretPlacement == false)
        #expect(codex.isSensitive == false)
        #expect(codex.promptAppSafetyMode == .wordOnly)
        #expect(codex.allowsStrictVisualProofSyntheticCaretPlacement == true)
        #expect(claude.notes.contains("Same-slice one-word no-submit proof exists"))
        #expect(claude.notes.contains("Default-on Claude desktop"))
        #expect(claude.promptAppSafetyMode == .wordOnly)
        #expect(claude.allowsStrictVisualProofSyntheticCaretPlacement == true)

        #expect(claudeCode.supportReason.contains("terminal-host adapter"))
        #expect(claudeCode.notes.contains("terminal adapter"))
        #expect(claudeCode.allowsStrictVisualProofSyntheticCaretPlacement == false)
    }

    @Test("Required prompt and chat apps are disabled except dogfood targets")
    func requiredPromptAndChatAppsAreDisabledExceptDogfoodTargets() throws {
        let store = CompatibilityProfileStore.mvp
        let codex = try #require(store.profile(for: "com.openai.codex"))
        #expect(codex.supportLevel == .yellow)
        #expect(codex.renderMode == .inlineAdjacent)
        #expect(codex.insertionMode == .axValueReplacement)
        #expect(codex.supportsOneWordAcceptance == true)
        #expect(codex.supportsFullAcceptance == true)
        #expect(codex.requiresNoSubmitAcceptanceProof == false)
        #expect(codex.promptAppSafetyMode == .wordOnly)
        #expect(codex.canPresentSuggestions == true)

        let disabledPromptApps = [
            "com.openai.chat",
            "com.openai.ChatGPT",
            "com.openai.atlas",
            "com.tinyspeck.slackmacgap",
            "ru.keepcoder.Telegram"
        ]

        for bundleIdentifier in disabledPromptApps {
            let profile = try #require(store.profile(for: bundleIdentifier))

            #expect(profile.supportLevel == .diagnosticsOnly)
            #expect(profile.renderMode == .disabled)
            #expect(profile.insertionMode == .disabled)
            #expect(profile.supportsOneWordAcceptance == false)
            #expect(profile.supportsFullAcceptance == false)
            #expect(profile.promptAppSafetyMode == .disabled)
            #expect(profile.canPresentSuggestions == false)
        }

        let messages = try #require(store.profile(for: "com.apple.MobileSMS"))
        #expect(messages.graduationDecision == .wordOnly)
        #expect(messages.promptAppSafetyMode == .wordOnly)
        #expect(messages.supportsOneWordAcceptance)
        #expect(!messages.supportsFullAcceptance)
        #expect(messages.requiresNoSubmitAcceptanceProof)

        let claudeCode = try #require(store.profile(for: "com.anthropic.claude-code"))
        #expect(claudeCode.graduationDecision == .wordOnly)
        #expect(claudeCode.promptAppSafetyMode == .wordOnly)
        #expect(claudeCode.canPresentSuggestions)
    }

    @Test("High-value writing surfaces have explicit graduation decisions")
    func highValueWritingSurfacesHaveExplicitGraduationDecisions() throws {
        let store = CompatibilityProfileStore.mvp

        let supportedBundles = [
            "com.google.Chrome",
            "md.obsidian",
            "com.openai.codex"
        ]
        for bundleIdentifier in supportedBundles {
            #expect(try #require(store.profile(for: bundleIdentifier)).graduationDecision == .supported)
        }

        let wordOnlyBundles = [
            "com.apple.MobileSMS",
            "com.anthropic.claude-code",
            "com.anthropic.claudefordesktop"
        ]
        for bundleIdentifier in wordOnlyBundles {
            let profile = try #require(store.profile(for: bundleIdentifier))
            #expect(profile.graduationDecision == .wordOnly)
            #expect(profile.supportsOneWordAcceptance)
            #expect(!profile.supportsFullAcceptance)
            #expect(profile.requiresNoSubmitAcceptanceProof)
        }

        #expect(try #require(store.profile(for: "com.apple.mail")).graduationDecision == .diagnosticsOnly)

        let blockedBundles = [
            "com.openai.chat",
            "com.openai.ChatGPT",
            "com.openai.atlas",
            "com.tinyspeck.slackmacgap",
            "com.hnc.Discord",
            "com.hnc.DiscordPTB",
            "com.hnc.DiscordCanary"
        ]
        for bundleIdentifier in blockedBundles {
            #expect(try #require(store.profile(for: bundleIdentifier)).graduationDecision == .blocked)
        }

        #expect(store.profiles["com.microsoft.VSCode"]?.graduationDecision == .blocked)
        #expect(store.supportStatus(for: "com.microsoft.VSCode").supportLevel == .diagnosticsOnly)
        #expect(store.profiles["com.todesktop.230313mzl4w4u92"]?.graduationDecision == .blocked)
        #expect(store.supportStatus(for: "com.todesktop.230313mzl4w4u92").supportLevel == .diagnosticsOnly)
    }

    @Test("Safety summaries expose the practical current-app stance")
    func safetySummariesExposePracticalCurrentAppStance() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let mailStatus = CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.mail")
        let atlasStatus = CompatibilityProfileStore.mvp.supportStatus(for: "com.openai.atlas")
        let genericStatus = CompatibilityProfileStore.mvp.supportStatus(for: "com.example.UnknownEditor")

        #expect(
            textEdit.userFacingSafetySummary
                == "Inline when caret proof is trusted; mirror fallback if inline is unsafe."
        )
        #expect(
            notes.userFacingSafetySummary
                == "Inline when caret proof is trusted; mirror fallback if inline is unsafe. Detached field/window suggestions are disabled. Insertion fails closed if the primary method is not verified."
        )
        #expect(
            codex.userFacingSafetySummary
                == "Inline when caret proof is trusted; mirror fallback if inline is unsafe. Detached field/window suggestions are disabled. Prompt safety mode is word-only. Insertion fails closed if the primary method is not verified."
        )
        #expect(mailStatus.userFacingSafetySummary == "Suggestions stay off here.")
        #expect(atlasStatus.userFacingSafetySummary == "Suggestions stay off here.")
        #expect(
            genericStatus.userFacingSafetySummary
                == "Inline when caret proof is trusted; mirror fallback if inline is unsafe. Insertion fails closed if the primary method is not verified."
        )
    }

    @Test("Proof-only profile copy can enable full accept without changing placement")
    func proofOnlyProfileCopyCanEnableFullAcceptWithoutChangingPlacement() throws {
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let proofProfile = codex.replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            notes: "Proof-only full accept."
        )

        #expect(proofProfile.bundleIdentifier == codex.bundleIdentifier)
        #expect(proofProfile.displayName == codex.displayName)
        #expect(proofProfile.renderMode == codex.renderMode)
        #expect(proofProfile.insertionMode == codex.insertionMode)
        #expect(proofProfile.fieldIdentityMode == codex.fieldIdentityMode)
        #expect(proofProfile.supportsOneWordAcceptance == codex.supportsOneWordAcceptance)
        #expect(proofProfile.supportsFullAcceptance)
        #expect(!proofProfile.requiresNoSubmitAcceptanceProof)
        #expect(proofProfile.promptAppSafetyMode == codex.promptAppSafetyMode)
        #expect(proofProfile.notes == "Proof-only full accept.")
    }

    @Test("Proof-only Codex full accept keeps strict visual synthetic caret proof")
    func proofOnlyCodexFullAcceptKeepsStrictVisualSyntheticCaretProof() throws {
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let proofProfile = codex.replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            notes: "\(codex.notes) Proof-only Codex full-accept no-submit scenario is active."
        )
        let unprovenFullAccept = codex.replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            notes: "Proof-only full accept."
        )

        #expect(codex.allowsStrictVisualProofSyntheticCaretPlacement)
        #expect(proofProfile.allowsStrictVisualProofSyntheticCaretPlacement)
        #expect(!unprovenFullAccept.allowsStrictVisualProofSyntheticCaretPlacement)
    }

    @Test("Insertion mode plans can skip failed primary modes")
    func insertionModePlansCanSkipFailedPrimaryModes() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(InsertionModePlan.modes(for: notes, skipping: [.axThenKeyEvents]) == [.keyEvents])
        #expect(InsertionModePlan.modes(for: notes, skipping: [.axThenKeyEvents, .keyEvents]) == [])
        #expect(InsertionModePlan.modes(for: chrome, skipping: [.axThenKeyEvents]) == [.axValueReplacement])
        #expect(InsertionModePlan.modes(for: chrome, skipping: [.axThenKeyEvents, .axValueReplacement]) == [])
    }

    @Test("Notes insertion can fall back while still failing closed after verification")
    func notesInsertionCanFallBackWhileStillFailingClosedAfterVerification() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))

        #expect(notes.insertionMode == .axThenKeyEvents)
        #expect(notes.fallbackInsertionMode == .keyEvents)
        #expect(notes.suppressesAfterInsertionFailure)
        #expect(notes.allowsDetachedSuggestions == false)
        #expect(InsertionModePlan.modes(for: notes) == [.axThenKeyEvents, .keyEvents])
        #expect(InsertionModePlan.modes(for: notes, skipping: [.axThenKeyEvents]) == [.keyEvents])
    }

    @Test("Render mode plans respect Codex dogfood and disabled prompt targets")
    func renderModePlansRespectCodexDogfoodAndDisabledPromptTargets() throws {
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
        let obsidian = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))
        #expect(RenderModePlan.effectiveMode(
            for: obsidian,
            supportsInlineSuggestions: true,
            hasMirrorAnchor: true
        ) == .inlineAdjacent)
        #expect(RenderModePlan.effectiveMode(
            for: obsidian,
            supportsInlineSuggestions: false,
            hasMirrorAnchor: true
        ) == nil)
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
        ) == .floatingMirror)
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

    @Test("Yellow mirror fallback does not permit low confidence placement without proof")
    func yellowMirrorFallbackDoesNotPermitLowConfidencePlacementWithoutProof() throws {
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        let chromeTrustPolicy = chrome.placementTrustPolicy()
        let chromePlan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: chrome.fallbackRenderMode,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: nil,
            textLineRect: nil,
            allowsDetachedSuggestions: chrome.allowsDetachedSuggestions,
            trustPolicy: chromeTrustPolicy
        )

        #expect(!chromeTrustPolicy.allowsLowConfidencePlacement)
        #expect(!chromeTrustPolicy.allowsSyntheticCaretPlacement)
        guard case let .suppress(chromeSuppression) = chromePlan else {
            Issue.record("Expected untrusted yellow mirror fallback to suppress")
            return
        }
        #expect(chromeSuppression.reason == .lowConfidencePlacement)

        #expect(textEdit.placementTrustPolicy().allowsLowConfidencePlacement)
        #expect(chrome.placementTrustPolicy(input: CompatibilityPlacementTrustInput(
            hasTrustedVisualAdjustment: true
        )).allowsLowConfidencePlacement)
    }

    @Test("Chrome trusts proofed synthetic text-area caret placement without trusting detached fallback")
    func chromeTrustsProofedSyntheticTextAreaCaretPlacement() throws {
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        let unproofedSyntheticCaretPlan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: chrome.fallbackRenderMode,
            caretRect: CGRect(x: 320, y: 260, width: 0, height: 22),
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: CGRect(x: 320, y: 260, width: 0, height: 22),
            caretIsSynthetic: true,
            allowsDetachedSuggestions: chrome.allowsDetachedSuggestions,
            trustPolicy: chrome.placementTrustPolicy()
        )

        guard case let .present(unproofedPresentation) = unproofedSyntheticCaretPlan else {
            Issue.record("Expected unproofed Chrome synthetic caret placement to fall back")
            return
        }
        #expect(unproofedPresentation.renderMode == .floatingMirror)
        #expect(unproofedPresentation.anchorSource == .element)
        #expect(unproofedPresentation.reason == .untrustedSyntheticCaret)

        let syntheticCaretPlan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: chrome.fallbackRenderMode,
            caretRect: CGRect(x: 320, y: 260, width: 0, height: 22),
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: CGRect(x: 320, y: 260, width: 0, height: 22),
            caretIsSynthetic: true,
            allowsDetachedSuggestions: chrome.allowsDetachedSuggestions,
            trustPolicy: chrome.placementTrustPolicy(input: CompatibilityPlacementTrustInput(
                hasProofedSyntheticCaret: true
            ))
        )

        guard case let .present(presentation) = syntheticCaretPlan else {
            Issue.record("Expected Chrome synthetic caret placement to present inline")
            return
        }
        #expect(presentation.renderMode == .inlineAdjacent)
        #expect(presentation.anchorSource == .syntheticCaret)
        #expect(presentation.reason == .healthy)
        #expect(presentation.metadata["placementConfidenceBand"] == "medium")

        let detachedFallbackPlan = PlacementHealth.plan(
            requestedRenderMode: .inlineAdjacent,
            fallbackRenderMode: chrome.fallbackRenderMode,
            caretRect: nil,
            elementRect: CGRect(x: 100, y: 200, width: 500, height: 180),
            windowRect: CGRect(x: 80, y: 160, width: 560, height: 300),
            textLineRect: nil,
            caretIsSynthetic: false,
            allowsDetachedSuggestions: chrome.allowsDetachedSuggestions,
            trustPolicy: chrome.placementTrustPolicy()
        )

        guard case let .suppress(suppression) = detachedFallbackPlan else {
            Issue.record("Expected Chrome detached low-confidence fallback to stay suppressed")
            return
        }
        #expect(suppression.reason == .lowConfidencePlacement)
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
