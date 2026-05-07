import AppKit
import AutocompleteLabCore

@MainActor
final class DiagnosticsWindowController {
    private let window: NSWindow
    private let textView: NSTextView
    private let refreshButton: NSButton
    private let pauseTracingButton: NSButton
    private let screenshotTracingButton: NSButton
    private let openTraceFolderButton: NSButton
    private let exportReportButton: NSButton
    private let deleteTracesButton: NSButton
    private var refreshAction: (() -> Void)?
    private var toggleTracingAction: (() -> Void)?
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
        tracePrivacySummary: String,
        tracingPaused: Bool,
        screenshotTracingEnabled: Bool,
        anchorDecisionSummary: String?,
        compatibilityLearningPath: String,
        compatibilityLearningProfile: CompatibilityLearningProfile?,
        refreshAction: @escaping () -> Void,
        toggleTracingAction: @escaping () -> Void,
        toggleScreenshotTracingAction: @escaping () -> Void,
        openTraceFolderAction: @escaping () -> Void,
        exportReportAction: @escaping () -> Void,
        deleteTracesAction: @escaping () -> Void
    ) {
        self.refreshAction = refreshAction
        self.toggleTracingAction = toggleTracingAction
        self.toggleScreenshotTracingAction = toggleScreenshotTracingAction
        self.openTraceFolderAction = openTraceFolderAction
        self.exportReportAction = exportReportAction
        self.deleteTracesAction = deleteTracesAction
        pauseTracingButton.title = tracingPaused ? "Resume Tracing" : "Pause Tracing"
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
        if let anchorDecisionSummary {
            sections.append("Anchor: \(anchorDecisionSummary)")
        }
        sections.append(whyNoSuggestionText(
            diagnostics: diagnostics,
            profile: profile,
            compatibilityStatus: compatibilityStatus,
            appEnabled: appEnabled,
            appTrusted: appTrusted,
            runtimeReport: runtimeReport,
            anchorDecisionSummary: anchorDecisionSummary,
            traceSummary: traceSummary
        ))
        sections.append(traceSummaryText(
            traceSummary,
            tracePath: tracePath,
            tracePrivacySummary: tracePrivacySummary,
            tracingPaused: tracingPaused,
            screenshotTracingEnabled: screenshotTracingEnabled,
            compatibilityLearningPath: compatibilityLearningPath,
            compatibilityLearningProfile: compatibilityLearningProfile
        ))
        sections.append(acceptRateBucketsText(title: "Accept rate by app", buckets: traceSummary.acceptRateByApp))
        sections.append(acceptRateBucketsText(title: "Accept rate by mode", buckets: traceSummary.acceptRateByMode))
        sections.append(acceptRateBucketsText(title: "Useful rate by app", buckets: traceSummary.usefulRateByApp))
        sections.append(acceptRateBucketsText(title: "Useful rate by mode", buckets: traceSummary.usefulRateByMode))
        sections.append(countBucketsText(title: "Suppressed by reason", buckets: traceSummary.suppressedByReason))
        sections.append(countBucketsText(title: "Suppressed by app", buckets: traceSummary.suppressedByApp))
        sections.append(countBucketsText(title: "Suppressed by mode", buckets: traceSummary.suppressedByMode))
        sections.append(countBucketsText(title: "Actionable suppressed by app", buckets: traceSummary.actionableSuppressedByApp))
        sections.append(countBucketsText(title: "Actionable suppressed by mode", buckets: traceSummary.actionableSuppressedByMode))
        sections.append(nestedCountBucketsText(title: "Anchor quality by app", buckets: traceSummary.anchorQualityByApp))
        sections.append(nestedCountBucketsText(title: "Insertion mode by app", buckets: traceSummary.insertionModeByApp))
        sections.append(nestedCountBucketsText(
            title: "Insertion failures by app and mode",
            buckets: traceSummary.insertionFailuresByAppAndMode
        ))
        sections.append(nestedCountBucketsText(title: "Update source by app", buckets: traceSummary.updateSourceByApp))
        sections.append(nestedCountBucketsText(title: "AX failure reason by app", buckets: traceSummary.axFailureReasonByApp))
        sections.append(topMissesText(traceSummary.topMisses))

        if let profile {
            sections.append(
                """
                Compatibility profile:
                  app: \(profile.displayName) (\(profile.bundleIdentifier))
                  family: \(profile.appFamily.rawValue)
                  render mode: \(profile.renderMode.rawValue)
                  insertion mode: \(profile.insertionMode.rawValue)
                  fallback render: \(profile.fallbackRenderMode?.rawValue ?? "none")
                  fallback insertion: \(profile.fallbackInsertionMode?.rawValue ?? "none")
                  field identity: \(profile.fieldIdentityMode.rawValue)
                  anchor ladder: \(profile.anchorLadder.map(\.rawValue).joined(separator: " > "))
                  field anchor: \(profile.allowsFieldAnchor)
                  window anchor: \(profile.allowsWindowAnchor)
                  requires validated caret: \(profile.requiresValidatedCaret)
                  observer updates: \(profile.supportsObserverUpdates)
                  one-word accept: \(profile.supportsOneWordAcceptance)
                  full accept: \(profile.supportsFullAcceptance)
                  Esc suppression: \(profile.suppressesUntilBlurAfterEscape)
                  suppress after failed insert: \(profile.suppressesAfterInsertionFailure)
                  sensitive: \(profile.isSensitive)
                  known failures: \(profile.knownFailureModes.isEmpty ? "none" : profile.knownFailureModes.joined(separator: "; "))
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
        tracePrivacySummary: String,
        tracingPaused: Bool,
        screenshotTracingEnabled: Bool,
        compatibilityLearningPath: String,
        compatibilityLearningProfile: CompatibilityLearningProfile?
    ) -> String {
        """
        Trace eval:
          path: \(tracePath)
          privacy: \(tracePrivacySummary)
          tracing: \(tracingPaused ? "paused" : "on")
          screenshot tracing: \(screenshotTracingEnabled ? "on" : "off")
          raw mode warning: \(tracePrivacySummary.contains("raw") ? "typed text may be persisted locally" : "typed text is redacted")
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
          accept rate: \(Self.percent(summary.acceptRate))
          useful rate: \(Self.percent(summary.usefulRate))
          p50 latency: \(Self.latency(summary.p50LatencyMilliseconds))
          p90 latency: \(Self.latency(summary.p90LatencyMilliseconds))
          p95 latency: \(Self.latency(summary.p95LatencyMilliseconds))
        """
    }

    private func whyNoSuggestionText(
        diagnostics: FocusedTextDiagnostics?,
        profile: CompatibilityProfile?,
        compatibilityStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        appTrusted: Bool,
        runtimeReport: RuntimeReadinessReport,
        anchorDecisionSummary: String?,
        traceSummary: AutocompleteTraceSummary
    ) -> String {
        let currentReason = currentNoSuggestionReason(
            diagnostics: diagnostics,
            profile: profile,
            compatibilityStatus: compatibilityStatus,
            appEnabled: appEnabled,
            appTrusted: appTrusted,
            runtimeReport: runtimeReport,
            anchorDecisionSummary: anchorDecisionSummary
        )
        let recentReasons = recentNoSuggestionReasons(traceSummary.suppressedByReason)

        return """
        Why no suggestion:
          now: \(currentReason)
        \(recentReasons)
        """
    }

    private func currentNoSuggestionReason(
        diagnostics: FocusedTextDiagnostics?,
        profile: CompatibilityProfile?,
        compatibilityStatus: CompatibilitySupportStatus,
        appEnabled: Bool,
        appTrusted: Bool,
        runtimeReport: RuntimeReadinessReport,
        anchorDecisionSummary: String?
    ) -> String {
        if !appTrusted {
            return "Accessibility permission is missing, so the app cannot read the focused field."
        }

        if !appEnabled {
            return "Suggestions are paused or disabled for the current app."
        }

        if !runtimeReport.allowsSuggestions {
            return "The local model is not ready. Next action: \(runtimeReport.action.displayName)."
        }

        guard let profile else {
            return "The current app is not allowed yet. \(compatibilityStatus.summary)."
        }

        if !profile.canPresentSuggestions {
            return "\(profile.displayName) is diagnostics-only until insertion and caret behavior are proven."
        }

        if diagnostics?.isSecure == true {
            return "The focused field looks private or secure, so suggestions stay off."
        }

        if let anchorDecisionSummary, anchorDecisionSummary.contains("canPresent=false") {
            return "Caret placement is not trusted enough to show a suggestion: \(anchorDecisionSummary)."
        }

        if diagnostics == nil {
            return "No focused text field is visible to Accessibility right now."
        }

        return "Nothing is blocked right now. If no text appears, check recent suppressed reasons below."
    }

    private func recentNoSuggestionReasons(_ buckets: [String: Int]) -> String {
        let topReasons = buckets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .prefix(5)

        guard !topReasons.isEmpty else {
            return "  recent: none recorded yet"
        }

        let lines = topReasons.map { reason, count in
            "  recent: \(reason) (\(count)) - \(plainNoSuggestionReason(reason))"
        }

        return lines.joined(separator: "\n")
    }

    private func plainNoSuggestionReason(_ reason: String) -> String {
        switch reason {
        case "profile-diagnostics-only":
            return "this app is being observed only, not completed into yet"
        case "runtime-not-ready":
            return "the local model is missing, loading, or failed"
        case "secure-field", "secureField":
            return "the field looks private or password-like"
        case "suppressed-field", "suppressedField":
            return "Esc or a failed insertion calmed this field until focus changes"
        case "sensitiveContent":
            return "the nearby text looks like payment, token, password, or key material"
        case "tooLittleContext":
            return "there is not enough typed context yet"
        case "middleOfLine":
            return "the cursor is in the middle of existing text"
        case "unfinishedWord":
            return "the app is waiting for a clearer word or phrase boundary"
        case "missing-inline-capabilities":
            return "the app did not expose enough Accessibility data for inline placement"
        case "detached-suggestion-disabled":
            return "only a whole-field/window anchor was available, so the bubble stayed hidden"
        case "empty-suggestion":
            return "the model returned nothing useful"
        case "repeated-miss":
            return "the same bad suggestion was typed over too often"
        case "no-fast-word-candidate":
            return "word completion did not have a confident local candidate"
        default:
            return "see recent trace events for the exact context"
        }
    }

    private func topMissesText(_ misses: [AutocompleteTraceMiss]) -> String {
        guard !misses.isEmpty else {
            return "Top 10 misses: none yet"
        }

        return """
        Top 10 misses:
        \(misses.enumerated().map { index, miss in
            "  \(index + 1). \(miss.title) | count=\(miss.count) | app=\(miss.appBundleIdentifier.isEmpty ? "unknown" : miss.appBundleIdentifier) | mode=\(miss.requestMode.isEmpty ? "unknown" : miss.requestMode) | fix=\(miss.fixCategory) | cause=\(miss.suggestedCause) | example=\(miss.exampleSuggestionID)"
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

    private func nestedCountBucketsText(title: String, buckets: [String: [String: Int]]) -> String {
        guard !buckets.isEmpty else {
            return "\(title): none yet"
        }

        let lines = buckets
            .sorted { $0.key < $1.key }
            .flatMap { app, values in
                values
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return lhs.key < rhs.key
                        }

                        return lhs.value > rhs.value
                    }
                    .map { key, value in
                        "  \(app): \(key)=\(value)"
                    }
            }
            .joined(separator: "\n")

        return """
        \(title):
        \(lines)
        """
    }

    private func recentTraceText(_ events: [AutocompleteTraceEvent]) -> String {
        guard !events.isEmpty else {
            return "Recent trace events: none yet"
        }

        return """
        Recent trace events:
        \(events.suffix(16).map {
            "  \($0.timestamp) \($0.type.rawValue) mode=\($0.requestMode) app=\($0.appBundleIdentifier) shown=\($0.displayedText) accepted=\($0.acceptedText) reason=\($0.reason) latency=\(Self.latency($0.latencyMilliseconds))"
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

    @objc
    private func refresh() {
        refreshAction?()
    }

    @objc
    private func toggleTracing() {
        toggleTracingAction?()
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
