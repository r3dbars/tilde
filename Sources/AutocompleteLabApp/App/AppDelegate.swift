import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let allowlist = AppAllowlist.default
    private let engine = MockCompletionEngine()
    private let suggestionPanel = SuggestionPanelController()

    private var statusItem: NSStatusItem?
    private var pollTimer: Timer?
    private var lastTextBeforeCursor = ""
    private var suggestionTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        accessibilityClient.requestPermissionIfNeeded()
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
            suggestionPanel.hide()
            return
        }

        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              allowlist.allows(bundleIdentifier: frontmostApp.bundleIdentifier) else {
            suggestionPanel.hide()
            return
        }

        guard let context = accessibilityClient.focusedTextContext(), !context.isSecure else {
            suggestionPanel.hide()
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
                        suggestionPanel.hide()
                        return
                    }

                    suggestionPanel.show(text: suggestion.visibleText, near: caretRect)
                }
            } catch {
                await MainActor.run {
                    suggestionPanel.hide()
                }
            }
        }
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
