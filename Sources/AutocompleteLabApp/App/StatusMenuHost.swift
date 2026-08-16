import AutocompleteLabCore
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
    private var personalHistoryItem: NSMenuItem?
    private var personalNextWordItem: NSMenuItem?
    private var historySizeItem: NSMenuItem?
    private var historyLocationItem: NSMenuItem?
    private var excludeCurrentAppItem: NSMenuItem?
    private var excludedAppsItem: NSMenuItem?
    private var deleteHistoryItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var currentExclusionCandidate: (name: String, bundle: String)?

    // Screen Memory, Phase 1a: capture engine only, nothing persisted or fed
    // into prompts yet. The full opt-in toggle is Phase 5's rollout; until
    // then this section only exists behind a dev flag so the TCC flow and
    // its graceful-degradation status line can be exercised and reviewed.
    private var screenMemoryItem: NSMenuItem?
    private var screenMemoryStatusItem: NSMenuItem?
    private var openScreenRecordingSettingsItem: NSMenuItem?

    /// Every setting, its defaults domain, and its fallback live in one tested
    /// type so menu switches cannot silently target keys nothing reads.
    private let settings = TildeSettings()
    private let personalHistory: PersonalHistoryController

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
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

        personalHistoryItem = addAction(
            to: menu,
            "Personal History (local only)",
            #selector(togglePersonalHistory(_:))
        )
        historySizeItem = addInfoRow(to: menu, "History: measuring…")
        personalNextWordItem = addInfoRow(
            to: menu,
            "Next-word test: waiting for fresh writing · shadow-only"
        )
        personalNextWordItem?.isHidden = true
        historyLocationItem = addInfoRow(
            to: menu,
            "Location: \(NSString(string: personalHistory.location.path).abbreviatingWithTildeInPath)"
        )
        excludeCurrentAppItem = addAction(
            to: menu,
            "Exclude Current App",
            #selector(excludeCurrentApp(_:))
        )
        let excluded = NSMenuItem(title: "Excluded Apps", action: nil, keyEquivalent: "")
        excluded.submenu = NSMenu()
        menu.addItem(excluded)
        excludedAppsItem = excluded
        deleteHistoryItem = addAction(
            to: menu,
            "Delete Personal History…",
            #selector(deletePersonalHistory(_:))
        )

        if TildeSettings.screenMemoryDevModeEnabled {
            menu.addItem(.separator())
            screenMemoryItem = addAction(
                to: menu,
                "Screen Memory (local only) [dev]",
                #selector(toggleScreenMemory(_:))
            )
            screenMemoryStatusItem = addInfoRow(to: menu, "Screen Recording: checking…")
            openScreenRecordingSettingsItem = addAction(
                to: menu,
                "Open Screen Recording Settings…",
                #selector(openScreenRecordingSettings(_:))
            )
            openScreenRecordingSettingsItem?.isHidden = true
        }
        menu.addItem(.separator())

        pauseItem = addAction(
            to: menu,
            "Pause suggestions for an hour",
            #selector(togglePause(_:))
        )
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

    @objc private func togglePersonalHistory(_ sender: Any?) {
        if personalHistory.isEnabled {
            personalHistory.isEnabled = false
            return
        }
        let alert = NSAlert()
        alert.messageText = "Turn on Personal History?"
        alert.informativeText = """
        Tilde will store text you produce through its keyboard in an encrypted file on this Mac. It rebuilds two personal next-word recipes from a bounded recent part of that history, then compares them on fresh writing while Tilde runs. Only aggregate lifetime totals and up to 64 daily buckets are retained with that encrypted history. This test is shadow-only: it makes no visible suggestion changes, and nothing is uploaded.

        macOS Secure Event Input blocks password capture when an app enables it. Custom sensitive fields may not be detectable, so exclude apps you do not want recorded.
        """
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            personalHistory.isEnabled = true
        }
    }

    @objc private func excludeCurrentApp(_ sender: Any?) {
        guard let candidate = currentExclusionCandidate else { return }
        var apps = personalHistory.excludedApps
        apps.insert(candidate.bundle)
        personalHistory.excludedApps = apps
        refreshExcludedAppsMenu()
    }

    @objc private func removeExcludedApp(_ sender: NSMenuItem) {
        guard let bundle = sender.representedObject as? String else { return }
        var apps = personalHistory.excludedApps
        apps.remove(bundle)
        personalHistory.excludedApps = apps
        refreshExcludedAppsMenu()
    }

    @objc private func deletePersonalHistory(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Delete all Personal History?"
        alert.informativeText = "This turns Personal History off and removes its encrypted file, Keychain key, and aggregate next-word test results. This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await personalHistory.deleteAll()
                refreshHistorySummary()
            } catch {
                let failure = NSAlert()
                failure.messageText = "Personal History could not be deleted"
                failure.informativeText = "Quit and reopen Tilde, then try again."
                failure.runModal()
            }
        }
    }

    /// The consent alert's disclosure of whether a suggestion actually
    /// consumes screen text — this must track `RawContinuationPrompt`'s
    /// real behavior, not describe an earlier phase forever. Screen context
    /// is wired into live suggestions once `screenMemoryDevModeEnabled` is
    /// set (see `AppDelegate.sceneProvider`), and this menu item itself is
    /// only ever shown under that same flag, so the alert must say so
    /// rather than the stale "no suggestion uses it yet."
    private var consentUsageSentence: String {
        TildeSettings.screenMemoryDevModeEnabled
            ? "In this dev build, on-screen text can be folded into your suggestions."
            : "No suggestion uses it yet."
    }

    /// Phase 1a's TCC flow, with graceful degradation at every branch:
    /// declining the explanation leaves the toggle untouched; declining or
    /// later revoking the system permission leaves the toggle on but the
    /// engine simply captures nothing (ScreenCaptureService checks
    /// `ScreenRecordingPermission.isGranted()` on every trigger) — the
    /// status line says so instead of the feature failing silently.
    @objc private func toggleScreenMemory(_ sender: Any?) {
        if settings.screenMemoryEnabled {
            settings.screenMemoryEnabled = false
            refreshScreenMemoryStatus()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Turn on Screen Memory?"
        alert.informativeText = """
        Tilde will read on-screen text on this Mac using on-device OCR — not just what you type — to build better suggestions. Screen text never leaves this Mac, is never uploaded, and in this build is memory-only: nothing is stored to disk. \(consentUsageSentence)

        macOS will ask you to grant Screen Recording permission. Secure Event Input and a locked screen always pause capture. Any app on your Personal History exclusion list blocks capture whenever it is visible on screen at all — not only when it is the frontmost window.
        """
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        settings.screenMemoryEnabled = true
        if !ScreenRecordingPermission.isGranted() {
            ScreenRecordingPermission.request()
        }
        refreshScreenMemoryStatus()
    }

    @objc private func openScreenRecordingSettings(_ sender: Any?) {
        NSWorkspace.shared.open(ScreenRecordingPermission.systemSettingsURL)
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
        let lifetimeShown = TildeStats.lifetimeSuggestionsShown()
        let lifetimeRate = TildeStats.acceptanceRate(
            accepted: TildeStats.lifetimeSuggestionsAccepted(),
            shown: lifetimeShown
        )
        let lifetimeRateSuffix = lifetimeShown > 0 ? " · \(lifetimeRate)% accept rate" : ""
        lifetimeItem?.title = (lifetime > 0 || lifetimeShown > 0)
            ? "\(lifetime.formatted()) words accepted\(lifetimeRateSuffix)"
            : "Tilde"

        let todayAccepted = TildeStats.todaySuggestionsAccepted()
        let todayShown = TildeStats.todaySuggestionsShown()
        let todayRate = TildeStats.acceptanceRate(accepted: todayAccepted, shown: todayShown)
        todayItem?.title = todayShown > 0
            ? "Today: \(todayAccepted) accepted · \(todayShown) shown (\(todayRate)%)"
            : "Today: none accepted"

        engineItem?.title = appDelegate?.engineStatusLine() ?? "Engine: unknown"
        suggestionsItem?.state = settings.suggestionsEnabled ? .on : .off
        personalHistoryItem?.state = personalHistory.isEnabled ? .on : .off
        personalNextWordItem?.isHidden = !personalHistory.isEnabled
        refreshCurrentExclusionCandidate()
        refreshExcludedAppsMenu()
        refreshHistorySummary()
        refreshPersonalNextWord()
        refreshScreenMemoryStatus()

        if let until = settings.pausedUntil {
            let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
            pauseItem?.title = "Resume Tilde (paused \(minutes)m)"
        } else {
            pauseItem?.title = "Pause suggestions for an hour"
        }
    }

    private func refreshCurrentExclusionCandidate() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier,
              bundle != Bundle.main.bundleIdentifier,
              PersonalHistoryEvent.validBundleIdentifier(bundle),
              !personalHistory.excludedApps.contains(bundle) else {
            currentExclusionCandidate = nil
            excludeCurrentAppItem?.title = "Exclude Current App"
            excludeCurrentAppItem?.isEnabled = false
            return
        }
        currentExclusionCandidate = (app.localizedName ?? bundle, bundle)
        excludeCurrentAppItem?.title = "Exclude \(app.localizedName ?? bundle)"
        excludeCurrentAppItem?.isEnabled = true
    }

    /// Honest status regardless of which way the degradation happened: off
    /// by the user's own toggle reads differently from off because macOS
    /// hasn't granted the permission the toggle asked for.
    private func refreshScreenMemoryStatus() {
        guard let screenMemoryItem, let screenMemoryStatusItem else { return }
        let enabled = settings.screenMemoryEnabled
        screenMemoryItem.state = enabled ? .on : .off
        guard enabled else {
            screenMemoryStatusItem.title = "Screen Recording: off"
            openScreenRecordingSettingsItem?.isHidden = true
            return
        }
        if ScreenRecordingPermission.isGranted() {
            screenMemoryStatusItem.title = "Screen Recording: granted"
            openScreenRecordingSettingsItem?.isHidden = true
        } else {
            screenMemoryStatusItem.title = "Screen Recording: not granted — capture is paused"
            openScreenRecordingSettingsItem?.isHidden = false
        }
    }

    private func refreshExcludedAppsMenu() {
        guard let menu = excludedAppsItem?.submenu else { return }
        menu.removeAllItems()
        let apps = personalHistory.excludedApps.sorted()
        if apps.isEmpty {
            let empty = NSMenuItem(title: "No excluded apps", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for bundle in apps {
            let item = NSMenuItem(
                title: "Remove \(bundle)",
                action: #selector(removeExcludedApp(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = bundle
            menu.addItem(item)
        }
    }

    private func refreshHistorySummary() {
        if showStorageFailureIfNeeded() { return }
        historySizeItem?.title = "History: measuring…"
        Task { [weak self] in
            guard let self else { return }
            guard let summary = await personalHistory.summary() else {
                if showStorageFailureIfNeeded() { return }
                historySizeItem?.title = "History: unavailable"
                deleteHistoryItem?.isEnabled = true
                return
            }
            if showStorageFailureIfNeeded() { return }
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            formatter.includesUnit = true
            formatter.isAdaptive = true
            historySizeItem?.title = "History: \(formatter.string(fromByteCount: summary.approximateBytes))"
            deleteHistoryItem?.isEnabled = summary.approximateBytes > 0
        }
    }

    private func showStorageFailureIfNeeded() -> Bool {
        guard let line = personalHistory.storageHealthSnapshot.menuLine else { return false }
        historySizeItem?.title = line
        deleteHistoryItem?.isEnabled = true
        return true
    }

    private func refreshPersonalNextWord() {
        guard personalHistory.isEnabled else { return }
        personalNextWordItem?.title = "Next-word test: loading… · shadow-only"
        Task { [weak self] in
            guard let self else { return }
            personalNextWordItem?.title = await personalHistory.nextWordStatus().menuLine
        }
    }
}
