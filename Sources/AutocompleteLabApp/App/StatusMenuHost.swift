import AppKit

/// Tilde stays quiet in the menu bar. Personal progress and controls live in
/// one unified window opened from a single menu action.
@MainActor
final class StatusMenuHost: NSObject {
    struct Presentation: Equatable {
        let status: String
        let detail: String
        let primaryAction: String?

        static func make(
            state: TildeApplicationState,
            model: ModelState,
            wordsToday: Int
        ) -> Self {
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
                    detail: "\(wordsToday.formatted()) words with Tilde today",
                    primaryAction: "Pause for 1 Hour"
                )
            case .paused, .disabled:
                return Self(
                    status: "Tilde is Paused",
                    detail: "\(wordsToday.formatted()) words with Tilde today",
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
    private var setupOrTildeItem: NSMenuItem?

    private var tildeWindow: TildeSettingsWindowController?

    init(appDelegate: AppDelegate, personalHistory: PersonalHistoryController) {
        self.appDelegate = appDelegate
        self.personalHistory = personalHistory
    }

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarMark()

        let menu = NSMenu()
        statusLineItem = addAction(to: menu, "Tilde is Getting Ready", #selector(openStatus(_:)))
        todayItem = addAction(to: menu, "0 words with Tilde today", #selector(openYourTilde(_:)))
        menu.addItem(.separator())

        pauseItem = addAction(to: menu, "Pause for 1 Hour", #selector(togglePause(_:)))
        setupOrTildeItem = addAction(to: menu, "Open Tilde", #selector(openTilde(_:)))
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
        let presentation = Presentation.make(
            state: state,
            model: appDelegate.modelState(),
            wordsToday: TildeStats.todayWordsAccepted()
        )
        statusLineItem?.title = presentation.status
        todayItem?.title = presentation.detail
        pauseItem?.title = presentation.primaryAction ?? ""
        pauseItem?.isHidden = presentation.primaryAction == nil
        setupOrTildeItem?.title = "Open Tilde"

        refreshIcon(for: state.iconAppearance)
        tildeWindow?.refresh()
    }

    @objc private func togglePause(_ sender: Any?) {
        if appDelegate?.applicationState().requiresUserAttention == true {
            appDelegate?.showSetup()
        } else if settings.pausedUntil != nil {
            settings.resume()
        } else if appDelegate?.applicationState() == .disabled {
            settings.suggestionsEnabled = true
            settings.screenMemoryEnabled = true
            settings.resume()
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
