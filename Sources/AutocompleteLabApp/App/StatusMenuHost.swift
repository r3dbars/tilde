import AppKit

/// Tilde's complete user-facing surface: useful stats, honest engine status,
/// working controls, pause, and quit. No settings window or panes.
@MainActor
final class StatusMenuHost: NSObject {

    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?

    private var lifetimeItem: NSMenuItem?
    private var todayItem: NSMenuItem?
    private var engineItem: NSMenuItem?
    private var suggestionsItem: NSMenuItem?
    private var pauseItem: NSMenuItem?

    /// Every setting, its defaults domain, and its fallback live in one tested
    /// type so menu switches cannot silently target keys nothing reads.
    private let settings = TildeSettings()

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarMark()

        let menu = NSMenu()
        lifetimeItem = addInfoRow(to: menu, "Tilde")
        todayItem = addInfoRow(to: menu, "Today: none accepted")
        engineItem = addInfoRow(to: menu, LlamaRuntimeSnapshot.starting.menuLine)
        menu.addItem(.separator())

        suggestionsItem = addAction(to: menu, "Suggestions", #selector(toggleSuggestions(_:)))
        menu.addItem(.separator())

        pauseItem = addAction(to: menu, "Pause for an hour", #selector(togglePause(_:)))
        addAction(to: menu, "Quit Tilde", #selector(quit(_:)), key: "q")

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Draw the brand mark directly: there is no tilde SF Symbol. Keeping it a
    /// template image lets macOS recolor it correctly in every menu-bar state.
    private static func menuBarMark() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 2.5, y: 7.0))
            path.curve(
                to: NSPoint(x: 9.0, y: 9.0),
                controlPoint1: NSPoint(x: 4.5, y: 12.0),
                controlPoint2: NSPoint(x: 7.0, y: 12.0)
            )
            path.curve(
                to: NSPoint(x: 15.5, y: 11.0),
                controlPoint1: NSPoint(x: 11.0, y: 6.0),
                controlPoint2: NSPoint(x: 13.5, y: 6.0)
            )
            path.lineWidth = 2.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.accessibilityDescription = "Tilde"
        image.isTemplate = true
        return image
    }

    @discardableResult
    private func addInfoRow(to menu: NSMenu, _ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    @discardableResult
    private func addAction(
        to menu: NSMenu,
        _ title: String,
        _ action: Selector,
        key: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleSuggestions(_ sender: Any?) {
        settings.suggestionsEnabled.toggle()
    }

    @objc private func togglePause(_ sender: Any?) {
        if settings.pausedUntil != nil {
            settings.resume()
        } else {
            settings.pause(for: 3600)
        }
    }

    @objc private func quit(_ sender: Any?) {
        // Deliberate quit means STAY quit: tell the keyboard's watchdog not to
        // summon the brain back. The flag lives in the IME's defaults domain
        // and is cleared by the next on-purpose app launch.
        UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
            .set(true, forKey: "GhostBrainQuietQuit")
        NSApp.terminate(nil)
    }
}

extension StatusMenuHost: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let lifetime = TildeStats.lifetimeWordsAccepted()
        lifetimeItem?.title = lifetime > 0
            ? "\(lifetime.formatted()) words accepted"
            : "Tilde"

        let today = TildeStats.todayWordsAccepted()
        todayItem?.title = today > 0 ? "Today: \(today) accepted" : "Today: none accepted"

        engineItem?.title = appDelegate?.engineStatusLine() ?? "Engine: unknown"
        suggestionsItem?.state = settings.suggestionsEnabled ? .on : .off

        if let until = settings.pausedUntil {
            let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
            pauseItem?.title = "Resume Tilde (paused \(minutes)m)"
        } else {
            pauseItem?.title = "Pause for an hour"
        }
    }
}
