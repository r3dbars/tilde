import AppKit
import AutocompleteLabCore
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bar.r3d.autocomplete-lab",
        category: "Autocomplete"
    )

    private let accessibilityClient = AccessibilityClient()
    private let allowlist = AppAllowlist.default
    private let settings = AppSettings()
    private let keyboardRouter = KeyboardActionRouter()
    private let suggestionPanel = SuggestionPanelController()

    private lazy var engine: any CompletionEngine = makeCompletionEngine()

    private var statusItem: NSStatusItem?
    private var suggestionsEnabledItem: NSMenuItem?
    private var allowlistItem: NSMenuItem?
    private var secureFieldsItem: NSMenuItem?
    private var shortTextItem: NSMenuItem?
    private var afterNewlineItem: NSMenuItem?
    private var gemmaRuntimeItem: NSMenuItem?
    private var mockRuntimeItem: NSMenuItem?
    private var runtimeStatusItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastTextElementRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastTextBeforeCursor = ""
    private var lastStatusSummary = ""
    private var suggestionTask: Task<Void, Never>?
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        accessibilityClient.requestPermissionIfNeeded()
        startKeyboardEventTapIfPossible()
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        suggestionTask?.cancel()
        pollTimer?.invalidate()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Autocomplete"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Transcripted Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let suggestionsEnabledItem = NSMenuItem(
            title: "Enable Suggestions",
            action: #selector(toggleSuggestionsEnabled),
            keyEquivalent: ""
        )
        menu.addItem(suggestionsEnabledItem)
        self.suggestionsEnabledItem = suggestionsEnabledItem

        let privacyMenu = NSMenu()
        let allowlistItem = NSMenuItem(
            title: "Only Allowed Apps",
            action: #selector(toggleAllowlist),
            keyEquivalent: ""
        )
        privacyMenu.addItem(allowlistItem)
        self.allowlistItem = allowlistItem

        let secureFieldsItem = NSMenuItem(
            title: "Hide In Secure Fields",
            action: #selector(toggleSecureFieldSuppression),
            keyEquivalent: ""
        )
        privacyMenu.addItem(secureFieldsItem)
        self.secureFieldsItem = secureFieldsItem

        let shortTextItem = NSMenuItem(
            title: "Wait For 3+ Characters",
            action: #selector(toggleShortTextSuppression),
            keyEquivalent: ""
        )
        privacyMenu.addItem(shortTextItem)
        self.shortTextItem = shortTextItem

        let afterNewlineItem = NSMenuItem(
            title: "Hide Right After Newline",
            action: #selector(toggleAfterNewlineSuppression),
            keyEquivalent: ""
        )
        privacyMenu.addItem(afterNewlineItem)
        self.afterNewlineItem = afterNewlineItem

        let privacyItem = NSMenuItem(title: "Privacy", action: nil, keyEquivalent: "")
        privacyItem.submenu = privacyMenu
        menu.addItem(privacyItem)

        let runtimeMenu = NSMenu()
        let gemmaRuntimeItem = NSMenuItem(
            title: AppSettings.RuntimeMode.gemmaLocalWithMockFallback.menuTitle,
            action: #selector(selectGemmaRuntime),
            keyEquivalent: ""
        )
        runtimeMenu.addItem(gemmaRuntimeItem)
        self.gemmaRuntimeItem = gemmaRuntimeItem

        let mockRuntimeItem = NSMenuItem(
            title: AppSettings.RuntimeMode.mockOnly.menuTitle,
            action: #selector(selectMockRuntime),
            keyEquivalent: ""
        )
        runtimeMenu.addItem(mockRuntimeItem)
        self.mockRuntimeItem = mockRuntimeItem

        runtimeMenu.addItem(NSMenuItem.separator())
        let runtimeStatusItem = NSMenuItem(title: "Runtime: Checking...", action: nil, keyEquivalent: "")
        runtimeMenu.addItem(runtimeStatusItem)
        self.runtimeStatusItem = runtimeStatusItem

        let runtimeItem = NSMenuItem(title: "Runtime", action: nil, keyEquivalent: "")
        runtimeItem.submenu = runtimeMenu
        menu.addItem(runtimeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        refreshStatusMenu()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedText()
            }
        }
    }

    private func pollFocusedText() {
        refreshStatusMenu()

        guard settings.suggestionsEnabled else {
            updateStatus("suggestions disabled")
            hideSuggestion()
            return
        }

        guard accessibilityClient.isTrusted else {
            updateStatus("accessibility not trusted")
            hideSuggestion()
            return
        }

        startKeyboardEventTapIfPossible()

        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            updateStatus("no frontmost app")
            hideSuggestion()
            return
        }

        guard let context = accessibilityClient.focusedTextContext() else {
            updateStatus("no focused text context")
            hideSuggestion()
            return
        }

        let privacyPolicy = SuggestionPrivacyPolicy(
            settings: settings.privacySettings(allowedBundleIdentifiers: allowlist.bundleIdentifiers)
        )
        let privacyDecision = privacyPolicy.decision(
            for: FocusedSuggestionPrivacyContext(
                bundleIdentifier: frontmostApp.bundleIdentifier,
                textBeforeCursor: context.textBeforeCursor,
                isSecureTextEntry: context.isSecure
            )
        )
        guard privacyDecision.shouldRequestSuggestion else {
            updateStatus("suppressed: \(privacyDecision.suppressionReason?.debugLabel ?? "unknown")")
            hideSuggestion()
            return
        }

        guard context.textBeforeCursor != lastTextBeforeCursor else {
            return
        }

        lastTextBeforeCursor = context.textBeforeCursor
        suggestionTask?.cancel()
        updateStatus("requesting suggestion via \(settings.runtimeMode.menuTitle)")

        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )

        let activeEngine = engine
        suggestionTask = Task { [activeEngine, suggestionPanel] in
            do {
                let suggestion = try await activeEngine.suggestion(for: request)
                await MainActor.run {
                    guard let suggestion, !suggestion.isEmpty, let caretRect = context.caretRect else {
                        self.updateStatus("engine returned no visible suggestion")
                        self.hideSuggestion()
                        return
                    }

                    self.updateStatus("showing suggestion")
                    self.suggestionSession.present(suggestion)
                    self.lastCaretRect = caretRect
                    self.lastTextLineRect = context.textLineRect
                    self.lastTextElementRect = context.textElementRect
                    self.lastTextStyle = context.textStyle
                    suggestionPanel.show(
                        text: suggestion.visibleText,
                        near: caretRect,
                        alignedTo: context.textLineRect,
                        boundedBy: context.textElementRect,
                        style: context.textStyle
                    )
                }
            } catch {
                await MainActor.run {
                    self.hideSuggestion()
                }
            }
        }
    }

    private func startKeyboardEventTapIfPossible() {
        guard keyboardEventTap == nil, accessibilityClient.isTrusted else {
            return
        }

        let eventTap = KeyboardEventTap { [weak self] key in
            var handled = false

            if Thread.isMainThread {
                handled = MainActor.assumeIsolated {
                    self?.handleAutocompleteKey(key) ?? false
                }
            } else {
                DispatchQueue.main.sync {
                    handled = MainActor.assumeIsolated {
                        self?.handleAutocompleteKey(key) ?? false
                    }
                }
            }

            return handled
        }

        if eventTap.start() {
            keyboardEventTap = eventTap
        }
    }

    private func handleAutocompleteKey(_ key: AutocompleteKey) -> Bool {
        if shouldSuppressKey(key) {
            return true
        }

        let hasVisibleSuggestion = suggestionSession.hasVisibleSuggestion
        let action = keyboardRouter.action(
            for: key,
            hasVisibleSuggestion: hasVisibleSuggestion
        )

        if key != .other {
            let visibleLabel = hasVisibleSuggestion ? "yes" : "no"
            logger.info("Autocomplete key: \(key.debugLabel, privacy: .public), visible: \(visibleLabel, privacy: .public), action: \(action.debugLabel, privacy: .public)")
        }

        switch action {
        case .acceptNextWord:
            guard let acceptedText = suggestionSession.acceptNextWord() else {
                logger.info("Autocomplete accept failed: no next word")
                return false
            }

            guard accessibilityClient.insertText(acceptedText) else {
                logger.info("Autocomplete accept failed: insertion unavailable")
                return false
            }

            refreshVisibleSuggestion()
            suppressKey(key)
            logger.info("Autocomplete accept succeeded: next word")
            return true

        case .acceptAllVisible:
            guard let acceptedText = suggestionSession.acceptAllVisible() else {
                logger.info("Autocomplete accept failed: no visible text")
                return false
            }

            guard accessibilityClient.insertText(acceptedText) else {
                logger.info("Autocomplete accept failed: insertion unavailable")
                return false
            }

            hideSuggestion()
            suppressKey(key)
            logger.info("Autocomplete accept succeeded: all visible")
            return true

        case .dismiss:
            hideSuggestion()
            suppressKey(key)
            return true

        case .passThrough:
            return false
        }
    }

    private func shouldSuppressKey(_ key: AutocompleteKey) -> Bool {
        guard let until = suppressKeyUntil[key] else {
            return false
        }

        if until > Date() {
            return true
        }

        suppressKeyUntil[key] = nil
        return false
    }

    private func suppressKey(_ key: AutocompleteKey) {
        suppressKeyUntil[key] = Date().addingTimeInterval(0.25)
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        suggestionPanel.show(
            text: suggestion.visibleText,
            near: caretRect,
            alignedTo: lastTextLineRect,
            boundedBy: lastTextElementRect,
            style: lastTextStyle
        )
    }

    private func hideSuggestion() {
        suggestionSession.dismiss()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastTextElementRect = nil
        lastTextStyle = nil
        suggestionPanel.hide()
    }

    private func updateStatus(_ summary: String) {
        guard summary != lastStatusSummary else {
            return
        }

        lastStatusSummary = summary
        logger.info("Autocomplete state: \(summary, privacy: .public)")
    }

    private func refreshStatusMenu() {
        suggestionsEnabledItem?.state = settings.suggestionsEnabled ? .on : .off
        allowlistItem?.state = settings.enforceAllowlist ? .on : .off
        secureFieldsItem?.state = settings.suppressSecureFields ? .on : .off
        shortTextItem?.state = settings.suppressShortText ? .on : .off
        afterNewlineItem?.state = settings.suppressAfterNewline ? .on : .off
        gemmaRuntimeItem?.state = settings.runtimeMode == .gemmaLocalWithMockFallback ? .on : .off
        mockRuntimeItem?.state = settings.runtimeMode == .mockOnly ? .on : .off

        if settings.runtimeMode == .mockOnly {
            runtimeStatusItem?.title = "Runtime: Mock only"
        } else if completionEngineFactory().selection() == .localGemma4E2B {
            runtimeStatusItem?.title = "Runtime: Gemma bridge ready"
        } else {
            runtimeStatusItem?.title = "Runtime: Mock fallback"
        }
    }

    private func makeCompletionEngine() -> any CompletionEngine {
        switch settings.runtimeMode {
        case .mockOnly:
            return MockCompletionEngine()
        case .gemmaLocalWithMockFallback:
            return completionEngineFactory().makeEngine()
        }
    }

    private func completionEngineFactory() -> CompletionEngineFactory {
        CompletionEngineFactory(
            runtimeExecutableURL: bundledRuntimeExecutableURL(),
            runtimeEnvironment: runtimeEnvironment()
        )
    }

    private func bundledRuntimeExecutableURL() -> URL? {
        Bundle.main.url(forResource: "local_completion_runtime", withExtension: "py")
    }

    private func runtimeEnvironment() -> [String: String] {
        let bundleURL = Bundle.main.bundleURL
        let repoRoot = bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return [
            "AUTOCOMPLETE_LAB_REPO_ROOT": repoRoot.path
        ]
    }

    @objc
    private func toggleSuggestionsEnabled() {
        settings.toggleSuggestionsEnabled()
        refreshStatusMenu()
        if !settings.suggestionsEnabled {
            hideSuggestion()
        }
    }

    @objc
    private func toggleAllowlist() {
        settings.toggleAllowlist()
        refreshStatusMenu()
    }

    @objc
    private func toggleSecureFieldSuppression() {
        settings.toggleSecureFieldSuppression()
        refreshStatusMenu()
    }

    @objc
    private func toggleShortTextSuppression() {
        settings.toggleShortTextSuppression()
        refreshStatusMenu()
    }

    @objc
    private func toggleAfterNewlineSuppression() {
        settings.toggleAfterNewlineSuppression()
        refreshStatusMenu()
    }

    @objc
    private func selectGemmaRuntime() {
        settings.runtimeMode = .gemmaLocalWithMockFallback
        engine = makeCompletionEngine()
        hideSuggestion()
        refreshStatusMenu()
    }

    @objc
    private func selectMockRuntime() {
        settings.runtimeMode = .mockOnly
        engine = makeCompletionEngine()
        hideSuggestion()
        refreshStatusMenu()
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private extension AutocompleteKey {
    var debugLabel: String {
        switch self {
        case .tab:
            return "tab"
        case .backtick:
            return "backtick"
        case .escape:
            return "escape"
        case .other:
            return "other"
        }
    }
}

private extension KeyboardAction {
    var debugLabel: String {
        switch self {
        case .acceptNextWord:
            return "accept next word"
        case .acceptAllVisible:
            return "accept all visible"
        case .dismiss:
            return "dismiss"
        case .passThrough:
            return "pass through"
        }
    }
}

private extension SuggestionSuppressionReason {
    var debugLabel: String {
        switch self {
        case .missingBundleIdentifier:
            return "missing bundle identifier"
        case .bundleIdentifierNotAllowed(let bundleIdentifier):
            return "bundle identifier not allowed: \(bundleIdentifier)"
        case .secureTextEntry:
            return "secure text entry"
        case .emptyText:
            return "empty text"
        case .afterNewline:
            return "after newline"
        case .belowMinimumCharacters:
            return "below minimum characters"
        }
    }
}
