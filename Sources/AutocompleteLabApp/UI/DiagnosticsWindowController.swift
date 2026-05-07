import AppKit
import AutocompleteLabCore

@MainActor
final class DiagnosticsWindowController {
    private let window: NSWindow
    private let textView: NSTextView
    private let refreshButton: NSButton
    private let pauseTracingButton: NSButton
    private let rawDebugTracingButton: NSButton
    private let screenshotTracingButton: NSButton
    private let openTraceFolderButton: NSButton
    private let exportReportButton: NSButton
    private let deleteTracesButton: NSButton
    private var refreshAction: (() -> Void)?
    private var toggleTracingAction: (() -> Void)?
    private var toggleRawDebugTracingAction: (() -> Void)?
    private var toggleScreenshotTracingAction: (() -> Void)?
    private var openTraceFolderAction: (() -> Void)?
    private var exportReportAction: (() -> Void)?
    private var deleteTracesAction: (() -> Void)?

    init() {
        textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
        pauseTracingButton = NSButton(title: "Pause Tracing", target: nil, action: nil)
        rawDebugTracingButton = NSButton(title: "Raw Debug Off", target: nil, action: nil)
        screenshotTracingButton = NSButton(title: "Screenshot Trace", target: nil, action: nil)
        openTraceFolderButton = NSButton(title: "Open Trace Folder", target: nil, action: nil)
        exportReportButton = NSButton(title: "Export Report", target: nil, action: nil)
        deleteTracesButton = NSButton(title: "Delete Traces", target: nil, action: nil)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        let buttonStack = NSStackView(views: [
            refreshButton,
            pauseTracingButton,
            rawDebugTracingButton,
            screenshotTracingButton,
            openTraceFolderButton,
            exportReportButton,
            deleteTracesButton
        ])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 6, right: 10)

