import AppKit
import AutocompleteLabCore

@MainActor
final class SettingsWindowController: NSObject {
    private let window: NSWindow
    private let permissionStatusLabel = SettingsWindowController.valueLabel()
    private let permissionDetailLabel = SettingsWindowController.detailLabel()
    private let runtimeStatusLabel = SettingsWindowController.valueLabel()
    private let runtimeDetailLabel = NSTextField(labelWithString: "")
    private let runtimeActionLabel = NSTextField(labelWithString: "")
    private let runtimeTargetLabel = NSTextField(labelWithString: "")
    private let modelDirectoryLabel = NSTextField(labelWithString: "")
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let privacyLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermissionButton = NSButton(title: "Request Access", target: nil, action: nil)
    private let openAccessibilityButton = NSButton(title: "Open Privacy Settings", target: nil, action: nil)
    private let revealModelFolderButton = NSButton(title: "Reveal Model Folder", target: nil, action: nil)
    private let diagnosticsButton = NSButton(title: "Open Diagnostics", target: nil, action: nil)
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let revealModelFolder: () -> Void
    private let showDiagnostics: () -> Void

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        revealModelFolder: @escaping () -> Void,
        showDiagnostics: @escaping () -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.revealModelFolder = revealModelFolder
        self.showDiagnostics = showDiagnostics

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 500))
        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 460)

        super.init()

        buildContent(in: contentView)
    }

    func show(
        isTrusted: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String
    ) {
        refresh(
            isTrusted: isTrusted,
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
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String
    ) {
        permissionStatusLabel.stringValue = isTrusted ? "Granted" : "Needs access"
        permissionDetailLabel.stringValue = isTrusted
            ? "Autocomplete can read the active text field and place suggestions near the cursor."
            : "Grant Accessibility so the app can see the active text field. Typed text stays local."
        requestPermissionButton.isEnabled = !isTrusted

        runtimeStatusLabel.stringValue = runtimeReport.summary
        runtimeDetailLabel.stringValue = runtimeReport.detail ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = runtimeActionText(for: runtimeReport)
        runtimeTargetLabel.stringValue = runtimeTargetSummary
        modelDirectoryLabel.stringValue = modelDirectoryPath
        firstRunLabel.stringValue = onboardingText(isTrusted: isTrusted, runtimeReport: runtimeReport)
        privacyLabel.stringValue = "Typed text is read only from the active field and is not stored. Screen recording and clipboard fallback are off in this build."
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Autocomplete Lab")
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "A tiny local writing helper. Keep it obvious, easy to pause, and safe to test.")
        subtitle.font = NSFont.systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.preferredMaxLayoutWidth = 480

        configureButton(requestPermissionButton, action: #selector(requestAccessibility))
        configureButton(openAccessibilityButton, action: #selector(openAccessibilitySettingsPane))
        configureButton(revealModelFolderButton, action: #selector(revealModelFolderAction))
        configureButton(diagnosticsButton, action: #selector(showDiagnosticsAction))

        runtimeStatusLabel.lineBreakMode = .byWordWrapping
        runtimeStatusLabel.maximumNumberOfLines = 0
        runtimeStatusLabel.preferredMaxLayoutWidth = 340
        runtimeDetailLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeDetailLabel.textColor = .secondaryLabelColor
        runtimeDetailLabel.lineBreakMode = .byWordWrapping
        runtimeDetailLabel.maximumNumberOfLines = 0
        runtimeDetailLabel.preferredMaxLayoutWidth = 340
        runtimeActionLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeActionLabel.textColor = .secondaryLabelColor
        runtimeActionLabel.lineBreakMode = .byWordWrapping
        runtimeActionLabel.maximumNumberOfLines = 0
        runtimeActionLabel.preferredMaxLayoutWidth = 340
        runtimeTargetLabel.textColor = .secondaryLabelColor
        runtimeTargetLabel.lineBreakMode = .byWordWrapping
        runtimeTargetLabel.maximumNumberOfLines = 0
        runtimeTargetLabel.preferredMaxLayoutWidth = 340
        modelDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        modelDirectoryLabel.maximumNumberOfLines = 1
        modelDirectoryLabel.preferredMaxLayoutWidth = 340
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        firstRunLabel.textColor = .secondaryLabelColor
        firstRunLabel.lineBreakMode = .byWordWrapping
        firstRunLabel.maximumNumberOfLines = 0
        firstRunLabel.preferredMaxLayoutWidth = 480
        privacyLabel.font = NSFont.systemFont(ofSize: 12)
        privacyLabel.textColor = .secondaryLabelColor
        privacyLabel.lineBreakMode = .byWordWrapping
        privacyLabel.maximumNumberOfLines = 0
        privacyLabel.preferredMaxLayoutWidth = 480

        let header = NSStackView(views: [title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4

        let setupButtons = NSStackView(views: [requestPermissionButton, openAccessibilityButton])
        setupButtons.orientation = .horizontal
        setupButtons.spacing = 8

        let modelButtons = NSStackView(views: [revealModelFolderButton])
        modelButtons.orientation = .horizontal
        modelButtons.spacing = 8

        let diagnosticButtons = NSStackView(views: [diagnosticsButton])
        diagnosticButtons.orientation = .horizontal
        diagnosticButtons.spacing = 8

        let sections = [
            header,
            section(
                title: "Setup",
                views: [
                    row(title: "Accessibility", value: permissionStatusLabel),
                    permissionDetailLabel,
                    setupButtons
                ]
            ),
            section(
                title: "Local Model",
                views: [
                    row(title: "State", value: runtimeStatusLabel),
                    runtimeDetailLabel,
                    row(title: "Target", value: runtimeTargetLabel),
                    row(title: "Folder", value: modelDirectoryLabel),
                    runtimeActionLabel,
                    modelButtons
                ]
            ),
            section(
                title: "Testing",
                views: [
                    firstRunLabel,
                    diagnosticButtons
                ]
            ),
            section(
                title: "Privacy",
                views: [
                    privacyLabel
                ]
            )
        ]

        sections.forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22)
        ])
    }

    private func section(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel as NSView] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

    private func row(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true
        value.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, value])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(lessThanOrEqualToConstant: 492).isActive = true

        return stack
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
    }

    private static func valueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    private static func detailLabel() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 480

        return label
    }

    private func runtimeActionText(for runtimeReport: RuntimeReadinessReport) -> String {
        switch runtimeReport.action {
        case .revealModelFolder:
            return "Next step: add or repair the local model files, then relaunch the app."
        case .wait:
            return "Next step: leave the app open while the model warms up."
        case .retry:
            return "Next step: relaunch the app. If it fails again, open diagnostics."
        case .none:
            return runtimeReport.isReady ? "Ready for suggestions." : "No action needed right now."
        }
    }

    private func onboardingText(isTrusted: Bool, runtimeReport: RuntimeReadinessReport) -> String {
        if !isTrusted {
            return "First run: grant Accessibility, then come back here."
        }

        if !runtimeReport.isReady {
            return "First run: wait for the local model before judging suggestion quality."
        }

        return "First run: open TextEdit or Codex, type a sentence, press Tab to accept one word, or press Esc to dismiss."
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
    private func revealModelFolderAction() {
        revealModelFolder()
    }

    @objc
    private func showDiagnosticsAction() {
        showDiagnostics()
    }
}
