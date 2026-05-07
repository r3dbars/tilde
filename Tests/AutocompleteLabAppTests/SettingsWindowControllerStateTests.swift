import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Settings window control state")
struct SettingsWindowControllerStateTests {
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
        #expect(allowed.toggleTitle == "Allow suggestions in this app")
        #expect(allowed.menuToggleTitle == "Disable TextEdit")
        #expect(allowed.blockedAppsText == "Blocked apps: none")
        #expect(allowed.canToggle)

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
        #expect(blocked.menuToggleTitle == "Enable Notes")
        #expect(blocked.blockedAppsText == "Blocked apps: 2")
        #expect(blocked.canToggle)
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
        #expect(missing.menuToggleTitle == "Toggle Current App")
        #expect(!missing.canToggle)
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
        #expect(forcedMirror.proofButtonTitle == "Start App Proof")
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
    }

    @Test("Accessibility permission copy says what the app reads and keeps local")
    func accessibilityPermissionCopySaysWhatTheAppReadsAndKeepsLocal() {
        let needed = SettingsPermissionState(isTrusted: false)

        #expect(needed.statusText == "Accessibility permission: needed")
        #expect(
            needed.detailText
                == "Allow Accessibility so Autocomplete Lab can read the active text field, find the cursor, and insert accepted suggestions. Text stays on this Mac."
        )

        let allowed = SettingsPermissionState(isTrusted: true)

        #expect(allowed.statusText == "Accessibility permission: allowed")
        #expect(
            allowed.detailText
                == "Autocomplete Lab can read the active text field and insert accepted suggestions. Text stays on this Mac."
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
            privacy.learningStatusText
                == "Learning: accepted-kept scores, style sketch, and recent words stay local"
        )
        #expect(
            privacy.screenRecordingPermissionText
                == "Screen Recording: only used for placement screenshots while this debug switch is on."
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
        #expect(paused.screenRecordingPermissionText == nil)
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
                == "Allow Accessibility so the app can read the active text field, find the cursor, and insert only what you accept. Text stays on this Mac."
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
}
