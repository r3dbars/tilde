import AppKit
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Settings window control state")
struct SettingsWindowControllerStateTests {
    @Test("Settings layout stays native and unframed")
    func settingsLayoutStaysNativeAndUnframed() {
        let style = SettingsLayoutStyle.nativeUtility

        #expect(!style.usesFramedCards)
        #expect(style.usesSystemFonts)
        #expect(style.usesDynamicSystemColors)
        #expect(style.appearanceCoverage.coversLightDarkAndHighContrast)
        #expect(style.sectionSpacing == 14)
        #expect(style.sectionItemSpacing == 5)
        #expect(style.contentInsets.top == 24)
        #expect(style.contentInsets.left == 24)
        #expect(style.contentInsets.bottom == 24)
        #expect(style.contentInsets.right == 24)
        #expect(style.secondaryLabelMaxWidth == 470)
    }

    @Test("Current app copy makes support stance and blocked state clear")
    func currentAppCopyMakesSupportStanceAndBlockedStateClear() {
        let store = CompatibilityProfileStore.mvp
        let allowed = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(allowed.statusText == "Current app: TextEdit is green and on")
        #expect(
            allowed.detailText
                == "Verified inline suggestions and native text insertion. Suggestions are on for this app."
        )
        #expect(allowed.modeText == "Mode: inline, mirror fallback")
        #expect(allowed.acceptanceText == "Acceptance: Tab next word + full accept")
        #expect(allowed.fallbackText == "Fallback: not needed; inline is available.")
        #expect(allowed.proofText == "Proof: use disposable text, press Tab once, then the full-accept shortcut.")
        #expect(allowed.proofCommandText == "Command: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit")
        #expect(allowed.proofCommandClipboardText == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit")
        #expect(allowed.copyProofCommandButtonTitle == "Copy Proof Command")
        #expect(allowed.canCopyProofCommand)
        #expect(allowed.proofButtonTitle == "Run TextEdit Proof")
        #expect(allowed.toggleTitle == "Allow suggestions in this app")
        #expect(allowed.menuToggleTitle == "Disable TextEdit")
        #expect(allowed.blockedAppsText == "Blocked apps: none")
        #expect(allowed.canToggle)

