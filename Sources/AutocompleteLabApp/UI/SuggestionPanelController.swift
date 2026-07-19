import AppKit
import AutocompleteLabCore

@MainActor
final class SuggestionPanelController {
    private let panel: NSPanel
    private let backdropView: NSVisualEffectView
    private let solidBackdropView: SolidBackdropView
    private let ghostTextView: GhostTextView
    private let visualStyle = SuggestionPanelVisualStyle.native
    private var lastText: String?
    private var lastFrame: CGRect?
    private var lastRenderMode: SuggestionRenderMode?

    var isVisible: Bool {
        panel.isVisible
    }

    init() {
        backdropView = NSVisualEffectView(frame: .zero)
        solidBackdropView = SolidBackdropView(frame: .zero)
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
        panel.collectionBehavior = OverlayDesktopBehavior.collectionBehavior

        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.material = visualStyle.mirrorMaterial
        backdropView.blendingMode = .behindWindow
        backdropView.state = .active
        backdropView.isHidden = true
        backdropView.wantsLayer = true
        backdropView.layer?.cornerRadius = visualStyle.mirrorCornerRadius
        backdropView.layer?.masksToBounds = true
        solidBackdropView.translatesAutoresizingMaskIntoConstraints = false
        solidBackdropView.configure(
            fillColor: visualStyle.mirrorSolidBackgroundColor,
            borderColor: visualStyle.mirrorSolidBorderColor,
            cornerRadius: visualStyle.mirrorCornerRadius
        )
        solidBackdropView.isHidden = true
        ghostTextView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(solidBackdropView)
        container.addSubview(backdropView)
        container.addSubview(ghostTextView)

        NSLayoutConstraint.activate([
            solidBackdropView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            solidBackdropView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            solidBackdropView.topAnchor.constraint(equalTo: container.topAnchor),
            solidBackdropView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        let color = visualStyle.textColor(for: renderMode)

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
        let screenHeight = Self.accessibilityScreenHeight()
        guard let screen = screen(containing: anchorRect, screenHeight: screenHeight) else {
            hide()
            DiagnosticsLog.shared.record(
                "suggestion-panel-frame-suppressed",
                metadata: [
                    "reason": "anchor-outside-active-display",
                    "renderMode": renderMode.rawValue,
                    "anchor": compactFrameDescription(anchorRect)
                ]
            )
            return nil
        }
        let screenFrame = screen.frame
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
                clippingFrame: appKitClippingRect,
                horizontalAlignmentOffset: 3,
                verticalAlignmentOffset: 3
            )
            guard SuggestionPanelFrameCalculator.isUsableInlineGhostFrame(frame) else {
                hide()
                DiagnosticsLog.shared.record(
                    "suggestion-panel-frame-suppressed",
                    metadata: [
                        "reason": "inline-width-too-small",
                        "renderMode": renderMode.rawValue,
                        "anchor": compactFrameDescription(anchorRect),
                        "frame": compactFrameDescription(frame),
                        "clipping": clippingRect.map(compactFrameDescription) ?? "none",
                        "screen": compactFrameDescription(screenFrame)
                    ]
                )
                return nil
            }

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
        let presentation = Self.accessibilityPresentation()
        applyBackdrop(presentation.background, visibleFor: renderMode)
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
            // Mid-stream updates snap so the ghost text never lags the cursor.
            panel.alphaValue = 1
            panel.displayIfNeeded()
        } else if presentation.animatesFirstAppearance {
            // First appearance fades in gently, the way native transient overlays do.
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = presentation.firstAppearanceFadeDuration
                panel.animator().alphaValue = 1
            }
        } else {
            // Reduce Motion: snap in with no fade.
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        return accessibilityFrame
    }

    func hide() {
        // Hiding stays instant: on acceptance the ghost text must vanish before the
        // accepted word lands, so a fade-out here could read as duplicated text.
        lastText = nil
        lastFrame = nil
        lastRenderMode = nil
        panel.alphaValue = 1
        panel.orderOut(nil)
    }

    func nativeAppearanceSnapshotPNGData(appearanceName: NSAppearance.Name) -> Data? {
        guard let appearance = NSAppearance(named: appearanceName) else {
            return nil
        }

        let view = SuggestionOverlayAppearancePreviewView(
            frame: NSRect(x: 0, y: 0, width: 520, height: 112),
            appearance: appearance,
            visualStyle: visualStyle
        )
        return view.pngData()
    }

