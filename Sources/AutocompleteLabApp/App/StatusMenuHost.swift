import AppKit

enum StatusMenuAction {
    case suggestNow
    case togglePauseSuggestions
    case pauseSuggestionsFor15Minutes
    case pauseSuggestionsFor1Hour
    case pauseSuggestionsUntilTomorrow
    case toggleCurrentApp
    case silenceCurrentField
    case showSettings
    case openFeedbackForm
    case revealModelFolder
    case nudgeSuggestionUp
    case nudgeSuggestionDown
    case nudgeSuggestionLeft
    case nudgeSuggestionRight
    case resetCurrentAppLearning
    case quit
}

/// Owns the menu-bar item and its menu action targets. AppDelegate supplies
/// status text and handles product behavior through the action surface.
@MainActor
final class StatusMenuHost: NSObject {
    private weak var appDelegate: AppDelegate?
    private let developerMenuEnabled: Bool
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var pauseSuggestionsMenuItem: NSMenuItem?
    private var silenceFieldMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?

    init(appDelegate: AppDelegate, developerMenuEnabled: Bool) {
        self.appDelegate = appDelegate
        self.developerMenuEnabled = developerMenuEnabled
    }

    func start(pauseSuggestionsTitle: String) {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton(item.button, configuration: .autocompleteLab)

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "SteadyType", action: nil, keyEquivalent: "")
        menu.addItem(statusMenu)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(actionItem(
            title: "Ask for a Suggestion",
            action: #selector(handleSuggestNow),
            keyEquivalent: "`",
            modifiers: [.control],
            toolTip: "\(SuggestionSummonHotKeyDescriptor.controlBacktick.displayName) asks for one suggestion without changing Tab."
        ))

        let pauseParentItem = NSMenuItem(title: "Pause Suggestions", action: nil, keyEquivalent: "")
        let pauseMenu = NSMenu()
        let pauseItem = actionItem(
            title: pauseSuggestionsTitle,
            action: #selector(handleTogglePauseSuggestions),
            keyEquivalent: "p"
        )
        pauseMenu.addItem(pauseItem)
        pauseMenu.addItem(NSMenuItem.separator())
        pauseMenu.addItem(actionItem(
            title: "For 15 Minutes",
            action: #selector(handlePauseSuggestionsFor15Minutes)
        ))
        pauseMenu.addItem(actionItem(
            title: "For 1 Hour",
            action: #selector(handlePauseSuggestionsFor1Hour)
        ))
        pauseMenu.addItem(actionItem(
            title: "Until Tomorrow",
            action: #selector(handlePauseSuggestionsUntilTomorrow)
        ))
        menu.setSubmenu(pauseMenu, for: pauseParentItem)
        menu.addItem(pauseParentItem)

