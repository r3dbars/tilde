import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let allowlist = AppAllowlist.default
    private let activationPolicy = CompletionActivationPolicy()
    private let engine = MockCompletionEngine()
    private let keyboardRouter = KeyboardActionRouter()
    private let suggestionPanel = SuggestionPanelController()

    private var statusItem: NSStatusItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
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
            currentFieldIdentity = nil
            lastTextSnapshot = nil
            hideSuggestion()
            return
        }

        guard let context = accessibilityClient.focusedTextContext(), !context.isSecure else {
            currentFieldIdentity = nil
            lastTextSnapshot = nil
            hideSuggestion()
            return
        }

        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            processIdentifier: frontmostApp.processIdentifier,
            elementIdentifier: context.elementIdentifier
        )
        currentFieldIdentity = fieldIdentity

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != lastTextSnapshot else {
            return
        }

        lastTextSnapshot = snapshot
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
                    self.lastTextLineRect = context.textLineRect
                    self.lastTextStyle = context.textStyle
                    suggestionPanel.show(
                        text: suggestion.visibleText,
                        near: caretRect,
                        alignedTo: context.textLineRect,
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
            suppressKey(key)
            return true

        case .acceptAllVisible:
            guard let acceptedText = suggestionSession.acceptAllVisible(),
                  accessibilityClient.insertText(acceptedText) else {
                return false
            }

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
            style: lastTextStyle
        )
    }

    private func hideSuggestion() {
        suggestionSession.dismiss()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastTextStyle = nil
        suggestionPanel.hide()
    }

    private func suppressCurrentField() {
        guard let currentFieldIdentity else {
            return
        }

        suppressedFieldIdentities.insert(currentFieldIdentity)
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
