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
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 12, height: 12)

        refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
        pauseTracingButton = NSButton(title: "Pause", target: nil, action: nil)
        screenshotTracingButton = NSButton(title: "Screenshots", target: nil, action: nil)
        openTraceFolderButton = NSButton(title: "Trace Folder", target: nil, action: nil)
        exportReportButton = NSButton(title: "Export", target: nil, action: nil)
        deleteTracesButton = NSButton(title: "Delete", target: nil, action: nil)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
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
        buttonStack.alignment = .centerY
        buttonStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 6, right: 10)
        [
            refreshButton,
            pauseTracingButton,
            screenshotTracingButton,
            openTraceFolderButton,
            exportReportButton,
            deleteTracesButton
        ].forEach {
            $0.bezelStyle = .rounded
            $0.controlSize = .small
            $0.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        }

        let contentStack = NSStackView(views: [buttonStack, scrollView])
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 460).isActive = true
        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 780, height: 560))
        contentView.material = .contentBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.addSubview(contentStack)

        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Diagnostics"
        window.contentView = contentView
        window.contentMinSize = NSSize(width: 680, height: 460)
        window.isMovableByWindowBackground = true
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

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
        lastSuggestionDecision: String,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        recentEvents: [String],
        traceSummary: AutocompleteTraceSummary,
        recentTraceEvents: [AutocompleteTraceEvent],
        tracePath: String,
        tracingPaused: Bool,
        screenshotTracingEnabled: Bool,
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
        pauseTracingButton.title = tracingPaused ? "Resume" : "Pause"
        screenshotTracingButton.title = screenshotTracingEnabled ? "Screenshots On" : "Screenshots Off"

        var sections: [String] = []

        sections.append("Accessibility: \(appTrusted ? "on" : "needed")")
        sections.append("Suggestion: \(lastSuggestionDecision)")
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
        sections.append("App enabled: \(appEnabled)")
        sections.append(traceSummaryText(
            traceSummary,
            tracePath: tracePath,
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
        sections.append(topMissesText(traceSummary.topMisses))
        sections.append(DiagnosticsPlacementEvidence(events: recentTraceEvents).summaryText)

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
        sections.append(typingHealthText(recentEvents))
        sections.append(recentDiagnosticsText(recentEvents))

        textView.string = sections.joined(separator: "\n\n")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func traceSummaryText(
        _ summary: AutocompleteTraceSummary,
        tracePath: String,
        tracingPaused: Bool,
        screenshotTracingEnabled: Bool,
        compatibilityLearningPath: String,
        compatibilityLearningProfile: CompatibilityLearningProfile?
    ) -> String {
        """
        Trace eval:
          path: \(tracePath)
          tracing: \(tracingPaused ? "paused" : "on")
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
        DiagnosticsTraceHistory(events: events).summaryText
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

    private func typingHealthText(_ events: [String]) -> String {
        let health = DiagnosticsTypingHealth(events: events)
        return """
        Typing health:
          key capture: \(health.keyCaptureStatus)
          key samples: \(health.keySampleDescription)
          AX polling: \(health.axPollingStatus)
          AX samples: \(health.axSampleDescription)
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

struct DiagnosticsPlacementEvidence {
    let rows: [Row]

    init(events: [AutocompleteTraceEvent]) {
        rows = events.suffix(16).compactMap(Row.init(event:))
    }

    var summaryText: String {
        guard !rows.isEmpty else {
            return "Placement confidence: none yet"
        }

        return """
        Placement confidence:
        \(rows.map(\.description).joined(separator: "\n"))
        """
    }

    struct Row: Equatable {
        let timestamp: String
        let type: String
        let app: String
        let mode: String
        let confidence: String
        let score: String
        let anchor: String
        let health: String
        let action: String
        let screenshot: String
        let shownChars: Int
        let acceptedChars: Int

        init?(event: AutocompleteTraceEvent) {
            guard event.metadata["placementConfidenceBand"] != nil
                || event.metadata["placementConfidenceScore"] != nil
                || event.metadata["placementHealthReason"] != nil
                || event.metadata["placementEffectiveRenderMode"] != nil
                || event.metadata["effectiveRenderMode"] != nil else {
                return nil
            }

            timestamp = event.timestamp
            type = event.type.rawValue
            app = event.appBundleIdentifier.isEmpty ? "unknown" : event.appBundleIdentifier
            mode = Self.modeText(event)
            confidence = event.metadata["placementConfidenceBand"] ?? "unknown"
            score = event.metadata["placementConfidenceScore"] ?? "n/a"
            anchor = event.metadata["placementAnchorSource"] ?? "unknown"
            health = event.metadata["placementHealthReason"] ?? (event.reason.isEmpty ? "n/a" : event.reason)
            action = event.metadata["placementSelfHealingAction"] ?? "none"
            screenshot = event.screenshotPath.isEmpty ? "none" : "captured"
            shownChars = DiagnosticsTraceHistory.textLength(
                event,
                text: event.displayedText,
                metadataKeys: ["visibleChars", "displayedTextChars"]
            )
            acceptedChars = DiagnosticsTraceHistory.textLength(
                event,
                text: event.acceptedText,
                metadataKeys: ["acceptedTextChars"]
            )
        }

        var description: String {
            "  \(timestamp) \(type) app=\(app) mode=\(mode) confidence=\(confidence) score=\(score) anchor=\(anchor) health=\(health) action=\(action) screenshot=\(screenshot) shownChars=\(shownChars) acceptedChars=\(acceptedChars)"
        }

        private static func modeText(_ event: AutocompleteTraceEvent) -> String {
            let requested = event.metadata["placementRequestedRenderMode"]
            let effective = event.metadata["placementEffectiveRenderMode"]
                ?? event.metadata["effectiveRenderMode"]
                ?? (event.requestMode.isEmpty ? nil : event.requestMode)
                ?? "unknown"

            guard let requested, requested != effective else {
                return effective
            }

            return "\(requested)->\(effective)"
        }
    }
}

struct DiagnosticsTraceHistory {
    let events: [AutocompleteTraceEvent]

    init(events: [AutocompleteTraceEvent]) {
        self.events = Array(events.suffix(16))
    }

    var summaryText: String {
        guard !events.isEmpty else {
            return "Recent trace events: none yet"
        }

        return """
        Recent trace events:
        \(events.map(Self.rowText).joined(separator: "\n"))
        """
    }

    static func rowText(_ event: AutocompleteTraceEvent) -> String {
        let shownChars = textLength(
            event,
            text: event.displayedText,
            metadataKeys: ["visibleChars", "displayedTextChars"]
        )
        let acceptedChars = textLength(
            event,
            text: event.acceptedText,
            metadataKeys: ["acceptedTextChars"]
        )
        let confidence = event.metadata["placementConfidenceBand"] ?? "n/a"
        let renderMode = event.metadata["placementEffectiveRenderMode"]
            ?? event.metadata["effectiveRenderMode"]
            ?? "n/a"

        return "  \(event.timestamp) \(event.type.rawValue) mode=\(event.requestMode) app=\(event.appBundleIdentifier) shownChars=\(shownChars) acceptedChars=\(acceptedChars) confidence=\(confidence) render=\(renderMode) reason=\(event.reason) latency=\(latency(event.latencyMilliseconds))"
    }

    static func textLength(
        _ event: AutocompleteTraceEvent,
        text: String,
        metadataKeys: [String]
    ) -> Int {
        for key in metadataKeys {
            if let value = event.metadata[key], let length = Int(value) {
                return length
            }
        }

        return text.count
    }

    private static func latency(_ value: Int?) -> String {
        value.map { "\($0)ms" } ?? "n/a"
    }
}

struct DiagnosticsTypingHealth {
    private var keySamples = 0
    private var keySummarySamples = 0
    private var keyMaxMicros: Int?
    private var keyP95Micros: Int?
    private var slowKeyMarkers = 0
    private var disabledKeyEvents = 0

    private var axSummarySamples = 0
    private var axP95Milliseconds: Int?
    private var axMaxMilliseconds: Int?
    private var slowAXMarkers = 0
    private var skippedAXPolls = 0
    private var axCooldowns = 0

    init(events: [String]) {
        for event in events {
            ingest(event)
        }
    }

    var keyCaptureStatus: String {
        if disabledKeyEvents > 0 {
            return "needs attention - event tap disabled \(disabledKeyEvents)x"
        }

        if slowKeyMarkers > 0 {
            return "needs attention - slow key capture \(slowKeyMarkers)x"
        }

        if keySamples + keySummarySamples == 0 {
            return "no recent key samples"
        }

        return "healthy"
    }

    var keySampleDescription: String {
        "raw=\(keySamples), summary=\(keySummarySamples), p95=\(microseconds(keyP95Micros)), max=\(microseconds(keyMaxMicros))"
    }

    var axPollingStatus: String {
        if axCooldowns > 0 {
            return "cooling down slow app reads, typing should pass through"
        }

        if slowAXMarkers > 0 || skippedAXPolls > 0 {
            return "warning - suggestions may lag, typing should pass through"
        }

        if axSummarySamples == 0 {
            return "no recent AX samples"
        }

        return "healthy"
    }

    var axSampleDescription: String {
        "summary=\(axSummarySamples), p95=\(milliseconds(axP95Milliseconds)), max=\(milliseconds(axMaxMilliseconds)), slow=\(slowAXMarkers), skipped=\(skippedAXPolls), cooldowns=\(axCooldowns)"
    }

    private mutating func ingest(_ line: String) {
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            return
        }

        let event = parts[1]
        let fields = Self.fields(from: parts.dropFirst(2))

        switch event {
        case "keyboard-event-tap-latency":
            keySamples += 1
            keyMaxMicros = maxOptional(keyMaxMicros, fields.intValue(for: "durationMicros"))
        case "keyboard-event-tap-latency-summary":
            keySummarySamples += fields.intValue(for: "count") ?? 0
            keyP95Micros = maxOptional(keyP95Micros, fields.intValue(for: "p95Micros"))
            keyMaxMicros = maxOptional(keyMaxMicros, fields.intValue(for: "maxMicros"))
        case "keyboard-event-tap-latency-slow":
            slowKeyMarkers += 1
            keyMaxMicros = maxOptional(keyMaxMicros, fields.intValue(for: "durationMicros"))
        case "keyboard-event-tap-disabled":
            disabledKeyEvents += 1
        case "focused-text-poll-latency-summary":
            axSummarySamples += fields.intValue(for: "count") ?? 0
            axP95Milliseconds = maxOptional(axP95Milliseconds, fields.intValue(for: "p95Milliseconds"))
            axMaxMilliseconds = maxOptional(axMaxMilliseconds, fields.intValue(for: "maxMilliseconds"))
        case "focused-text-poll-latency-slow":
            slowAXMarkers += 1
            axMaxMilliseconds = maxOptional(axMaxMilliseconds, fields.intValue(for: "durationMilliseconds"))
        case "focused-text-ax-read-slow":
            slowAXMarkers += 1
            axMaxMilliseconds = maxOptional(
                axMaxMilliseconds,
                fields.intValue(for: "readDurationMilliseconds")
            )
        case "focused-text-poll-skipped":
            skippedAXPolls += fields.intValue(for: "count") ?? 1
        case "focused-text-poll-skip-summary":
            skippedAXPolls += fields.intValue(for: "count") ?? 0
        case "focused-text-ax-health-cooldown", "focused-text-ax-health-cooldown-started":
            axCooldowns += 1
        default:
            return
        }
    }

    private func maxOptional(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return max(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private static func fields<S: Sequence>(from parts: S) -> [String: String] where S.Element == String {
        var result: [String: String] = [:]
        for part in parts {
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else {
                continue
            }
            result[pieces[0]] = pieces[1]
        }
        return result
    }

    private func microseconds(_ value: Int?) -> String {
        value.map { "\($0)us" } ?? "n/a"
    }

    private func milliseconds(_ value: Int?) -> String {
        value.map { "\($0)ms" } ?? "n/a"
    }
}

private extension Dictionary where Key == String, Value == String {
    func intValue(for key: String) -> Int? {
        guard let value = self[key] else {
            return nil
        }
        return Int(value)
    }
}
