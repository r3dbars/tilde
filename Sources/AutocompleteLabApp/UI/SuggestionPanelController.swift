import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let backdropView: NSVisualEffectView
    private let ghostTextView: GhostTextView
    private var lastText: String?
    private var lastFrame: CGRect?
    private var lastRenderMode: SuggestionRenderMode?

    init() {
        backdropView = NSVisualEffectView(frame: .zero)
        ghostTextView = GhostTextView(frame: .zero)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.material = .popover
        backdropView.blendingMode = .behindWindow
        backdropView.state = .active
        backdropView.isHidden = true
        backdropView.wantsLayer = true
        backdropView.layer?.cornerRadius = 7
        backdropView.layer?.masksToBounds = true
        ghostTextView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backdropView)
        container.addSubview(ghostTextView)

        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backdropView.topAnchor.constraint(equalTo: container.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        near anchorRect: CGRect,
        alignedTo textLineRect: CGRect?,
        boundedBy clippingRect: CGRect?,
        style: FocusedTextStyle?,
        renderMode: SuggestionRenderMode
    ) -> CGRect? {
        let fontSize = defaultFontSize(anchorRect: anchorRect, renderMode: renderMode)
        let font = style?.font ?? NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let color = textColor(matching: style?.foregroundColor, renderMode: renderMode)

        let textInsets = Self.textInsets(for: renderMode)
        let textPadding = CGSize(
            width: textInsets.left + textInsets.right,
            height: textInsets.top + textInsets.bottom
        )
        let rawSize = text.size(withAttributes: [.font: font])
        let lineHeight = ceil(max(rawSize.height, font.ascender - font.descender + font.leading))
        let textSize = CGSize(width: ceil(rawSize.width), height: lineHeight)
        let minimumSize = Self.minimumPanelSize(for: renderMode, anchorRect: anchorRect, textSize: textSize)
        let size = CGSize(
            width: max(ceil(textSize.width + textPadding.width), minimumSize.width),
            height: max(ceil(textSize.height + textPadding.height), minimumSize.height)
        )
        let screen = screen(containing: anchorRect) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let screenHeight = Self.accessibilityScreenHeight()
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
            return nil
        }

        let accessibilityFrame = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: frame,
            screenHeight: screenHeight
        )

        let shouldRefresh = !panel.isVisible || SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: lastText,
            previousFrame: lastFrame,
            previousRenderMode: lastRenderMode,
            nextText: text,
            nextFrame: frame,
            nextRenderMode: renderMode
        )

        guard shouldRefresh else {
            return accessibilityFrame
        }

        let wasVisible = panel.isVisible
        backdropView.isHidden = renderMode != .floatingMirror
        ghostTextView.update(
            text: text,
            font: font,
            color: color,
            renderMode: renderMode,
            textInsets: textInsets
        )
        panel.setFrame(frame, display: true, animate: false)
        DiagnosticsLog.shared.record(
            "suggestion-panel-frame",
            metadata: [
                "renderMode": renderMode.rawValue,
                "anchor": compactFrameDescription(anchorRect),
                "frame": compactFrameDescription(frame),
                "clipping": clippingRect.map(compactFrameDescription) ?? "none",
                "screen": compactFrameDescription(screenFrame)
            ]
        )
        lastText = text
        lastFrame = frame
        lastRenderMode = renderMode
        if wasVisible {
            panel.displayIfNeeded()
        } else {
            panel.orderFrontRegardless()
        }
        return accessibilityFrame
    }

    func hide() {
        lastText = nil
        lastFrame = nil
        lastRenderMode = nil
        panel.orderOut(nil)
    }

    private func screen(containing accessibilityRect: CGRect) -> NSScreen? {
        let screenHeight = Self.accessibilityScreenHeight()
        return NSScreen.screens.first { screen in
            let probeRect = AccessibilityCoordinateConverter.appKitProbeRect(
                fromAccessibilityRect: accessibilityRect,
                screenHeight: screenHeight
            )

            return screen.frame.intersects(probeRect)
        }
    }

    private static func accessibilityScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
    }

    private func textColor(matching _: NSColor?, renderMode: SuggestionRenderMode) -> NSColor {
        switch renderMode {
        case .floatingMirror:
            return NSColor.labelColor
        case .inlineAdjacent:
            return NSColor(calibratedWhite: 0.58, alpha: 0.82)
        case .disabled:
            return NSColor.secondaryLabelColor
        }
    }

    private func defaultFontSize(anchorRect: CGRect, renderMode: SuggestionRenderMode) -> CGFloat {
        switch renderMode {
        case .inlineAdjacent:
            return min(max(anchorRect.height * 0.9, 12), 28)
        case .floatingMirror:
            return 15
        case .disabled:
            return 15
        }
    }

    private static func textInsets(for renderMode: SuggestionRenderMode) -> NSEdgeInsets {
        switch renderMode {
        case .floatingMirror:
            return NSEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        case .inlineAdjacent:
            return NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 2)
        case .disabled:
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }

    private static func minimumPanelSize(
        for renderMode: SuggestionRenderMode,
        anchorRect: CGRect,
        textSize: CGSize
    ) -> CGSize {
        switch renderMode {
        case .floatingMirror:
            return CGSize(width: 44, height: 28)
        case .inlineAdjacent:
            let anchorHeight = anchorRect.height > 0 ? min(anchorRect.height, 32) : textSize.height
            return CGSize(width: 1, height: ceil(max(textSize.height, anchorHeight)))
        case .disabled:
            return .zero
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
    private var textInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    override var isFlipped: Bool {
        true
    }

    func update(
        text: String,
        font: NSFont,
        color: NSColor,
        renderMode: SuggestionRenderMode,
        textInsets: NSEdgeInsets
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.renderMode = renderMode
        self.textInsets = textInsets
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !text.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let textSize = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: textInsets.left,
            y: max(textInsets.top, (bounds.height - textSize.height) / 2)
        )

        text.draw(
            with: NSRect(
                x: point.x,
                y: point.y,
                width: max(1, bounds.width - textInsets.left - textInsets.right),
                height: textSize.height
            ),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }
}
