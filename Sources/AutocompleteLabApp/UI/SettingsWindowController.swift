import AppKit

@MainActor
final class SettingsWindowController: NSObject {
    private let window: NSWindow
    private let permissionLabel = NSTextField(labelWithString: "")
    private let requestPermission: () -> Void

    init(requestPermission: @escaping () -> Void) {
        self.requestPermission = requestPermission

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 210))
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

    func show(isTrusted: Bool) {
        refresh(isTrusted: isTrusted)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(isTrusted: Bool) {
        permissionLabel.stringValue = isTrusted ? "Accessibility: granted" : "Accessibility: needed"
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Transcripted Autocomplete Lab")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let requestButton = NSButton(title: "Request Accessibility", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded

        let screenRecording = NSButton(checkboxWithTitle: "Screen Recording", target: nil, action: nil)
        screenRecording.isEnabled = false

        let clipboardFallback = NSButton(checkboxWithTitle: "Clipboard fallback", target: nil, action: nil)
        clipboardFallback.isEnabled = false

        let note = NSTextField(wrappingLabelWithString: "Clipboard fallback stays off unless a debug build explicitly enables it.")
        note.font = NSFont.systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor

        [title, permissionLabel, requestButton, screenRecording, clipboardFallback, note].forEach {
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