        let chrome = SettingsCurrentAppState(
            displayName: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            supportStatus: store.supportStatus(for: "com.google.Chrome"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(chrome.proofButtonTitle == "Run Chrome Proof")
        #expect(chrome.proofCommandText == "Manual command: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all")
        #expect(chrome.proofCommandClipboardText == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all")
        #expect(chrome.canStartProof)

        let blocked = SettingsCurrentAppState(
            displayName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            supportStatus: store.supportStatus(for: "com.apple.Notes"),
            isEnabled: false,
            disabledAppCount: 2
        )

        #expect(blocked.statusText == "Current app: Notes is yellow and off")
        #expect(
            blocked.detailText
                == "Rich text can drift; display can fall back to floating, and insertion fails closed. Suggestions are off for this app. Turn them on only where you want to test."
        )
        #expect(blocked.modeText == "Mode: inline, mirror fallback")
        #expect(blocked.acceptanceText == "Acceptance: Tab next word + full accept")
        #expect(blocked.fallbackText == "Fallback: off because this app is disabled.")
        #expect(blocked.proofText == "Proof: turn on suggestions for this app first.")
        #expect(blocked.proofCommandText == nil)
        #expect(blocked.proofCommandClipboardText == nil)
        #expect(blocked.copyProofCommandButtonTitle == "No Proof Command")
        #expect(!blocked.canCopyProofCommand)
        #expect(blocked.menuToggleTitle == "Enable Notes")
        #expect(blocked.blockedAppsText == "Blocked apps: 2")
        #expect(blocked.canToggle)

        let enabledNotes = SettingsCurrentAppState(
            displayName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            supportStatus: store.supportStatus(for: "com.apple.Notes"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(enabledNotes.proofCommandText?.contains("notes-title --manual-gate") == true)
        #expect(enabledNotes.proofCommandText?.contains("notes-body --manual-gate") == true)
        #expect(enabledNotes.proofCommandText?.contains("notes-checklist --manual-gate") == true)
        #expect(
            enabledNotes.proofCommandClipboardText
                == """
                AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
                AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
                AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
                """
        )
        #expect(enabledNotes.canCopyProofCommand)
    }

    @Test("Diagnostics-only unsupported or missing current app cannot be toggled")
    func diagnosticsOnlyUnsupportedOrMissingCurrentAppCannotBeToggled() {
        let store = CompatibilityProfileStore.mvp
        let diagnosticsOnly = SettingsCurrentAppState(
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            supportStatus: store.supportStatus(for: "com.apple.mail"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(diagnosticsOnly.statusText == "Current app: Mail is diagnostics-only")
        #expect(
            diagnosticsOnly.detailText
                == "Mail compose is sensitive and insertion is not proven. Suggestions stay off here."
        )
        #expect(diagnosticsOnly.modeText == "Mode: disabled")
        #expect(diagnosticsOnly.acceptanceText == "Acceptance: off here")
        #expect(diagnosticsOnly.fallbackText == "Fallback: unavailable in sensitive apps or fields.")
        #expect(diagnosticsOnly.proofText == "Proof: unavailable here.")
        #expect(diagnosticsOnly.proofCommandText == nil)
        #expect(diagnosticsOnly.proofCommandClipboardText == nil)
        #expect(!diagnosticsOnly.canCopyProofCommand)
        #expect(diagnosticsOnly.menuToggleTitle == "Suggestions unavailable in Mail")
        #expect(!diagnosticsOnly.canToggle)

        let unsupported = SettingsCurrentAppState(
            displayName: "Atlas",
            bundleIdentifier: "com.openai.atlas",
            supportStatus: store.supportStatus(for: "com.openai.atlas"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(unsupported.statusText == "Current app: Atlas is unsupported")
        #expect(unsupported.detailText == "No compatibility profile yet. Suggestions stay off here.")
        #expect(unsupported.modeText == "Mode: not tested yet")
        #expect(unsupported.acceptanceText == "Acceptance: off here")
        #expect(unsupported.fallbackText == "Fallback: unavailable until this app has a profile.")
        #expect(unsupported.proofText == "Proof: unavailable here.")
        #expect(unsupported.proofCommandText == nil)
        #expect(unsupported.proofCommandClipboardText == nil)
        #expect(!unsupported.canCopyProofCommand)
        #expect(unsupported.menuToggleTitle == "Suggestions unavailable in Atlas")
        #expect(!unsupported.canToggle)

        let missing = SettingsCurrentAppState(
            displayName: "None",
            bundleIdentifier: nil,
            supportStatus: .unsupported,
            isEnabled: false,
            disabledAppCount: 0
        )

        #expect(missing.statusText == "Current app: no app selected")
        #expect(missing.detailText == "Open a writing app to see whether suggestions are supported.")
        #expect(missing.modeText == "Mode: choose a writing app")
        #expect(missing.acceptanceText == "Acceptance: off until an app is selected")
        #expect(missing.fallbackText == "Fallback: choose a writing app first.")
        #expect(missing.proofText == "Proof: choose a writing app first.")
        #expect(missing.proofCommandText == nil)
        #expect(missing.proofCommandClipboardText == nil)
        #expect(!missing.canCopyProofCommand)
        #expect(missing.menuToggleTitle == "Toggle Current App")
        #expect(!missing.canToggle)
    }

    @Test("Diagnostics-only non-sensitive apps show copy-only fallback")
    func diagnosticsOnlyNonSensitiveAppsShowCopyOnlyFallback() {
        let store = CompatibilityProfileStore.mvp
        let safari = SettingsCurrentAppState(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            supportStatus: store.supportStatus(for: "com.apple.Safari"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(safari.statusText == "Current app: Safari is diagnostics-only")
        #expect(safari.modeText == "Mode: disabled")
        #expect(safari.acceptanceText == "Acceptance: off here")
        #expect(safari.fallbackText == "Fallback: copy-only; inline and auto-insert stay off until proof passes.")
        #expect(safari.proofText == "Proof: unavailable here.")
        #expect(!safari.canToggle)
    }

    @Test("Prompt apps show full accept is off for safety")
    func promptAppsShowFullAcceptIsOffForSafety() {
        let store = CompatibilityProfileStore.mvp
        let codex = SettingsCurrentAppState(
            displayName: "Codex",
            bundleIdentifier: "com.openai.codex",
            supportStatus: store.supportStatus(for: "com.openai.codex"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(codex.modeText == "Mode: inline, mirror fallback")
        #expect(codex.acceptanceText == "Acceptance: Tab next word only; full accept is off for safety")
        #expect(codex.proofText == "Proof: include AUTOCOMPLETE_LAB_CODEX_PROOF, press Tab once, and do not press Enter.")
        #expect(codex.proofCommandText == "Manual command: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate")
        #expect(codex.proofCommandClipboardText == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate")
        #expect(codex.canCopyProofCommand)
    }

    @Test("Per-app mode copy exposes forced mirror overrides")
    func perAppModeCopyExposesForcedMirrorOverrides() {
        let store = CompatibilityProfileStore.mvp
        let forcedMirror = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0,
            renderModeOverride: .floatingMirror
        )

        #expect(forcedMirror.modeText == "Mode: mirror forced (profile inline)")
        #expect(forcedMirror.modeButtonTitle == "Use Profile Mode")
        #expect(forcedMirror.canOverrideMode)
        #expect(forcedMirror.proofButtonTitle == "Run TextEdit Proof")
        #expect(forcedMirror.canStartProof)

        let profileMode = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(profileMode.modeButtonTitle == "Force Mirror Mode")
        #expect(profileMode.canOverrideMode)
        #expect(profileMode.proofButtonTitle == "Run TextEdit Proof")
        #expect(profileMode.canStartProof)

        let diagnosticsOnly = SettingsCurrentAppState(
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            supportStatus: store.supportStatus(for: "com.apple.mail"),
            isEnabled: false,
            disabledAppCount: 0
        )

        #expect(!diagnosticsOnly.canOverrideMode)
        #expect(!diagnosticsOnly.canStartProof)

        let disabled = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(disabled.proofButtonTitle == "Enable App First")
        #expect(!disabled.canStartProof)
        #expect(!disabled.canCopyProofCommand)
    }

    @Test("Accessibility permission copy says what the app reads and keeps local")
    func accessibilityPermissionCopySaysWhatTheAppReadsAndKeepsLocal() {
        let needed = SettingsPermissionState(isTrusted: false)

        #expect(needed.statusText == "Accessibility permission: needed")
        #expect(
            needed.detailText
                == "Allow Accessibility in System Settings so Autocomplete Lab can see the focused text field, find the cursor, and insert text only when you accept. Text stays on this Mac."
        )

        let allowed = SettingsPermissionState(isTrusted: true)

        #expect(allowed.statusText == "Accessibility permission: allowed")
        #expect(
            allowed.detailText
                == "Autocomplete Lab can see the focused text field, place suggestions at the cursor, and insert text only when you accept. Text stays on this Mac."
        )
    }

    @Test("Privacy copy exposes diagnostics and raw content state")
    func privacyCopyExposesDiagnosticsAndRawContentState() {
        let privacy = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            rawContentTracingExpiresAt: nil,
            screenshotTracingEnabled: true,
            screenshotTracingExpiresAt: nil,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(privacy.statusText == "Privacy: local diagnostics only")
        #expect(
            privacy.diagnosticsStatusText
                == "Diagnostics: performance + placement traces recording, screenshots on"
        )
        #expect(privacy.contentStatusText == "Raw text capture: off")
        #expect(
            privacy.sharingStatusText
                == "Sharing: use Export Privacy Bundle; do not share debug traces or screenshots."
        )
        #expect(
            privacy.learningStatusText
                == "Learning: accepted-kept scores, style sketch, and recent words stay local"
        )
        #expect(
            privacy.screenRecordingPermissionText
                == "Screen Recording: used only while screenshot proof is on to capture local placement screenshots."
        )
        #expect(privacy.pathText == "Logs: /tmp/diagnostics.log | Traces: /tmp/traces.jsonl")

        let paused = SettingsPrivacyState(
            tracingPaused: true,
            rawContentTracingEnabled: true,
            rawContentTracingExpiresAt: Date(timeIntervalSince1970: 1_000),
            screenshotTracingEnabled: false,
            screenshotTracingExpiresAt: nil,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            paused.diagnosticsStatusText
                == "Diagnostics: performance + placement traces paused, screenshots off"
        )
        #expect(paused.contentStatusText == "Raw text capture: on temporarily")
        #expect(
            paused.sharingStatusText
                == "Sharing: use Export Privacy Bundle; do not share debug traces or screenshots."
        )
        #expect(paused.screenRecordingPermissionText == nil)

        let temporaryScreenshots = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            rawContentTracingExpiresAt: nil,
            screenshotTracingEnabled: true,
            screenshotTracingExpiresAt: Date(timeIntervalSince1970: 2_000),
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            temporaryScreenshots.screenRecordingPermissionText
                == "Screen Recording: used only for temporary local placement screenshots."
        )

