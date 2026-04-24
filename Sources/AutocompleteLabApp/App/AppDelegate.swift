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
    private let compatibilityRouter = CompatibilityRouter()
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
    private var copyDiagnosticsItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastTextElementRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastAppBundleIdentifier: String?
    private var lastAppProcessIdentifier: pid_t?
    private var lastPlacementContextUpdatedAt: Date?
    private var lastTextBeforeCursor = ""
    private var lastSuggestionRequestSignature: SuggestionRequestSignature?
    private var lastCompatibilityDecision: CompatibilityDecision?
    private var suggestionRequestGeneration = 0
    private var lastStatusSummary = ""
    private var lastPlacementDiagnostics = "No geometry diagnostics yet."
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

        let copyDiagnosticsItem = NSMenuItem(
            title: "Copy Last Geometry Diagnostics",
            action: #selector(copyLastGeometryDiagnostics),
            keyEquivalent: ""
        )
        menu.addItem(copyDiagnosticsItem)
        self.copyDiagnosticsItem = copyDiagnosticsItem

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
            if preserveVisibleSuggestionDuringTransientFocusLoss(summary: "no frontmost app", frontmostApp: nil) {
                return
            }

            updateStatus("no frontmost app")
            hideSuggestion()
            return
        }

        guard let context = accessibilityClient.focusedTextContext() else {
            if preserveVisibleSuggestionDuringTransientFocusLoss(summary: "no focused text context", frontmostApp: frontmostApp) {
                return
            }

            updateStatus("no focused text context")
            hideSuggestion()
            return
        }

        let compatibilityDecision = compatibilityDecision(for: context, app: frontmostApp)
        guard compatibilityDecision.shouldRequestSuggestion else {
            updateStatus("suppressed: \(compatibilityDecision.suppressionReason?.debugLabel ?? "unknown")")
            hideSuggestion()
            return
        }

        let requestSignature = SuggestionRequestSignature(context: context, app: frontmostApp)
        guard requestSignature != lastSuggestionRequestSignature else {
            if suggestionSession.hasVisibleSuggestion, context.caretRect != nil {
                cachePlacementContext(context, app: frontmostApp)
                refreshVisibleSuggestion()
            }
            return
        }

        lastTextBeforeCursor = context.textBeforeCursor
        suggestionTask?.cancel()
        suggestionRequestGeneration += 1
        lastSuggestionRequestSignature = requestSignature
        lastCompatibilityDecision = compatibilityDecision
        let requestGeneration = suggestionRequestGeneration
        hideSuggestion(clearLastTextBeforeCursor: false)
        updateStatus("requesting suggestion via \(settings.runtimeMode.menuTitle) \(compatibilityDecision.profile.id)")

        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )

        let activeEngine = engine
        suggestionTask = Task { [activeEngine, suggestionPanel] in
            do {
                let suggestion = try await activeEngine.suggestion(for: request)
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard let currentContext = self.currentFocusedContext(
                        for: requestSignature,
                        generation: requestGeneration
                    ) else {
                        self.updateStatus("dropped stale suggestion")
                        return
                    }

                    let currentCompatibilityDecision = self.compatibilityDecision(
                        for: currentContext,
                        app: frontmostApp
                    )
                    guard currentCompatibilityDecision.shouldRequestSuggestion else {
                        self.updateStatus("dropped unsupported suggestion: \(currentCompatibilityDecision.suppressionReason?.debugLabel ?? "unknown")")
                        self.hideSuggestion(clearLastTextBeforeCursor: false)
                        return
                    }

                    guard let suggestion, !suggestion.isEmpty, let caretRect = currentContext.caretRect else {
                        self.updateStatus("engine returned no visible suggestion")
                        self.hideSuggestion(clearLastTextBeforeCursor: false)
                        return
                    }

                    self.updateStatus("showing suggestion")
                    self.lastCompatibilityDecision = currentCompatibilityDecision
                    self.suggestionSession.present(suggestion)
                    self.lastCaretRect = caretRect
                    self.cachePlacementContext(currentContext, app: frontmostApp)
                    let decision = suggestionPanel.show(
                        text: suggestion.visibleText,
                        appBundleIdentifier: frontmostApp.bundleIdentifier,
                        near: caretRect,
                        alignedTo: currentContext.textLineRect,
                        boundedBy: currentContext.textElementRect,
                        style: currentContext.textStyle
                    )
                    if decision?.strategy == .hiddenNoRoom {
                        self.suggestionSession.dismiss()
                    }
                    self.recordPlacementDiagnostics(
                        decision,
                        app: frontmostApp,
                        context: currentContext
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard self.suggestionRequestGeneration == requestGeneration else {
                        return
                    }

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
            guard let compatibilityDecision = lastCompatibilityDecision,
                  compatibilityDecision.canAcceptSuggestion else {
                hideSuggestion(clearLastTextBeforeCursor: false)
                logger.info("Autocomplete accept unavailable for current compatibility rung")
                return false
            }

            guard isCurrentAppStillSuggestionTarget() else {
                hideSuggestion()
                suppressKey(key)
                logger.info("Autocomplete accept blocked: focus changed")
                return true
            }

            guard let suggestion = suggestionSession.visibleSuggestion else {
                logger.info("Autocomplete accept failed: no next word")
                return false
            }

            let acceptedText = suggestion.acceptedPrefix(wordLimit: 1)
            guard !acceptedText.isEmpty else {
                logger.info("Autocomplete accept failed: empty next word")
                return false
            }

            guard accessibilityClient.insertText(
                acceptedText,
                allowClipboardFallback: compatibilityDecision.allowsClipboardFallback
            ) else {
                logger.info("Autocomplete accept failed: insertion unavailable")
                hideSuggestion(clearLastTextBeforeCursor: false)
                suppressKey(key)
                return true
            }

            _ = suggestionSession.acceptNextWord()
            refreshCachedPlacementContextFromFocusedText()
            refreshVisibleSuggestion()
            suppressKey(key)
            logger.info("Autocomplete accept succeeded: next word")
            return true

        case .acceptAllVisible:
            guard let compatibilityDecision = lastCompatibilityDecision,
                  compatibilityDecision.canAcceptSuggestion else {
                hideSuggestion(clearLastTextBeforeCursor: false)
                logger.info("Autocomplete accept unavailable for current compatibility rung")
                return false
            }

            guard isCurrentAppStillSuggestionTarget() else {
                hideSuggestion()
                suppressKey(key)
                logger.info("Autocomplete accept blocked: focus changed")
                return true
            }

            guard let suggestion = suggestionSession.visibleSuggestion else {
                logger.info("Autocomplete accept failed: no visible text")
                return false
            }

            let acceptedText = suggestion.visibleText
            guard !acceptedText.isEmpty else {
                logger.info("Autocomplete accept failed: empty visible text")
                return false
            }

            guard accessibilityClient.insertText(
                acceptedText,
                allowClipboardFallback: compatibilityDecision.allowsClipboardFallback
            ) else {
                logger.info("Autocomplete accept failed: insertion unavailable")
                hideSuggestion(clearLastTextBeforeCursor: false)
                suppressKey(key)
                return true
            }

            _ = suggestionSession.acceptAllVisible()
            hideSuggestion()
            suppressKey(key)
            logger.info("Autocomplete accept succeeded: all visible")
            return true

        case .dismiss:
            hideSuggestion(clearLastTextBeforeCursor: false)
            suppressKey(key)
            return true

        case .passThrough:
            if key == .other, suggestionSession.hasVisibleSuggestion || suggestionTask != nil {
                hideSuggestion()
            }

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

        let decision = suggestionPanel.show(
            text: suggestion.visibleText,
            appBundleIdentifier: lastAppBundleIdentifier,
            near: caretRect,
            alignedTo: lastTextLineRect,
            boundedBy: lastTextElementRect,
            style: lastTextStyle
        )
        if decision?.strategy == .hiddenNoRoom {
            suggestionSession.dismiss()
        }
    }

    private func hideSuggestion(clearLastTextBeforeCursor: Bool = true) {
        if clearLastTextBeforeCursor {
            suggestionTask?.cancel()
            suggestionRequestGeneration += 1
            lastSuggestionRequestSignature = nil
            lastCompatibilityDecision = nil
        }

        suggestionSession.dismiss()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastTextElementRect = nil
        lastTextStyle = nil
        lastAppBundleIdentifier = nil
        lastAppProcessIdentifier = nil
        lastPlacementContextUpdatedAt = nil
        if clearLastTextBeforeCursor {
            lastTextBeforeCursor = ""
        }
        suggestionPanel.hide()
    }

    private func compatibilityDecision(
        for context: FocusedTextContext,
        app: RunningApplicationInfo
    ) -> CompatibilityDecision {
        compatibilityRouter.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: app.bundleIdentifier,
                elementRole: context.elementRole,
                elementSubrole: context.elementSubrole,
                isSecureTextEntry: context.isSecure,
                textBeforeCursor: context.textBeforeCursor,
                hasCaretRect: context.caretRect != nil
            ),
            settings: settings.compatibilityRoutingSettings()
        )
    }

    private func currentFocusedContext(
        for signature: SuggestionRequestSignature,
        generation: Int
    ) -> FocusedTextContext? {
        guard generation == suggestionRequestGeneration,
              lastSuggestionRequestSignature == signature,
              let currentApp = accessibilityClient.frontmostApplication(),
              currentApp.processIdentifier == signature.processIdentifier,
              let currentContext = accessibilityClient.focusedTextContext(),
              SuggestionRequestSignature(context: currentContext, app: currentApp) == signature else {
            return nil
        }

        return currentContext
    }

    private func cachePlacementContext(
        _ context: FocusedTextContext,
        app: RunningApplicationInfo
    ) {
        lastCaretRect = context.caretRect
        lastTextLineRect = context.textLineRect
        lastTextElementRect = context.textElementRect
        lastTextStyle = context.textStyle
        lastAppBundleIdentifier = app.bundleIdentifier
        lastAppProcessIdentifier = app.processIdentifier
        lastPlacementContextUpdatedAt = Date()
    }

    private func isCurrentAppStillSuggestionTarget() -> Bool {
        guard let expectedProcessIdentifier = lastAppProcessIdentifier,
              let currentApp = accessibilityClient.frontmostApplication() else {
            return false
        }

        return currentApp.processIdentifier == expectedProcessIdentifier
    }

    private func refreshCachedPlacementContextFromFocusedText() {
        guard let expectedProcessIdentifier = lastAppProcessIdentifier,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.processIdentifier == expectedProcessIdentifier,
              let context = accessibilityClient.focusedTextContext() else {
            return
        }

        cachePlacementContext(context, app: frontmostApp)
        lastTextBeforeCursor = context.textBeforeCursor
    }

    private func preserveVisibleSuggestionDuringTransientFocusLoss(
        summary: String,
        frontmostApp: RunningApplicationInfo?
    ) -> Bool {
        guard suggestionSession.hasVisibleSuggestion,
              let updatedAt = lastPlacementContextUpdatedAt,
              Date().timeIntervalSince(updatedAt) <= 1.5 else {
            return false
        }

        if let expectedProcessIdentifier = lastAppProcessIdentifier,
           let frontmostApp,
           frontmostApp.processIdentifier != expectedProcessIdentifier {
            return false
        }

        updateStatus("\(summary) (holding visible suggestion)")
        return true
    }

    private func recordPlacementDiagnostics(
        _ decision: InlineGhostPlacementDecision?,
        app: RunningApplicationInfo,
        context: FocusedTextContext
    ) {
        guard let decision else {
            lastPlacementDiagnostics = diagnosticReport(
                app: app,
                context: context,
                placementSummary: "hidden before placement"
            )
            return
        }

        lastPlacementDiagnostics = diagnosticReport(
            app: app,
            context: context,
            placementSummary: decision.debugSummary
        )
        logger.info("Autocomplete placement: \(decision.debugSummary, privacy: .public)")
    }

    private func diagnosticReport(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        placementSummary: String
    ) -> String {
        """
        Autocomplete geometry diagnostics
        time: \(ISO8601DateFormatter().string(from: Date()))
        app: \(app.localizedName)
        bundleIdentifier: \(app.bundleIdentifier)
        pid: \(app.processIdentifier)
        role: \(context.elementRole ?? "unknown")
        subrole: \(context.elementSubrole ?? "unknown")
        secureTextEntry: \(context.isSecure)
        textBeforeCursorUTF16Length: \(context.textBeforeCursor.utf16.count)
        textAfterCursorUTF16Length: \(context.textAfterCursor.utf16.count)
        selectedRange: \(context.diagnostics.selectedRangeLocation.map(String.init) ?? "nil"):\(context.diagnostics.selectedRangeLength.map(String.init) ?? "nil")
        textLengthUTF16: \(context.diagnostics.textLengthUTF16)
        caretAX: \(context.caretRect?.diagnosticDescription ?? "nil")
        textLineAX: \(context.textLineRect?.diagnosticDescription ?? "nil")
        textElementAX: \(context.textElementRect?.diagnosticDescription ?? "nil")
        font: \(context.textStyle?.fontName ?? "unknown")
        fontSize: \(context.textStyle.map { String(format: "%.1f", Double($0.fontSize)) } ?? "unknown")
        compatibility: \(lastCompatibilityDecision?.debugLabel ?? "unknown")
        placement: \(placementSummary)
        supportedAttributes: \(context.diagnostics.supportedAttributes.joined(separator: ", "))
        supportedParameterizedAttributes: \(context.diagnostics.supportedParameterizedAttributes.joined(separator: ", "))
        """
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
        copyDiagnosticsItem?.isEnabled = !lastPlacementDiagnostics.isEmpty

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
            "AUTOCOMPLETE_LAB_REPO_ROOT": repoRoot.path,
            "AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT": String(
                format: "%.2f",
                Double(CompletionModelPolicy.mvp.targetLatencyMilliseconds) / 1_000
            )
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
    private func copyLastGeometryDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastPlacementDiagnostics, forType: .string)
        updateStatus("copied geometry diagnostics")
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private struct SuggestionRequestSignature: Equatable {
    let processIdentifier: pid_t
    let textBeforeCursor: String
    let textAfterCursor: String

    init(context: FocusedTextContext, app: RunningApplicationInfo) {
        processIdentifier = app.processIdentifier
        textBeforeCursor = context.textBeforeCursor
        textAfterCursor = context.textAfterCursor
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
