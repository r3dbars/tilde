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
            return "Current app: none"
        }

        guard isSupported else {
            return "Current app: \(displayName) - unsupported"
        }

        return "Current app: \(displayName) - \(isEnabled ? "on" : "off")"
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let screenshotTracingEnabled: Bool
    let diagnosticsPath: String
    let tracePath: String

    var statusText: String {
        "Privacy: traces \(tracingPaused ? "paused" : "on"), raw text \(rawContentTracingEnabled ? "on" : "off"), screenshots \(screenshotTracingEnabled ? "on" : "off")"
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut

    var statusText: String {
        "Shortcuts: Tab next word, \(acceptAllShortcut.displayName) full accept"
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
    private let togglePauseButton = NSButton(title: "Pause Suggestions", target: nil, action: nil)
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(title: "Disable Current App", target: nil, action: nil)
    private let enableAllAppsButton = NSButton(title: "Enable All Apps", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let privacyPathLabel = NSTextField(labelWithString: "")
    private let toggleTracingButton = NSButton(title: "Pause Tracing", target: nil, action: nil)
    private let toggleRawTraceButton = NSButton(title: "Raw Text Off", target: nil, action: nil)
    private let toggleScreenshotTraceButton = NSButton(title: "Screenshots Off", target: nil, action: nil)
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

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 690))
        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autocomplete Lab Settings"
        window.contentView = contentView
        window.isReleasedWhenClosed = false

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
        permissionLabel.stringValue = isTrusted ? "Accessibility: granted" : "Accessibility: needed"
        controlLabel.stringValue = suggestionsPaused ? "Global control: paused" : "Global control: on"
        togglePauseButton.title = suggestionsPaused ? "Resume Suggestions" : "Pause Suggestions"
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail.map { "Detail: \($0)" } ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = "Next: \(runtimeReport.action.displayName)"
        runtimeActionButton.title = guidance.actionTitle
        runtimeActionButton.isEnabled = guidance.isActionEnabled
        currentRuntimeAction = runtimeReport.action
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        currentAppLabel.stringValue = currentApp.statusText
        if currentApp.isSupported {
            toggleCurrentAppButton.title = currentApp.isEnabled ? "Disable Current App" : "Enable Current App"
        } else {
            toggleCurrentAppButton.title = "Unsupported App"
        }
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        disabledAppsLabel.stringValue = "Disabled apps: \(currentApp.disabledAppCount)"
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        privacyPathLabel.stringValue = "Diagnostics: \(privacy.diagnosticsPath) | Traces: \(privacy.tracePath)"
        toggleTracingButton.title = privacy.tracingPaused ? "Resume Tracing" : "Pause Tracing"
        toggleRawTraceButton.title = privacy.rawContentTracingEnabled ? "Raw Text On" : "Raw Text Off"
        toggleScreenshotTraceButton.title = privacy.screenshotTracingEnabled ? "Screenshots On" : "Screenshots Off"
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
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Transcripted Autocomplete Lab")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        runtimeLabel.lineBreakMode = .byWordWrapping
        runtimeLabel.maximumNumberOfLines = 0
        runtimeLabel.preferredMaxLayoutWidth = 360
        runtimeDetailLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeDetailLabel.textColor = .secondaryLabelColor
        runtimeDetailLabel.lineBreakMode = .byWordWrapping
        runtimeDetailLabel.maximumNumberOfLines = 0
        runtimeDetailLabel.preferredMaxLayoutWidth = 360
        runtimeActionLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeActionLabel.textColor = .secondaryLabelColor
        runtimeTargetLabel.textColor = .secondaryLabelColor
        runtimeTargetLabel.lineBreakMode = .byWordWrapping
        runtimeTargetLabel.maximumNumberOfLines = 0
        runtimeTargetLabel.preferredMaxLayoutWidth = 360
        modelDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        modelDirectoryLabel.maximumNumberOfLines = 1
        modelDirectoryLabel.preferredMaxLayoutWidth = 360
        controlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        firstRunLabel.textColor = .secondaryLabelColor
        firstRunLabel.lineBreakMode = .byWordWrapping
        firstRunLabel.maximumNumberOfLines = 0
        firstRunLabel.preferredMaxLayoutWidth = 390
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 420
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let requestButton = NSButton(title: "Request Accessibility", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded
        let openSettingsButton = NSButton(
            title: "Open Accessibility Settings",
            target: self,
            action: #selector(openAccessibilitySettingsPane)
        )
        openSettingsButton.bezelStyle = .rounded
        togglePauseButton.target = self
        togglePauseButton.action = #selector(togglePause)
        togglePauseButton.bezelStyle = .rounded
        runtimeActionButton.target = self
        runtimeActionButton.action = #selector(runRuntimeAction)
        runtimeActionButton.bezelStyle = .rounded
        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.bezelStyle = .rounded
        enableAllAppsButton.target = self
        enableAllAppsButton.action = #selector(enableAllAppsControl)
        enableAllAppsButton.bezelStyle = .rounded
        toggleTracingButton.target = self
        toggleTracingButton.action = #selector(toggleTracingControl)
        toggleTracingButton.bezelStyle = .rounded
        toggleRawTraceButton.target = self
        toggleRawTraceButton.action = #selector(toggleRawTraceControl)
        toggleRawTraceButton.bezelStyle = .rounded
        toggleScreenshotTraceButton.target = self
        toggleScreenshotTraceButton.action = #selector(toggleScreenshotTraceControl)
        toggleScreenshotTraceButton.bezelStyle = .rounded
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
            permissionLabel,
            requestButton,
            openSettingsButton,
            runtimeLabel,
            runtimeDetailLabel,
            runtimeActionLabel,
            runtimeActionButton,
            runtimeTargetLabel,
            modelDirectoryLabel,
            controlLabel,
            togglePauseButton,
            currentAppLabel,
            toggleCurrentAppButton,
            disabledAppsLabel,
            enableAllAppsButton,
            privacyLabel,
            privacyPathLabel,
            toggleTracingButton,
            toggleRawTraceButton,
            toggleScreenshotTraceButton,
            deleteLocalLogsButton,
            shortcutLabel,
            cycleAcceptAllShortcutButton,
            firstRunLabel,
            screenRecording,
            clipboardFallback,
            note
        ].forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    private func onboardingText(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        guidance: RuntimeReadinessGuidance
    ) -> String {
        if !isTrusted {
            return "First run: grant Accessibility, then return here. The app only reads the active text field locally."
        }

        if suggestionsPaused {
            return "Paused: resume when you are ready to test suggestions again."
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
