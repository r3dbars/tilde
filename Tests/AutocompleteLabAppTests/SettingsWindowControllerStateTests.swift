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
        let controller = makeController()

        #expect(controller.usesScrollableSettingsContent)
        #expect(controller.preferredSettingsContentSize.height == 680)
        #expect(controller.minimumSettingsContentSize.height == 420)
        #expect(controller.minimumSettingsContentSize.height < controller.preferredSettingsContentSize.height)
    }

    @Test("Current app copy stays plain about whether suggestions work")
    func currentAppCopyStaysPlainAboutWhetherSuggestionsWork() {
        let store = CompatibilityProfileStore.mvp
        let allowed = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(allowed.statusText == "TextEdit: suggestions on")
        #expect(
            allowed.detailText
                == "Verified suggestions near the cursor and native text insertion. Suggestions are on for this app."
        )
        #expect(allowed.fallbackText == "Suggestions are on in this app.")
        #expect(allowed.toggleTitle == "Suggest while I type here")
        #expect(allowed.menuToggleTitle == "Pause in TextEdit")
        #expect(allowed.blockedAppsText == "No apps are paused.")
        #expect(allowed.canToggle)
        #expect(allowed.canChangePlacement)
        #expect(allowed.placementButtonTitle == "Show in a Floating Box")

        // No shell commands, no "proof", no "green/yellow target" leaks anywhere.
        let leakyTerms = ["AUTOCOMPLETE_LAB", "proof", "green target", "yellow target", "render mode", "denylisted"]
        for text in [allowed.statusText, allowed.detailText, allowed.fallbackText, allowed.toggleTitle, allowed.menuToggleTitle] {
            for term in leakyTerms {
                #expect(!text.localizedCaseInsensitiveContains(term))
            }
        }

        let pausedNotes = SettingsCurrentAppState(
            displayName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            supportStatus: store.supportStatus(for: "com.apple.Notes"),
            isEnabled: false,
            disabledAppCount: 2
        )

        #expect(pausedNotes.statusText == "Notes: suggestions paused")
        #expect(
            pausedNotes.detailText
                == "Rich text can drift; display can use a floating backup, and insertion fails closed. Suggestions are paused here — resume them whenever you like."
        )
        #expect(pausedNotes.fallbackText == "Suggestions are paused in this app.")
        #expect(pausedNotes.menuToggleTitle == "Resume in Notes")
        #expect(pausedNotes.blockedAppsText == "2 apps are paused.")
        #expect(pausedNotes.canToggle)
    }

    @Test("Unsupported and missing current apps read plainly and cannot toggle")
    func unsupportedAndMissingCurrentAppsReadPlainlyAndCannotToggle() {
        let store = CompatibilityProfileStore.mvp
        let diagnosticsOnly = SettingsCurrentAppState(
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            supportStatus: store.supportStatus(for: "com.apple.mail"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(diagnosticsOnly.statusText == "Mail: suggestions aren’t available here")
        #expect(
            diagnosticsOnly.detailText
                == "Mail compose is sensitive and insertion is not proven. Suggestions stay off here."
        )
        #expect(diagnosticsOnly.fallbackText == "Suggestions aren’t available in this app.")
        #expect(diagnosticsOnly.menuToggleTitle == "Suggestions unavailable in Mail")
        #expect(!diagnosticsOnly.canToggle)
        #expect(!diagnosticsOnly.canChangePlacement)

        let unsupported = SettingsCurrentAppState(
            displayName: "Unknown",
            bundleIdentifier: "com.example.UnknownEditor",
            supportStatus: store.supportStatus(for: "com.example.UnknownEditor"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(unsupported.statusText == "Unknown: suggestions paused")
        #expect(
            unsupported.detailText
                == "Default-on generic Accessibility path for apps without a custom profile. Suggestions are paused here — resume them whenever you like."
        )
        #expect(unsupported.menuToggleTitle == "Resume in Unknown")
        #expect(unsupported.blockedAppsText == "1 app is paused.")
        #expect(unsupported.canToggle)

        let missing = SettingsCurrentAppState(
            displayName: "None",
            bundleIdentifier: nil,
            supportStatus: .unsupported,
            isEnabled: false,
            disabledAppCount: 0
        )

        #expect(missing.statusText == "No writing app in front")
        #expect(missing.detailText == "Open a writing app to see whether SteadyType can help there.")
        #expect(missing.fallbackText == "Choose a writing app first.")
        #expect(missing.menuToggleTitle == "Pause Current App")
        #expect(missing.blockedAppsText == "No apps are paused.")
        #expect(!missing.canToggle)
    }

    @Test("Prompt apps can toggle and choose placement without exposing proof tooling")
    func promptAppsCanToggleAndChoosePlacementWithoutExposingProofTooling() {
        let store = CompatibilityProfileStore.mvp
        let claude = SettingsCurrentAppState(
            displayName: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            supportStatus: store.supportStatus(for: "com.anthropic.claudefordesktop"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(claude.statusText == "Claude: suggestions on")
        #expect(claude.menuToggleTitle == "Pause in Claude")
        #expect(claude.canToggle)
        #expect(claude.canChangePlacement)
        #expect(claude.placementButtonTitle == "Show in a Floating Box")

        let forcedClaude = SettingsCurrentAppState(
            displayName: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            supportStatus: store.supportStatus(for: "com.anthropic.claudefordesktop"),
            isEnabled: true,
            disabledAppCount: 0,
            renderModeOverride: .floatingMirror
        )

        #expect(forcedClaude.placementButtonTitle == "Show Inline Text")
        #expect(forcedClaude.canChangePlacement)

        let disabledClaude = SettingsCurrentAppState(
            displayName: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            supportStatus: store.supportStatus(for: "com.anthropic.claudefordesktop"),
            isEnabled: false,
            disabledAppCount: 1
        )

        #expect(disabledClaude.statusText == "Claude: suggestions paused")
        #expect(disabledClaude.menuToggleTitle == "Resume in Claude")
        #expect(disabledClaude.canToggle)
    }

    @Test("Per-app placement copy flips between inline and floating")
    func perAppPlacementCopyFlipsBetweenInlineAndFloating() {
        let store = CompatibilityProfileStore.mvp
        let forcedMirror = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0,
            renderModeOverride: .floatingMirror
        )

        #expect(forcedMirror.placementButtonTitle == "Show Inline Text")
        #expect(forcedMirror.canChangePlacement)

        let profileMode = SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )

        #expect(profileMode.placementButtonTitle == "Show in a Floating Box")
        #expect(profileMode.canChangePlacement)

        let sensitive = SettingsCurrentAppState(
            displayName: "Mail",
            bundleIdentifier: "com.apple.mail",
            supportStatus: store.supportStatus(for: "com.apple.mail"),
            isEnabled: false,
            disabledAppCount: 0
        )

        #expect(!sensitive.canChangePlacement)
    }

    @Test("Accessibility permission copy says what the app reads and keeps local")
    func accessibilityPermissionCopySaysWhatTheAppReadsAndKeepsLocal() {
        let needed = SettingsPermissionState(isTrusted: false)

        #expect(needed.statusText == "Accessibility: needed")
        #expect(
            needed.detailText
                == "SteadyType needs Accessibility so it can see the text field you’re typing in and insert a suggestion only after you accept it. Nothing leaves your Mac. Screen Recording is not needed for everyday use."
        )

        let allowed = SettingsPermissionState(isTrusted: true)

        #expect(allowed.statusText == "Accessibility: allowed")
        #expect(
            allowed.detailText
                == "SteadyType can read the text field you’re typing in and only inserts text after you accept a suggestion. Nothing leaves your Mac. Screen Recording is not needed for everyday use."
        )
    }

    @Test("First run trust copy explains placement controls privacy and app scope")
    func firstRunTrustCopyExplainsPlacementControlsPrivacyAndAppScope() {
        let state = SettingsFirstRunTrustState()

        #expect(state.statusText == "New here? Start in TextEdit")
        #expect(state.detailText.contains("next to your cursor"))
        #expect(state.detailText.contains("Tab to accept one word"))
        #expect(state.detailText.contains("Shift-Tab for the whole visible suggestion"))
        #expect(state.detailText.contains("Esc to dismiss"))
        #expect(state.detailText.contains("Pause Suggestions stops them everywhere"))
        #expect(state.detailText.contains("Pause in Current App stops only that app"))
        #expect(state.quickStartText.contains("60-second path"))
        #expect(state.quickStartText.contains("Start TextEdit Practice"))
        #expect(state.quickStartText.contains("Shift-Tab once"))
        #expect(state.quickStartText.contains("Delete Local Logs"))
        #expect(state.appsText.contains("stays on this Mac"))
        #expect(state.appsText.contains("Start with TextEdit"))
        #expect(state.appsText.contains("Chrome practice pages"))
        #expect(state.appsText.contains("Avoid random websites"))
    }

    @Test("Privacy copy stays plain and local-first")
    func privacyCopyStaysPlainAndLocalFirst() {
        let screenshotsOn = SettingsPrivacyState(
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

        #expect(screenshotsOn.statusText == "Everything stays on your Mac")
        #expect(screenshotsOn.diagnosticsStatusText == "Activity log: on")
        #expect(screenshotsOn.contentStatusText == "Exact text in logs: off")
        #expect(
            screenshotsOn.visiblePageContextStatusText
                == "Reads nearby on-screen text: off. This happens on your Mac and only improves suggestions."
        )
        #expect(
            screenshotsOn.sharingStatusText
                == "Nothing is ever sent automatically. A diagnostic report you choose to export never includes your text or screenshots."
        )
        #expect(
            screenshotsOn.learningStatusText
                == "SteadyType remembers which suggestions you keep — only on this Mac."
        )
        #expect(
            screenshotsOn.localOnlyProofText
                == "Suggestions come from a model that runs entirely on your Mac. There is no server, and exact text is off by default."
        )
        #expect(
            screenshotsOn.screenRecordingPermissionText
                == "Screen Recording: used on your Mac to check where suggestions appear."
        )
        #expect(screenshotsOn.pathText == "Activity log: /tmp/diagnostics.log | Event log: /tmp/traces.jsonl")

        // Make sure the old jargon never reappears.
        let leaky = ["Privacy Bundle", "trace", "OCR", "app-owned", "dogfood", "Justin"]
        for text in [
            screenshotsOn.statusText,
            screenshotsOn.diagnosticsStatusText,
            screenshotsOn.contentStatusText,
            screenshotsOn.visiblePageContextStatusText,
            screenshotsOn.sharingStatusText,
            screenshotsOn.learningStatusText,
            screenshotsOn.localOnlyProofText
        ] {
            for term in leaky {
                #expect(!text.localizedCaseInsensitiveContains(term))
            }
        }

        let pausedRaw = SettingsPrivacyState(
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

        #expect(pausedRaw.diagnosticsStatusText == "Activity log: paused")
        #expect(pausedRaw.contentStatusText == "Exact text in logs: on for a short time")
        #expect(
            pausedRaw.visiblePageContextStatusText
                == "Reads nearby on-screen text: on — waiting for Screen Recording permission."
        )
        #expect(pausedRaw.screenRecordingPermissionText == "Screen Recording: needed to read nearby on-screen text.")

        let allOff = SettingsPrivacyState(
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

        #expect(allOff.screenRecordingPermissionText == nil)
    }

    @Test("Onboarding copy explains first run without private app tests")
    func onboardingCopyExplainsFirstRunWithoutPrivateAppTests() {
        let missingPermission = SettingsOnboardingState(
            isTrusted: false,
            suggestionsPaused: false,
            runtimeGuidance: RuntimeReadinessGuidance(
                report: RuntimeReadinessReport(stage: .ready, summary: "ready", action: .none, isReady: true)
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
                report: RuntimeReadinessReport(stage: .ready, summary: "ready", action: .none, isReady: true)
            )
        )

        #expect(paused.text == "Paused. Resume when you want suggestions.")

        let ready = SettingsOnboardingState(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeGuidance: RuntimeReadinessGuidance(
                report: RuntimeReadinessReport(stage: .ready, summary: "ready", action: .none, isReady: true)
            )
        )

        #expect(ready.text == "Ready: use Practice to open TextEdit, try Tab for one word, Shift-Tab for the whole visible suggestion, press Esc to dismiss, then pause or delete local logs.")
        #expect(!ready.text.localizedCaseInsensitiveContains("Notes"))
    }

    @MainActor
    @Test("Settings local model detail shows runtime guidance")
    func settingsLocalModelDetailShowsRuntimeGuidance() {
        _ = NSApplication.shared
        let controller = makeController()

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
            currentApp: textEditState,
            fieldControl: activeFieldState,
            privacy: offPrivacyState,
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .shiftTab),
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

        #expect(missingModel.statusText == "Practice: on-device model not ready")
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
        #expect(ready.stepsText.localizedCaseInsensitiveContains("Shift-Tab once"))
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

        #expect(missing.statusText == "Current field: nothing selected yet")
        #expect(missing.detailText == "Click into a writing field to silence just that field.")
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
        let shiftTab = SettingsKeyboardShortcutState(acceptAllShortcut: .shiftTab)

        #expect(shiftTab.statusText == "Tab accepts one word. Esc dismisses. Control-Backtick asks for a suggestion.")
        #expect(shiftTab.acceptAllStatusText == "Shift-Tab accepts the whole suggestion.")
        #expect(shiftTab.conflictText == "Conflict check: choose an app")
        #expect(shiftTab.perAppProfileText == "Per-app profile: choose an app to check whole-suggestion accept.")
        #expect(shiftTab.acceptAllPickerLabel == "Accept the whole suggestion with:")
        #expect(shiftTab.cycleButtonTitle == "Use Option-Tab")

        let optionTab = SettingsKeyboardShortcutState(acceptAllShortcut: .optionTab)

        #expect(optionTab.acceptAllStatusText == "Option-Tab accepts the whole suggestion.")
        #expect(optionTab.conflictDetailText == "Open a writing app to check the shortcut against that app profile.")
        #expect(optionTab.cycleButtonTitle == "Turn Off")

        let disabled = SettingsKeyboardShortcutState(acceptAllShortcut: .disabled)
        #expect(disabled.acceptAllStatusText == "Accepting the whole suggestion is off.")
        #expect(disabled.cycleButtonTitle == "Use Shift-Tab")

        let store = CompatibilityProfileStore.mvp
        let textEdit = SettingsKeyboardShortcutState(
            acceptAllShortcut: .shiftTab,
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
    }

    @Test("Trust state gathers local privacy current surface and why copy")
    func trustStateGathersLocalPrivacyCurrentSurfaceAndWhyCopy() {
        let trust = SettingsTrustState(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: readyRuntimeReport,
            currentApp: textEditState,
            privacy: offPrivacyState,
            lastSuggestionDecision: "Waiting: cadence policy"
        )

        #expect(trust.statusText == "SteadyType is on")
        #expect(trust.localModeText == "On-device model: ready.")
        #expect(trust.typedTextText == "Your text: never stored unless you turn it on.")
        #expect(trust.currentSurfaceText == "TextEdit: suggestions on")
        #expect(trust.whyText == "Why now: Waiting: cadence policy")

        let rawCapture = SettingsTrustState(
            isTrusted: true,
            suggestionsPaused: true,
            runtimeReport: readyRuntimeReport,
            currentApp: textEditState,
            privacy: SettingsPrivacyState(
                tracingPaused: false,
                rawContentTracingEnabled: true,
                rawContentTracingExpiresAt: nil,
                screenshotTracingEnabled: false,
                screenshotTracingExpiresAt: nil,
                visiblePageContextEnabled: false,
                screenCaptureAccessGranted: false,
                diagnosticsPath: "/tmp/diagnostics.log",
                tracePath: "/tmp/traces.jsonl"
            ),
            lastSuggestionDecision: "Paused"
        )

        #expect(rawCapture.statusText == "Suggestions are paused")
        #expect(rawCapture.typedTextText == "Your text: a local journal or detailed log is on.")
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

        #expect(feedback.statusText == "Feedback shares a redacted report only")
        #expect(
            feedback.detailText
                == "Use this to send beta feedback. The report leaves out your text, prompts, accepted suggestions, and screenshots."
        )
        #expect(feedback.buttonTitle == "Export Diagnostic Report…")
    }

    @Test("Suggestion tuning copy reads in plain language")
    func suggestionTuningCopyReadsInPlainLanguage() {
        let quiet = SettingsSuggestionAggressivenessState(aggressiveness: .quiet)
        let normal = SettingsSuggestionAggressivenessState(tuning: SuggestionTuning(aggressivenessLevel: 2, maxVisibleWords: 12))
        let max = SettingsSuggestionAggressivenessState(tuning: SuggestionTuning(aggressivenessLevel: 5, maxVisibleWords: 20))

        #expect(quiet.statusText == "How eager: Quiet")
        #expect(quiet.detailText == "Fewer suggestions. Waits longer.")
        #expect(quiet.maxWordsText == "Longest suggestion: 8 words")
        #expect(quiet.maxWordsDetailText == "Aims for 3–8 words when there’s enough context.")
        #expect(normal.statusText == "How eager: Normal")
        #expect(normal.detailText == "Balanced suggestions.")
        #expect(normal.maxWordsText == "Longest suggestion: 12 words")
        #expect(max.statusText == "How eager: Max")
        #expect(max.maxWordsText == "Longest suggestion: 20 words")
        #expect(max.maxWordsDetailText == "Aims for 12–20 words when there’s enough context.")
        #expect(max.wordStartText == "Show word hints after: 2 letters")
        #expect(max.wordStartDetailText == "Lower shows word suggestions sooner.")
        #expect(max.phraseStartText == "Show phrase hints after: 2 words")
        #expect(max.phraseStartDetailText == "Lower offers longer phrase suggestions with less context.")
        #expect(max.responseSpeedText == "Suggestion delay: Instant")
        #expect(max.responseSpeedDetailText == "Higher shows suggestions sooner; lower waits for a clearer pause.")
        #expect(max.confidenceText == "How sure before showing: Loose")
        #expect(max.confidenceDetailText == "Looser shows more guesses; stricter shows fewer.")
        #expect(max.learningRestraintText == "Influence of your history: Low")
        #expect(
            max.learningRestraintDetailText
                == "Higher means suggestions you’ve ignored before are more likely to stay hidden."
        )
        #expect(max.aggressivenessSliderValue == 5)
        #expect(max.maxWordsSliderValue == 20)
        #expect(max.wordStartSliderValue == 2)
        #expect(max.phraseStartSliderValue == 2)
        #expect(max.responseSpeedSliderValue == 5)
        #expect(max.confidenceSliderValue == 4)
        #expect(max.learningRestraintSliderValue == 1)
    }

    @Test("Suggestion decision copy explains quiet waiting visible and local thinking states")
    func suggestionDecisionCopyExplainsStates() {
        let blocked = SettingsSuggestionDecisionState("Blocked: display score accepted-and-kept-low")
        #expect(blocked.statusText == "Right now: quiet")
        #expect(
            blocked.detailText
                == "Quiet because display score accepted-and-kept-low. Keep typing and it’ll pick back up."
        )

        let waiting = SettingsSuggestionDecisionState("Waiting: AX cooldown")
        #expect(waiting.statusText == "Right now: getting ready")
        #expect(waiting.detailText == "Getting ready: AX cooldown. This keeps suggestions from jumping around.")

        let queued = SettingsSuggestionDecisionState("Queued: model word completion")
        #expect(queued.statusText == "Right now: thinking on your Mac")
        #expect(queued.detailText == "Thinking on your Mac. Your text never leaves it.")

        let shown = SettingsSuggestionDecisionState("Shown: private phrase should not be repeated")
        #expect(shown.statusText == "Right now: showing a suggestion")
        #expect(shown.detailText == "A suggestion is next to your cursor. Tab accepts one word; Shift-Tab accepts the whole visible suggestion; Esc dismisses.")

        let ready = SettingsSuggestionDecisionState("")
        #expect(ready.statusText == "Right now: ready")
        #expect(ready.detailText == "Ready as soon as you type in a supported field.")

        let acceptedUndo = SettingsSuggestionDecisionState("Accepted insertion undone")
        #expect(acceptedUndo.statusText == "Right now: accepted")
        #expect(
            acceptedUndo.detailText
                == "Accepted. SteadyType will look for the next suggestion once the field settles."
        )
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
            requestPermission: { permissionCount += 1 },
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: { pauseCount += 1 },
            silenceCurrentField: {},
            performRuntimeAction: { runtimeActions.append($0) },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            startCurrentAppProof: {},
            startTextEditPractice: { practiceStartCount += 1 },
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
            toggleVisiblePageContext: {},
            deleteLocalLogs: { deleteCount += 1 },
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

    // MARK: - Helpers

    @MainActor
    private func makeController() -> SettingsWindowController {
        SettingsWindowController(
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
    }

    private var textEditState: SettingsCurrentAppState {
        SettingsCurrentAppState(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            isEnabled: true,
            disabledAppCount: 0
        )
    }

    private var activeFieldState: SettingsFieldControlState {
        SettingsFieldControlState(
            appDisplayName: "TextEdit",
            hasFieldTarget: true,
            isCurrentField: true,
            isSilenced: false
        )
    }

    private var offPrivacyState: SettingsPrivacyState {
        SettingsPrivacyState(
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
            currentApp: textEditState,
            fieldControl: activeFieldState,
            practice: practice,
            privacy: offPrivacyState,
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .shiftTab),
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