        let contentStack = NSStackView(views: [buttonStack, scrollView])
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 460).isActive = true

        window = NSWindow(
            contentRect: contentStack.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autocomplete Diagnostics"
        window.contentView = contentStack

        refreshButton.target = self
        refreshButton.action = #selector(refresh)
        pauseTracingButton.target = self
        pauseTracingButton.action = #selector(toggleTracing)
        rawDebugTracingButton.target = self
        rawDebugTracingButton.action = #selector(toggleRawDebugTracing)
        screenshotTracingButton.target = self
        screenshotTracingButton.action = #selector(toggleScreenshotTracing)
        openTraceFolderButton.target = self
        openTraceFolderButton.action = #selector(openTraceFolder)
        exportReportButton.target = self
        exportReportButton.action = #selector(exportReport)
        deleteTracesButton.target = self
        deleteTracesButton.action = #selector(deleteTraces)
    }

    func show(
        diagnostics: FocusedTextDiagnostics?,
        profile: CompatibilityProfile?,
        compatibilityStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        appTrusted: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        recentEvents: [String],
        traceSummary: AutocompleteTraceSummary,
        recentTraceEvents: [AutocompleteTraceEvent],
        tracePath: String,
        tracingPaused: Bool,
        rawDebugTracingEnabled: Bool,
        screenshotTracingEnabled: Bool,
        compatibilityLearningPath: String,
        compatibilityLearningProfile: CompatibilityLearningProfile?,
        quietModeSummary: String,
        refreshAction: @escaping () -> Void,
        toggleTracingAction: @escaping () -> Void,
        toggleRawDebugTracingAction: @escaping () -> Void,
        toggleScreenshotTracingAction: @escaping () -> Void,
        openTraceFolderAction: @escaping () -> Void,
        exportReportAction: @escaping () -> Void,
        deleteTracesAction: @escaping () -> Void
    ) {
        self.refreshAction = refreshAction
        self.toggleTracingAction = toggleTracingAction
        self.toggleRawDebugTracingAction = toggleRawDebugTracingAction
        self.toggleScreenshotTracingAction = toggleScreenshotTracingAction
        self.openTraceFolderAction = openTraceFolderAction
        self.exportReportAction = exportReportAction
        self.deleteTracesAction = deleteTracesAction
        pauseTracingButton.title = tracingPaused ? "Resume Tracing" : "Pause Tracing"
        rawDebugTracingButton.title = rawDebugTracingEnabled ? "RAW Debug On" : "Raw Debug Off"
        screenshotTracingButton.title = screenshotTracingEnabled ? "Screenshots On" : "Screenshots Off"

        var sections: [String] = []

        sections.append("Permission: Accessibility \(appTrusted ? "granted" : "missing")")
        sections.append(
            """
            Local model: \(runtimeReport.summary)
              target: \(runtimeTargetSummary)
              stage: \(runtimeReport.stage.rawValue)
              action: \(runtimeReport.action.displayName)
              detail: \(runtimeReport.detail ?? "none")
            """
        )
        sections.append("Model folder: \(modelDirectoryPath)")
        sections.append("Compatibility: \(compatibilityStatus.summary)")
        sections.append("Current app enabled: \(appEnabled)")
        sections.append("Quiet mode: \(quietModeSummary)")
        sections.append(traceSummaryText(
            traceSummary,
            tracePath: tracePath,
            tracingPaused: tracingPaused,
            rawDebugTracingEnabled: rawDebugTracingEnabled,
            screenshotTracingEnabled: screenshotTracingEnabled,
            compatibilityLearningPath: compatibilityLearningPath,
            compatibilityLearningProfile: compatibilityLearningProfile
        ))
        sections.append(acceptRateBucketsText(title: "Accept rate by app", buckets: traceSummary.acceptRateByApp))
        sections.append(acceptRateBucketsText(title: "Accept rate by mode", buckets: traceSummary.acceptRateByMode))
        sections.append(acceptRateBucketsText(title: "Accept rate by experiment arm", buckets: traceSummary.acceptRateByExperimentArm))
        sections.append(acceptRateBucketsText(title: "Useful rate by app", buckets: traceSummary.usefulRateByApp))
        sections.append(acceptRateBucketsText(title: "Useful rate by mode", buckets: traceSummary.usefulRateByMode))
        sections.append(acceptRateBucketsText(title: "Useful rate by experiment arm", buckets: traceSummary.usefulRateByExperimentArm))
        sections.append(countBucketsText(title: "Presented by experiment arm", buckets: traceSummary.presentedByExperimentArm))
        sections.append(countBucketsText(title: "Accepted and kept by experiment arm", buckets: traceSummary.acceptedAndKeptByExperimentArm))
        sections.append(countBucketsText(title: "Suppressed by experiment arm", buckets: traceSummary.suppressedByExperimentArm))
        sections.append(countBucketsText(title: "Presented by field kind", buckets: traceSummary.presentedByFieldKind))
        sections.append(countBucketsText(title: "Accepted and kept by field kind", buckets: traceSummary.acceptedAndKeptByFieldKind))
        sections.append(countBucketsText(title: "Suppressed by reason", buckets: traceSummary.suppressedByReason))
        sections.append(countBucketsText(title: "Suppressed by app", buckets: traceSummary.suppressedByApp))
        sections.append(countBucketsText(title: "Suppressed by mode", buckets: traceSummary.suppressedByMode))
        sections.append(countBucketsText(title: "Suppressed by field kind", buckets: traceSummary.suppressedByFieldKind))
        sections.append(countBucketsText(title: "Actionable suppressed by app", buckets: traceSummary.actionableSuppressedByApp))
        sections.append(countBucketsText(title: "Actionable suppressed by mode", buckets: traceSummary.actionableSuppressedByMode))
        sections.append(countBucketsText(title: "Caret failures by app", buckets: traceSummary.caretGeometryFailuresByApp))
        sections.append(acceptRateBucketsText(title: "Caret failure rate by app", buckets: traceSummary.caretGeometryFailureRateByApp))
        sections.append(countBucketsText(title: "Caret failures by render mode", buckets: traceSummary.caretGeometryFailuresByRenderMode))
        sections.append(acceptRateBucketsText(title: "Caret failure rate by render mode", buckets: traceSummary.caretGeometryFailureRateByRenderMode))
        sections.append(countBucketsText(title: "Annoyance signals", buckets: traceSummary.annoyanceSignalCounts))
        sections.append(topMissesText(traceSummary.topMisses))
        sections.append(supportStateText(recentTraceEvents))

        if let profile {
            sections.append(
                """
                Compatibility profile:
                  app: \(profile.displayName) (\(profile.bundleIdentifier))
                  render mode: \(profile.renderMode.rawValue)
                  insertion mode: \(profile.insertionMode.rawValue)
                  fallback render: \(profile.fallbackRenderMode?.rawValue ?? "none")
                  fallback insertion: \(profile.fallbackInsertionMode?.rawValue ?? "none")
                  field identity: \(profile.fieldIdentityMode.rawValue)
                  one-word accept: \(profile.supportsOneWordAcceptance)
                  full accept: \(profile.supportsFullAcceptance)
                  Esc suppression: \(profile.suppressesUntilBlurAfterEscape)
                  suppress after failed insert: \(profile.suppressesAfterInsertionFailure)
                  sensitive: \(profile.isSensitive)
                  debug summary: \(profile.debugSummary)
                  notes: \(profile.notes)
                """
            )
        } else {
            sections.append("Compatibility profile: not allowed or not recognized")
        }

        sections.append(diagnostics?.summary ?? "Focused text diagnostics: unavailable")
        sections.append(recentTraceText(recentTraceEvents))
        sections.append(recentDiagnosticsText(recentEvents))

        textView.string = sections.joined(separator: "\n\n")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func traceSummaryText(
        _ summary: AutocompleteTraceSummary,
        tracePath: String,
        tracingPaused: Bool,
        rawDebugTracingEnabled: Bool,
        screenshotTracingEnabled: Bool,
        compatibilityLearningPath: String,
        compatibilityLearningProfile: CompatibilityLearningProfile?
    ) -> String {
        """
        Trace eval:
          path: \(tracePath)
          tracing: \(tracingPaused ? "paused" : "on")
          raw local debug: \(rawDebugTracingEnabled ? "on" : "off")
          screenshot tracing: \(screenshotTracingEnabled ? "on" : "off")
          compatibility learning: \(compatibilityLearningPath)
          current learned adapter: \(compatibilityLearningProfile?.debugSummary ?? "none")
          events: \(summary.totalEvents)
          presented: \(summary.presentedCount)
          accepted: \(summary.acceptedCount)
          typed through: \(summary.typedThroughCount)
          typed over: \(summary.typedOverCount)
          ignored: \(summary.ignoredCount)
          suppressed: \(summary.suppressedCount)
          actionable suppressed: \(summary.actionableSuppressedCount)
          insertion failures: \(summary.insertionFailureCount)
          insertion verified: \(summary.insertionVerifiedCount)
          insertion verification success: \(Self.percent(summary.insertionVerificationSuccessRate))
          accepted and kept: \(summary.acceptedAndKeptCount)
          kept / shown: \(Self.percent(summary.acceptedAndKeptRateShown))
          kept / accepted: \(Self.percent(summary.acceptedAndKeptRateAccepted))
          median edit distance after accept: \(Self.decimal(summary.medianEditDistanceAfterAccept))
          median first edit delay: \(Self.latency(summary.medianTimeUntilFirstEditAfterAcceptMilliseconds))
          Tab accept share: \(Self.percent(summary.tabAcceptShare))
          full accept share: \(Self.percent(summary.fullAcceptShare))
          duplicate text: \(summary.duplicateTextCount)
          app disables: \(summary.appDisableCount)
          caret geometry failures: \(summary.caretGeometryFailureCount)
          caret geometry failure rate: \(Self.percent(summary.caretGeometryFailureRate))
          annoyance score: \(String(format: "%.2f", summary.annoyanceScore))
          accept rate: \(Self.percent(summary.acceptRate))
          useful rate: \(Self.percent(summary.usefulRate))
          p50 latency: \(Self.latency(summary.p50LatencyMilliseconds))
          p90 latency: \(Self.latency(summary.p90LatencyMilliseconds))
          p95 latency: \(Self.latency(summary.p95LatencyMilliseconds))
        """
    }

    private func topMissesText(_ misses: [AutocompleteTraceMiss]) -> String {
        guard !misses.isEmpty else {
            return "Top 5 misses: none yet"
        }

        return """
        Top 5 misses:
        \(misses.enumerated().map { index, miss in
            "  \(index + 1). \(miss.title) | count=\(miss.count) | app=\(miss.appBundleIdentifier.isEmpty ? "unknown" : miss.appBundleIdentifier) | mode=\(miss.requestMode.isEmpty ? "unknown" : miss.requestMode) | fix=\(miss.fixCategory) | cause=\(miss.suggestedCause) | example=\(miss.exampleSuggestionID)"
        }.joined(separator: "\n"))
        """
    }

    private func supportStateText(_ events: [AutocompleteTraceEvent]) -> String {
        let evaluations = CompatibilitySupportEvaluator().evaluations(for: events)
        guard !evaluations.isEmpty else {
            return "Support state by app: none yet"
        }

        return """
        Support state by app:
        \(evaluations.map { evaluation in
            "  \(evaluation.bundleIdentifier): \(evaluation.state.rawValue) shown=\(evaluation.presentedCount) kept=\(Self.percent(evaluation.acceptedAndKeptShownRate)) insert=\(Self.percent(evaluation.insertionVerificationSuccessRate)) p95=\(Self.latency(evaluation.p95LatencyMilliseconds)) annoyance=\(Self.decimal(evaluation.annoyanceScore))"
        }.joined(separator: "\n"))
        """
    }

    private func acceptRateBucketsText(title: String, buckets: [String: Double]) -> String {
        guard !buckets.isEmpty else {
            return "\(title): none yet"
        }

        return """
        \(title):
        \(buckets.sorted { $0.key < $1.key }.map { key, value in
            "  \(key): \(Self.percent(value))"
        }.joined(separator: "\n"))
        """
    }

    private func countBucketsText(title: String, buckets: [String: Int]) -> String {
        guard !buckets.isEmpty else {
            return "\(title): none yet"
        }

        return """
        \(title):
        \(buckets.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }

            return lhs.value > rhs.value
        }.map { key, value in
            "  \(key): \(value)"
        }.joined(separator: "\n"))
        """
    }

    private func recentTraceText(_ events: [AutocompleteTraceEvent]) -> String {
        guard !events.isEmpty else {
            return "Recent trace events: none yet"
        }

        return """
        Recent trace events:
        \(events.suffix(16).map {
            "  \($0.timestamp) \($0.type.rawValue) arm=\($0.experimentArm) mode=\($0.requestMode) app=\($0.appBundleIdentifier) shown=\($0.displayedText) accepted=\($0.acceptedText) reason=\($0.reason) latency=\(Self.latency($0.latencyMilliseconds))"
        }.joined(separator: "\n"))
        """
    }

    private func recentDiagnosticsText(_ events: [String]) -> String {
        guard !events.isEmpty else {
            return "Recent events: unavailable"
        }

        return """
        Recent events:
        \(events.map { "  \($0)" }.joined(separator: "\n"))
        """
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func latency(_ value: Int?) -> String {
        value.map { "\($0)ms" } ?? "n/a"
    }

    private static func decimal(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? "n/a"
    }

    @objc
    private func refresh() {
        refreshAction?()
    }

    @objc
    private func toggleTracing() {
        toggleTracingAction?()
    }

    @objc
    private func toggleRawDebugTracing() {
        toggleRawDebugTracingAction?()
    }

    @objc
    private func toggleScreenshotTracing() {
        toggleScreenshotTracingAction?()
    }

    @objc
    private func openTraceFolder() {
        openTraceFolderAction?()
    }

    @objc
    private func exportReport() {
        exportReportAction?()
    }

    @objc
    private func deleteTraces() {
        deleteTracesAction?()
    }
}
