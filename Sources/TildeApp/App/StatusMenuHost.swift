import AppKit
import TildeCore

/// A frontmost app, as the menu needs to talk about it: the bundle
/// identifier the exclusion list is keyed by, and the app's own display
/// name. Nothing else about the app is read — never its window title, never
/// anything it is displaying, never anything typed into it.
struct ForegroundApplication: Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
}

/// The pure half of the menu's one-click "Ignore <App>" affordance, kept out
/// of the AppKit class so both the wording and the list arithmetic are
/// testable.
enum IgnoreApplicationMenuItem {
    /// `nil` hides the item — there is nothing to offer until some other app
    /// has been frontmost. An app that is already ignored keeps a line in
    /// the menu (with a checkmark) rather than vanishing: silently removing
    /// the row would read as "the click did nothing".
    static func title(for application: ForegroundApplication?, isIgnored: Bool) -> String? {
        guard let application else { return nil }
        let name = application.name.isEmpty ? application.bundleIdentifier : application.name
        return isIgnored ? "Ignoring \(name)" : "Ignore \(name)"
    }

    /// Adds one bundle identifier to the same excluded-apps list the
    /// Settings file panel writes, normalized exactly the way that flow
    /// normalizes it. Idempotent: adding an app already on the list returns
    /// the list unchanged, so a second click cannot rotate the consent
    /// identifier or grow the stored array. An identifier the shared
    /// contract would reject is dropped rather than stored — the exclusion
    /// would silently never match.
    static func adding(_ bundleIdentifier: String, to excluded: Set<String>) -> Set<String> {
        guard PersonalHistoryEvent.validBundleIdentifier(bundleIdentifier) else { return excluded }
        return Set(
            PersonalHistoryCapturePolicy.normalizedExcludedApps(excluded.union([bundleIdentifier]))
        )
    }
}

/// Tilde stays quiet in the menu bar. Personal progress and controls live in
/// one unified window opened from a single menu action.
@MainActor
final class StatusMenuHost: NSObject {
    struct Presentation: Equatable {
        let status: String
        let detail: String
        let primaryAction: String?

        /// `screenMemoryEnabled` is not cosmetic here. `.disabled` covers two
        /// different user choices — suggestions off, or the Screen Memory
        /// master toggle off — and the resume action turns both back on. A
        /// button labelled only "Resume Tilde" would quietly undo an explicit
        /// privacy choice, so when Screen Memory is the reason, the menu says
        /// so and the action names what it will switch on.
        static func make(
            state: TildeApplicationState,
            model: ModelState,
            wordsToday: Int,
            screenMemoryEnabled: Bool = true,
            ledger: OutcomeLedgerSummary = .empty,
            screenAccessGranted: Bool = true
        ) -> Self {
            /// Value first: keystrokes saved and the honest held-back count,
            /// falling back to the words line until the ledger has evidence.
            let today = OutcomeLedgerPresentation.menuDetail(
                summary: ledger,
                wordsToday: wordsToday,
                screenAccessGranted: screenAccessGranted
            )
            if state.requiresUserAttention {
                return Self(
                    status: "Tilde Needs Attention",
                    detail: "Finish setup to start suggesting",
                    primaryAction: "Finish Setup"
                )
            }

            if case let .downloading(receivedBytes, totalBytes) = model,
               state == .preparingModel {
                let fraction = totalBytes > 0
                    ? min(1, max(0, Double(receivedBytes) / Double(totalBytes)))
                    : 0
                let percent = Int((fraction * 100).rounded())
                let progress = TildeModelDownloadProgress(
                    receivedBytes: receivedBytes,
                    totalBytes: totalBytes
                )
                return Self(
                    status: "Downloading Local Model · \(percent)%",
                    detail: progress.detail,
                    primaryAction: nil
                )
            }

            switch state {
            case .ready:
                return Self(
                    status: "Tilde is Ready",
                    detail: today,
                    primaryAction: "Pause for 1 Hour"
                )
            case .disabled where !screenMemoryEnabled:
                return Self(
                    status: "Screen Memory is Off",
                    detail: "Tilde suggests nothing until it can read the screen",
                    primaryAction: "Turn Screen Memory Back On"
                )
            case .paused, .disabled:
                return Self(
                    status: "Tilde is Paused",
                    detail: today,
                    primaryAction: "Resume Tilde"
                )
            case .needsKeyboard, .needsPermission, .recoverableError:
                assertionFailure("User-attention states are handled above")
                return Self(status: "Tilde Needs Attention", detail: "Finish setup", primaryAction: "Finish Setup")
            case .preparingModel:
                return Self(
                    status: "Tilde is Getting Ready",
                    detail: "Preparing local model",
                    primaryAction: nil
                )
            }
        }
    }

    private weak var appDelegate: AppDelegate?
    private let personalHistory: PersonalHistoryController
    private let settings = TildeSettings()

    private var statusItem: NSStatusItem?
    private var statusLineItem: NSMenuItem?
    private var todayItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var ignoreAppItem: NSMenuItem?
    private var setupOrTildeItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var modelPickerItem: NSMenuItem?
    private var productionModelChoiceItems: [TildeModelChoice: NSMenuItem] = [:]
    private var modelChoiceItems: [PreviewModelChoice: NSMenuItem] = [:]
    private var h01Item: NSMenuItem?

