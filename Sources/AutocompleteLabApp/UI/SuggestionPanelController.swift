import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let textField: NSTextField

    init() {
        textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = NSColor.secondaryLabelColor
        textField.backgroundColor = .clear
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        container.layer?.masksToBounds = true

        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        panel.contentView = container
    }

    func show(text: String, near caretRect: CGRect) {
        textField.stringValue = text
        let size = text.size(withAttributes: [.font: textField.font as Any])
        let width = min(max(size.width + 24, 80), 360)
        let screenHeight = NSScreen.main?.frame.height ?? caretRect.maxY
        let appKitCaretRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: caretRect,
            screenHeight: screenHeight
        )
        let frame = NSRect(
            x: appKitCaretRect.minX,
            y: appKitCaretRect.minY - 38,
            width: width,
            height: 32
        )

        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
