import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let profileStore = CompatibilityProfileStore.mvp
    private let activationPolicy = CompletionActivationPolicy()
    private let triggerPolicy = SuggestionTriggerPolicy()
    private let engine = MockCompletionEngine()
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardRouter = KeyboardActionRouter()
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let suggestionPanel = SuggestionPanelController()
    private let diagnosticsWindow = DiagnosticsWindowController()
    private lazy var settingsWindow = SettingsWindowController { [weak self] in
        self?.requestAccessibilityPermission()
    }

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastRequestedTextBeforeCursor: String?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var suggestionTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var lastStatusLine: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        DiagnosticsLog.shared.record("launch", metadata: ["accessibility": String(accessibilityClient.isTrusted)])
        accessibilityClient.requestPermissionIfNeeded()
        if !accessibilityClient.isTrusted {
            settingsWindow.show(isTrusted: false)
        }
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        debounceTask?.cancel()
        suggestionTask?.cancel()
        pollTimer?.invalidate()
        stopKeyboardEventTapIfActive()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Autocomplete"

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "Status: starting", action: nil, keyEquivalent: "")
        let toggleItem = NSMenuItem(title: "Toggle Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")

        menu.addItem(NSMenuItem(title: "Transcripted Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(statusMenu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Show Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "d"))
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        statusMenuItem = statusMenu
        toggleAppMenuItem = toggleItem
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedText()
            }
        }
    }

    private func pollFocusedText() {
        guard accessibilityClient.isTrusted else {
            updateStatusMenu(app: nil, profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = profileStore.profile(for: frontmostApp.bundleIdentifier) else {
            clearFocusedFieldState()
            currentProfile = nil
            updateStatusMenu(app: accessibilityClient.frontmostApplication(), profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        let appEnabled = !disabledBundleIdentifiers.contains(frontmostApp.bundleIdentifier)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, profile: profile, appEnabled: appEnabled)

        guard appEnabled else {
            clearFocusedFieldState()
            hideSuggestion()
            return
        }

        guard let context = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ), !context.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            hideSuggestion()
            return
        }

        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            processIdentifier: frontmostApp.processIdentifier,
            elementIdentifier: context.elementIdentifier
        )
        transitionToField(fieldIdentity)

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != lastTextSnapshot else {
            return
        }

        lastTextSnapshot = snapshot
        debounceTask?.cancel()
        suggestionTask?.cancel()

        guard activationPolicy.canSuggest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity)
        ) else {
            hideSuggestion()
            return
        }

        guard context.capabilities.supportsInlineSuggestions || profile.renderMode == .floatingMirror else {
            hideSuggestion()
            return
        }

        guard triggerPolicy.shouldRequestSuggestion(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor
        ) else {
            return
        }

        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )
    }

    private func startKeyboardEventTapIfPossible() {
        guard keyboardCapturePolicy.shouldCaptureKeys(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        ), keyboardEventTap == nil else {
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
            DiagnosticsLog.shared.record("keyboard-event-tap-started")
        }
    }

    private func stopKeyboardEventTapIfActive() {
        guard let keyboardEventTap else {
            return
        }

        keyboardEventTap.stop()
        self.keyboardEventTap = nil
        DiagnosticsLog.shared.record("keyboard-event-tap-stopped")
    }

    private func handleAutocompleteKey(_ key: AutocompleteKey) -> Bool {
        if shouldSuppressKey(key) {
            return true
        }

        let action = keyboardRouter.action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )

        switch action {
        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                return false
            }

            guard let acceptedText = suggestionSession.acceptNextWord(),
                  insertAcceptedText(acceptedText) else {
                return false
            }

            recordAcceptedText(acceptedText)
            refreshVisibleSuggestion()
            suppressKey(key)
            return true

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                return false
            }

            guard let acceptedText = suggestionSession.acceptAllVisible(),
                  insertAcceptedText(acceptedText) else {
                return false
            }

            recordAcceptedText(acceptedText)
            hideSuggestion()
            suppressKey(key)
            return true

        case .dismiss:
            suppressCurrentField()
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

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String
    ) {
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: appBundleIdentifier
        )

        debounceTask = Task { [engine] in
            try? await Task.sleep(for: .milliseconds(profile.renderMode == .inlineAdjacent ? 80 : 120))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await engine.suggestion(for: request)
                await MainActor.run {
                    let anchorRect = context.caretRect ?? (profile.renderMode == .floatingMirror ? context.elementRect ?? context.windowRect : nil)
                    guard let suggestion, !suggestion.isEmpty, let anchorRect else {
                        self.hideSuggestion()
                        return
                    }

                    self.suggestionSession.present(suggestion)
                    self.lastCaretRect = anchorRect
                    self.lastTextLineRect = context.textLineRect
                    self.lastTextStyle = context.textStyle
                    self.lastRenderMode = profile.renderMode
                    self.suggestionPanel.show(
                        text: suggestion.visibleText,
                        near: anchorRect,
                        alignedTo: profile.renderMode == .inlineAdjacent ? context.textLineRect : nil,
                        style: context.textStyle,
                        renderMode: profile.renderMode
                    )
                    self.startKeyboardEventTapIfPossible()
                }
            } catch {
                await MainActor.run {
                    self.hideSuggestion()
                }
            }
        }
    }

    private func insertAcceptedText(_ acceptedText: String) -> Bool {
        guard let profile = currentProfile else {
            return accessibilityClient.insertText(acceptedText)
        }

        let result = insertionEngine.insert(acceptedText, profile: profile)
        DiagnosticsLog.shared.record(
            "insert",
            metadata: [
                "app": profile.bundleIdentifier,
                "mode": result.mode.rawValue,
                "success": String(result.succeeded)
            ]
        )

        return result.succeeded
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
            style: lastTextStyle,
            renderMode: lastRenderMode ?? .inlineAdjacent
        )
    }

    private func recordAcceptedText(_ acceptedText: String) {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return
        }

        self.lastTextSnapshot = FocusedTextSnapshot(
            fieldIdentity: currentFieldIdentity,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor + acceptedText,
            textAfterCursor: lastTextSnapshot.textAfterCursor
        )
    }

    private func hideSuggestion() {
        suggestionSession.dismiss()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastTextStyle = nil
        lastRenderMode = nil
        suggestionPanel.hide()
        stopKeyboardEventTapIfActive()
    }

    private func updateStatusMenu(
        app: RunningApplicationInfo?,
        profile: CompatibilityProfile?,
        appEnabled: Bool
    ) {
        let permission = accessibilityClient.isTrusted ? "AX ok" : "AX missing"
        let appName = app?.localizedName ?? "No app"
        let profileName = profile?.displayName ?? "unsupported"
        let enabled = appEnabled ? "on" : "off"
        let statusLine = "Status: \(permission) | \(appName) | \(profileName) | \(enabled)"

        statusMenuItem?.title = statusLine
        toggleAppMenuItem?.title = app.map { appEnabled ? "Disable \($0.localizedName)" : "Enable \($0.localizedName)" } ?? "Toggle Current App"
        settingsWindow.refresh(isTrusted: accessibilityClient.isTrusted)

        guard lastStatusLine != statusLine else {
            return
        }

        lastStatusLine = statusLine
        DiagnosticsLog.shared.record(
            "status",
            metadata: [
                "accessibility": permission,
                "app": appName,
                "profile": profileName,
                "enabled": enabled
            ]
        )
    }

    private func suppressCurrentField() {
        guard currentProfile?.suppressesUntilBlurAfterEscape == true,
              let currentFieldIdentity else {
            return
        }

        suppressedFieldIdentities.insert(currentFieldIdentity)
    }

    private func transitionToField(_ fieldIdentity: FocusedFieldIdentity) {
        guard currentFieldIdentity != fieldIdentity else {
            return
        }

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
        }

        currentFieldIdentity = fieldIdentity
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
    }

    private func clearFocusedFieldState() {
        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
        settingsWindow.refresh(isTrusted: accessibilityClient.isTrusted)
        DiagnosticsLog.shared.record("request-accessibility")
    }

    @objc
    private func showSettings() {
        settingsWindow.show(isTrusted: accessibilityClient.isTrusted)
    }

    @objc
    private func showDiagnostics() {
        let app = accessibilityClient.frontmostApplication()
        let profile = app.flatMap { profileStore.profile(for: $0.bundleIdentifier) }
        let appEnabled = app.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false

        diagnosticsWindow.show(
            diagnostics: accessibilityClient.focusedTextDiagnostics(
                allowDescendantTextFallback: profile?.allowsDescendantTextFallback == true
            ),
            profile: profile,
            appEnabled: appEnabled,
            appTrusted: accessibilityClient.isTrusted
        )
    }

    @objc
    private func toggleCurrentApp() {
        guard let app = accessibilityClient.frontmostApplication(),
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        if disabledBundleIdentifiers.contains(app.bundleIdentifier) {
            disabledBundleIdentifiers.remove(app.bundleIdentifier)
        } else {
            disabledBundleIdentifiers.insert(app.bundleIdentifier)
            hideSuggestion()
        }

        updateStatusMenu(
            app: app,
            profile: profileStore.profile(for: app.bundleIdentifier),
            appEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        )
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private struct FocusedFieldIdentity: Equatable, Hashable {
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let elementIdentifier: Int
}

private struct FocusedTextSnapshot: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let textBeforeCursor: String
    let textAfterCursor: String
}
