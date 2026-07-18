import Foundation
import AutocompleteLabCore

struct StatusChromeSettingsState {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let suggestionsPausedUntil: Date?
    let runtimeReport: RuntimeReadinessReport
    let runtimeTargetSummary: String
    let modelDirectoryPath: String
    let modelInstallStatusText: String?
    let isModelInstallInProgress: Bool
    let currentApp: SettingsCurrentAppState
    let fieldControl: SettingsFieldControlState
    let practice: SettingsPracticeState
    let privacy: SettingsPrivacyState
    let keyboardShortcuts: SettingsKeyboardShortcutState
    let suggestionAggressiveness: SettingsSuggestionAggressivenessState
    let lastSuggestionDecision: String
}

struct StatusChromeUpdate {
    let statusLine: String
    let statusSignature: String
    let lastSuggestionDecision: String
    let pauseSuggestionsTitle: String
    let silenceFieldTitle: String
    let silenceFieldEnabled: Bool
    let silenceFieldToolTip: String
    let toggleAppTitle: String
    let toggleAppEnabled: Bool
    let toggleAppToolTip: String
    let settings: StatusChromeSettingsState
    let diagnosticsMetadata: [String: String]
}

/// Owns status-menu output, Settings refresh, and duplicate status diagnostics.
/// AppDelegate supplies already-decided presentation data and remains responsible
/// for product state and status decisions.
@MainActor
final class StatusChromeHost {
    private let statusMenuHost: StatusMenuHost
    private let settingsWindow: () -> SettingsWindowController?
    private var lastStatusLine: String?

    init(
        statusMenuHost: StatusMenuHost,
        settingsWindow: @escaping () -> SettingsWindowController?
    ) {
        self.statusMenuHost = statusMenuHost
        self.settingsWindow = settingsWindow
    }

    func update(_ update: StatusChromeUpdate) {
        statusMenuHost.update(
            statusLine: update.statusLine,
            statusToolTip: update.lastSuggestionDecision,
            pauseSuggestionsTitle: update.pauseSuggestionsTitle,
            silenceFieldTitle: update.silenceFieldTitle,
            silenceFieldEnabled: update.silenceFieldEnabled,
            silenceFieldToolTip: update.silenceFieldToolTip,
            toggleAppTitle: update.toggleAppTitle,
            toggleAppEnabled: update.toggleAppEnabled,
            toggleAppToolTip: update.toggleAppToolTip
        )

        if let settingsWindow = settingsWindow(), settingsWindow.isShowing {
            let settings = update.settings
            settingsWindow.refresh(
                isTrusted: settings.isTrusted,
                suggestionsPaused: settings.suggestionsPaused,
                suggestionsPausedUntil: settings.suggestionsPausedUntil,
                runtimeReport: settings.runtimeReport,
                runtimeTargetSummary: settings.runtimeTargetSummary,
                modelDirectoryPath: settings.modelDirectoryPath,
                modelInstallStatusText: settings.modelInstallStatusText,
                isModelInstallInProgress: settings.isModelInstallInProgress,
                currentApp: settings.currentApp,
                fieldControl: settings.fieldControl,
                practice: settings.practice,
                privacy: settings.privacy,
                keyboardShortcuts: settings.keyboardShortcuts,
                suggestionAggressiveness: settings.suggestionAggressiveness,
                lastSuggestionDecision: settings.lastSuggestionDecision
            )
        }

        guard lastStatusLine != update.statusSignature else {
            return
        }

        lastStatusLine = update.statusSignature
        let decisionPresentation = SuggestionDecisionPresentation(update.lastSuggestionDecision)
        var metadata = update.diagnosticsMetadata
        metadata["decisionKind"] = decisionPresentation.diagnosticsKind
        metadata["decisionSummary"] = decisionPresentation.summary
        DiagnosticsLog.shared.record("status", metadata: metadata)
    }
}
