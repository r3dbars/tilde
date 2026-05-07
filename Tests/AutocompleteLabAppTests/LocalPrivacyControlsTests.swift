import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Local privacy controls")
struct LocalPrivacyControlsTests {
    @Test("Settings privacy state reads trace and diagnostics paths without raw content")
    func settingsPrivacyStateReadsTraceAndDiagnosticsPaths() {
        let fixture = makeFixture()
        _ = fixture.controls.toggleRawContentTracing(surface: "settings")
        _ = fixture.controls.toggleScreenshotTracing(surface: "settings")

        let state = fixture.controls.settingsPrivacyState(diagnosticsPath: "/tmp/diagnostics.log")

        #expect(state.rawContentTracingEnabled)
        #expect(state.screenshotTracingEnabled)
        #expect(state.diagnosticsPath == "/tmp/diagnostics.log")
        #expect(state.tracePath == fixture.traceLog.path)
    }

    @Test("Trace pause toggle keeps diagnostics metadata surface-specific")
    func tracePauseToggleKeepsDiagnosticsMetadataSurfaceSpecific() {
        let fixture = makeFixture()

        let diagnostics = fixture.controls.toggleTracePause()
        let settings = fixture.controls.toggleTracePause(surface: "settings")

        #expect(diagnostics.eventName == "trace-control")
        #expect(diagnostics.metadata == ["paused": "true"])
        #expect(settings.metadata == ["paused": "false", "surface": "settings"])
    }

    @Test("Raw and screenshot toggles return trace-safe metadata")
    func rawAndScreenshotTogglesReturnTraceSafeMetadata() {
        let fixture = makeFixture()

        let raw = fixture.controls.toggleRawContentTracing(surface: "settings")
        let screenshot = fixture.controls.toggleScreenshotTracing(surface: "settings")

        #expect(raw.eventName == "raw-trace-control")
        #expect(raw.metadata == ["enabled": "true", "surface": "settings"])
        #expect(screenshot.eventName == "screenshot-trace-control")
        #expect(screenshot.metadata == ["enabled": "true", "surface": "settings"])
    }

    @Test("Delete clears trace flags and per-app screenshot tracing")
    func deleteClearsTraceFlagsAndPerAppScreenshotTracing() {
        let fixture = makeFixture()
        _ = fixture.controls.toggleRawContentTracing(surface: "settings")
        _ = fixture.controls.toggleScreenshotTracing(surface: "settings")
        fixture.learningStore.setScreenshotTracing(true, for: "com.apple.TextEdit")

        let result = fixture.controls.deleteTraceAndCompatibilityLogs(surface: "settings")

        #expect(result.eventName == "local-privacy-logs-deleted")
        #expect(result.metadata == ["surface": "settings"])
        #expect(!fixture.traceLog.rawContentTracingEnabled)
        #expect(!fixture.traceLog.screenshotTracingEnabled)
        #expect(fixture.learningStore.profile(for: "com.apple.TextEdit")?.screenshotTracingEnabled != true)
    }

    private func makeFixture() -> PrivacyControlsFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "LocalPrivacyControlsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defaults.removePersistentDomain(forName: defaultsName)

        let traceLog = RawAutocompleteTraceLog(
            logURL: directory.appendingPathComponent("trace.jsonl"),
            screenshotsURL: directory.appendingPathComponent("screenshots", isDirectory: true),
            userDefaults: defaults,
            environment: [:],
            debugCaptureDuration: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        let learningStore = CompatibilityLearningStore(
            fileURL: directory.appendingPathComponent("compatibility-learning.json"),
            screenshotTracingDuration: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        return PrivacyControlsFixture(
            traceLog: traceLog,
            learningStore: learningStore,
            controls: LocalPrivacyControls(
                traceLog: traceLog,
                compatibilityLearningStore: learningStore
            )
        )
    }
}

private struct PrivacyControlsFixture {
    let traceLog: RawAutocompleteTraceLog
    let learningStore: CompatibilityLearningStore
    let controls: LocalPrivacyControls
}
