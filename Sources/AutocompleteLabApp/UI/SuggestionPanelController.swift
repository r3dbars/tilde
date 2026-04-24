import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let ghostTextView: GhostTextView

    init() {
        ghostTextView = GhostTextView(frame: .zero)

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

        ghostTextView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(ghostTextView)

        NSLayoutConstraint.activate([
            ghostTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ghostTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ghostTextView.topAnchor.constraint(equalTo: container.topAnchor),
            ghostTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.contentView = container
    }

    @discardableResult
    func show(
        text: String,
        appBundleIdentifier: String?,
        near caretRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy textElementRect: CGRect?,
        style: FocusedTextStyle?
    ) -> InlineGhostPlacementDecision? {
        let fontSize = min(max(caretRect.height * 1.02, 12), 32)
        let font = style?.font ?? NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let color = ghostColor(matching: style?.foregroundColor)

        ghostTextView.update(text: text, font: font, color: color)
        let size = text.size(withAttributes: [.font: font])
        let screen = screen(containing: caretRect) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let appKitCaretRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: caretRect,
            screenFrame: screenFrame
        )
        let appKitTextLineRect = textLineRect.map {
            AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: $0,
                screenFrame: screenFrame
            )
        }
        let appKitTextElementRect = textElementRect.map {
            AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: $0,
                screenFrame: screenFrame
            )
        }
        let decision = SuggestionPanelFrameCalculator.inlineGhostPlacement(
            appBundleIdentifier: appBundleIdentifier,
            caretRect: appKitCaretRect,
            textLineRect: appKitTextLineRect,
            boundaryFrame: appKitTextElementRect,
            textSize: size,
            screenFrame: screenFrame
        )

        guard decision.strategy != .hiddenNoRoom else {
            hide()
            return decision
        }

        panel.setFrame(decision.frame, display: true)
        ghostTextView.needsDisplay = true
        panel.orderFrontRegardless()
        return decision
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func screen(containing accessibilityRect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            let convertedRect = AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: accessibilityRect,
                screenFrame: screen.frame
            )

            return screen.frame.intersects(convertedRect)
        }
    }

    private func ghostColor(matching foregroundColor: NSColor?) -> NSColor {
        guard let foregroundColor else {
            return NSColor.labelColor.withAlphaComponent(0.42)
        }

        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        return color.withAlphaComponent(0.42)
    }
}

private final class GhostTextView: NSView {
    private var text = ""
    private var font = NSFont.systemFont(ofSize: 15)
    private var color = NSColor.labelColor.withAlphaComponent(0.42)

    override var isFlipped: Bool {
        true
    }

    func update(text: String, font: NSFont, color: NSColor) {
        self.text = text
        self.font = font
        self.color = color
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !text.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let textSize = text.size(withAttributes: attributes)
        let point = NSPoint(x: 0, y: max(0, (bounds.height - textSize.height) / 2))

        text.draw(at: point, withAttributes: attributes)
    }
}
