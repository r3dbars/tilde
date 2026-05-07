import Foundation

struct LocalPrivacyControlResult: Equatable {
    let eventName: String
    let metadata: [String: String]
}

final class LocalPrivacyControls {
    private let traceLog: RawAutocompleteTraceLog
    private let compatibilityLearningStore: CompatibilityLearningStore

    init(
        traceLog: RawAutocompleteTraceLog,
        compatibilityLearningStore: CompatibilityLearningStore
    ) {
        self.traceLog = traceLog
        self.compatibilityLearningStore = compatibilityLearningStore
    }

    func settingsPrivacyState(diagnosticsPath: String) -> SettingsPrivacyState {
        SettingsPrivacyState(
            tracingPaused: traceLog.isPaused,
            rawContentTracingEnabled: traceLog.rawContentTracingEnabled,
            rawContentTracingExpiresAt: traceLog.rawContentTracingExpiresAt,
            screenshotTracingEnabled: traceLog.screenshotTracingEnabled,
            screenshotTracingExpiresAt: traceLog.screenshotTracingExpiresAt,
            diagnosticsPath: diagnosticsPath,
            tracePath: traceLog.path
        )
    }

    func toggleTracePause(surface: String? = nil) -> LocalPrivacyControlResult {
        let nextPaused = !traceLog.isPaused
        traceLog.setPaused(nextPaused)

        var metadata = ["paused": String(nextPaused)]
        if let surface {
            metadata["surface"] = surface
        }

        return LocalPrivacyControlResult(
            eventName: "trace-control",
            metadata: metadata
        )
    }

    func toggleRawContentTracing(surface: String) -> LocalPrivacyControlResult {
        let nextEnabled = !traceLog.rawContentTracingEnabled
        traceLog.setRawContentTracingEnabled(nextEnabled)
        return LocalPrivacyControlResult(
            eventName: "raw-trace-control",
            metadata: [
                "surface": surface,
                "enabled": String(nextEnabled)
            ]
        )
    }

    func toggleScreenshotTracing(surface: String? = nil) -> LocalPrivacyControlResult {
        let nextEnabled = !traceLog.screenshotTracingEnabled
        traceLog.setScreenshotTracingEnabled(nextEnabled)

        var metadata = ["enabled": String(nextEnabled)]
        if let surface {
            metadata["surface"] = surface
        }

        return LocalPrivacyControlResult(
            eventName: "screenshot-trace-control",
            metadata: metadata
        )
    }

    func deleteTraceAndCompatibilityLogs(surface: String) -> LocalPrivacyControlResult {
        traceLog.deleteAll()
        compatibilityLearningStore.disableScreenshotTracing()
        return LocalPrivacyControlResult(
            eventName: "local-privacy-logs-deleted",
            metadata: ["surface": surface]
        )
    }
}
