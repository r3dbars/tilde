import AppKit

/// Tilde stays quiet in the menu bar. Detailed privacy and application
/// controls live in the dedicated settings window.
@MainActor
final class StatusMenuHost: NSObject {
    private weak var appDelegate: AppDelegate?
    private let personalHistory: PersonalHistoryController
    private let settings = TildeSettings()

    private var statusItem: NSStatusItem?
    private var statusLineItem: NSMenuItem?
    private var todayItem: NSMenuItem?
    private var engineItem: NSMenuItem?
    private var screenMemoryItem: NSMenuItem?
    private var suggestionsItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var setupOrSettingsItem: NSMenuItem?

    private var settingsWindow: TildeSettingsWindowController?
    private var yourTildeWindow: YourTildeWindowController?

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
    }

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarMark()

        let menu = NSMenu()
        statusLineItem = addInfoRow(to: menu, "Model is Loading")
        todayItem = addInfoRow(to: menu, "Today: 0 words saved")
        engineItem = addInfoRow(to: menu, "Engine: Gemma (starting…)")
        screenMemoryItem = addInfoRow(to: menu, "Screen Memory: checking…")
        menu.addItem(.separator())

        suggestionsItem = addAction(to: menu, "Tilde On", #selector(toggleSuggestions(_:)))
        pauseItem = addAction(to: menu, "Pause for 1 Hour", #selector(togglePause(_:)))
        addAction(to: menu, "Your Tilde…", #selector(openYourTilde(_:)))
        setupOrSettingsItem = addAction(
            to: menu,
            "Settings…",
            #selector(openSetupOrSettings(_:)),
            key: ","
        )
        menu.addItem(.separator())
        addAction(to: menu, "Quit Tilde", #selector(quit(_:)), key: "q")

        menu.delegate = self
        item.menu = menu
        statusItem = item
        refresh()
    }

    func refresh() {
        guard let appDelegate else { return }
        let state = appDelegate.applicationState()
        statusLineItem?.title = state.statusText
        todayItem?.title = "Today: \(TildeStats.todayWordsAccepted().formatted()) words saved"
        engineItem?.title = appDelegate.engineStatusLine()
        suggestionsItem?.state = settings.suggestionsEnabled ? .on : .off
        setupOrSettingsItem?.title = appDelegate.setupRequired() ? "Finish Setup…" : "Settings…"

        if let until = settings.pausedUntil {
            let minutes = max(1, Int(ceil(until.timeIntervalSinceNow / 60)))
            pauseItem?.title = "Resume Tilde (\(minutes)m left)"
        } else {
            pauseItem?.title = "Pause for 1 Hour"
        }
        pauseItem?.isEnabled = settings.suggestionsEnabled

        refreshScreenMemoryLine()
        refreshIcon(for: state.iconAppearance)
        settingsWindow?.refresh()
        yourTildeWindow?.refresh()
    }

    @objc private func toggleSuggestions(_ sender: Any?) {
        settings.suggestionsEnabled.toggle()
        if !settings.suggestionsEnabled { settings.resume() }
        refresh()
    }

    @objc private func togglePause(_ sender: Any?) {
        if settings.pausedUntil != nil {
            settings.resume()
        } else {
            settings.pause(for: 3_600)
        }
        refresh()
    }

    @objc private func openSetupOrSettings(_ sender: Any?) {
        guard let appDelegate else { return }
        if appDelegate.setupRequired() {
            appDelegate.showSetup()
            return
        }
        if settingsWindow == nil {
            settingsWindow = TildeSettingsWindowController(
                appDelegate: appDelegate,
                personalHistory: personalHistory
            )
        }
        settingsWindow?.show()
    }

    @objc private func openYourTilde(_ sender: Any?) {
        if yourTildeWindow == nil {
            yourTildeWindow = YourTildeWindowController(
                personalHistory: personalHistory,
                openSettings: { [weak self] in self?.openSetupOrSettings(nil) }
            )
        }
        yourTildeWindow?.show()
    }

    @objc private func quit(_ sender: Any?) {
        UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
            .set(true, forKey: "GhostBrainQuietQuit")
        NSApp.terminate(nil)
    }

    private func refreshScreenMemoryLine() {
        guard settings.screenMemoryEnabled else {
            screenMemoryItem?.title = "Screen Memory: Off"
            return
        }
        screenMemoryItem?.title = ScreenRecordingPermission.isGranted()
            ? "Screen Memory: Ready"
            : "Screen Memory: Permission Required"
    }

    private func refreshIcon(for appearance: TildeMenuIconAppearance) {
        guard let button = statusItem?.button else { return }
        switch appearance {
        case .normal:
            button.image = Self.menuBarMark()
            button.contentTintColor = nil
        case .dimmed:
            button.image = Self.menuBarMark()
            button.contentTintColor = .disabledControlTextColor
        case .warning:
            let image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "Tilde needs attention"
            )
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = nil
        }
    }

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
            path.lineWidth = 2
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
}

extension StatusMenuHost: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }
}
