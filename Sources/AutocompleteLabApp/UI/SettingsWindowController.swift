import AppKit
import AutocompleteLabCore

struct SettingsCurrentAppState: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    let supportStatus: CompatibilitySupportStatus
    let isEnabled: Bool
    let disabledAppCount: Int

    var canToggle: Bool {
        bundleIdentifier != nil && supportStatus.canToggleSuggestions
    }

    var statusText: String {
        guard bundleIdentifier != nil else {
            return "Current app: no app selected"
        }

        guard supportStatus.canToggleSuggestions else {
            return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName)"
        }

        return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName) and \(isEnabled ? "allowed" : "blocked")"
    }

    var detailText: String {
        guard bundleIdentifier != nil else {
            return "Open a writing app to see whether suggestions are supported."
        }

        guard supportStatus.canToggleSuggestions else {
            return "\(supportStatus.userFacingReason) Suggestions stay off here."
        }

        if isEnabled {
            return "\(supportStatus.userFacingReason) Suggestions are on for this app."
        }

        return "\(supportStatus.userFacingReason) Suggestions are blocked by your app list."
    }

    var modeText: String {
        guard bundleIdentifier != nil else {
            return "Mode: choose a writing app"
        }

        guard case let .supported(profile) = supportStatus else {
            return "Mode: not tested yet"
        }

        let primary = Self.renderModeName(profile.renderMode)
        guard let fallback = profile.fallbackRenderMode,
              fallback != profile.renderMode,
              fallback != .disabled else {
            return "Mode: \(primary)"
        }

        return "Mode: \(primary), \(Self.renderModeName(fallback)) fallback"
    }

    var acceptanceText: String {
        guard bundleIdentifier != nil else {
            return "Acceptance: off until an app is selected"
        }

        guard case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return "Acceptance: off here"
        }

        switch (profile.supportsOneWordAcceptance, profile.supportsFullAcceptance) {
        case (true, true):
            return "Acceptance: Tab next word + full accept"
        case (true, false):
            return "Acceptance: Tab next word only; full accept is off for safety"
        case (false, true):
            return "Acceptance: full accept only"
        case (false, false):
            return "Acceptance: off here"
        }
    }

    var toggleTitle: String {
        canToggle ? "Allow suggestions in this app" : "Suggestions unavailable in this app"
    }

    var menuToggleTitle: String {
        guard bundleIdentifier != nil else {
            return "Toggle Current App"
        }

        guard canToggle else {
            return "Suggestions unavailable in \(displayName)"
        }

        return isEnabled ? "Disable \(displayName)" : "Enable \(displayName)"
    }

    var blockedAppsText: String {
        if disabledAppCount == 0 {
            return "Blocked apps: none"
        }

        return "Blocked apps: \(disabledAppCount)"
    }

    private static func renderModeName(_ mode: SuggestionRenderMode) -> String {
        switch mode {
        case .inlineAdjacent:
            return "inline"
        case .floatingMirror:
            return "mirror"
        case .disabled:
            return "disabled"
        }
    }
}

struct SettingsPermissionState: Equatable {
    let isTrusted: Bool

    var statusText: String {
        isTrusted ? "Accessibility permission: allowed" : "Accessibility permission: needed"
    }

