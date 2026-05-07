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
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 420))
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
        permissionLabel.stringValue = isTrusted ? "Accessibility: granted" : "Accessibility: needed"
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail.map { "Detail: \($0)" } ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = "Next: \(runtimeReport.action.displayName)"
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        firstRunLabel.stringValue = onboardingText(isTrusted: isTrusted, runtimeReport: runtimeReport)
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

        let screenRecording = NSButton(checkboxWithTitle: "Screen Recording", target: nil, action: nil)
        screenRecording.isEnabled = false

        let clipboardFallback = NSButton(checkboxWithTitle: "Clipboard fallback", target: nil, action: nil)
        clipboardFallback.isEnabled = false

        let note = NSTextField(wrappingLabelWithString: "No cloud model, no clipboard context, no screen recording. Raw traces are local debugging only.")
        note.font = NSFont.systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 0
        note.preferredMaxLayoutWidth = 390

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

    private func onboardingText(isTrusted: Bool, runtimeReport: RuntimeReadinessReport) -> String {
        if !isTrusted {
            return "First run: grant Accessibility so the app can read the active text field on this Mac. Suggestions stay local."
        }

        if !runtimeReport.isReady {
            return "First run: keep this app open while the local model warms. Suggestions stay off until it is ready."
        }

        return "First run: open TextEdit, type a short sentence, press Tab for one word, backtick for the visible suggestion, or Esc to snooze the field."
    }

    @objc
    private func requestAccessibility() {
        requestPermission()
    }

    @objc
    private func openAccessibilitySettingsPane() {
        openAccessibilitySettings()
    }
}
