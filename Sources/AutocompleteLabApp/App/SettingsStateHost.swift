import AppKit
import AutocompleteLabCore
import CoreGraphics

/// Values needed to render Settings are supplied by the app coordinator, while
/// this host owns the state assembly and refresh contract. Keeping this work in
/// one place prevents AppDelegate action handlers from rebuilding privacy and
/// runtime state slightly differently.
@MainActor
struct SettingsStateHostDependencies {
    let appForSettingsState: () -> RunningApplicationInfo?
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let profileSupportStatus: (String) -> CompatibilitySupportStatus
    let disabledBundleIdentifiers: () -> Set<String>
    let renderModeOverride: (String) -> SuggestionRenderMode?
    let fieldControlTarget: () -> FieldControlTarget?
    let isFieldSilenced: (FocusedFieldIdentity) -> Bool
    let isTrusted: () -> Bool
    let suggestionsPaused: () -> Bool
    let suggestionsPausedUntil: () -> Date?
    let runtimeReadinessReport: () -> RuntimeReadinessReport
    let modelDirectoryPath: () -> String
    let modelInstallStatusText: () -> String
    let modelInstallInProgress: () -> Bool
    let isTextEditEnabled: () -> Bool
    let acceptAllShortcut: () -> AcceptAllShortcut
    let tracingPaused: () -> Bool
    let rawContentTracingEnabled: () -> Bool
    let rawContentTracingExpiresAt: () -> Date?
    let screenshotTracingEnabled: () -> Bool
    let screenshotTracingExpiresAt: () -> Date?
    let visiblePageContextEnabled: () -> Bool
    let diagnosticsPath: () -> String
    let tracePath: () -> String
    let suggestionTuning: () -> SuggestionTuning
    let modelName: () -> String
    let completionLengthSummary: () -> String
}

@MainActor
final class SettingsStateHost {
    private let dependencies: SettingsStateHostDependencies

    init(dependencies: SettingsStateHostDependencies) {
        self.dependencies = dependencies
    }

    var currentAppState: SettingsCurrentAppState {
        let disabledBundleIdentifiers = dependencies.disabledBundleIdentifiers()
        guard let app = dependencies.appForSettingsState() else {
            return SettingsCurrentAppState(
                displayName: "None",
                bundleIdentifier: nil,
                supportStatus: .unsupported,
                isEnabled: false,
                disabledAppCount: disabledBundleIdentifiers.count,
                renderModeOverride: nil
            )
        }

        return SettingsCurrentAppState(
            displayName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            supportStatus: dependencies.profileSupportStatus(app.bundleIdentifier),
            isEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier),
            disabledAppCount: disabledBundleIdentifiers.count,
            renderModeOverride: dependencies.renderModeOverride(app.bundleIdentifier)
        )
    }

    var fieldControlState: SettingsFieldControlState {
        guard let target = dependencies.fieldControlTarget() else {
            return SettingsFieldControlState(
                appDisplayName: nil,
                hasFieldTarget: false,
                isCurrentField: false,
                isSilenced: false
            )
        }

        return SettingsFieldControlState(
            appDisplayName: target.appDisplayName,
            hasFieldTarget: true,
            isCurrentField: target.fieldIdentity == dependencies.currentFieldIdentity(),
            isSilenced: dependencies.isFieldSilenced(target.fieldIdentity)
        )
    }

    var practiceState: SettingsPracticeState {
        SettingsPracticeState(
            isTrusted: dependencies.isTrusted(),
            suggestionsPaused: dependencies.suggestionsPaused(),
            runtimeReport: dependencies.runtimeReadinessReport(),
            isModelInstallInProgress: dependencies.modelInstallInProgress(),
            isTextEditEnabled: dependencies.isTextEditEnabled()
        )
    }

    var privacyState: SettingsPrivacyState {
        SettingsPrivacyState(
            tracingPaused: dependencies.tracingPaused(),
            rawContentTracingEnabled: dependencies.rawContentTracingEnabled(),
            rawContentTracingExpiresAt: dependencies.rawContentTracingExpiresAt(),
            screenshotTracingEnabled: dependencies.screenshotTracingEnabled(),
            screenshotTracingExpiresAt: dependencies.screenshotTracingExpiresAt(),
            visiblePageContextEnabled: dependencies.visiblePageContextEnabled(),
            screenCaptureAccessGranted: CGPreflightScreenCaptureAccess(),
            diagnosticsPath: dependencies.diagnosticsPath(),
            tracePath: dependencies.tracePath()
        )
    }

    var keyboardShortcutState: SettingsKeyboardShortcutState {
        SettingsKeyboardShortcutState(
            acceptAllShortcut: dependencies.acceptAllShortcut(),
            currentApp: currentAppState
        )
    }

    var suggestionAggressivenessState: SettingsSuggestionAggressivenessState {
        SettingsSuggestionAggressivenessState(tuning: dependencies.suggestionTuning())
    }

    var runtimeTargetSummary: String {
        let tuning = dependencies.suggestionTuning()
        let pageContextState = dependencies.visiblePageContextEnabled() ? "on" : "off"
        return "\(dependencies.modelName()) • \(dependencies.completionLengthSummary()) • \(tuning.displayName.lowercased()) • showing up to \(tuning.maxVisibleWords) • page context \(pageContextState)"
    }

    func refreshIfShowing(
        settingsWindow: SettingsWindowController,
        lastSuggestionDecision: String
    ) {
        guard settingsWindow.isShowing else {
            return
        }

        settingsWindow.refresh(
            isTrusted: dependencies.isTrusted(),
            suggestionsPaused: dependencies.suggestionsPaused(),
            suggestionsPausedUntil: dependencies.suggestionsPausedUntil(),
            runtimeReport: dependencies.runtimeReadinessReport(),
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: dependencies.modelDirectoryPath(),
            modelInstallStatusText: dependencies.modelInstallStatusText(),
            isModelInstallInProgress: dependencies.modelInstallInProgress(),
            currentApp: currentAppState,
            fieldControl: fieldControlState,
            practice: practiceState,
            privacy: privacyState,
            keyboardShortcuts: keyboardShortcutState,
            suggestionAggressiveness: suggestionAggressivenessState,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }
}
