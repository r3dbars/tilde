import AppKit
import AutocompleteLabCore

struct DiagnosticsWindowPresentation {
    let bundleIdentifier: String
    let diagnostics: FocusedTextDiagnostics?
    let profile: CompatibilityProfile?
    let compatibilityStatus: CompatibilitySupportStatus
    let appEnabled: Bool
    let appTrusted: Bool
    let lastSuggestionDecision: String
    let runtimeReport: RuntimeReadinessReport
    let runtimeTargetSummary: String
    let pauseControl: ControlPauseState
    let modelDirectoryPath: String
    let recentEvents: [String]
    let traceSummary: AutocompleteTraceSummary
    let recentTraceEvents: [AutocompleteTraceEvent]
    let tracePath: String
    let tracingPaused: Bool
    let screenshotTracingEnabled: Bool
    let compatibilityLearningPath: String
    let compatibilityLearningProfile: CompatibilityLearningProfile?
}

@MainActor
protocol DiagnosticsWindowActionHandling: AnyObject {
    func refreshDiagnostics()
    func toggleDiagnosticsTracing()
    func toggleDiagnosticsScreenshotTracing(for bundleIdentifier: String)
    func openDiagnosticsTraceFolder()
    func exportDiagnosticsTraceReport()
    func deleteDiagnosticsTraces()
}

/// Owns diagnostics-window presentation and translates its controls into typed
/// actions. AppDelegate keeps the diagnostics snapshot and product decisions.
@MainActor
final class DiagnosticsWindowHost {
    private weak var handler: (any DiagnosticsWindowActionHandling)?
    private let controller: DiagnosticsWindowController

    init(
        handler: any DiagnosticsWindowActionHandling,
        controller: DiagnosticsWindowController = DiagnosticsWindowController()
    ) {
        self.handler = handler
        self.controller = controller
    }

    func show(_ presentation: DiagnosticsWindowPresentation) {
        controller.show(
            diagnostics: presentation.diagnostics,
            profile: presentation.profile,
            compatibilityStatus: presentation.compatibilityStatus,
            appEnabled: presentation.appEnabled,
            appTrusted: presentation.appTrusted,
            lastSuggestionDecision: presentation.lastSuggestionDecision,
            runtimeReport: presentation.runtimeReport,
            runtimeTargetSummary: presentation.runtimeTargetSummary,
            pauseControl: presentation.pauseControl,
            modelDirectoryPath: presentation.modelDirectoryPath,
            recentEvents: presentation.recentEvents,
            traceSummary: presentation.traceSummary,
            recentTraceEvents: presentation.recentTraceEvents,
            tracePath: presentation.tracePath,
            tracingPaused: presentation.tracingPaused,
            screenshotTracingEnabled: presentation.screenshotTracingEnabled,
            compatibilityLearningPath: presentation.compatibilityLearningPath,
            compatibilityLearningProfile: presentation.compatibilityLearningProfile,
            refreshAction: { [weak self] in
                self?.handler?.refreshDiagnostics()
            },
            toggleTracingAction: { [weak self] in
                self?.handler?.toggleDiagnosticsTracing()
            },
            toggleScreenshotTracingAction: { [weak self] in
                self?.handler?.toggleDiagnosticsScreenshotTracing(
                    for: presentation.bundleIdentifier
                )
            },
            openTraceFolderAction: { [weak self] in
                self?.handler?.openDiagnosticsTraceFolder()
            },
            exportReportAction: { [weak self] in
                self?.handler?.exportDiagnosticsTraceReport()
            },
            deleteTracesAction: { [weak self] in
                self?.handler?.deleteDiagnosticsTraces()
            }
        )
    }
}
