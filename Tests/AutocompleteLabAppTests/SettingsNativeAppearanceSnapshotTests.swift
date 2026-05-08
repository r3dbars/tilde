import AppKit
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Settings native appearance snapshots")
struct SettingsNativeAppearanceSnapshotTests {
    @MainActor
    @Test("Settings renders under light dark and high contrast appearances")
    func settingsRendersUnderNativeAppearances() throws {
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
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            ),
            runtimeTargetSummary: "Qwen local • short completions • normal",
            modelDirectoryPath: "/Users/example/Library/Application Support/AutocompleteLab/Models",
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
                diagnosticsPath: "/Users/example/Library/Logs/AutocompleteLab/diagnostics.log",
                tracePath: "/Users/example/Library/Logs/AutocompleteLab/events.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .backtick),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(tuning: SuggestionTuning()),
            lastSuggestionDecision: "Shown"
        )

        for appearanceName in NativeAppearanceCoverage.lightDarkAndHighContrast.appearanceNames {
            let name = NSAppearance.Name(appearanceName)
            let pngData = try #require(controller.nativeAppearanceSnapshotPNGData(appearanceName: name))
            #expect(pngData.count > 20_000)
            try writeSnapshotIfRequested(pngData, appearanceName: name)
        }
    }

    private func writeSnapshotIfRequested(
        _ pngData: Data,
        appearanceName: NSAppearance.Name
    ) throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment[
            "AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR"
        ], !outputDirectory.isEmpty else {
            return
        }

        let directoryURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(snapshotName(for: appearanceName)).png")
        try pngData.write(to: fileURL)
    }

    private func snapshotName(for appearanceName: NSAppearance.Name) -> String {
        switch appearanceName.rawValue {
        case NSAppearance.Name.aqua.rawValue:
            return "settings-light"
        case NSAppearance.Name.darkAqua.rawValue:
            return "settings-dark"
        case NSAppearance.Name.accessibilityHighContrastAqua.rawValue:
            return "settings-high-contrast-light"
        case NSAppearance.Name.accessibilityHighContrastDarkAqua.rawValue:
            return "settings-high-contrast-dark"
        default:
            return appearanceName.rawValue
                .replacingOccurrences(of: "NSAppearanceName", with: "settings-")
                .lowercased()
        }
    }
}
