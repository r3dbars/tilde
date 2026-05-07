import AppKit
import AutocompleteLabCore

struct SettingsCurrentAppState: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    let isSupported: Bool
    let isEnabled: Bool
    let disabledAppCount: Int

    var canToggle: Bool {
        bundleIdentifier != nil && isSupported
    }

    var statusText: String {
        guard bundleIdentifier != nil else {
            return "Current app: no supported app selected"
        }

        guard isSupported else {
            return "Current app: \(displayName) is not on the test allowlist"
        }

        return "Current app: \(displayName) is \(isEnabled ? "allowed" : "blocked")"
    }

    var detailText: String {
        guard bundleIdentifier != nil else {
            return "Open a supported writing app to control it here."
        }

        guard isSupported else {
            return "Suggestions stay off until this app is added to the test allowlist."
        }

        if isEnabled {
            return "On the test allowlist. Turn it off here if it gets annoying."
        }

        return "This app is in your blocked-app list."
    }

    var blockedAppsText: String {
        if disabledAppCount == 0 {
            return "Blocked apps: none"
        }

        return "Blocked apps: \(disabledAppCount)"
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let screenshotTracingEnabled: Bool
    let diagnosticsPath: String
    let tracePath: String

    var statusText: String {
        "Privacy: local diagnostics only"
    }

    var diagnosticsStatusText: String {
        let traceState = tracingPaused ? "paused" : "recording"
        let screenshotState = screenshotTracingEnabled ? "screenshots on" : "screenshots off"
        return "Diagnostics: performance + placement traces \(traceState), \(screenshotState)"
    }

    var contentStatusText: String {
        "Raw text capture: \(rawContentTracingEnabled ? "on" : "off")"
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
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Allow suggestions in this app",
        target: nil,
        action: nil
    )
    private let enableAllAppsButton = NSButton(title: "Clear Blocked Apps", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let rawContentStatusLabel = NSTextField(labelWithString: "")
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
        keyboardShortcuts: SettingsKeyboardShortcutState
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: currentApp,
            privacy: privacy,
            keyboardShortcuts: keyboardShortcuts
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
        keyboardShortcuts: SettingsKeyboardShortcutState
    ) {
        let guidance = RuntimeReadinessGuidance(report: runtimeReport)
        permissionLabel.stringValue = isTrusted ? "Accessibility: on" : "Accessibility: needed"
        controlLabel.stringValue = suggestionsPaused ? "Suggestions: paused" : "Suggestions: ready"
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
        toggleCurrentAppButton.state = currentApp.isEnabled ? .on : .off
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        rawContentStatusLabel.stringValue = privacy.contentStatusText
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
        configureSecondaryLabel(disabledAppsLabel)
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(diagnosticsStatusLabel)
        configureSecondaryLabel(rawContentStatusLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 470
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let requestButton = NSButton(title: "Request Access", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded
        let openSettingsButton = NSButton(
            title: "Open Settings",
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

        let screenRecording = NSButton(checkboxWithTitle: "Screen Recording", target: nil, action: nil)
        screenRecording.isEnabled = false

        let clipboardFallback = NSButton(checkboxWithTitle: "Clipboard fallback", target: nil, action: nil)
        clipboardFallback.isEnabled = false

        let note = NSTextField(wrappingLabelWithString: "Clipboard fallback stays off unless a debug build explicitly enables it.")
        note.font = NSFont.systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor

        [
            title,
            makeSection(
                title: "Access",
                views: [
                    permissionLabel,
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
                    firstRunLabel
                ]
            ),
            makeSection(
                title: "Apps",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
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
            ),
            makeSection(
                title: "Safety",
                views: [
                    screenRecording,
                    clipboardFallback,
                    note
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
            return "Grant Accessibility to read the active text field locally."
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
