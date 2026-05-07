import AutocompleteLabCore
import Foundation

struct StatusMenuState: Equatable {
    let title: String
    let tooltip: String
    let pauseTitle: String
    let toggleTitle: String
    let toggleEnabled: Bool
    let diagnosticsSignature: String
    let diagnosticsMetadata: [String: String]
}

enum StatusMenuStateBuilder {
    static func make(
        isTrustedForAccessibility: Bool,
        controlState: SuggestionControlState,
        appDisplayName: String?,
        appBundleIdentifier: String?,
        supportStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        disabledAppCount: Int,
        lastSuggestionDecision: String
    ) -> StatusMenuState {
        let permission = isTrustedForAccessibility ? "AX ok" : "AX missing"
        let appName = appDisplayName ?? "No app"
        let enabled = appEnabled ? "on" : "off"
        let profileName = appDisplayName.map { _ in supportStatus.summary } ?? "none"
        let appStatus = appDisplayName.map {
            supportStatus.menuText(appDisplayName: $0, isEnabled: appEnabled)
        } ?? appName
        let appControlState = appDisplayName.map {
            SettingsCurrentAppState(
                displayName: $0,
                bundleIdentifier: appBundleIdentifier,
                supportStatus: supportStatus,
                isEnabled: appEnabled,
                disabledAppCount: disabledAppCount
            )
        }
        let title = statusTitle(
            isTrustedForAccessibility: isTrustedForAccessibility,
            controlState: controlState,
            appDisplayName: appDisplayName,
            supportStatus: supportStatus,
            appEnabled: appEnabled,
            lastSuggestionDecision: lastSuggestionDecision
        )
        let diagnosticsSignature = [
            controlState.statusName,
            permission,
            appStatus,
            lastSuggestionDecision,
            title
        ].joined(separator: "|")

        return StatusMenuState(
            title: title,
            tooltip: lastSuggestionDecision,
            pauseTitle: controlState.toggleTitle,
            toggleTitle: appControlState?.menuToggleTitle ?? "Toggle Current App",
            toggleEnabled: appControlState?.canToggle ?? false,
            diagnosticsSignature: diagnosticsSignature,
            diagnosticsMetadata: [
                "accessibility": permission,
                "control": controlState.statusName,
                "app": appName,
                "profile": profileName,
                "enabled": enabled,
                "paused": String(controlState.isPaused),
                "decision": lastSuggestionDecision
            ]
        )
    }

    private static func statusTitle(
        isTrustedForAccessibility: Bool,
        controlState: SuggestionControlState,
        appDisplayName: String?,
        supportStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        lastSuggestionDecision: String
    ) -> String {
        guard isTrustedForAccessibility else {
            return "Needs Accessibility"
        }

        if controlState.isPaused {
            return "Paused"
        }

        guard let appDisplayName else {
            return "Ready"
        }

        guard supportStatus.canToggleSuggestions else {
            switch supportStatus.supportLevel {
            case .diagnosticsOnly:
                return "Diagnostics only in \(appDisplayName)"
            case .unsupported:
                return "Unsupported in \(appDisplayName)"
            case .green, .yellow:
                return "Off in \(appDisplayName)"
            }
        }

        guard appEnabled else {
            return "Blocked in \(appDisplayName)"
        }

        if lastSuggestionDecision.hasPrefix("Shown") {
            return "Showing in \(appDisplayName)"
        }

        if lastSuggestionDecision.hasPrefix("Queued") {
            return "Thinking in \(appDisplayName)"
        }

        if lastSuggestionDecision.hasPrefix("Waiting") {
            return "Waiting in \(appDisplayName)"
        }

        return "Ready in \(appDisplayName)"
    }
}
