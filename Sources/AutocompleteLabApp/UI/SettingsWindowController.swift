import AppKit
import AutocompleteLabCore

@MainActor
final class SettingsWindowController: NSObject {
    private let window: NSWindow
    private let permissionLabel = NSTextField(labelWithString: "")
    private let runtimeLabel = NSTextField(labelWithString: "")
    private let requestPermission: () -> Void

    init(requestPermission: @escaping () -> Void) {
        self.requestPermission = requestPermission

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
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

    func show(isTrusted: Bool, runtimeReadiness: String) {
        refresh(isTrusted: isTrusted, runtimeReadiness: runtimeReadiness)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(isTrusted: Bool, runtimeReadiness: String) {
        permissionLabel.stringValue = isTrusted ? "Accessibility: granted" : "Accessibility: needed"
        runtimeLabel.stringValue = "Local model: \(runtimeReadiness)"
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

        let requestButton = NSButton(title: "Request Accessibility", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded

        let runtimeTarget = NSTextField(labelWithString: "Runtime target: app-owned Gemma 4 E2B")
        runtimeTarget.textColor = .secondaryLabelColor

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
            runtimeLabel,
            runtimeTarget,
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

    @objc
    private func requestAccessibility() {
        requestPermission()
    }
}