    var detailText: String {
        if isTrusted {
            return "Autocomplete Lab can read the active text field and insert accepted suggestions. Text stays on this Mac."
        }

        return "Allow Accessibility so Autocomplete Lab can read the active text field, find the cursor, and insert accepted suggestions. Text stays on this Mac."
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let rawContentTracingExpiresAt: Date?
    let screenshotTracingEnabled: Bool
    let screenshotTracingExpiresAt: Date?
    let diagnosticsPath: String
    let tracePath: String

    var statusText: String {
        "Privacy: local diagnostics only"
    }

    var diagnosticsStatusText: String {
        let traceState = tracingPaused ? "paused" : "recording"
        let screenshotState = screenshotTracingEnabled
            ? (screenshotTracingExpiresAt == nil ? "screenshots on" : "screenshots on temporarily")
            : "screenshots off"
        return "Diagnostics: performance + placement traces \(traceState), \(screenshotState)"
    }

    var contentStatusText: String {
        let state = rawContentTracingEnabled
            ? (rawContentTracingExpiresAt == nil ? "on" : "on temporarily")
            : "off"
        return "Raw text capture: \(state)"
    }

    var screenRecordingPermissionText: String? {
        guard screenshotTracingEnabled else {
            return nil
        }

        if screenshotTracingExpiresAt == nil {
            return "Screen Recording: only used for placement screenshots while this debug switch is on."
        }

        return "Screen Recording: only used for temporary placement screenshots."
    }

    var pathText: String {
        "Logs: \(diagnosticsPath) | Traces: \(tracePath)"
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut

    var statusText: String {
        "Shortcuts: Tab next word | \(acceptAllShortcut.displayName) all"
    }

    var cycleButtonTitle: String {
        "Use \(acceptAllShortcut.next.displayName)"
    }
}

@MainActor
final class SettingsWindowController: NSObject {
    private let window: NSWindow
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionDetailLabel = NSTextField(labelWithString: "")
    private let runtimeLabel = NSTextField(labelWithString: "")
    private let runtimeDetailLabel = NSTextField(labelWithString: "")
    private let runtimeActionLabel = NSTextField(labelWithString: "")
    private let runtimeTargetLabel = NSTextField(labelWithString: "")
    private let modelDirectoryLabel = NSTextField(labelWithString: "")
    private let controlLabel = NSTextField(labelWithString: "")
    private let togglePauseButton = NSButton(checkboxWithTitle: "Suggestions", target: nil, action: nil)
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let currentAppDetailLabel = NSTextField(labelWithString: "")
    private let currentAppModeLabel = NSTextField(labelWithString: "")
    private let currentAppAcceptanceLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let suggestionDecisionLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Allow suggestions in this app",
        target: nil,
        action: nil
    )
    private let enableAllAppsButton = NSButton(title: "Clear Blocked Apps", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let rawContentStatusLabel = NSTextField(labelWithString: "")
    private let screenRecordingPermissionLabel = NSTextField(labelWithString: "")
    private let privacyPathLabel = NSTextField(labelWithString: "")
    private let toggleTracingButton = NSButton(
        checkboxWithTitle: "Performance and placement traces",
        target: nil,
        action: nil
    )
    private let toggleRawTraceButton = NSButton(
        checkboxWithTitle: "Include raw text in traces",
        target: nil,
        action: nil
    )
    private let toggleScreenshotTraceButton = NSButton(
        checkboxWithTitle: "Capture placement screenshots",
        target: nil,
        action: nil
    )
    private let deleteLocalLogsButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let cycleAcceptAllShortcutButton = NSButton(title: "Use Option-Tab", target: nil, action: nil)
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let toggleSuggestionsPaused: () -> Void
    private let performRuntimeAction: (RuntimeReadinessAction) -> Void
    private let toggleCurrentApp: () -> Void
    private let enableAllApps: () -> Void
    private let toggleTracingPaused: () -> Void
    private let toggleRawContentTracing: () -> Void
    private let toggleScreenshotTracing: () -> Void
    private let deleteLocalLogs: () -> Void
    private let cycleAcceptAllShortcut: () -> Void
    private var currentRuntimeAction: RuntimeReadinessAction = .none

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        toggleSuggestionsPaused: @escaping () -> Void,
        performRuntimeAction: @escaping (RuntimeReadinessAction) -> Void,
        toggleCurrentApp: @escaping () -> Void,
        enableAllApps: @escaping () -> Void,
        toggleTracingPaused: @escaping () -> Void,
        toggleRawContentTracing: @escaping () -> Void,
        toggleScreenshotTracing: @escaping () -> Void,
        deleteLocalLogs: @escaping () -> Void,
        cycleAcceptAllShortcut: @escaping () -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.toggleSuggestionsPaused = toggleSuggestionsPaused
        self.performRuntimeAction = performRuntimeAction
        self.toggleCurrentApp = toggleCurrentApp
        self.enableAllApps = enableAllApps
        self.toggleTracingPaused = toggleTracingPaused
        self.toggleRawContentTracing = toggleRawContentTracing
        self.toggleScreenshotTracing = toggleScreenshotTracing
        self.deleteLocalLogs = deleteLocalLogs
        self.cycleAcceptAllShortcut = cycleAcceptAllShortcut

        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 720))
        contentView.material = .contentBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autocomplete Lab"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 540, height: 660)
        window.isMovableByWindowBackground = true

        super.init()

