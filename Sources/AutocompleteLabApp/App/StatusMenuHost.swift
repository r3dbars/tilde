import AppKit

/// The menu bar IS the app (owner decision 2026-07-29). No settings window,
/// no panes, no nesting: one click shows what Tilde did for you, whether it's
/// healthy, and every switch there is. Ten rows, all of them real — a toggle
/// only earns a row if something actually reads its key.
///
/// Two defaults domains, deliberately: settings the KEYBOARD obeys are written
/// into its suite (it reads them as its own `.standard`); settings the APP
/// obeys live in the app's domain. Writing to the wrong one is a silent no-op,
/// which is how three decorative toggles survived in the old window.
@MainActor
final class StatusMenuHost: NSObject {

    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?

    private var lifetimeItem: NSMenuItem?
    private var todayItem: NSMenuItem?
    private var engineItem: NSMenuItem?
    private var suggestionsItem: NSMenuItem?
    private var screenItem: NSMenuItem?
    private var soundsItem: NSMenuItem?
    private var learningItem: NSMenuItem?
    private var pauseItem: NSMenuItem?

    /// The keyboard's own defaults domain — it reads these as `.standard`.
    private let keyboard = UserDefaults(suiteName: "bar.r3d.inputmethod.InlineGhost")
    private static let defaultSoundVolume = 0.4

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarMark()

        let menu = NSMenu()

        lifetimeItem = addInfoRow(to: menu, "Tilde")
        todayItem = addInfoRow(to: menu, "Today: no typing yet")
        engineItem = addInfoRow(to: menu, "Engine: starting…")
        menu.addItem(.separator())

        suggestionsItem = addToggle(to: menu, "Suggestions", #selector(toggleSuggestions(_:)))
        screenItem = addToggle(to: menu, "Screen-aware", #selector(toggleScreenContext(_:)))
        soundsItem = addToggle(to: menu, "Sounds", #selector(toggleSounds(_:)))
        learningItem = addToggle(to: menu, "Learns from typing", #selector(toggleLearning(_:)))
        menu.addItem(.separator())

        pauseItem = addAction(to: menu, "Pause for an hour", #selector(togglePause(_:)))
        addAction(to: menu, "Show data in Finder", #selector(showData(_:)))
        addAction(to: menu, "Quit Tilde", #selector(quit(_:)), key: "q")

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// The status-bar mark, drawn rather than borrowed: there is no "tilde" SF
    /// Symbol (verified — NSImage(systemSymbolName:) returns nil), so asking
    /// for one silently yielded the old keyboard glyph and the brand mark never
    /// appeared. Template image = macOS recolors it for light/dark and for the
    /// highlighted menu, which is why the blue underline stays out of the menu
    /// bar (docs/brand/BRAND.md).
    private static func menuBarMark() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            // One crest, one midline crossing, one trough; endpoints in 180°
            // rotational balance about the centre — the mark's construction.
            path.move(to: NSPoint(x: 2.5, y: 7.0))
            path.curve(to: NSPoint(x: 9.0, y: 9.0),
                       controlPoint1: NSPoint(x: 4.5, y: 12.0),
                       controlPoint2: NSPoint(x: 7.0, y: 12.0))
            path.curve(to: NSPoint(x: 15.5, y: 11.0),
                       controlPoint1: NSPoint(x: 11.0, y: 6.0),
                       controlPoint2: NSPoint(x: 13.5, y: 6.0))
            path.lineWidth = 2.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Row builders

    @discardableResult
    private func addInfoRow(to menu: NSMenu, _ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    @discardableResult
    private func addToggle(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @discardableResult
    private func addAction(to menu: NSMenu, _ title: String, _ action: Selector,
                           key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Settings the keyboard obeys (its own domain)

    private var suggestionsEnabled: Bool {
        keyboard?.object(forKey: "GhostSuggestionsEnabled") as? Bool ?? true
    }

    private var learningEnabled: Bool {
        keyboard?.object(forKey: "GhostUsageCaptureEnabled") as? Bool ?? true
    }

    private var soundsEnabled: Bool {
        (keyboard?.object(forKey: "GhostSoundVolume") as? Double ?? Self.defaultSoundVolume) > 0
    }

    private var pausedUntil: Date? {
        let stamp = keyboard?.double(forKey: "GhostPausedUntil") ?? 0
        let date = Date(timeIntervalSince1970: stamp)
        return date > Date() ? date : nil
    }

    @objc private func toggleSuggestions(_ sender: Any?) {
        keyboard?.set(!suggestionsEnabled, forKey: "GhostSuggestionsEnabled")
    }

    @objc private func toggleLearning(_ sender: Any?) {
        keyboard?.set(!learningEnabled, forKey: "GhostUsageCaptureEnabled")
    }

    /// Muting must not forget a hand-tuned volume: stash the level being
    /// silenced and restore exactly that, not a hardcoded default. (Live
    /// volumes in the wild are not the default — this Mac sits at 0.8.)
    @objc private func toggleSounds(_ sender: Any?) {
        guard let keyboard else { return }
        if soundsEnabled {
            let current = keyboard.object(forKey: "GhostSoundVolume") as? Double
                ?? Self.defaultSoundVolume
            keyboard.set(current, forKey: "GhostSoundVolumeBeforeMute")
            keyboard.set(0.0, forKey: "GhostSoundVolume")
        } else {
            let restored = keyboard.object(forKey: "GhostSoundVolumeBeforeMute") as? Double
            keyboard.set(max(0.05, restored ?? Self.defaultSoundVolume), forKey: "GhostSoundVolume")
        }
    }

    @objc private func togglePause(_ sender: Any?) {
        let resuming = pausedUntil != nil
        keyboard?.set(resuming ? 0 : Date().timeIntervalSince1970 + 3600,
                      forKey: "GhostPausedUntil")
    }

    // MARK: - Settings the app obeys (app domain)

    @objc private func toggleScreenContext(_ sender: Any?) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "VisiblePageContextEnabled"),
                     forKey: "VisiblePageContextEnabled")
    }

    // MARK: - Actions

    @objc private func showData(_ sender: Any?) {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SteadyType")
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

extension StatusMenuHost: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let lifetime = TildeStats.lifetimeWordsAccepted()
        lifetimeItem?.title = lifetime > 0
            ? "\(lifetime.formatted()) words written for you"
            : "Tilde"

        let today = TildeStats.today()
        if today.wordsAccepted > 0 {
            var line = "Today: \(today.wordsAccepted) words (\(today.shareOfTyping)%)"
            if today.wordsPerMinute > 0 { line += " · \(today.wordsPerMinute) wpm" }
            todayItem?.title = line
        } else {
            todayItem?.title = "Today: no typing yet"
        }

        engineItem?.title = appDelegate?.engineStatusLine() ?? "Engine: unknown"

        suggestionsItem?.state = suggestionsEnabled ? .on : .off
        screenItem?.state = UserDefaults.standard.bool(forKey: "VisiblePageContextEnabled") ? .on : .off
        soundsItem?.state = soundsEnabled ? .on : .off
        learningItem?.state = learningEnabled ? .on : .off

        if let until = pausedUntil {
            let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
            pauseItem?.title = "Resume Tilde (paused \(minutes)m)"
        } else {
            pauseItem?.title = "Pause for an hour"
        }
    }
}
