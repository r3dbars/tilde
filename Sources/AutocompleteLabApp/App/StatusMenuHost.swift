import AppKit

/// The menu-bar presence, minimal by design: engine status, the screen-context
/// toggle, feedback, quit. The keyboard itself is configured from the system
/// input menu; the app is just the brain's caretaker.
@MainActor
final class StatusMenuHost: NSObject {

    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?
    private var engineStatusItem: NSMenuItem?
    private var todayStatItem: NSMenuItem?
    private var screenContextItem: NSMenuItem?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "keyboard.badge.ellipsis",
            accessibilityDescription: "SteadyType"
        )

        // Minimal wireframe (owner-approved 2026-07-26): today stat, health,
        // pause, open, quit. Five rows, no submenus; toggles live in the window.
        let menu = NSMenu()
        let today = NSMenuItem(title: "Today: starting…", action: nil, keyEquivalent: "")
        today.isEnabled = false
        menu.addItem(today)
        todayStatItem = today
        let status = NSMenuItem(title: "Engine: starting…", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        engineStatusItem = status
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause for 1 hour", action: #selector(pauseHour(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        let open = NSMenuItem(title: "Open Tilde…", action: #selector(openTilde(_:)), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Tilde", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    @objc private func pauseHour(_ sender: Any?) {
        UserDefaults(suiteName: "bar.r3d.inputmethod.InlineGhost")?
            .set(Date().timeIntervalSince1970 + 3600, forKey: "GhostPausedUntil")
    }

    @objc private func openTilde(_ sender: Any?) {
        TildeWindowHost.shared.show()
    }

    @objc private func toggleScreenContext(_ sender: Any?) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "VisiblePageContextEnabled"), forKey: "VisiblePageContextEnabled")
    }

    @objc private func openFeedback(_ sender: Any?) {
        if let url = URL(string: BetaFeedbackLink.issueTemplateURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

extension StatusMenuHost: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        engineStatusItem?.title = appDelegate?.engineStatusLine() ?? "Tilde"
        let t = TildeStats.today()
        todayStatItem?.title = t.wordsAccepted > 0
            ? "Today: wrote \(t.wordsAccepted) words for you (\(t.shareOfTyping)%)"
            : "Today: no typing yet"
        screenContextItem?.state = UserDefaults.standard.bool(forKey: "VisiblePageContextEnabled") ? .on : .off
    }
}
