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

        #expect(allowed.statusText == "Current app: TextEdit is green and allowed")
        #expect(
            allowed.detailText
                == "Verified inline suggestions and native text insertion. Suggestions are on for this app."
        )
        #expect(allowed.modeText == "Mode: inline, mirror fallback")
        #expect(allowed.acceptanceText == "Acceptance: Tab next word + full accept")
        #expect(
            allowed.safetyText
                == "Safety: Inline when caret proof is trusted; mirror fallback if inline is unsafe."
        )
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

        #expect(blocked.statusText == "Current app: Notes is yellow and blocked")
        #expect(
            blocked.detailText
                == "Rich text can drift; display stays mirror-first and insertion fails closed until each Notes surface is proven. Suggestions are blocked by your app list."
        )
        #expect(blocked.modeText == "Mode: mirror")
        #expect(blocked.acceptanceText == "Acceptance: Tab next word + full accept")
        #expect(
            blocked.safetyText
                == "Safety: Mirror only until caret placement proof is current. Detached field/window suggestions are disabled. Insertion fails closed if the primary method is not verified."
        )
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
        #expect(diagnosticsOnly.safetyText == "Safety: Suggestions stay off here.")
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
        #expect(
            unsupported.safetyText
                == "Safety: Suggestions stay off until this app has a compatibility profile."
        )
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
        #expect(missing.safetyText == "Safety: choose a writing app first")
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

        #expect(codex.modeText == "Mode: mirror")
        #expect(codex.acceptanceText == "Acceptance: Tab next word only; full accept is off for safety")
        #expect(
            codex.safetyText
                == "Safety: Mirror only until caret placement proof is current. Detached field/window suggestions are disabled. Full accept stays off until no-submit proof exists."
        )
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
}
