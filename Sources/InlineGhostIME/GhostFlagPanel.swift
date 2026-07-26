import AppKit

/// The flag-comment box: after a double-Esc flag, a small Spotlight-style
/// panel appears near the caret so the writer can say WHY in their own words
/// — the in-the-moment open-coding stream. Enter submits, Esc cancels; the
/// panel is non-activating so the host app keeps its state and focus returns
/// the instant it closes.
@MainActor
final class GhostFlagPanel: NSObject, NSTextFieldDelegate {

    static let shared = GhostFlagPanel()

    private var panel: NSPanel?
    private var field: NSTextField?
    private var onSubmit: ((String) -> Void)?

    func show(near lineRect: NSRect, onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
        let p = ensurePanel()
        field?.stringValue = ""
        var origin = NSPoint(x: lineRect.minX, y: lineRect.minY - 46)
        if lineRect == .zero, let screen = NSScreen.main {
            origin = NSPoint(x: screen.visibleFrame.midX - 190, y: screen.visibleFrame.midY)
        }
        if let screen = NSScreen.main {
            origin.x = min(max(origin.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - 388)
            origin.y = max(origin.y, screen.visibleFrame.minY + 8)
        }
        p.setFrameOrigin(origin)
        p.makeKeyAndOrderFront(nil)
        p.makeFirstResponder(field)
    }

    func hide() {
        panel?.orderOut(nil)
        onSubmit = nil
    }

    @objc private func submit(_ sender: Any?) {
        let text = field?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let callback = onSubmit
        hide()
        if !text.isEmpty { callback?(text) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            hide()
            return true
        }
        return false
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: p.contentRect(forFrameRect: p.frame))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.145, green: 0.157, blue: 0.165, alpha: 0.96).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor(calibratedRed: 0.56, green: 0.78, blue: 0.64, alpha: 0.5).cgColor

        let flag = NSTextField(labelWithString: "⚑")
        flag.font = NSFont.systemFont(ofSize: 14)
        flag.textColor = NSColor(calibratedRed: 0.56, green: 0.78, blue: 0.64, alpha: 1)
        flag.frame = NSRect(x: 10, y: 9, width: 20, height: 20)
        container.addSubview(flag)

        let f = NSTextField(frame: NSRect(x: 32, y: 7, width: 338, height: 24))
        f.isBordered = false
        f.drawsBackground = false
        f.focusRingType = .none
        f.font = NSFont.systemFont(ofSize: 14)
        f.textColor = NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.92, alpha: 1)
        f.placeholderAttributedString = NSAttributedString(
            string: "why was it bad? (Enter saves · Esc skips)",
            attributes: [.foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1),
                         .font: NSFont.systemFont(ofSize: 14)]
        )
        f.target = self
        f.action = #selector(submit(_:))
        f.delegate = self
        container.addSubview(f)

        p.contentView = container
        panel = p
        field = f
        return p
    }
}
