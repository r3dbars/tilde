import AppKit
import AutocompleteLabCore

private extension Collection where Element == AutocompleteTraceEvent {
    func latestEvent(containingAny keys: Set<String>) -> AutocompleteTraceEvent? {
        reversed().first { event in
            !keys.isDisjoint(with: Set(event.metadata.keys))
        }
    }
}

struct DiagnosticsInspectorState: Equatable {
    let appTrusted: Bool
    let appEnabled: Bool
    let compatibilityStatus: CompatibilitySupportStatus
    let lastSuggestionDecision: String
    let runtimeReport: RuntimeReadinessReport
    let runtimeTargetSummary: String
    var pauseControl: ControlPauseState = ControlPauseState(isPaused: false, pausedUntil: nil)
    let tracePath: String
    let tracingPaused: Bool
    let screenshotTracingEnabled: Bool
    let compatibilityLearningPath: String
    let compatibilityLearningProfile: CompatibilityLearningProfile?

    var summaryText: String {
        """
        Status:
          Suggestions: \(lastSuggestionDecision)
          Next action: \(nextActionText)
          Accessibility: \(appTrusted ? "allowed" : "needed")
          \(pauseControl.statusText)
          App: \(compatibilityStatus.userFacingSummary), \(appEnabled ? "allowed" : "blocked")
          Mode: \(Self.modeText(for: compatibilityStatus))
          Local model: \(runtimeReport.summary)
          Runtime target: \(runtimeTargetSummary)
          Local recording: \(tracingPaused ? "paused" : "recording")
          Screenshots: \(screenshotTracingEnabled ? "on" : "off")
          Check data file: \(tracePath)
          Learning file: \(compatibilityLearningPath)
          Learned adapter: \(compatibilityLearningProfile?.debugSummary ?? "none")
        """
    }

    private var nextActionText: String {
        if !appTrusted {
            return "Allow Accessibility"
        }

        if runtimeReport.action != .none {
            return runtimeReport.action.displayName
        }

        if pauseControl.isPaused {
            return "Resume Suggestions"
        }

        if !compatibilityStatus.canToggleSuggestions {
            return "Open TextEdit or another supported writing app"
        }

        if !appEnabled {
            return "Resume this app if you want suggestions here"
        }

        return "Type in a supported writing app"
    }

