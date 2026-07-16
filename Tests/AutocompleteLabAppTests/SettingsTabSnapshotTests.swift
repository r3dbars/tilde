import AppKit
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Settings tab snapshots")
struct SettingsTabSnapshotTests {
    @MainActor
    @Test("Every settings tab renders real content, not a blank pane")
    func everySettingsTabRendersRealContent() throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController(
            requestPermission: {},
            openAccessibilitySettings: {},
            toggleSuggestionsPaused: {},
            silenceCurrentField: {},
            performRuntimeAction: { _ in },
            toggleCurrentApp: {},
            toggleCurrentAppMirrorMode: {},
            enableAllApps: {},
            toggleTracingPaused: {},
            toggleRawContentTracing: {},
            toggleScreenshotTracing: {},
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
            runtimeReport: RuntimeReadinessReport(stage: .ready, summary: "ready", action: .none, isReady: true),
            runtimeTargetSummary: "Qwen on-device • short completions",
            modelDirectoryPath: "/Users/example/Library/Application Support/SteadyType/Models",
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
                screenCaptureAccessGranted: false,
                diagnosticsPath: "~/Library/Logs/SteadyType/activity.log",
                tracePath: "~/Library/Logs/SteadyType/events.jsonl"
            ),
            keyboardShortcuts: SettingsKeyboardShortcutState(acceptAllShortcut: .shiftTab),
            suggestionAggressiveness: SettingsSuggestionAggressivenessState(tuning: SuggestionTuning()),
            lastSuggestionDecision: "Shown"
        )

        // General, Privacy, and Advanced must each lay out and draw substantial content.
        // (Regression guard: NSTabView sizes item views by autoresizing mask, so a
        // constraint-only container collapses non-default tabs to a blank pane.)
        let names = ["general", "privacy", "advanced"]
        for index in 0..<3 {
            controller.selectTab(at: index)
            let pngData = try #require(controller.nativeAppearanceSnapshotPNGData(appearanceName: .aqua))
            #expect(pngData.count > 40_000, "Tab \(names[index]) rendered too little content (\(pngData.count) bytes)")
            try writeSnapshotIfRequested(pngData, name: "tab-\(names[index])")
        }
    }

    private func writeSnapshotIfRequested(_ pngData: Data, name: String) throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment[
            "AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR"
        ], !outputDirectory.isEmpty else {
            return
        }

        let directoryURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try pngData.write(to: directoryURL.appendingPathComponent("\(name).png"))
    }
}
