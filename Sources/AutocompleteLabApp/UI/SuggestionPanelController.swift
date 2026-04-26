import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let ghostTextView: GhostTextView
    private var lastText: String?
    private var lastFrame: CGRect?
    private var lastRenderMode: SuggestionRenderMode?

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

    func show(
        text: String,
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) {
        let fontSize = defaultFontSize(anchorRect: anchorRect, renderMode: renderMode)
        let font = style?.font ?? NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let color = textColor(matching: style?.foregroundColor, renderMode: renderMode)

        let textPadding = renderMode == .floatingMirror ? CGSize(width: 18, height: 10) : .zero
        let rawSize = text.size(withAttributes: [.font: font])
        let size = CGSize(width: rawSize.width + textPadding.width, height: rawSize.height + textPadding.height)
        let screen = screen(containing: anchorRect) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let screenHeight = screenFrame.height > 0 ? screenFrame.height : anchorRect.maxY
        let appKitAnchorRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: anchorRect,
            screenHeight: screenHeight
        )
        let appKitTextLineRect = textLineRect.map {
            AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: $0,
                screenHeight: screenHeight
            )
        }
        let appKitClippingRect = clippingRect.map {
            AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: $0,
                screenHeight: screenHeight
            )
        }
        let frame: CGRect

        switch renderMode {
        case .inlineAdjacent:
            frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
                caretRect: appKitAnchorRect,
                textLineRect: appKitTextLineRect,
                textSize: size,
                screenFrame: screenFrame,
                clippingFrame: appKitClippingRect
            )

        case .floatingMirror:
            frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
                anchorRect: appKitAnchorRect,
                textSize: size,
                screenFrame: screenFrame,
                clippingFrame: appKitClippingRect
            )

        case .disabled:
            return
        }

        let shouldRefresh = !panel.isVisible || SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: lastText,
            previousFrame: lastFrame,
            previousRenderMode: lastRenderMode,
            nextText: text,
            nextFrame: frame,
            nextRenderMode: renderMode
        )

        guard shouldRefresh else {
            return
        }

        ghostTextView.update(text: text, font: font, color: color, renderMode: renderMode)
        panel.setFrame(frame, display: true)
        DiagnosticsLog.shared.record(
            "suggestion-panel-frame",
            metadata: [
                "renderMode": renderMode.rawValue,
                "anchor": compactFrameDescription(anchorRect),
                "frame": compactFrameDescription(frame),
                "clipping": clippingRect.map(compactFrameDescription) ?? "none"
            ]
        )
        lastText = text
        lastFrame = frame
        lastRenderMode = renderMode
        panel.orderFrontRegardless()
    }

    func hide() {
        lastText = nil
        lastFrame = nil
        lastRenderMode = nil
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

    private func textColor(matching foregroundColor: NSColor?, renderMode: SuggestionRenderMode) -> NSColor {
        if renderMode == .floatingMirror {
            return NSColor.white.withAlphaComponent(0.86)
        }

        guard let foregroundColor else {
            return NSColor.labelColor.withAlphaComponent(0.42)
        }

        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        return color.withAlphaComponent(0.42)
    }

    private func defaultFontSize(anchorRect: CGRect, renderMode: SuggestionRenderMode) -> CGFloat {
        switch renderMode {
        case .inlineAdjacent:
            return min(max(anchorRect.height * 1.02, 12), 32)
        case .floatingMirror:
            return 15
        case .disabled:
            return 15
        }
    }

    private func compactFrameDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}

private final class GhostTextView: NSView {
    private var text = ""
    private var font = NSFont.systemFont(ofSize: 15)
    private var color = NSColor.labelColor.withAlphaComponent(0.42)
    private var renderMode = SuggestionRenderMode.inlineAdjacent

    override var isFlipped: Bool {
        true
    }

    func update(text: String, font: NSFont, color: NSColor, renderMode: SuggestionRenderMode) {
        self.text = text
        self.font = font
        self.color = color
        self.renderMode = renderMode
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !text.isEmpty else {
            return
        }

        let textInset = textInsets
        if renderMode == .floatingMirror {
            let bubbleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 6, yRadius: 6)
            NSColor.black.withAlphaComponent(0.76).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let textSize = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: textInset.left,
            y: max(textInset.top, (bounds.height - textSize.height) / 2)
        )

        text.draw(
            with: NSRect(
                x: point.x,
                y: point.y,
                width: max(1, bounds.width - textInset.left - textInset.right),
                height: textSize.height
            ),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private var textInsets: NSEdgeInsets {
        switch renderMode {
        case .floatingMirror:
            return NSEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        case .inlineAdjacent, .disabled:
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }
}
