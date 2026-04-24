import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let allowlist = AppAllowlist.default
    private let engine = MockCompletionEngine()
    private let keyboardRouter = KeyboardActionRouter()
    private let suggestionPanel = SuggestionPanelController()

    private var statusItem: NSStatusItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextBeforeCursor = ""
    private var suggestionTask: Task<Void, Never>?

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
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
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
            hideSuggestion()
            return
        }

        startKeyboardEventTapIfPossible()

        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              allowlist.allows(bundleIdentifier: frontmostApp.bundleIdentifier) else {
            hideSuggestion()
            return
        }

        guard let context = accessibilityClient.focusedTextContext(), !context.isSecure else {
            hideSuggestion()
            return
        }

        guard context.textBeforeCursor != lastTextBeforeCursor else {
            return
        }

        lastTextBeforeCursor = context.textBeforeCursor
        suggestionTask?.cancel()

        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )

        suggestionTask = Task { [engine, suggestionPanel] in
            do {
                let suggestion = try await engine.suggestion(for: request)
                await MainActor.run {
                    guard let suggestion, !suggestion.isEmpty, let caretRect = context.caretRect else {
                        self.hideSuggestion()
                        return
                    }

                    self.suggestionSession.present(suggestion)
                    self.lastCaretRect = caretRect
                    suggestionPanel.show(text: suggestion.visibleText, near: caretRect)
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
        let action = keyboardRouter.action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )

        switch action {
        case .acceptNextWord:
            guard let acceptedText = suggestionSession.acceptNextWord(),
                  accessibilityClient.insertText(acceptedText) else {
                return false
            }

            refreshVisibleSuggestion()
            return true

        case .acceptAllVisible:
            guard let acceptedText = suggestionSession.acceptAllVisible(),
                  accessibilityClient.insertText(acceptedText) else {
                return false
            }

            hideSuggestion()
            return true

        case .dismiss:
            hideSuggestion()
            return true

        case .passThrough:
            return false
        }
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        suggestionPanel.show(text: suggestion.visibleText, near: caretRect)
    }

    private func hideSuggestion() {
        suggestionSession.dismiss()
        lastCaretRect = nil
        suggestionPanel.hide()
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