    private static func modeText(for status: CompatibilitySupportStatus) -> String {
        guard case let .supported(profile) = status else {
            return "off"
        }

        if profile.supportLevel == .yellow,
           profile.fallbackRenderMode == .floatingMirror {
            return "mirror"
        }

        switch profile.renderMode {
        case .inlineAdjacent:
            return "inline"
        case .floatingMirror:
            return "mirror"
        case .disabled:
            return "off"
        }
    }
}

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
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 12, height: 12)

        refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
        pauseTracingButton = NSButton(title: "Pause Recording", target: nil, action: nil)
        screenshotTracingButton = NSButton(title: "Placement Screenshots", target: nil, action: nil)
        openTraceFolderButton = NSButton(title: "Logs Folder", target: nil, action: nil)
        exportReportButton = NSButton(title: "Export Privacy Bundle", target: nil, action: nil)
        deleteTracesButton = NSButton(title: "Delete Logs", target: nil, action: nil)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
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
        pauseTracingButton.toolTip = "Pauses diagnostics recording only. Suggestions use the Suggestion controls."
        screenshotTracingButton.target = self
        screenshotTracingButton.action = #selector(toggleScreenshotTracing)
        screenshotTracingButton.toolTip = "Saves local screenshots for placement checks."
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
        pauseControl: ControlPauseState = ControlPauseState(isPaused: false, pausedUntil: nil),
        modelDirectoryPath: String,
        recentEvents: [String],
        traceSummary: AutocompleteTraceSummary,
        personalCaptureScorecard: SuggestionEpisodeScorecard?,
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
        pauseTracingButton.title = tracingPaused ? "Resume Recording" : "Pause Recording"
        screenshotTracingButton.title = screenshotTracingEnabled ? "Placement Screenshots On" : "Placement Screenshots Off"

        var sections: [String] = []

        sections.append(DiagnosticsOverviewState(
            appTrusted: appTrusted,
            appEnabled: appEnabled,
            lastSuggestionDecision: lastSuggestionDecision,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            pauseControl: pauseControl,
            compatibilityStatus: compatibilityStatus,
            diagnostics: diagnostics,
            traceSummary: traceSummary,
            tracingPaused: tracingPaused,
            screenshotTracingEnabled: screenshotTracingEnabled
        ).text)
        sections.append(
            """
            Local model check:
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
        sections.append(SuggestionLearningDiagnostics(
            summary: traceSummary,
            recentEvents: recentTraceEvents
        ).text)
        sections.append(PersonalCaptureLoopDiagnostics(
            scorecard: personalCaptureScorecard
        ).text)
        sections.append(PromptContextDiagnostics(
            recentEvents: recentTraceEvents
        ).text)
        sections.append(PlacementDiagnostics(
            summary: traceSummary,
            recentEvents: recentTraceEvents
        ).text)
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
        sections.append(DiagnosticsTraceHistory(events: recentTraceEvents).summaryText)
        sections.append(typingHealthText(recentEvents))
        sections.append(recentDiagnosticsText(recentEvents))

        textView.string = sections.joined(separator: "\n\n")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func nativeAppearanceSnapshotPNGData(appearanceName: NSAppearance.Name) -> Data? {
        guard let contentView = window.contentView,
              let appearance = NSAppearance(named: appearanceName) else {
            return nil
        }

        let previousAppearance = window.appearance
        window.appearance = appearance
        defer {
            window.appearance = previousAppearance
        }

        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        let bounds = contentView.bounds
        guard !bounds.isEmpty,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        contentView.cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
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
        Local check data:
          path: \(tracePath)
          recording: \(tracingPaused ? "paused" : "on")
          placement screenshots: \(screenshotTracingEnabled ? "on" : "off")
          app learning file: \(compatibilityLearningPath)
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

struct DiagnosticsOverviewState: Equatable {
    let accessibilityText: String
    let suggestionText: String
    let nextActionText: String
    let localModelText: String
    let pauseText: String
    let currentAppText: String
    let tracingText: String

    init(
        appTrusted: Bool,
        appEnabled: Bool,
        lastSuggestionDecision: String,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        pauseControl: ControlPauseState = ControlPauseState(isPaused: false, pausedUntil: nil),
        compatibilityStatus: CompatibilitySupportStatus,
        diagnostics: FocusedTextDiagnostics?,
        traceSummary: AutocompleteTraceSummary,
        tracingPaused: Bool,
        screenshotTracingEnabled: Bool
    ) {
        accessibilityText = appTrusted ? "On" : "Needs permission"
        suggestionText = Self.suggestionSummary(lastSuggestionDecision)
        nextActionText = Self.nextActionText(
            appTrusted: appTrusted,
            appEnabled: appEnabled,
            runtimeReport: runtimeReport,
            pauseControl: pauseControl,
            compatibilityStatus: compatibilityStatus
        )
        localModelText = Self.oneLine(runtimeReport.summary, maxLength: 140)
        pauseText = Self.pauseSummary(pauseControl.statusText)

        let appName = diagnostics?.localizedAppName ?? "No focused app"
        let bundle = diagnostics?.bundleIdentifier.map { " (\($0))" } ?? ""
        let enabledText = appEnabled ? "enabled" : "disabled"
        currentAppText = Self.oneLine(
            "\(appName)\(bundle) | \(compatibilityStatus.summary) | \(enabledText)",
            maxLength: 140
        )
        tracingText = Self.oneLine(
            "recording \(tracingPaused ? "paused" : "on") | placement screenshots \(screenshotTracingEnabled ? "on" : "off") | events \(traceSummary.totalEvents) | accept \(Self.percent(traceSummary.acceptRate)) | useful \(Self.percent(traceSummary.usefulRate))",
            maxLength: 140
        )
    }

    var text: String {
        [
            "Status",
            "Suggestions: \(suggestionText)",
            "Next action: \(nextActionText)",
            "Accessibility: \(accessibilityText)",
            "Suggestion pause: \(pauseText)",
            "Local model: \(localModelText)",
            "Current app: \(currentAppText)",
            "Local recording: \(tracingText)"
        ].joined(separator: "\n")
    }

    private static func nextActionText(
        appTrusted: Bool,
        appEnabled: Bool,
        runtimeReport: RuntimeReadinessReport,
        pauseControl: ControlPauseState,
        compatibilityStatus: CompatibilitySupportStatus
    ) -> String {
        if !appTrusted {
            return "Allow Accessibility"
        }

        if runtimeReport.action != .none {
            return runtimeReport.action.displayName
        }

        if pauseControl.isPaused {
            return "Resume Suggestions"
        }

        if !compatibilityStatus.canToggleSuggestions {
            return "Open TextEdit or another supported writing app"
        }

        if !appEnabled {
            return "Resume this app if you want suggestions here"
        }

        return "Type in a supported writing app"
    }

    private static func pauseSummary(_ text: String) -> String {
        text.replacingOccurrences(of: "Suggestion pause: ", with: "")
    }

    private static func suggestionSummary(_ decision: String) -> String {
        let trimmed = oneLine(decision, maxLength: 100)
        guard !trimmed.isEmpty else {
            return "No suggestion yet"
        }

        if trimmed.localizedCaseInsensitiveContains("shown") {
            return "Shown"
        }

        for prefix in ["Blocked:", "Waiting:", "Ready:", "Paused", "Starting"] where trimmed.hasPrefix(prefix) {
            return trimmed
        }

        return trimmed
    }

    private static func oneLine(_ text: String, maxLength: Int) -> String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxLength else {
            return collapsed
        }

        let cutoff = collapsed.index(collapsed.startIndex, offsetBy: maxLength - 1)
        return String(collapsed[..<cutoff]) + "..."
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

struct PersonalCaptureLoopDiagnostics: Equatable {
    let scorecard: SuggestionEpisodeScorecard?

    var text: String {
        guard let scorecard else {
            return "Personal Capture loop: off"
        }

        let latency = scorecard.averageLatencyMilliseconds.map { "\($0)ms" } ?? "n/a"
        let rows = scorecard.modelPromptRows.isEmpty
            ? "  none yet"
            : scorecard.modelPromptRows.prefix(5).map { "  \($0)" }.joined(separator: "\n")

        return """
        Personal Capture loop:
          score: \(scorecard.score)/100
          episodes: \(scorecard.total)
          accepted: \(scorecard.accepted)
          kept: \(scorecard.kept)
          ignored: \(scorecard.ignored)
          dismissed: \(scorecard.dismissed)
          typed past: \(scorecard.typedPast)
          deleted fast: \(scorecard.deletedFast)
          eval cases: \(scorecard.evalCaseCount)
          average latency: \(latency)
        Model / prompt:
        \(rows)
        """
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

struct PromptContextDiagnostics: Equatable {
    let recentEvents: [AutocompleteTraceEvent]

    var text: String {
        [
            headlineText,
            latestDocumentTitleShapeText,
            latestPartialWordShapeText,
            latestCurrentLineShapeText,
            latestVisiblePageContextFilterText
        ].joined(separator: "\n")
    }

    private var headlineText: String {
        "Prompt context diagnostics: recent shape events \(shapeEvents.count)"
    }

    private var latestDocumentTitleShapeText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "documentTitleWordCount",
            "documentTitleLengthBucket"
        ]) else {
            return "Document title shape: no recent title-shape metadata"
        }

        let words = event.metadata["documentTitleWordCount"] ?? "unknown"
        let length = event.metadata["documentTitleLengthBucket"] ?? "unknown"
        let fileExtension = event.metadata["documentTitleExtension"] ?? "none"
        let untitled = event.metadata["documentTitleIsUntitled"] ?? "unknown"
        let unsaved = event.metadata["documentTitleHasUnsavedMarker"] ?? "unknown"
        return "Document title shape: length=\(length), words=\(words), extension=\(fileExtension), untitled=\(untitled), unsaved=\(unsaved)"
    }

    private var latestPartialWordShapeText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "partialWordCharacters",
            "partialWordLetters"
        ]) else {
            return "Partial word shape: no recent partial-word metadata"
        }

        let characters = event.metadata["partialWordCharacters"] ?? "unknown"
        let letters = event.metadata["partialWordLetters"] ?? "unknown"
        let digits = event.metadata["partialWordDigits"] ?? "unknown"
        let casing = event.metadata["partialWordCasing"] ?? "unknown"
        let hyphen = event.metadata["partialWordHasHyphen"] ?? "unknown"
        let apostrophe = event.metadata["partialWordHasApostrophe"] ?? "unknown"
        return "Partial word shape: chars=\(characters), letters=\(letters), digits=\(digits), casing=\(casing), hyphen=\(hyphen), apostrophe=\(apostrophe)"
    }

    private var latestCurrentLineShapeText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "currentLineStructure",
            "currentLineMarkerStyle"
        ]) else {
            return "Current line shape: no recent line-shape metadata"
        }

        let kind = event.metadata["currentLineStructure"] ?? "unknown"
        let marker = event.metadata["currentLineMarkerStyle"] ?? "unknown"
        let indentation = event.metadata["currentLineIndentationColumns"] ?? "unknown"
        let contentWords = event.metadata["currentLineContentWords"] ?? "unknown"
        return "Current line shape: kind=\(kind), marker=\(marker), indent=\(indentation), contentWords=\(contentWords)"
    }

    private var latestVisiblePageContextFilterText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "visiblePageContextActiveLineFiltered"
        ]) else {
            return "Screen context active-line filter: no recent OCR context metadata"
        }

        switch event.metadata["visiblePageContextActiveLineFiltered"]?.lowercased() {
        case "true", "1", "yes":
            return "Screen context active-line filter: removed active typed line"
        case "false", "0", "no":
            return "Screen context active-line filter: no active line removed"
        default:
            return "Screen context active-line filter: unknown"
        }
    }

    private var shapeEvents: [AutocompleteTraceEvent] {
        recentEvents.filter { event in
            event.metadata.keys.contains { key in
                key.hasPrefix("documentTitle")
                    || key.hasPrefix("partialWord")
                    || key.hasPrefix("currentLine")
            }
        }
    }
}

struct PlacementDiagnostics: Equatable {
    let summary: AutocompleteTraceSummary
    let recentEvents: [AutocompleteTraceEvent]

    var text: String {
        [
            headlineText,
            latestPlacementText,
            countBucketsText(title: "Recent confidence bands", buckets: confidenceBandCounts),
            countBucketsText(title: "Placement self-healing actions", buckets: selfHealingActionCounts),
            countBucketsText(title: "Render mode transitions", buckets: renderModeTransitionCounts),
            nestedCountBucketsText(title: "Anchor quality by app", buckets: summary.anchorQualityByApp),
            failureRatesText(
                title: "Caret failures by app",
                counts: summary.caretGeometryFailuresByApp,
                rates: summary.caretGeometryFailureRateByApp
            ),
            failureRatesText(
                title: "Caret failures by render mode",
                counts: summary.caretGeometryFailuresByRenderMode,
                rates: summary.caretGeometryFailureRateByRenderMode
            )
        ].joined(separator: "\n")
    }

    private var headlineText: String {
        "Placement diagnostics: caret failures \(summary.caretGeometryFailureCount) (\(Self.percent(summary.caretGeometryFailureRate))), recent placement events \(recentPlacementEvents.count)"
    }

    private var latestPlacementText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "placementConfidenceScore",
            "placementConfidenceBand",
            "placementAnchorSource",
            "placementRequestedRenderMode",
            "placementEffectiveRenderMode",
            "placementSelfHealingAction"
        ]) else {
            return "Current placement: no recent placement metadata"
        }

        let score = event.metadata["placementConfidenceScore"] ?? "unknown"
        let band = event.metadata["placementConfidenceBand"] ?? "unknown"
        let anchor = event.metadata["placementAnchorSource"] ?? "unknown"
        let requestedRenderMode = event.metadata["placementRequestedRenderMode"]
            ?? event.metadata["requestedRenderMode"]
            ?? "unknown"
        let effectiveRenderMode = event.metadata["placementEffectiveRenderMode"]
            ?? event.metadata["effectiveRenderMode"]
            ?? "unknown"
        let selfHealingApplied = event.metadata["placementSelfHealingApplied"] ?? "unknown"
        let selfHealingAction = event.metadata["placementSelfHealingAction"] ?? "unknown"
        let eventReason = event.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = event.metadata["placementHealthReason"] ?? (eventReason.isEmpty ? "none" : eventReason)

        return "Current placement: confidence=\(score) (\(band)), anchor=\(anchor), render=\(requestedRenderMode)->\(effectiveRenderMode), selfHealing=\(selfHealingApplied)/\(selfHealingAction), clipping=\(clippingDescription(for: event)), screenshot=\(screenshotDescription(for: event)), reason=\(reason)"
    }

    private var recentPlacementEvents: [AutocompleteTraceEvent] {
        recentEvents.filter { event in
            event.metadata.keys.contains { $0.hasPrefix("placement") }
        }
    }

    private var confidenceBandCounts: [String: Int] {
        counts(for: recentPlacementEvents.compactMap { $0.metadata["placementConfidenceBand"] })
    }

    private var selfHealingActionCounts: [String: Int] {
        counts(for: recentPlacementEvents.compactMap { $0.metadata["placementSelfHealingAction"] })
    }

    private var renderModeTransitionCounts: [String: Int] {
        counts(for: recentPlacementEvents.compactMap { event in
            guard let requested = event.metadata["placementRequestedRenderMode"],
                  let effective = event.metadata["placementEffectiveRenderMode"] else {
                return nil
            }

            return "\(requested)->\(effective)"
        })
    }

    private func clippingDescription(for event: AutocompleteTraceEvent) -> String {
        if let clipped = event.metadata["placementClipped"] {
            return clipped
        }

        guard let clippingRect = event.metadata["clippingRect"] else {
            return "unknown"
        }

        return clippingRect == "none" ? "missing" : "available"
    }

    private func screenshotDescription(for event: AutocompleteTraceEvent) -> String {
        if let screenshotCaptured = event.metadata["screenshotCaptured"] {
            return screenshotCaptured
        }

        return event.screenshotPath.isEmpty ? "false" : "true"
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

        return """
        \(title):
        \(buckets.sorted { $0.key < $1.key }.map { app, counts in
            let countText = counts
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value {
                        return lhs.key < rhs.key
                    }

                    return lhs.value > rhs.value
                }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            return "  \(app): \(countText)"
        }.joined(separator: "\n"))
        """
    }

    private func failureRatesText(title: String, counts: [String: Int], rates: [String: Double]) -> String {
        let keys = Set(counts.keys).union(rates.keys)
        guard !keys.isEmpty else {
            return "\(title): none yet"
        }

        return """
        \(title):
        \(keys.sorted().map { key in
            let count = counts[key] ?? 0
            let rate = rates[key] ?? 0
            return "  \(key): \(count) (\(Self.percent(rate)))"
        }.joined(separator: "\n"))
        """
    }

    private func counts(for values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { result, value in
            result[value, default: 0] += 1
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct SuggestionLearningDiagnostics: Equatable {
    let summary: AutocompleteTraceSummary
    let recentEvents: [AutocompleteTraceEvent]

    var text: String {
        [
            headlineText,
            acceptedAndKeptText(title: "Accepted-kept by app", buckets: summary.acceptedAndKeptRateByApp),
            acceptedAndKeptText(title: "Accepted-kept by mode", buckets: summary.acceptedAndKeptRateByRequestMode),
            countBucketsText(title: "Annoyance signals", buckets: summary.annoyanceSignalCounts),
            recentQuietModeText,
            recentDisplayAffinityText,
            recentRepeatedMissText,
            recentPrefixCooldownText,
            recentStyleSketchText
        ].joined(separator: "\n")
    }

    private var headlineText: String {
        "Learning diagnostics: accepted-kept \(summary.acceptedAndKeptCount) (\(Self.percent(summary.acceptedAndKeptRateAccepted)) of accepted, \(Self.percent(summary.acceptedAndKeptRateShown)) of shown), typed-over \(summary.typedOverCount), ignored \(summary.ignoredCount), annoyance \(Self.score(summary.annoyanceScore))"
    }

    private var recentDisplayAffinityText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "displayScoreAcceptedAndKeptProbability",
            "displayScoreAcceptedAndKeptSamples"
        ]) else {
            return "Current display affinity: no recent accepted-kept gate metadata"
        }

        let probability = event.metadata["displayScoreAcceptedAndKeptProbability"] ?? "unknown"
        let samples = event.metadata["displayScoreAcceptedAndKeptSamples"] ?? "0"
        let threshold = event.metadata["displayScoreAcceptedAndKeptThreshold"] ?? "n/a"
        return "Current display affinity: probability=\(probability), samples=\(samples), threshold=\(threshold)"
    }

    private var recentQuietModeText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "quietMode",
            "quietReason",
            "quietScore",
            "annoyanceSignal"
        ]) else {
            return "Quiet mode: no recent quiet-mode metadata"
        }

        let mode = event.metadata["quietMode"] ?? "unknown"
        let signal = event.metadata["annoyanceSignal"] ?? "unknown"
        let reason = event.metadata["quietReason"] ?? event.metadata["annoyanceReason"] ?? "unknown"
        let score = event.metadata["quietScore"] ?? event.metadata["annoyanceFieldScore"] ?? "unknown"
        let until = event.metadata["quietUntil"].map { ", until=\($0)" } ?? ""
        return "Quiet mode: scope=\(mode), signal=\(signal), reason=\(reason), score=\(score)\(until)"
    }

    private var recentRepeatedMissText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "repetitionMissTotal",
            "repetitionMissSuppressed"
        ]) else {
            return "Repeated miss state: no recent miss-score metadata"
        }

        let kind = event.metadata["repetitionMissKind"] ?? "miss"
        let total = event.metadata["repetitionMissTotal"] ?? "unknown"
        let threshold = event.metadata["repetitionMissThreshold"] ?? "unknown"
        let suppressed = event.metadata["repetitionMissSuppressed"] ?? "false"
        let lifetime = event.metadata["repetitionMissLifetimeMs"].map { ", lifetime=\($0)ms" } ?? ""
        return "Repeated miss state: kind=\(kind), score=\(total)/\(threshold), suppressed=\(suppressed)\(lifetime)"
    }

    private var recentPrefixCooldownText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "prefixCooldownReason",
            "prefixCooldownDurationMilliseconds"
        ]) else {
            return "Prefix cooldown: no recent cooldown metadata"
        }

        let reason = event.metadata["prefixCooldownReason"] ?? "unknown"
        let duration = event.metadata["prefixCooldownDurationMilliseconds"] ?? "unknown"
        let tokens = event.metadata["prefixFamilyTokenCount"] ?? "unknown"
        let escalated = event.metadata["prefixCooldownEscalated"] ?? "false"
        let hash = event.metadata["prefixFamilyHMACToken"].map { ", familyHash=\($0)" } ?? ""
        return "Prefix cooldown: reason=\(reason), duration=\(duration)ms, familyTokens=\(tokens), escalated=\(escalated)\(hash)"
    }

    private var recentStyleSketchText: String {
        guard let event = recentEvents.latestEvent(containingAny: [
            "styleSketchSamples",
            "styleSketchAverageWords"
        ]) else {
            return "Style sketch: no recent aggregate style metadata"
        }

        let samples = event.metadata["styleSketchSamples"] ?? "0"
        let averageWords = event.metadata["styleSketchAverageWords"] ?? "unknown"
        let punctuation = event.metadata["styleSketchTerminalPunctuationRate"] ?? "unknown"
        let lowercase = event.metadata["styleSketchLowercaseStartRate"] ?? "unknown"
        let questions = event.metadata["styleSketchQuestionEndingRate"] ?? "unknown"
        return "Style sketch: samples=\(samples), avgWords=\(averageWords), terminalPunctuation=\(punctuation), lowercaseStarts=\(lowercase), questionEndings=\(questions)"
    }

    private func acceptedAndKeptText(title: String, buckets: [String: Double]) -> String {
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

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func score(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

struct DiagnosticsTypingHealth {
    private var keySamples = 0
    private var keySummarySamples = 0
    private var keyMaxMicros: Int?
    private var keyP95Micros: Int?
    private var slowKeyMarkers = 0
    private var disabledKeyEvents = 0
    private var startFailedKeyEvents = 0
    private var failedClosedKeyEvents = 0
    private var replayedCapturedKeyEvents = 0
    private var droppedCapturedKeyEvents = 0

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
        if startFailedKeyEvents > 0 {
            return "needs attention - event tap start failed \(startFailedKeyEvents)x"
        }

        if failedClosedKeyEvents > 0 {
            return "needs attention - event tap failed closed \(failedClosedKeyEvents)x"
        }

        if disabledKeyEvents > 0 {
            return "needs attention - event tap disabled \(disabledKeyEvents)x"
        }

        if slowKeyMarkers > 0 {
            return "needs attention - slow key capture \(slowKeyMarkers)x"
        }

        if droppedCapturedKeyEvents > 0 {
            return "needs attention - captured key dropped \(droppedCapturedKeyEvents)x"
        }

        if keySamples + keySummarySamples == 0 {
            return "no recent key samples"
        }

        return "healthy"
    }

    var keySampleDescription: String {
        "raw=\(keySamples), summary=\(keySummarySamples), p95=\(microseconds(keyP95Micros)), max=\(microseconds(keyMaxMicros)), replayed=\(replayedCapturedKeyEvents), dropped=\(droppedCapturedKeyEvents)"
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
        case "keyboard-event-tap-start-failed":
            startFailedKeyEvents += 1
        case "keyboard-event-tap-failed-closed":
            failedClosedKeyEvents += 1
        case "keyboard-event-tap-replayed-captured-key":
            replayedCapturedKeyEvents += 1
        case "keyboard-event-tap-unhandled-consumed-key-dropped":
            droppedCapturedKeyEvents += 1
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
