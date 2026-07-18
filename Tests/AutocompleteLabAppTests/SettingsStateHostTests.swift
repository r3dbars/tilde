import Foundation
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Settings state host")
struct SettingsStateHostTests {
    @Test("Builds current app, field, practice, and tuning state from dependencies")
    func buildsStateFromDependencies() {
        let app = RunningApplicationInfo(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            processIdentifier: 42
        )
        let field = FocusedFieldIdentity(
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            elementIdentifier: 7
        )
        var currentApp: RunningApplicationInfo? = app
        var currentField: FocusedFieldIdentity? = field
        let target = FieldControlTarget(
            appBundleIdentifier: app.bundleIdentifier,
            appDisplayName: app.localizedName,
            fieldIdentity: field,
            requestMode: .wordCompletion,
            fieldKind: .singlelineCompose
        )
        let tuning = SuggestionTuning(aggressivenessLevel: 2, maxVisibleWords: 5)
        let host = SettingsStateHost(
            dependencies: makeDependencies(
                app: { currentApp },
                field: { currentField },
                target: { target },
                tuning: { tuning },
                silenced: { $0 == field }
            )
        )

        #expect(host.currentAppState.displayName == "TextEdit")
        #expect(host.currentAppState.isEnabled)
        #expect(host.currentAppState.supportStatus == CompatibilityProfileStore.mvp.supportStatus(for: app.bundleIdentifier))
        #expect(host.fieldControlState.appDisplayName == "TextEdit")
        #expect(host.fieldControlState.isCurrentField)
        #expect(host.fieldControlState.isSilenced)
        #expect(host.practiceState.isTrusted)
        #expect(host.practiceState.runtimeReport.isReady)
        #expect(host.suggestionAggressivenessState.tuning == tuning)
        #expect(host.runtimeTargetSummary.contains("showing up to 5"))

        currentField = nil
        currentApp = nil
        #expect(host.currentAppState.displayName == "None")
        #expect(host.fieldControlState.hasFieldTarget)
        #expect(!host.fieldControlState.isCurrentField)
    }

    @Test("Keeps privacy state metadata-only and preserves tracing flags")
    func buildsPrivacyStateWithoutContent() {
        let host = SettingsStateHost(
            dependencies: makeDependencies(
                tracingPaused: { true },
                rawTracingEnabled: { false },
                screenshotTracingEnabled: { true },
                visiblePageContextEnabled: { false },
                personalCaptureEnabled: { true },
                diagnosticsPath: { "/tmp/diagnostics" },
                tracePath: { "/tmp/trace" },
                personalCapturePath: { "/tmp/journal" }
            )
        )

        let state = host.privacyState
        #expect(state.tracingPaused)
        #expect(!state.rawContentTracingEnabled)
        #expect(state.screenshotTracingEnabled)
        #expect(!state.visiblePageContextEnabled)
        #expect(state.personalCaptureEnabled)
        #expect(state.diagnosticsPath == "/tmp/diagnostics")
        #expect(state.tracePath == "/tmp/trace")
        #expect(state.personalCapturePath == "/tmp/journal")
    }

    @Test("AppDelegate keeps settings state assembly behind the host")
    func appDelegateUsesSettingsStateHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var settingsStateHost = SettingsStateHost"))
        #expect(appDelegate.contains("settingsStateHost.refreshIfShowing"))
        #expect(!appDelegate.contains("screenCaptureAccessGranted: CGPreflightScreenCaptureAccess()"))
    }
}

@MainActor
private func makeDependencies(
    app: @escaping () -> RunningApplicationInfo? = { nil },
    field: @escaping () -> FocusedFieldIdentity? = { nil },
    target: @escaping () -> FieldControlTarget? = { nil },
    tuning: @escaping () -> SuggestionTuning = { SuggestionTuning() },
    silenced: @escaping (FocusedFieldIdentity) -> Bool = { _ in false },
    tracingPaused: @escaping () -> Bool = { false },
    rawTracingEnabled: @escaping () -> Bool = { true },
    screenshotTracingEnabled: @escaping () -> Bool = { false },
    visiblePageContextEnabled: @escaping () -> Bool = { true },
    personalCaptureEnabled: @escaping () -> Bool = { false },
    diagnosticsPath: @escaping () -> String = { "/tmp/diagnostics" },
    tracePath: @escaping () -> String = { "/tmp/trace" },
    personalCapturePath: @escaping () -> String = { "/tmp/journal" }
) -> SettingsStateHostDependencies {
    SettingsStateHostDependencies(
        appForSettingsState: app,
        currentFieldIdentity: field,
        profileSupportStatus: { CompatibilityProfileStore.mvp.supportStatus(for: $0) },
        disabledBundleIdentifiers: { [] },
        renderModeOverride: { _ in nil },
        fieldControlTarget: target,
        isFieldSilenced: silenced,
        isTrusted: { true },
        suggestionsPaused: { false },
        suggestionsPausedUntil: { nil },
        runtimeReadinessReport: {
            RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            )
        },
        modelDirectoryPath: { "/tmp/models" },
        modelInstallStatusText: { "ready" },
        modelInstallInProgress: { false },
        isTextEditEnabled: { true },
        acceptAllShortcut: { .shiftTab },
        tracingPaused: tracingPaused,
        rawContentTracingEnabled: rawTracingEnabled,
        rawContentTracingExpiresAt: { nil },
        screenshotTracingEnabled: screenshotTracingEnabled,
        screenshotTracingExpiresAt: { nil },
        visiblePageContextEnabled: visiblePageContextEnabled,
        personalCaptureEnabled: personalCaptureEnabled,
        diagnosticsPath: diagnosticsPath,
        tracePath: tracePath,
        personalCapturePath: personalCapturePath,
        suggestionTuning: tuning,
        modelName: { "Qwen3.5 4B" },
        completionLengthSummary: { "up to 8 words" }
    )
}