    /// Resolve how the panel should present itself from the live macOS
    /// accessibility display preferences. The decision itself is pure and lives
    /// in `AutocompleteLabCore`; this only reads the system prefs.
    private static func accessibilityPresentation() -> SuggestionPanelAccessibilityPresentation {
        let workspace = NSWorkspace.shared
        return SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: workspace.accessibilityDisplayShouldReduceMotion,
            reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency
        )
    }

    /// Show the backdrop that matches the resolved transparency preference, but
    /// only for the floating mirror (inline ghost text never has a backdrop).
    private func applyBackdrop(
        _ background: SuggestionPanelAccessibilityPresentation.Background,
        visibleFor renderMode: SuggestionRenderMode
    ) {
        let showsBackdrop = renderMode == .floatingMirror
        switch background {
        case .translucentMaterial:
            backdropView.isHidden = !showsBackdrop
            solidBackdropView.isHidden = true
        case .solid:
            backdropView.isHidden = true
            solidBackdropView.isHidden = !showsBackdrop
        }
    }

    private func screen(containing accessibilityRect: CGRect, screenHeight: CGFloat) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: accessibilityRect,
            screenFrames: screens.map(\.frame),
            accessibilityScreenHeight: screenHeight
        ), screens.indices.contains(index) else {
            return nil
        }

        return screens[index]
    }

    private static func accessibilityScreenHeight() -> CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
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
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 2)
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

enum GhostTextColorPolicy {
    static func color(
        matching foregroundColor: NSColor?,
        renderMode: SuggestionRenderMode
    ) -> NSColor {
        switch renderMode {
        case .floatingMirror:
            return NSColor.labelColor
        case .inlineAdjacent:
            return inlineColor(matching: foregroundColor)
        case .disabled:
            return NSColor.secondaryLabelColor
        }
    }

    private static func inlineColor(matching foregroundColor: NSColor?) -> NSColor {
        guard let luminance = relativeLuminance(of: foregroundColor) else {
            return NSColor(calibratedWhite: 0.58, alpha: 0.82)
        }

        if luminance >= 0.62 {
            return NSColor(calibratedWhite: 0.82, alpha: 0.88)
        }

        if luminance <= 0.25 {
            return NSColor(calibratedWhite: 0.52, alpha: 0.78)
        }

        return NSColor(calibratedWhite: 0.62, alpha: 0.82)
    }

    private static func relativeLuminance(of color: NSColor?) -> CGFloat? {
        guard let color,
              let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        return (0.2126 * rgbColor.redComponent)
            + (0.7152 * rgbColor.greenComponent)
            + (0.0722 * rgbColor.blueComponent)
    }
}

private final class SuggestionOverlayAppearancePreviewView: NSView {
    private let previewAppearance: NSAppearance
    private let visualStyle: SuggestionPanelVisualStyle

    init(
        frame: NSRect,
        appearance: NSAppearance,
        visualStyle: SuggestionPanelVisualStyle
    ) {
        previewAppearance = appearance
        self.visualStyle = visualStyle
        super.init(frame: frame)
        self.appearance = appearance
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func pngData() -> Data? {
        layoutSubtreeIfNeeded()
        guard let bitmap = bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        previewAppearance.performAsCurrentDrawingAppearance {
            NSColor.textBackgroundColor.setFill()
            bounds.fill()

            drawInlinePreview()
            drawMirrorPreview()
        }
    }

    private func drawInlinePreview() {
        let font = NSFont.systemFont(ofSize: 18)
        let typedText = "Draft a short update"
        let typedOrigin = NSPoint(x: 24, y: 24)
        let typedAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        typedText.draw(at: typedOrigin, withAttributes: typedAttributes)

        let typedSize = typedText.size(withAttributes: typedAttributes)
        let cursorRect = NSRect(x: typedOrigin.x + typedSize.width + 3, y: 22, width: 1.5, height: 25)
        NSColor.labelColor.setFill()
        cursorRect.fill()

        let ghostOrigin = NSPoint(x: cursorRect.maxX + 4, y: typedOrigin.y)
        " for tomorrow".draw(
            at: ghostOrigin,
            withAttributes: [
                .font: font,
                .foregroundColor: visualStyle.textColor(for: .inlineAdjacent)
            ]
        )
    }

    private func drawMirrorPreview() {
        let mirrorRect = NSRect(x: 24, y: 64, width: 184, height: 34)
        let mirrorPath = NSBezierPath(
            roundedRect: mirrorRect,
            xRadius: visualStyle.mirrorCornerRadius,
            yRadius: visualStyle.mirrorCornerRadius
        )
        NSColor.controlBackgroundColor.withAlphaComponent(0.92).setFill()
        mirrorPath.fill()
        NSColor.separatorColor.setStroke()
        mirrorPath.lineWidth = 1
        mirrorPath.stroke()

        "finish the thought".draw(
            at: NSPoint(x: mirrorRect.minX + 10, y: mirrorRect.minY + 8),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: visualStyle.textColor(for: .floatingMirror)
            ]
        )
    }
}

/// A layer-backed opaque pill shown instead of the translucent vibrancy
/// backdrop when the user enables Reduce Transparency. Resolving the colors in
/// `updateLayer()` keeps the fill correct across light, dark, and high-contrast
/// appearances, and re-resolves automatically when the appearance changes.
private final class SolidBackdropView: NSView {
    private var fillColor: NSColor = .controlBackgroundColor
    private var borderColor: NSColor = .separatorColor
    private var cornerRadius: CGFloat = 7

    func configure(fillColor: NSColor, borderColor: NSColor, cornerRadius: CGFloat) {
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        wantsLayer = true
        needsDisplay = true
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        guard let layer else {
            return
        }
        layer.backgroundColor = fillColor.cgColor
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
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
