import AppKit
import AutocompleteLabCore

struct FieldStatusIndicatorState: Equatable {
    enum Kind: String, Equatable {
        case ready
        case thinking
        case shown
        case waiting
        case blocked
    }

    let kind: Kind
    let accessibilityLabel: String

    static let ready = FieldStatusIndicatorState(
        kind: .ready,
        accessibilityLabel: "SteadyType is on in this field"
    )
    static let thinking = FieldStatusIndicatorState(
        kind: .thinking,
        accessibilityLabel: "SteadyType is thinking in this field"
    )
    static let shown = FieldStatusIndicatorState(
        kind: .shown,
        accessibilityLabel: "SteadyType is showing a suggestion in this field"
    )
    static let waiting = FieldStatusIndicatorState(
        kind: .waiting,
        accessibilityLabel: "SteadyType is waiting in this field"
    )
    static let blocked = FieldStatusIndicatorState(
        kind: .blocked,
        accessibilityLabel: "SteadyType is off in this field"
    )

    func withReason(_ reason: String) -> FieldStatusIndicatorState {
        let reason = Self.cleanReason(reason)
        guard !reason.isEmpty else {
            return self
        }

        return FieldStatusIndicatorState(
            kind: kind,
            accessibilityLabel: "\(accessibilityLabel): \(reason)"
        )
    }

    private static func cleanReason(_ reason: String, maxLength: Int = 96) -> String {
        let cleaned = reason
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maxLength else {
            return cleaned
        }

        let cutoff = cleaned.index(cleaned.startIndex, offsetBy: max(0, maxLength - 3))
        return String(cleaned[..<cutoff]) + "..."
    }
}

@MainActor
final class FieldStatusIndicatorController {
    private let panel: NSPanel
    private let badgeView = FieldStatusBadgeView(frame: NSRect(
        origin: .zero,
        size: FieldStatusIndicatorFrameCalculator.defaultBadgeSize
    ))
    private var lastState: FieldStatusIndicatorState?
    private var lastFrame: CGRect?

    var isVisible: Bool {
        panel.isVisible
    }

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: FieldStatusIndicatorFrameCalculator.defaultBadgeSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = OverlayDesktopBehavior.collectionBehavior
        panel.contentView = badgeView
    }

    func show(
        state: FieldStatusIndicatorState,
        near anchorRect: CGRect,
        fieldRect: CGRect?
    ) {
        let screenHeight = Self.accessibilityScreenHeight()
        guard let screen = screen(containing: fieldRect ?? anchorRect, screenHeight: screenHeight) else {
            hide()
            DiagnosticsLog.shared.record(
                "field-status-indicator-suppressed",
                metadata: [
                    "reason": "anchor-outside-active-display",
                    "state": state.kind.rawValue,
                    "anchor": compactFrameDescription(anchorRect)
                ]
            )
            return
        }

        let appKitAnchorRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: anchorRect,
            screenHeight: screenHeight
        )
        let appKitFieldRect = fieldRect.map {
            AccessibilityCoordinateConverter.appKitRect(
                fromAccessibilityRect: $0,
                screenHeight: screenHeight
            )
        }

        guard let frame = FieldStatusIndicatorFrameCalculator.frame(
            anchorRect: appKitAnchorRect,
            fieldRect: appKitFieldRect,
            screenFrame: screen.frame
        ) else {
            hide()
            DiagnosticsLog.shared.record(
                "field-status-indicator-suppressed",
                metadata: [
                    "reason": "frame-unusable",
                    "state": state.kind.rawValue,
                    "anchor": compactFrameDescription(anchorRect)
                ]
            )
            return
        }

        let shouldRefresh = !panel.isVisible
            || lastState != state
            || shouldRefreshFrame(previousFrame: lastFrame, nextFrame: frame)
        guard shouldRefresh else {
            return
        }

        let wasVisible = panel.isVisible
        badgeView.update(state: state)
        panel.contentView?.toolTip = state.accessibilityLabel
        badgeView.toolTip = state.accessibilityLabel
        badgeView.setAccessibilityElement(true)
        badgeView.setAccessibilityLabel(state.accessibilityLabel)
        panel.setFrame(frame, display: true, animate: false)
        DiagnosticsLog.shared.record(
            "field-status-indicator-frame",
            metadata: [
                "state": state.kind.rawValue,
                "anchor": compactFrameDescription(anchorRect),
                "field": fieldRect.map(compactFrameDescription) ?? "none",
                "frame": compactFrameDescription(frame),
                "screen": compactFrameDescription(screen.frame)
            ]
        )
        lastState = state
        lastFrame = frame
        if wasVisible {
            panel.displayIfNeeded()
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        lastState = nil
        lastFrame = nil
        panel.orderOut(nil)
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

    private func shouldRefreshFrame(
        previousFrame: CGRect?,
        nextFrame: CGRect,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        guard let previousFrame else {
            return true
        }

        return abs(previousFrame.minX - nextFrame.minX) > tolerance
            || abs(previousFrame.minY - nextFrame.minY) > tolerance
            || abs(previousFrame.width - nextFrame.width) > tolerance
            || abs(previousFrame.height - nextFrame.height) > tolerance
    }

    private func compactFrameDescription(_ rect: CGRect) -> String {
        let x = Int(rect.origin.x.rounded())
        let y = Int(rect.origin.y.rounded())
        let width = Int(rect.width.rounded())
        let height = Int(rect.height.rounded())
        return "x=\(x),y=\(y),w=\(width),h=\(height)"
    }
}

private final class FieldStatusBadgeView: NSView {
    private let glyphLabel = NSTextField(labelWithString: "A")
    private let statusDot = NSView(frame: .zero)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = frameRect.height / 2
        layer?.masksToBounds = false
        layer?.borderWidth = 1

        glyphLabel.translatesAutoresizingMaskIntoConstraints = false
        glyphLabel.alignment = .center
        glyphLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        glyphLabel.isBezeled = false
        glyphLabel.drawsBackground = false
        glyphLabel.isEditable = false
        glyphLabel.isSelectable = false

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 2.5

        addSubview(glyphLabel)
        addSubview(statusDot)

        NSLayoutConstraint.activate([
            glyphLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyphLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.5),
            statusDot.widthAnchor.constraint(equalToConstant: 5),
            statusDot.heightAnchor.constraint(equalToConstant: 5),
            statusDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            statusDot.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])

        update(state: .ready)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(state: FieldStatusIndicatorState) {
        let tint = tintColor(for: state.kind)
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.86).cgColor
        layer?.borderColor = tint.withAlphaComponent(0.72).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        glyphLabel.textColor = tint
        statusDot.layer?.backgroundColor = tint.cgColor
    }

    private func tintColor(for kind: FieldStatusIndicatorState.Kind) -> NSColor {
        switch kind {
        case .ready:
            return .systemGreen
        case .thinking:
            return .systemBlue
        case .shown:
            return .controlAccentColor
        case .waiting:
            return .systemOrange
        case .blocked:
            return .systemRed
        }
    }
}
