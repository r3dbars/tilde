import AppKit
import AutocompleteLabCore

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
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let toggleSuggestionsPaused: () -> Void

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        toggleSuggestionsPaused: @escaping () -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.toggleSuggestionsPaused = toggleSuggestionsPaused

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 428))
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
        modelDirectoryPath: String
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String
    ) {
        permissionLabel.stringValue = isTrusted ? "Accessibility: granted" : "Accessibility: needed"
        controlLabel.stringValue = suggestionsPaused ? "Global control: paused" : "Global control: on"
        togglePauseButton.title = suggestionsPaused ? "Resume Suggestions" : "Pause Suggestions"
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail.map { "Detail: \($0)" } ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = "Next: \(runtimeReport.action.displayName)"
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        firstRunLabel.stringValue = onboardingText(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport
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
            runtimeTargetLabel,
            modelDirectoryLabel,
            controlLabel,
            togglePauseButton,
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
        runtimeReport: RuntimeReadinessReport
    ) -> String {
        if !isTrusted {
            return "First run: grant Accessibility, then return here. The app only reads the active text field locally."
        }

        if suggestionsPaused {
            return "Paused: resume when you are ready to test suggestions again."
        }

        if !runtimeReport.isReady {
            return "First run: keep this app open while the local model warms. Suggestions stay off until the model is ready."
        }

        return "First run: open TextEdit, type a short sentence, press Tab for one word, Esc to dismiss, or disable the current app from the menu."
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
}