        let toggleItem = actionItem(
            title: "Pause Current App",
            action: #selector(handleToggleCurrentApp),
            keyEquivalent: "t"
        )
        menu.addItem(toggleItem)
        let silenceFieldItem = actionItem(
            title: "Silence This Field",
            action: #selector(handleSilenceCurrentField),
            keyEquivalent: "s"
        )
        menu.addItem(silenceFieldItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(title: "Settings…", action: #selector(handleShowSettings), keyEquivalent: ","))
        let feedbackItem = NSMenuItem(
            title: BetaFeedbackLink.menuTitle,
            action: #selector(handleOpenFeedbackForm),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        feedbackItem.toolTip = BetaFeedbackLink.privacyNote
        menu.addItem(feedbackItem)

        if developerMenuEnabled {
            let debugMenuItem = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
            let debugMenu = NSMenu()
            debugMenu.addItem(actionItem(title: "Model Folder", action: #selector(handleRevealModelFolder), keyEquivalent: "m"))
            debugMenu.addItem(NSMenuItem.separator())
            debugMenu.addItem(actionItem(title: "Nudge Suggestion Up", action: #selector(handleNudgeSuggestionUp)))
            debugMenu.addItem(actionItem(title: "Nudge Suggestion Down", action: #selector(handleNudgeSuggestionDown)))
            debugMenu.addItem(actionItem(title: "Nudge Suggestion Left", action: #selector(handleNudgeSuggestionLeft)))
            debugMenu.addItem(actionItem(title: "Nudge Suggestion Right", action: #selector(handleNudgeSuggestionRight)))
            debugMenu.addItem(actionItem(title: "Reset Current App Learning", action: #selector(handleResetCurrentAppLearning)))
            menu.setSubmenu(debugMenu, for: debugMenuItem)
            menu.addItem(debugMenuItem)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(title: "Quit SteadyType", action: #selector(handleQuit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        statusMenuItem = statusMenu
        pauseSuggestionsMenuItem = pauseItem
        silenceFieldMenuItem = silenceFieldItem
        toggleAppMenuItem = toggleItem
    }

    func update(
        statusLine: String,
        statusToolTip: String,
        pauseSuggestionsTitle: String,
        silenceFieldTitle: String,
        silenceFieldEnabled: Bool,
        silenceFieldToolTip: String,
        toggleAppTitle: String,
        toggleAppEnabled: Bool,
        toggleAppToolTip: String
    ) {
        statusMenuItem?.title = statusLine
        statusMenuItem?.toolTip = statusToolTip
        pauseSuggestionsMenuItem?.title = pauseSuggestionsTitle
        silenceFieldMenuItem?.title = silenceFieldTitle
        silenceFieldMenuItem?.isEnabled = silenceFieldEnabled
        silenceFieldMenuItem?.toolTip = silenceFieldToolTip
        toggleAppMenuItem?.title = toggleAppTitle
        toggleAppMenuItem?.isEnabled = toggleAppEnabled
        toggleAppMenuItem?.toolTip = toggleAppToolTip
    }

    private func actionItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        toolTip: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        item.toolTip = toolTip
        return item
    }

    private func configureStatusButton(
        _ button: NSStatusBarButton?,
        configuration: MenuBarStatusItemConfiguration
    ) {
        guard let button else {
            return
        }

        if let image = NSImage(
            systemSymbolName: configuration.symbolName,
            accessibilityDescription: configuration.accessibilityLabel
        ) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = configuration.fallbackTitle
        }
        button.toolTip = configuration.accessibilityLabel
    }

    private func send(_ action: StatusMenuAction) {
        appDelegate?.handleStatusMenuAction(action)
    }

    @objc private func handleSuggestNow() { send(.suggestNow) }
    @objc private func handleTogglePauseSuggestions() { send(.togglePauseSuggestions) }
    @objc private func handlePauseSuggestionsFor15Minutes() { send(.pauseSuggestionsFor15Minutes) }
    @objc private func handlePauseSuggestionsFor1Hour() { send(.pauseSuggestionsFor1Hour) }
    @objc private func handlePauseSuggestionsUntilTomorrow() { send(.pauseSuggestionsUntilTomorrow) }
    @objc private func handleToggleCurrentApp() { send(.toggleCurrentApp) }
    @objc private func handleSilenceCurrentField() { send(.silenceCurrentField) }
    @objc private func handleShowSettings() { send(.showSettings) }
    @objc private func handleOpenFeedbackForm() { send(.openFeedbackForm) }
    @objc private func handleRevealModelFolder() { send(.revealModelFolder) }
    @objc private func handleNudgeSuggestionUp() { send(.nudgeSuggestionUp) }
    @objc private func handleNudgeSuggestionDown() { send(.nudgeSuggestionDown) }
    @objc private func handleNudgeSuggestionLeft() { send(.nudgeSuggestionLeft) }
    @objc private func handleNudgeSuggestionRight() { send(.nudgeSuggestionRight) }
    @objc private func handleResetCurrentAppLearning() { send(.resetCurrentAppLearning) }
    @objc private func handleQuit() { send(.quit) }
}
