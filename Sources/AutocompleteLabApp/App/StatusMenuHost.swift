import AppKit

/// The menu-bar presence, minimal by design: engine status, the screen-context
/// toggle, feedback, quit. The keyboard itself is configured from the system
/// input menu; the app is just the brain's caretaker.
@MainActor
final class StatusMenuHost: NSObject {

    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?
    private var engineStatusItem: NSMenuItem?
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

        let menu = NSMenu()
        let status = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        engineStatusItem = status
        menu.addItem(.separator())

        let screenContext = NSMenuItem(
            title: "Screen-aware suggestions",
            action: #selector(toggleScreenContext(_:)),
            keyEquivalent: ""
        )
        screenContext.target = self
        menu.addItem(screenContext)
        screenContextItem = screenContext
        menu.addItem(.separator())

        let feedback = NSMenuItem(
            title: BetaFeedbackLink.menuTitle,
            action: #selector(openFeedback(_:)),
            keyEquivalent: ""
        )
        feedback.target = self
        menu.addItem(feedback)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit SteadyType", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.delegate = self
        item.menu = menu
        statusItem = item
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
        engineStatusItem?.title = appDelegate?.engineStatusLine() ?? "SteadyType"
        screenContextItem?.state = UserDefaults.standard.bool(forKey: "VisiblePageContextEnabled") ? .on : .off
    }
}
