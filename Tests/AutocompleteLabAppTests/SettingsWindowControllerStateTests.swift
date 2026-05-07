import Testing
@testable import AutocompleteLabApp

@Suite("Settings window control state")
struct SettingsWindowControllerStateTests {
    @Test("Current app copy makes allowlist and blocked state clear")
    func currentAppCopyMakesAllowlistAndBlockedStateClear() {
        let allowed = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            isSupported: true,
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(allowed.statusText == "Current app: TextEdit is allowed")
        #expect(allowed.detailText == "On the test allowlist. Turn it off here if it gets annoying.")
        #expect(allowed.blockedAppsText == "Blocked apps: none")
        #expect(allowed.canToggle)

        let blocked = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            isSupported: true,
            isEnabled: false,
            disabledAppCount: 2
        )

        #expect(blocked.statusText == "Current app: TextEdit is blocked")
        #expect(blocked.detailText == "This app is in your blocked-app list.")
        #expect(blocked.blockedAppsText == "Blocked apps: 2")
        #expect(blocked.canToggle)
    }

    @Test("Unsupported or missing current app cannot be toggled")
    func unsupportedOrMissingCurrentAppCannotBeToggled() {
        let unsupported = SettingsCurrentAppState(
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            isSupported: false,
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(unsupported.statusText == "Current app: Mail is not on the test allowlist")
        #expect(unsupported.detailText == "Suggestions stay off until this app is added to the test allowlist.")
        #expect(!unsupported.canToggle)

        let missing = SettingsCurrentAppState(
            displayName: "None",
            bundleIdentifier: nil,
            isSupported: false,
            isEnabled: false,
            disabledAppCount: 0
        )

        #expect(missing.statusText == "Current app: no supported app selected")
        #expect(missing.detailText == "Open a supported writing app to control it here.")
        #expect(!missing.canToggle)
    }

    @Test("Privacy copy exposes diagnostics and raw content state")
    func privacyCopyExposesDiagnosticsAndRawContentState() {
        let privacy = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            screenshotTracingEnabled: true,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(privacy.statusText == "Privacy: local diagnostics only")
        #expect(
            privacy.diagnosticsStatusText
                == "Diagnostics: performance + placement traces recording, screenshots on"
        )
        #expect(privacy.contentStatusText == "Raw text capture: off")
        #expect(privacy.pathText == "Logs: /tmp/diagnostics.log | Traces: /tmp/traces.jsonl")

        let paused = SettingsPrivacyState(
            tracingPaused: true,
            rawContentTracingEnabled: true,
            screenshotTracingEnabled: false,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            paused.diagnosticsStatusText
                == "Diagnostics: performance + placement traces paused, screenshots off"
        )
        #expect(paused.contentStatusText == "Raw text capture: on")
    }
}