        let shareSafe = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            rawContentTracingExpiresAt: nil,
            screenshotTracingEnabled: false,
            screenshotTracingExpiresAt: nil,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            shareSafe.sharingStatusText
                == "Sharing: Export Privacy Bundle excludes raw text, prompts, accepted text, and screenshots."
        )
    }

    @Test("Onboarding copy explains first run without private app tests")
    func onboardingCopyExplainsFirstRunWithoutPrivateAppTests() {
        let missingPermission = SettingsOnboardingState(
            isTrusted: false,
            suggestionsPaused: false,
            runtimeGuidance: RuntimeReadinessGuidance(
                report: RuntimeReadinessReport(
                    stage: .ready,
                    summary: "ready",
                    action: .none,
                    isReady: true
                )
            )
        )

        #expect(
            missingPermission.text
                == "Allow Accessibility in System Settings so suggestions can appear at the cursor and insert only when you accept. Text stays on this Mac."
        )

        let paused = SettingsOnboardingState(
            isTrusted: true,
            suggestionsPaused: true,
            runtimeGuidance: RuntimeReadinessGuidance(
                report: RuntimeReadinessReport(
                    stage: .ready,
                    summary: "ready",
                    action: .none,
                    isReady: true
                )
            )
        )

        #expect(paused.text == "Paused. Resume when you want to test suggestions.")

        let ready = SettingsOnboardingState(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeGuidance: RuntimeReadinessGuidance(
                report: RuntimeReadinessReport(
                    stage: .ready,
                    summary: "ready",
                    action: .none,
                    isReady: true
                )
            )
        )

        #expect(ready.text == "Ready: open TextEdit, turn on suggestions for TextEdit, type a short sentence, press Tab for one word, or Esc to dismiss.")
        #expect(!ready.text.localizedCaseInsensitiveContains("Notes"))
    }

    @Test("Field control copy scopes silence to the current field")
    func fieldControlCopyScopesSilenceToCurrentField() {
        let missing = SettingsFieldControlState(
            appDisplayName: nil,
            hasFieldTarget: false,
            isCurrentField: false,
            isSilenced: false
        )

        #expect(missing.statusText == "Current field: no writing field selected")
        #expect(missing.detailText == "Click into a writing field to silence only that field.")
        #expect(missing.buttonTitle == "Silence This Field")
        #expect(!missing.canSilence)

        let active = SettingsFieldControlState(
            appDisplayName: "TextEdit",
            hasFieldTarget: true,
            isCurrentField: true,
            isSilenced: false
        )

        #expect(active.statusText == "Current field: active in TextEdit")
        #expect(
            active.detailText
                == "Silence only this field for the current session; other fields and apps stay available."
        )
        #expect(active.buttonTitle == "Silence This Field")
        #expect(active.canSilence)

        let silenced = SettingsFieldControlState(
            appDisplayName: "TextEdit",
            hasFieldTarget: true,
            isCurrentField: false,
            isSilenced: true
        )

        #expect(silenced.statusText == "Last field: silenced for this session")
        #expect(silenced.detailText == "Suggestions stay off here until you leave this field.")
        #expect(silenced.buttonTitle == "Field Silenced")
        #expect(!silenced.canSilence)
    }

    @Test("Keyboard shortcut copy supports direct accept-all editing")
    func keyboardShortcutCopySupportsDirectAcceptAllEditing() {
        let backtick = SettingsKeyboardShortcutState(acceptAllShortcut: .backtick)

        #expect(backtick.statusText == "Shortcuts: Tab next word | Backtick all")
        #expect(backtick.acceptAllPickerLabel == "Accept all:")
        #expect(backtick.cycleButtonTitle == "Use Option-Tab")

        let optionTab = SettingsKeyboardShortcutState(acceptAllShortcut: .optionTab)

        #expect(optionTab.statusText == "Shortcuts: Tab next word | Option-Tab all")
        #expect(optionTab.acceptAllPickerLabel == "Accept all:")
        #expect(optionTab.cycleButtonTitle == "Use Backtick")
    }

    @Test("Suggestion aggressiveness copy supports quiet normal and eager")
    func suggestionAggressivenessCopySupportsQuietNormalAndEager() {
        let quiet = SettingsSuggestionAggressivenessState(aggressiveness: .quiet)
        let normal = SettingsSuggestionAggressivenessState(aggressiveness: .normal)
        let eager = SettingsSuggestionAggressivenessState(aggressiveness: .eager)

        #expect(quiet.statusText == "Aggressiveness: Quiet")
        #expect(quiet.detailText == "Waits longer and needs stronger scores before showing.")
        #expect(quiet.cycleButtonTitle == "Use Normal")
        #expect(normal.statusText == "Aggressiveness: Normal")
        #expect(normal.detailText == "Uses the current balanced timing and score gates.")
        #expect(normal.cycleButtonTitle == "Use Eager")
        #expect(eager.statusText == "Aggressiveness: Eager")
        #expect(eager.detailText == "Shows sooner when safe, while keeping sensitive-field and high-risk blocks.")
        #expect(eager.cycleButtonTitle == "Use Quiet")
    }

    @MainActor
    @Test("Settings proof actions dispatch current app proof and copy clean command")
    func settingsProofActionsDispatchCurrentAppProofAndCopyCleanCommand() throws {
        _ = NSApplication.shared
        var proofStartCount = 0
        let controller = SettingsWindowController(
            requestPermission: {},
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: {},
            silenceCurrentField: {},
            performRuntimeAction: { _ in },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            startCurrentAppProof: {
                proofStartCount += 1
            },
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
            deleteLocalLogs: {},
            clearLearningData: {},
            cycleAcceptAllShortcut: {},
            setAcceptAllShortcut: { _ in },
            cycleSuggestionAggressiveness: {}
        )

        controller.refresh(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            ),
            runtimeTargetSummary: "Qwen local - short completions - normal",
            modelDirectoryPath: "/tmp/AutocompleteLab/Models",
            modelInstallStatusText: nil,
            isModelInstallInProgress: false,
            currentApp: SettingsCurrentAppState(
                displayName: "TextEdit",
                bundleIdentifier: "com.apple.TextEdit",
                supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
                isEnabled: true,
                disabledAppCount: 0
            ),
            fieldControl: SettingsFieldControlState(
                appDisplayName: "TextEdit",
                hasFieldTarget: true,
                isCurrentField: true,
                isSilenced: false
            ),
            privacy: SettingsPrivacyState(
                tracingPaused: false,
                rawContentTracingEnabled: false,
                rawContentTracingExpiresAt: nil,
                screenshotTracingEnabled: false,
                screenshotTracingExpiresAt: nil,
                diagnosticsPath: "/tmp/diagnostics.log",
                tracePath: "/tmp/traces.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .backtick),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(aggressiveness: .normal),
            lastSuggestionDecision: "Shown"
        )

        controller.performStartAppProofAction()
        #expect(proofStartCount == 1)

        let pasteboard = NSPasteboard.withUniqueName()
        controller.copyCurrentProofCommand(to: pasteboard)
        #expect(
            pasteboard.string(forType: .string)
                == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit"
        )
    }
}