        buildContent(in: contentView)
    }

    func show(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        currentApp: SettingsCurrentAppState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        lastSuggestionDecision: String
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: currentApp,
            privacy: privacy,
            keyboardShortcuts: keyboardShortcuts,
            lastSuggestionDecision: lastSuggestionDecision
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var isShowing: Bool {
        window.isVisible
    }

    func refresh(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        currentApp: SettingsCurrentAppState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        lastSuggestionDecision: String
    ) {
        let guidance = RuntimeReadinessGuidance(report: runtimeReport)
        let permission = SettingsPermissionState(isTrusted: isTrusted)
        permissionLabel.stringValue = permission.statusText
        permissionDetailLabel.stringValue = permission.detailText
        controlLabel.stringValue = suggestionsPaused ? "Suggestions: paused" : "Suggestions: ready"
        suggestionDecisionLabel.stringValue = "Why: \(lastSuggestionDecision)"
        togglePauseButton.state = suggestionsPaused ? .off : .on
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = "Next step: \(runtimeReport.action.displayName)"
        runtimeActionButton.title = guidance.actionTitle
        runtimeActionButton.isEnabled = guidance.isActionEnabled
        currentRuntimeAction = runtimeReport.action
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        currentAppLabel.stringValue = currentApp.statusText
        currentAppDetailLabel.stringValue = currentApp.detailText
        currentAppModeLabel.stringValue = currentApp.modeText
        currentAppAcceptanceLabel.stringValue = currentApp.acceptanceText
        toggleCurrentAppButton.title = currentApp.toggleTitle
        toggleCurrentAppButton.state = currentApp.isEnabled ? .on : .off
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        rawContentStatusLabel.stringValue = privacy.contentStatusText
        let screenRecordingText = privacy.screenRecordingPermissionText
        screenRecordingPermissionLabel.stringValue = screenRecordingText ?? ""
        screenRecordingPermissionLabel.isHidden = screenRecordingText == nil
        privacyPathLabel.stringValue = privacy.pathText
        toggleTracingButton.state = privacy.tracingPaused ? .off : .on
        toggleRawTraceButton.state = privacy.rawContentTracingEnabled ? .on : .off
        toggleScreenshotTraceButton.state = privacy.screenshotTracingEnabled ? .on : .off
        shortcutLabel.stringValue = keyboardShortcuts.statusText
        cycleAcceptAllShortcutButton.title = keyboardShortcuts.cycleButtonTitle
        firstRunLabel.stringValue = onboardingText(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            guidance: guidance
        )
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Autocomplete Lab")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        permissionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(permissionDetailLabel)
        runtimeLabel.lineBreakMode = .byWordWrapping
        runtimeLabel.maximumNumberOfLines = 0
        runtimeLabel.preferredMaxLayoutWidth = 470
        runtimeDetailLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(runtimeDetailLabel)
        runtimeActionLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeActionLabel.textColor = .secondaryLabelColor
        configureSecondaryLabel(runtimeTargetLabel)
        modelDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        modelDirectoryLabel.maximumNumberOfLines = 1
        modelDirectoryLabel.preferredMaxLayoutWidth = 470
        controlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(firstRunLabel)
        currentAppLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(currentAppDetailLabel)
        configureSecondaryLabel(currentAppModeLabel)
        configureSecondaryLabel(currentAppAcceptanceLabel)
        configureSecondaryLabel(disabledAppsLabel)
        configureSecondaryLabel(suggestionDecisionLabel)
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(diagnosticsStatusLabel)
        configureSecondaryLabel(rawContentStatusLabel)
        configureSecondaryLabel(screenRecordingPermissionLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 470
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let requestButton = NSButton(title: "Allow Accessibility", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded
        let openSettingsButton = NSButton(
            title: "Open Privacy Settings",
            target: self,
            action: #selector(openAccessibilitySettingsPane)
        )
        openSettingsButton.bezelStyle = .rounded
        togglePauseButton.target = self
        togglePauseButton.action = #selector(togglePause)
        togglePauseButton.toolTip = "Turns suggestions on or off immediately."
        runtimeActionButton.target = self
        runtimeActionButton.action = #selector(runRuntimeAction)
        runtimeActionButton.bezelStyle = .rounded
        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.toolTip = "Adds or removes the current app from your blocked-app list."
        enableAllAppsButton.target = self
        enableAllAppsButton.action = #selector(enableAllAppsControl)
        enableAllAppsButton.bezelStyle = .rounded
        toggleTracingButton.target = self
        toggleTracingButton.action = #selector(toggleTracingControl)
        toggleTracingButton.toolTip = "Keeps local performance and placement events available for debugging."
        toggleRawTraceButton.target = self
        toggleRawTraceButton.action = #selector(toggleRawTraceControl)
        toggleRawTraceButton.toolTip = "Off by default. Turn on only when you need local raw-text debugging."
        toggleScreenshotTraceButton.target = self
        toggleScreenshotTraceButton.action = #selector(toggleScreenshotTraceControl)
        toggleScreenshotTraceButton.toolTip = "Captures local screenshots for placement debugging."
        deleteLocalLogsButton.target = self
        deleteLocalLogsButton.action = #selector(deleteLocalLogsControl)
        deleteLocalLogsButton.bezelStyle = .rounded
        cycleAcceptAllShortcutButton.target = self
        cycleAcceptAllShortcutButton.action = #selector(cycleAcceptAllShortcutControl)
        cycleAcceptAllShortcutButton.bezelStyle = .rounded

        [
            title,
            makeSection(
                title: "Access",
                views: [
                    permissionLabel,
                    permissionDetailLabel,
                    makeButtonRow([requestButton, openSettingsButton])
                ]
            ),
            makeSection(
                title: "Local Model",
                views: [
                    runtimeLabel,
                    runtimeDetailLabel,
                    runtimeActionLabel,
                    makeButtonRow([runtimeActionButton]),
                    runtimeTargetLabel,
                    modelDirectoryLabel
                ]
            ),
            makeSection(
                title: "Suggestions",
                views: [
                    controlLabel,
                    togglePauseButton,
                    suggestionDecisionLabel,
                    firstRunLabel
                ]
            ),
            makeSection(
                title: "Apps",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
                    currentAppModeLabel,
                    currentAppAcceptanceLabel,
                    toggleCurrentAppButton,
                    makeButtonRow([disabledAppsLabel, enableAllAppsButton])
                ]
            ),
            makeSection(
                title: "Privacy and Diagnostics",
                views: [
                    privacyLabel,
                    diagnosticsStatusLabel,
                    rawContentStatusLabel,
                    screenRecordingPermissionLabel,
                    toggleTracingButton,
                    toggleRawTraceButton,
                    toggleScreenshotTraceButton,
                    privacyPathLabel,
                    makeButtonRow([deleteLocalLogsButton])
                ]
            ),
            makeSection(
                title: "Keyboard",
                views: [
                    shortcutLabel,
                    makeButtonRow([cycleAcceptAllShortcutButton])
                ]
            )
        ].forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func configureSecondaryLabel(_ label: NSTextField, maxWidth: CGFloat = 470) {
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = maxWidth
    }

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        var arrangedSubviews: [NSView] = [titleLabel]
        arrangedSubviews.append(contentsOf: views)

        let section = NSStackView(views: arrangedSubviews)
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 5
        return section
    }

    private func makeButtonRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func onboardingText(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        guidance: RuntimeReadinessGuidance
    ) -> String {
        if !isTrusted {
            return "Finish Accessibility setup above, then open a writing app to test suggestions."
        }

        if suggestionsPaused {
            return "Paused. Resume when you want to test suggestions."
        }

        return guidance.message
    }

    @objc
    private func requestAccessibility() {
        requestPermission()
    }

    @objc
    private func openAccessibilitySettingsPane() {
        openAccessibilitySettings()
    }

    @objc
    private func togglePause() {
        toggleSuggestionsPaused()
    }

    @objc
    private func runRuntimeAction() {
        performRuntimeAction(currentRuntimeAction)
    }

    @objc
    private func toggleCurrentAppControl() {
        toggleCurrentApp()
    }

    @objc
    private func enableAllAppsControl() {
        enableAllApps()
    }

    @objc
    private func toggleTracingControl() {
        toggleTracingPaused()
    }

    @objc
    private func toggleRawTraceControl() {
        toggleRawContentTracing()
    }

    @objc
    private func toggleScreenshotTraceControl() {
        toggleScreenshotTracing()
    }

    @objc
    private func deleteLocalLogsControl() {
        deleteLocalLogs()
    }

    @objc
    private func cycleAcceptAllShortcutControl() {
        cycleAcceptAllShortcut()
    }
}
