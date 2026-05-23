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
        #expect(style.preferredContentSize.width == 560)
        #expect(style.preferredContentSize.height == 680)
        #expect(style.minimumContentSize.width == 540)
        #expect(style.minimumContentSize.height == 420)
        #expect(style.visibleScreenInset == 32)
        #expect(style.secondaryLabelMaxWidth == 470)
    }

    @MainActor
    @Test("Settings content scrolls inside a shorter window")
    func settingsContentScrollsInsideShorterWindow() {
        _ = NSApplication.shared
        let controller = SettingsWindowController(
            requestPermission: {},
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: {},
            silenceCurrentField: {},
            performRuntimeAction: { _ in },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            startCurrentAppProof: {},
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
            toggleVisiblePageContext: {},
            deleteLocalLogs: {},
            clearLearningData: {},
            cycleAcceptAllShortcut: {},
            setAcceptAllShortcut: { _ in },
            setSuggestionAggressivenessLevel: { _ in },
            setSuggestionMaxVisibleWords: { _ in }
        )

        #expect(controller.usesScrollableSettingsContent)
        #expect(controller.preferredSettingsContentSize.height == 680)
        #expect(controller.minimumSettingsContentSize.height == 420)
        #expect(controller.minimumSettingsContentSize.height < controller.preferredSettingsContentSize.height)
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
                == "Verified suggestions near the cursor and native text insertion. Suggestions are on for this app."
        )
        #expect(allowed.modeText == "Mode: next to the cursor, floating backup fallback")
        #expect(
            allowed.acceptanceText
                == "Keys: Tab accepts one word + space. Press Tab again for the next word. Whole-suggestion shortcut works here."
        )
        #expect(allowed.fallbackText == "Fallback: not needed; cursor placement is available.")
        #expect(allowed.proofText == "Check: use disposable text, press Tab once, then the whole-suggestion shortcut.")
        #expect(allowed.proofCommandText == "Check command: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit")
        #expect(allowed.proofCommandClipboardText == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit")
        #expect(allowed.copyProofCommandButtonTitle == "Copy Check Command")
        #expect(allowed.canCopyProofCommand)
        #expect(allowed.proofButtonTitle == "Check TextEdit")
        #expect(allowed.shouldShowCheckControls)
        #expect(allowed.toggleTitle == "Suggestions in this app")
        #expect(allowed.menuToggleTitle == "Pause in TextEdit")
        #expect(allowed.blockedAppsText == "Paused apps: none")
        #expect(allowed.canToggle)

        let chrome = SettingsCurrentAppState(
            displayName: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            supportStatus: store.supportStatus(for: "com.google.Chrome"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(chrome.proofButtonTitle == "Check Chrome")
        #expect(
            chrome.proofCommandText
                == "Manual checks: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea; AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable"
        )
        #expect(
            chrome.proofCommandClipboardText
                == """
                AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea
                AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable
                """
        )
        #expect(chrome.canStartProof)
        #expect(chrome.shouldShowCheckControls)

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
                == "Rich text can drift; display can use a floating backup, and insertion fails closed. Suggestions are paused in this app. Resume only where you want suggestions."
        )
        #expect(blocked.modeText == "Mode: next to the cursor, floating backup fallback")
        #expect(
            blocked.acceptanceText
                == "Keys: Tab accepts one word + space. Press Tab again for the next word. Whole-suggestion shortcut works here."
        )
        #expect(blocked.fallbackText == "Fallback: off while this app is paused.")
        #expect(blocked.proofText == "Check: turn on suggestions for this app first.")
        #expect(blocked.proofCommandText == nil)
        #expect(blocked.proofCommandClipboardText == nil)
        #expect(blocked.copyProofCommandButtonTitle == "No Check Command")
        #expect(!blocked.canCopyProofCommand)
        #expect(blocked.shouldShowCheckControls)
        #expect(blocked.menuToggleTitle == "Resume in Notes")
        #expect(blocked.blockedAppsText == "Paused apps: 2")
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
        #expect(diagnosticsOnly.proofText == "Check: unavailable here.")
        #expect(diagnosticsOnly.proofCommandText == nil)
        #expect(diagnosticsOnly.proofCommandClipboardText == nil)
        #expect(!diagnosticsOnly.canCopyProofCommand)
        #expect(diagnosticsOnly.menuToggleTitle == "Suggestions unavailable in Mail")
        #expect(!diagnosticsOnly.canToggle)

        let claudeCode = SettingsCurrentAppState(
            displayName: "Claude Code",
            bundleIdentifier: "com.anthropic.claude-code",
            supportStatus: store.supportStatus(for: "com.anthropic.claude-code"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(claudeCode.statusText == "Current app: Claude Code is diagnostics-only")
        #expect(
            claudeCode.detailText
                == "The installed Claude Code bundle is a background-only CLI helper; interactive Claude Code typing usually happens inside a terminal host, which is blocked until a separate safe adapter exists. Suggestions stay off here."
        )
        #expect(claudeCode.proofText == "Check: unavailable here.")
        #expect(claudeCode.proofCommandText == nil)
        #expect(!claudeCode.canToggle)

        let unsupported = SettingsCurrentAppState(
            displayName: "Unknown",
            bundleIdentifier: "com.example.UnknownEditor",
            supportStatus: store.supportStatus(for: "com.example.UnknownEditor"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(unsupported.statusText == "Current app: Unknown is unsupported")
        #expect(unsupported.detailText == "No compatibility profile yet. Suggestions stay off here.")
        #expect(unsupported.modeText == "Mode: not set up here")
        #expect(unsupported.acceptanceText == "Acceptance: off here")
        #expect(unsupported.fallbackText == "Fallback: unavailable until this app has a profile.")
        #expect(unsupported.proofText == "Check: unavailable here.")
        #expect(unsupported.proofCommandText == nil)
        #expect(unsupported.proofCommandClipboardText == nil)
        #expect(!unsupported.canCopyProofCommand)
        #expect(unsupported.menuToggleTitle == "Suggestions unavailable in Unknown")
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
        #expect(missing.proofText == "Check: choose a writing app first.")
        #expect(missing.proofCommandText == nil)
        #expect(missing.proofCommandClipboardText == nil)
        #expect(!missing.canCopyProofCommand)
        #expect(missing.menuToggleTitle == "Pause Current App")
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
        #expect(safari.fallbackText == "Fallback: copy-only; cursor placement and auto-insert stay off until testing passes.")
        #expect(safari.proofText == "Check: unavailable here.")
        #expect(!safari.canToggle)
    }

    @Test("Codex prompt app exposes one-word no-submit proof controls")
    func codexPromptAppExposesOneWordNoSubmitProofControls() {
        let store = CompatibilityProfileStore.mvp
        let codex = SettingsCurrentAppState(
            displayName: "Codex",
            bundleIdentifier: "com.openai.codex",
            supportStatus: store.supportStatus(for: "com.openai.codex"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(codex.statusText == "Current app: Codex is yellow and on")
        #expect(
            codex.detailText
                == "Codex prompt support is on for this installed app: one-word suggestions, no whole-suggestion accept, and prompt safety gates stay on. Suggestions are on for this app."
        )
        #expect(codex.modeText == "Mode: next to the cursor, floating backup fallback")
        #expect(
            codex.acceptanceText
                == "Keys: Tab accepts one word + space. Press Tab again for the next word. Whole-suggestion accept is off for safety."
        )
        #expect(codex.proofText == "Check: use the guided prompt-app check, press Tab once, and do not press Enter.")
        #expect(
            codex.proofCommandText
                == "Manual check: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
        )
        #expect(
            codex.proofCommandClipboardText
                == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
        )
        #expect(codex.canCopyProofCommand)
        #expect(codex.toggleTitle == "Suggestions in this app")
        #expect(codex.menuToggleTitle == "Pause in Codex")
        #expect(codex.canOverrideMode)
        #expect(codex.canToggle)

        let forcedCodex = SettingsCurrentAppState(
            displayName: "Codex",
            bundleIdentifier: "com.openai.codex",
            supportStatus: store.supportStatus(for: "com.openai.codex"),
            isEnabled: true,
            disabledAppCount: 0,
            renderModeOverride: .floatingMirror
        )

        #expect(forcedCodex.modeButtonTitle == "Use Default Placement")
        #expect(forcedCodex.canOverrideMode)

        let disabledCodex = SettingsCurrentAppState(
            displayName: "Codex",
            bundleIdentifier: "com.openai.codex",
            supportStatus: store.supportStatus(for: "com.openai.codex"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(disabledCodex.statusText == "Current app: Codex is yellow and off")
        #expect(
            disabledCodex.detailText
                == "Codex prompt support is on for this installed app: one-word suggestions, no whole-suggestion accept, and prompt safety gates stay on. Suggestions are paused in this app. Resume only where you want suggestions."
        )
        #expect(disabledCodex.proofText == "Check: turn on suggestions for this app first.")
        #expect(disabledCodex.proofButtonTitle == "Enable Suggestions First")
        #expect(disabledCodex.proofCommandText == nil)
        #expect(disabledCodex.proofCommandClipboardText == nil)
        #expect(disabledCodex.menuToggleTitle == "Resume in Codex")
        #expect(disabledCodex.canToggle)
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

        #expect(forcedMirror.modeText == "Mode: floating backup forced (profile next to the cursor)")
        #expect(forcedMirror.modeButtonTitle == "Use Default Placement")
        #expect(forcedMirror.canOverrideMode)
        #expect(forcedMirror.proofButtonTitle == "Check TextEdit")
        #expect(forcedMirror.canStartProof)

        let profileMode = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(profileMode.modeButtonTitle == "Use Floating Backup")
        #expect(profileMode.canOverrideMode)
        #expect(profileMode.proofButtonTitle == "Check TextEdit")
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

        #expect(disabled.proofButtonTitle == "Enable Suggestions First")
        #expect(!disabled.canStartProof)
        #expect(!disabled.canCopyProofCommand)
    }

    @Test("Accessibility permission copy says what the app reads and keeps local")
    func accessibilityPermissionCopySaysWhatTheAppReadsAndKeepsLocal() {
        let needed = SettingsPermissionState(isTrusted: false)

        #expect(needed.statusText == "Accessibility permission: needed")
        #expect(
            needed.detailText
                == "Click Allow Accessibility when you are ready. macOS asks so SteadyType can read the focused text field and insert only after you accept. Text stays on this Mac. Screen Recording is not needed for normal use."
        )

        let allowed = SettingsPermissionState(isTrusted: true)

        #expect(allowed.statusText == "Accessibility permission: allowed")
        #expect(
            allowed.detailText
                == "SteadyType can read the focused text field and insert only after you accept. Text stays on this Mac. Screen Recording is not needed for normal use."
        )
    }

    @Test("First run trust copy explains placement controls privacy and app scope")
    func firstRunTrustCopyExplainsPlacementControlsPrivacyAndAppScope() {
        let state = SettingsFirstRunTrustState()

        #expect(state.statusText == "First run: practice in TextEdit")
        #expect(state.detailText.contains("near the cursor"))
        #expect(state.detailText.contains("Tab accepts one word"))
        #expect(state.detailText.contains("Esc dismisses"))
        #expect(state.detailText.contains("Pause Suggestions stops suggestions everywhere"))
        #expect(state.detailText.contains("Pause in Current App stops only that app"))
        #expect(state.appsText.contains("Text stays on this Mac"))
        #expect(state.appsText.contains("Start with TextEdit"))
        #expect(state.appsText.contains("Chrome practice pages"))
        #expect(state.appsText.contains("Avoid random websites"))
    }

    @Test("Privacy copy exposes diagnostics and raw content state")
    func privacyCopyExposesDiagnosticsAndRawContentState() {
        let privacy = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            rawContentTracingExpiresAt: nil,
            screenshotTracingEnabled: true,
            screenshotTracingExpiresAt: nil,
            visiblePageContextEnabled: false,
            screenCaptureAccessGranted: true,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(privacy.statusText == "Privacy: stays on this Mac")
        #expect(
            privacy.diagnosticsStatusText
                == "Local check data: recording, screenshots on"
        )
        #expect(privacy.contentStatusText == "Raw text in local logs: off")
        #expect(privacy.visiblePageContextStatusText == "Screen context: off. OCR is local and only helps suggestions.")
        #expect(
            privacy.sharingStatusText
                == "Nothing leaves automatically. Share Privacy Bundles, not raw logs or screenshots."
        )
        #expect(
            privacy.learningStatusText
                == "Learning: local usefulness scores only"
        )
        #expect(
            privacy.screenRecordingPermissionText
                == "Screen Recording: used only for local placement screenshots while enabled."
        )
        #expect(privacy.pathText == "Diagnostics log: /tmp/diagnostics.log | Check data: /tmp/traces.jsonl")

        let paused = SettingsPrivacyState(
            tracingPaused: true,
            rawContentTracingEnabled: true,
            rawContentTracingExpiresAt: Date(timeIntervalSince1970: 1_000),
            screenshotTracingEnabled: false,
            screenshotTracingExpiresAt: nil,
            visiblePageContextEnabled: true,
            screenCaptureAccessGranted: false,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            paused.diagnosticsStatusText
                == "Local check data: paused, screenshots off"
        )
        #expect(paused.contentStatusText == "Raw text in local logs: on temporarily")
        #expect(paused.visiblePageContextStatusText == "Screen context: on, waiting for Screen Recording permission.")
        #expect(
            paused.sharingStatusText
                == "Nothing leaves automatically. Share Privacy Bundles, not raw logs or screenshots."
        )
        #expect(paused.screenRecordingPermissionText == "Screen Recording: required for screen context.")

        let temporaryScreenshots = SettingsPrivacyState(
            tracingPaused: false,
            rawContentTracingEnabled: false,
            rawContentTracingExpiresAt: nil,
            screenshotTracingEnabled: true,
            screenshotTracingExpiresAt: Date(timeIntervalSince1970: 2_000),
            visiblePageContextEnabled: false,
            screenCaptureAccessGranted: true,
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
            visiblePageContextEnabled: false,
            screenCaptureAccessGranted: false,
            diagnosticsPath: "/tmp/diagnostics.log",
            tracePath: "/tmp/traces.jsonl"
        )

        #expect(
            shareSafe.sharingStatusText
                == "Nothing leaves automatically. Privacy Bundles exclude raw text and screenshots."
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
                == "Allow Accessibility so suggestions can appear near the cursor and insert only when you accept. Text stays on this Mac."
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

        #expect(paused.text == "Paused. Resume when you want suggestions.")

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

        #expect(ready.text == "Ready: use Practice to open TextEdit, try Tab for one word, press Esc to dismiss, then pause or delete local logs.")
        #expect(!ready.text.localizedCaseInsensitiveContains("Notes"))
    }

    @MainActor
    @Test("Settings local model detail shows runtime guidance")
    func settingsLocalModelDetailShowsRuntimeGuidance() {
        _ = NSApplication.shared
        let controller = SettingsWindowController(
            requestPermission: {},
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: {},
            silenceCurrentField: {},
            performRuntimeAction: { _ in },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            startCurrentAppProof: {},
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
            toggleVisiblePageContext: {},
            deleteLocalLogs: {},
            clearLearningData: {},
            cycleAcceptAllShortcut: {},
            setAcceptAllShortcut: { _ in },
            setSuggestionAggressivenessLevel: { _ in },
            setSuggestionMaxVisibleWords: { _ in }
        )

        controller.refresh(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                detail: "short detail",
                action: .installModel,
                isReady: false
            ),
            runtimeTargetSummary: "Qwen local - short completions - normal",
            modelDirectoryPath: "/tmp/SteadyType/Models",
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
                visiblePageContextEnabled: false,
                screenCaptureAccessGranted: false,
                diagnosticsPath: "/tmp/diagnostics.log",
                tracePath: "/tmp/traces.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .backtick),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(tuning: SuggestionTuning()),
            lastSuggestionDecision: "Blocked"
        )

        #expect(controller.runtimeDetailTextForTesting.contains("pinned Hugging Face revision"))
        #expect(controller.runtimeDetailTextForTesting.contains("You do not need Ollama or a model server"))
        #expect(controller.runtimeDetailTextForTesting.contains("Runtime detail: short detail"))
        #expect(controller.runtimeDetailTextForTesting.contains("Suggestions stay off"))
    }

    @Test("Practice state guides safe TextEdit smoke")
    func practiceStateGuidesSafeTextEditSmoke() {
        let missingPermission = SettingsPracticeState(
            isTrusted: false,
            suggestionsPaused: false,
            runtimeReport: readyRuntimeReport,
            isModelInstallInProgress: false,
            isTextEditEnabled: false
        )

        #expect(missingPermission.statusText == "Practice: allow Accessibility first")
        #expect(missingPermission.primaryButtonTitle == "Allow Accessibility")
        #expect(missingPermission.primaryAction == .requestAccessibility)
        #expect(missingPermission.isPrimaryButtonEnabled)

        let missingModel = SettingsPracticeState(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                action: .installModel,
                isReady: false
            ),
            isModelInstallInProgress: false,
            isTextEditEnabled: false
        )

        #expect(missingModel.statusText == "Practice: local model not ready")
        #expect(missingModel.primaryAction == .performRuntimeAction(.installModel))
        #expect(missingModel.primaryButtonTitle == "Install Local Model")

        let ready = SettingsPracticeState(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: readyRuntimeReport,
            isModelInstallInProgress: false,
            isTextEditEnabled: false
        )

        #expect(ready.statusText == "Practice: ready in TextEdit")
        #expect(ready.textEditText == "TextEdit: will be enabled for this practice")
        #expect(ready.primaryAction == .openTextEditPractice)
        #expect(ready.primaryButtonTitle == "Start TextEdit Practice")
        #expect(ready.detailText.localizedCaseInsensitiveContains("near the cursor"))
        #expect(ready.detailText.localizedCaseInsensitiveContains("No Screen Recording needed"))
        #expect(ready.stepsText.localizedCaseInsensitiveContains("Tab once"))
        #expect(ready.stepsText.localizedCaseInsensitiveContains("Esc"))
        #expect(ready.stepsText.localizedCaseInsensitiveContains("delete local logs"))
    }

    @Test("Practice model line exposes missing corrupt and unlinked runtime detail")
    func practiceModelLineExposesRuntimeFailureDetail() {
        let reports = [
            RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                detail: "The local model is not installed yet. Expected folder: /tmp/SteadyType/model",
                action: .installModel
            ),
            RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: "model folder needs repair",
                detail: "The local model folder is incomplete: missing tokenizer.json. Folder: /tmp/SteadyType/model",
                action: .repairModel
            ),
            RuntimeReadinessReport(
                stage: .runtimeUnavailable,
                summary: "runtime unavailable (MLX)",
                detail: "This build is missing its local model engine. A separate model server will not fix it.",
                action: .none
            )
        ]

        for report in reports {
            let state = SettingsPracticeState(
                isTrusted: true,
                suggestionsPaused: false,
                runtimeReport: report,
                isModelInstallInProgress: false,
                isTextEditEnabled: true
            )

            #expect(state.modelText.contains(report.summary))
            #expect(state.modelText.contains(report.detail ?? ""))
            #expect(state.modelText.contains("Runtime detail:"))
        }
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

        #expect(backtick.statusText == "Shortcuts: Tab accepts one word + space | Backtick accepts whole suggestion")
        #expect(backtick.conflictText == "Conflict check: choose an app")
        #expect(backtick.perAppProfileText == "Per-app profile: choose an app to check whole-suggestion accept.")
        #expect(backtick.acceptAllPickerLabel == "Whole suggestion:")
        #expect(backtick.cycleButtonTitle == "Use Option-Tab")

        let optionTab = SettingsKeyboardShortcutState(acceptAllShortcut: .optionTab)

        #expect(optionTab.statusText == "Shortcuts: Tab accepts one word + space | Option-Tab accepts whole suggestion")
        #expect(optionTab.conflictDetailText == "Open a writing app to check the shortcut against that app profile.")
        #expect(optionTab.acceptAllPickerLabel == "Whole suggestion:")
        #expect(optionTab.cycleButtonTitle == "Use Backtick")

        let store = CompatibilityProfileStore.mvp
        let textEdit = SettingsKeyboardShortcutState(
            acceptAllShortcut: .backtick,
            currentApp: SettingsCurrentAppState(
                displayName: "TextEdit",
                bundleIdentifier: "com.apple.TextEdit",
                supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
                isEnabled: true,
                disabledAppCount: 0
            )
        )
        #expect(textEdit.conflictText == "Conflict check: no known conflict in TextEdit")
        #expect(textEdit.perAppProfileText == "Per-app profile: TextEdit allows Tab one-word accept and whole-suggestion accept.")

        let codex = SettingsKeyboardShortcutState(
            acceptAllShortcut: .backtick,
            currentApp: SettingsCurrentAppState(
                displayName: "Codex",
                bundleIdentifier: "com.openai.codex",
                supportStatus: store.supportStatus(for: "com.openai.codex"),
                isEnabled: true,
                disabledAppCount: 0
            )
        )
        #expect(codex.conflictText == "Conflict check: whole-suggestion accept is off in Codex")
        #expect(codex.perAppProfileText == "Per-app profile: Codex allows Tab one-word accept only.")
    }

    @Test("Pause state copy stays shared across surfaces")
    func pauseStateCopyStaysSharedAcrossSurfaces() throws {
        let ready = ControlPauseState(isPaused: false, pausedUntil: nil)

        #expect(ready.statusName == "running")
        #expect(ready.statusText == "Suggestion pause: off")
        #expect(ready.settingsSummaryText == "Suggestions: on")
        #expect(ready.settingsDetailText == "Suggestions are on. You can still pause one app or one field.")
        #expect(ready.toggleTitle == "Pause Suggestions")

        let until = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 9,
            hour: 9,
            minute: 0
        )))
        let paused = ControlPauseState(
            isPaused: true,
            pausedUntil: until,
            now: until.addingTimeInterval(-60)
        )

        #expect(paused.statusName == "paused")
        #expect(paused.statusText.contains("Suggestion pause: until"))
        #expect(paused.settingsSummaryText.contains("Suggestions: paused until"))
        #expect(paused.menuPausedTitle.contains("Paused until"))
        #expect(paused.toggleTitle == "Resume Suggestions")
    }

    @Test("Feedback copy stays redacted for beta")
    func feedbackCopyStaysRedactedForBeta() {
        let feedback = SettingsFeedbackState()

        #expect(feedback.statusText == "Feedback: redacted Privacy Bundle only")
        #expect(
            feedback.detailText
                == "Use this for beta feedback. It excludes raw text, prompts, accepted text, and screenshots."
        )
        #expect(feedback.buttonTitle == "Export Privacy Bundle")
    }

    @Test("Suggestion tuning copy supports sliders")
    func suggestionTuningCopySupportsSliders() {
        let quiet = SettingsSuggestionAggressivenessState(aggressiveness: .quiet)
        let normal = SettingsSuggestionAggressivenessState(tuning: SuggestionTuning(aggressivenessLevel: 2, maxVisibleWords: 4))
        let max = SettingsSuggestionAggressivenessState(tuning: SuggestionTuning(aggressivenessLevel: 5, maxVisibleWords: 8))

        #expect(quiet.statusText == "Suggestions: 1/5 - Quiet")
        #expect(quiet.detailText == "Fewer suggestions. Waits longer.")
        #expect(quiet.maxWordsText == "Words shown: 8")
        #expect(normal.statusText == "Suggestions: 2/5 - Normal")
        #expect(normal.detailText == "Balanced suggestions.")
        #expect(normal.maxWordsText == "Words shown: 4")
        #expect(normal.maxWordsDetailText == "Caps visible phrase suggestions at 4 words.")
        #expect(max.statusText == "Suggestions: 5/5 - Max")
        #expect(max.detailText == "Most active. Shows whenever checks allow.")
        #expect(max.maxWordsText == "Words shown: 8")
        #expect(max.wordStartText == "Word help starts after: 2 letters")
        #expect(max.wordStartDetailText == "Lower means word suggestions show sooner.")
        #expect(max.phraseStartText == "Phrase help starts after: 3 words")
        #expect(max.phraseStartDetailText == "Lower means phrase suggestions need less context.")
        #expect(max.responseSpeedText == "Wait after typing: Normal")
        #expect(max.responseSpeedDetailText == "Higher feels faster. Lower waits for a clearer pause.")
        #expect(max.confidenceText == "Guess strength: Normal")
        #expect(max.confidenceDetailText == "Loose shows more guesses. Strict hides more.")
        #expect(max.learningRestraintText == "Learned caution: Normal")
        #expect(max.learningRestraintDetailText == "Lower lets ignored old suggestions matter less.")
        #expect(max.aggressivenessSliderValue == 5)
        #expect(max.maxWordsSliderValue == 8)
        #expect(max.wordStartSliderValue == 2)
        #expect(max.phraseStartSliderValue == 3)
        #expect(max.responseSpeedSliderValue == 3)
        #expect(max.confidenceSliderValue == 3)
        #expect(max.learningRestraintSliderValue == 2)
    }

    @MainActor
    @Test("Settings practice actions dispatch safe TextEdit flow controls")
    func settingsPracticeActionsDispatchSafeTextEditFlowControls() {
        _ = NSApplication.shared
        var permissionCount = 0
        var runtimeActions: [RuntimeReadinessAction] = []
        var practiceStartCount = 0
        var pauseCount = 0
        var deleteCount = 0
        let controller = SettingsWindowController(
            requestPermission: {
                permissionCount += 1
            },
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: {
                pauseCount += 1
            },
            silenceCurrentField: {},
            performRuntimeAction: {
                runtimeActions.append($0)
            },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            startCurrentAppProof: {},
            startTextEditPractice: {
                practiceStartCount += 1
            },
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
            toggleVisiblePageContext: {},
            deleteLocalLogs: {
                deleteCount += 1
            },
            clearLearningData: {},
            cycleAcceptAllShortcut: {},
            setAcceptAllShortcut: { _ in },
            setSuggestionAggressivenessLevel: { _ in },
            setSuggestionMaxVisibleWords: { _ in }
        )

        refreshPracticeController(
            controller,
            practice: SettingsPracticeState(
                isTrusted: false,
                suggestionsPaused: false,
                runtimeReport: readyRuntimeReport,
                isModelInstallInProgress: false,
                isTextEditEnabled: false
            )
        )
        controller.performPracticePrimaryAction()
        #expect(permissionCount == 1)

        refreshPracticeController(
            controller,
            practice: SettingsPracticeState(
                isTrusted: true,
                suggestionsPaused: false,
                runtimeReport: RuntimeReadinessReport(
                    stage: .downloadNeeded,
                    summary: "download needed",
                    action: .installModel,
                    isReady: false
                ),
                isModelInstallInProgress: false,
                isTextEditEnabled: false
            )
        )
        controller.performPracticePrimaryAction()
        #expect(runtimeActions == [.installModel])

        refreshPracticeController(
            controller,
            practice: SettingsPracticeState(
                isTrusted: true,
                suggestionsPaused: false,
                runtimeReport: readyRuntimeReport,
                isModelInstallInProgress: false,
                isTextEditEnabled: true
            )
        )
        controller.performPracticePrimaryAction()
        #expect(practiceStartCount == 1)

        controller.performPracticePauseAction()
        controller.performPracticeDeleteTracesAction()
        #expect(pauseCount == 1)
        #expect(deleteCount == 1)
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
            toggleVisiblePageContext: {},
            deleteLocalLogs: {},
            clearLearningData: {},
            cycleAcceptAllShortcut: {},
            setAcceptAllShortcut: { _ in },
            setSuggestionAggressivenessLevel: { _ in },
            setSuggestionMaxVisibleWords: { _ in }
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
            modelDirectoryPath: "/tmp/SteadyType/Models",
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
                visiblePageContextEnabled: false,
                screenCaptureAccessGranted: false,
                diagnosticsPath: "/tmp/diagnostics.log",
                tracePath: "/tmp/traces.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .backtick),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(tuning: SuggestionTuning()),
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

    @MainActor
    private func refreshPracticeController(
        _ controller: SettingsWindowController,
        practice: SettingsPracticeState
    ) {
        controller.refresh(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: readyRuntimeReport,
            runtimeTargetSummary: "Qwen local - short completions - normal",
            modelDirectoryPath: "/tmp/SteadyType/Models",
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
            practice: practice,
            privacy: SettingsPrivacyState(
                tracingPaused: false,
                rawContentTracingEnabled: false,
                rawContentTracingExpiresAt: nil,
                screenshotTracingEnabled: false,
                screenshotTracingExpiresAt: nil,
                visiblePageContextEnabled: false,
                screenCaptureAccessGranted: false,
                diagnosticsPath: "/tmp/diagnostics.log",
                tracePath: "/tmp/traces.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .backtick),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(tuning: SuggestionTuning()),
            lastSuggestionDecision: "Shown"
        )
    }
}

private let readyRuntimeReport = RuntimeReadinessReport(
    stage: .ready,
    summary: "ready",
    action: .none,
    isReady: true
)
