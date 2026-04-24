import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let textField: NSTextField

    init() {
        textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = NSColor.labelColor.withAlphaComponent(0.36)
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

        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        panel.contentView = container
    }

    func show(text: String, near caretRect: CGRect) {
        let fontSize = min(max(caretRect.height * 0.95, 12), 28)
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        textField.textColor = NSColor.labelColor.withAlphaComponent(0.36)
        textField.stringValue = text
        let size = text.size(withAttributes: [.font: textField.font as Any])
        let screen = screen(containing: caretRect) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let screenHeight = screenFrame.height > 0 ? screenFrame.height : caretRect.maxY
        let appKitCaretRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: caretRect,
            screenHeight: screenHeight
        )
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: appKitCaretRect,
            textSize: size,
            screenFrame: screenFrame
        )

        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func screen(containing accessibilityRect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            let convertedRect = AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: accessibilityRect,
                screenHeight: screen.frame.height
            )

            return screen.frame.intersects(convertedRect)
        }
    }
}