    private var tildeWindow: TildeSettingsWindowController?

    /// Last aggregate read of the text-free outcome ledger. The menu renders
    /// from this cache; the read itself never runs on the main thread.
    private var ledger = OutcomeLedgerSummary.empty
    private var ledgerLoad: Task<Void, Never>?
    private var ledgerLoadedAt: Date?
    /// A menu opened twice in a few seconds should not re-read the file.
    private static let ledgerRefreshInterval: TimeInterval = 5

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
    }

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarMark()

        let menu = NSMenu()
        let productName = TildeProductProfile.current.displayName
        statusLineItem = addAction(to: menu, "\(productName) is Getting Ready", #selector(openStatus(_:)))
        todayItem = addAction(to: menu, "0 words with Tilde today", #selector(openYourTilde(_:)))
        menu.addItem(.separator())

        if TildeProductProfile.current == .production {
            let picker = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Model")
            for choice in TildeModelChoice.allCases {
                let choiceItem = addAction(to: submenu, choice.displayName, #selector(selectModel(_:)))
                choiceItem.representedObject = choice.rawValue
                productionModelChoiceItems[choice] = choiceItem
            }
            picker.submenu = submenu
            menu.addItem(picker)
            modelPickerItem = picker
            menu.addItem(.separator())
        } else if TildeProductProfile.current == .modelPreview {
            let picker = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Model")
            for choice in PreviewModelChoice.allCases {
                let choiceItem = addAction(
                    to: submenu,
                    choice.displayName,
                    #selector(selectModel(_:))
                )
                choiceItem.representedObject = choice.rawValue
                modelChoiceItems[choice] = choiceItem
            }
            picker.submenu = submenu
            menu.addItem(picker)
            modelPickerItem = picker

            // H01 harness (three visible words vs eight). Model Preview only,
            // off unless the owner turns it on, and inert while off.
            h01Item = addAction(
                to: menu,
                "Experiment: 3 vs 8 Visible Words",
                #selector(toggleH01BlockRandomization(_:))
            )
            menu.addItem(.separator())
        }

        pauseItem = addAction(to: menu, "Pause for 1 Hour", #selector(togglePause(_:)))
        // One click to exclude whatever the user was just writing in, from
        // the same list the Settings file panel writes — so it applies to
        // Screen Memory capture, Personal History, and the outcome ledger
        // alike. Hidden until some other app has actually been frontmost.
        ignoreAppItem = addAction(to: menu, "Ignore App", #selector(ignoreForegroundApplication(_:)))
        ignoreAppItem?.isHidden = true
        accessibilityItem = addAction(to: menu, "Exact Screen Text", #selector(enableExactScreenText(_:)))
        setupOrTildeItem = addAction(to: menu, "Open \(productName)", #selector(openTilde(_:)))
        menu.addItem(.separator())
        addAction(to: menu, "Quit \(productName)", #selector(quit(_:)), key: "q")

        menu.delegate = self
        item.menu = menu
        statusItem = item
        refresh()
    }

    func refresh() {
        guard let appDelegate else { return }
        let state = appDelegate.applicationState()
        refreshLedgerIfStale()
        let presentation = Presentation.make(
            state: state,
            model: appDelegate.modelState(),
            wordsToday: TildeStats.todayWordsAccepted(),
            screenMemoryEnabled: settings.screenMemoryEnabled,
            ledger: ledger,
            screenAccessGranted: screenAccessGranted
        )
        statusLineItem?.title = switch TildeProductProfile.current {
        case .production: "\(appDelegate.selectedProductionModel()?.shortName ?? "Gemma E2B") · \(presentation.status)"
        case .preview26B: "26B Preview · \(presentation.status)"
        case .preview9B: "9B Preview · \(presentation.status)"
        case .modelPreview: "\(appDelegate.selectedPreviewModel()?.shortName ?? "Model Preview") · \(presentation.status)"
        }
        todayItem?.title = presentation.detail
        pauseItem?.title = presentation.primaryAction ?? ""
        pauseItem?.isHidden = presentation.primaryAction == nil
        setupOrTildeItem?.title = "Open \(TildeProductProfile.current.displayName)"
        if let active = appDelegate.selectedProductionModel() {
            modelPickerItem?.title = "Model: \(active.shortName)"
            for (choice, item) in productionModelChoiceItems {
                item.state = choice == active ? .on : .off
            }
        } else if let active = appDelegate.selectedPreviewModel() {
            modelPickerItem?.title = "Model: \(active.shortName)"
            for (choice, item) in modelChoiceItems {
                item.state = choice == active ? .on : .off
            }
        }

        let foreground = appDelegate.foregroundApplication()
        let foregroundIsIgnored = foreground.map {
            DefaultExcludedApps.isExcluded(
                $0.bundleIdentifier,
                configuredExcludedApps: personalHistory.excludedApps
            )
        } ?? false
        if let ignoreTitle = IgnoreApplicationMenuItem.title(
            for: foreground,
            isIgnored: foregroundIsIgnored
        ) {
            ignoreAppItem?.title = ignoreTitle
            ignoreAppItem?.state = foregroundIsIgnored ? .on : .off
            ignoreAppItem?.isHidden = false
        } else {
            ignoreAppItem?.isHidden = true
        }

        h01Item?.state = settings.h01BlockRandomizationEnabled ? .on : .off
        let exactTextGranted = AccessibilityPermission.isGranted()
        accessibilityItem?.title = exactTextGranted
            ? "Exact Screen Text: On"
            : "Enable Exact Screen Text (Accessibility)…"
        accessibilityItem?.state = exactTextGranted ? .on : .off

        refreshIcon(for: state.iconAppearance)
        tildeWindow?.refresh()
    }

    /// Suggesting at all needs Screen Memory on and the OS permission granted.
    private var screenAccessGranted: Bool {
        settings.screenMemoryEnabled && ScreenRecordingPermission.isGranted()
    }

    private func refreshLedgerIfStale() {
        guard ledgerLoad == nil else { return }
        if let ledgerLoadedAt,
           Date().timeIntervalSince(ledgerLoadedAt) < Self.ledgerRefreshInterval {
            return
        }
        let url = TildeLocalOutcomeStores.eventURL()
        ledgerLoad = Task { [weak self] in
            let summary = await OutcomeLedgerReader.summary(url: url)
            guard let self else { return }
            self.ledger = summary
            self.ledgerLoadedAt = Date()
            self.ledgerLoad = nil
            self.refresh()
        }
    }

    @objc private func togglePause(_ sender: Any?) {
        if appDelegate?.applicationState().requiresUserAttention == true {
            appDelegate?.showSetup()
        } else if settings.pausedUntil != nil {
            settings.resume()
        } else if appDelegate?.applicationState() == .disabled {
            let screenMemoryWasOff = !settings.screenMemoryEnabled
            settings.suggestionsEnabled = true
            settings.screenMemoryEnabled = true
            settings.resume()
            // The menu item says which switch this flips (see
            // `Presentation.make`), and the app still has to hear about it:
            // the capture service and the status icon both key off it.
            if screenMemoryWasOff { appDelegate?.screenMemoryEnabledDidChange(true) }
        } else {
            settings.pause(for: 3_600)
        }
        refresh()
    }

    @objc private func openStatus(_ sender: Any?) {
        if appDelegate?.applicationState().requiresUserAttention == true {
            appDelegate?.showSetup()
        } else {
            showYourTilde()
        }
    }

    @objc private func openYourTilde(_ sender: Any?) {
        showYourTilde()
    }

    @objc private func openTilde(_ sender: Any?) {
        showYourTilde()
    }

    /// Exact screen text reads the focused window's text through the
    /// Accessibility API instead of OCR. Asks the system prompt, then opens
    /// the pane so a previously dismissed prompt still has a path.
    @objc private func enableExactScreenText(_ sender: Any?) {
        guard let appDelegate else { return }
        if !AccessibilityPermission.isGranted() {
            appDelegate.requestAccessibilityAccess()
            if !AccessibilityPermission.isGranted() { appDelegate.openAccessibilitySettings() }
        }
        refresh()
    }

    /// Adds the last frontmost non-Tilde app to the shared excluded-apps
    /// list. Same list, same writer, same normalization as the Settings
    /// "Add App…" panel, so the exclusion applies everywhere it applies
    /// today: Screen Memory capture, Personal History, and the outcome
    /// ledger. Only the bundle identifier is stored.
    @objc private func ignoreForegroundApplication(_ sender: Any?) {
        guard let application = appDelegate?.foregroundApplication() else { return }
        let excluded = personalHistory.excludedApps
        let updated = IgnoreApplicationMenuItem.adding(application.bundleIdentifier, to: excluded)
        if updated != excluded { personalHistory.excludedApps = updated }
        refresh()
    }

    @objc private func toggleH01BlockRandomization(_ sender: Any?) {
        guard TildeProductProfile.current == .modelPreview else { return }
        settings.h01BlockRandomizationEnabled = !settings.h01BlockRandomizationEnabled
        refresh()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }
        if TildeProductProfile.current == .production,
           let choice = TildeModelChoice(rawValue: rawValue) {
            appDelegate?.selectProductionModel(choice)
        } else if let choice = PreviewModelChoice(rawValue: rawValue) {
            appDelegate?.selectPreviewModel(choice)
        }
    }

    func showTilde() {
        guard let appDelegate else { return }
        if appDelegate.setupRequired() {
            appDelegate.showSetup()
            return
        }
        showYourTilde()
    }

    private func showYourTilde() {
        guard let appDelegate else { return }
        if tildeWindow == nil {
            tildeWindow = TildeSettingsWindowController(
                appDelegate: appDelegate,
                personalHistory: personalHistory
            )
        }
        tildeWindow?.show()
    }

    @objc private func quit(_ sender: Any?) {
        UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
            .set(true, forKey: "GhostBrainQuietQuit")
        NSApp.terminate(nil)
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
