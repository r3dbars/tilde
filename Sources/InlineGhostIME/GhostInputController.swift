import AutocompleteLabCore
import Cocoa
import InputMethodKit

/// A deliberately small IMKit keyboard: marked-text display, type-through,
/// dictionary suffixes, and phrase requests to Tilde's app-owned model.
@objc(GhostInputController)
final class GhostInputController: IMKInputController {
    private static let unset = NSRange(location: NSNotFound, length: NSNotFound)
    private static let contextLimit = 3_000

    private struct FallbackOwner: Equatable {
        let client: String
        let bundle: String
        let caret: Int
    }

    private var state = InlineSuggestionState()
    private var typedFallback = ""
    private var fallbackOwner: FallbackOwner?
    private var scheduleRevision = 0
    private var revealTask: Task<Void, Never>?
    private var modelTask: Task<Void, Never>?

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else {
            return false
        }
        let defaults = UserDefaults.standard
        let suggestionsEnabled = defaults.object(forKey: "GhostSuggestionsEnabled") as? Bool ?? true
        let paused = defaults.double(forKey: "GhostPausedUntil") > Date().timeIntervalSince1970
        guard suggestionsEnabled, !paused else {
            dismiss(client)
            resetFallback()
            return false
        }
        synchronizeFallback(with: client)

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command)
            || modifiers.contains(.control)
            || modifiers.contains(.function)
            || modifiers.contains(.option) {
            dismiss(client)
            resetFallback()
            return false
        }

        switch event.keyCode {
        case 48: // Plain Tab accepts all. Shift-Tab remains the host app's key.
            guard !modifiers.contains(.shift) else {
                dismiss(client)
                return false
            }
            return acceptSuggestion(client)

        case 53: // Escape dismisses only when something is visible.
            let wasVisible = state.isVisible
            dismiss(client)
            return wasVisible

        case 51: // The host owns deletion; wait for the next typed character.
            dismiss(client)
            resetFallback()
            return false

        default:
            break
        }

        if let grapheme = printableGrapheme(from: event) {
            let current = matchingVisibleTicket(for: client)
            cancelPendingWork()
            let advanced = current?.advancing(with: grapheme)
            let effects = state.reduce(.type(grapheme, current: current, advanced: advanced))
            apply(effects, to: client)
            appendFallback(grapheme, for: client)
            return true
        }

        dismiss(client)
        resetFallback()
        return false
    }

    /// Client-driven composition endings must never commit an unaccepted ghost.
    override func commitComposition(_ sender: Any!) {
        if let client = sender as? IMKTextInput { dismiss(client) }
    }

    override func deactivateServer(_ sender: Any!) {
        GhostStats.flush(force: true)
        if let client = sender as? IMKTextInput { dismiss(client) }
        resetFallback()
        super.deactivateServer(sender)
    }

    // MARK: - Input and effects

    private func printableGrapheme(from event: NSEvent) -> String? {
        guard let characters = event.characters, characters.count == 1 else { return nil }
        guard characters.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
            return nil
        }
        return characters
    }

    private func appendFallback(_ text: String, for client: IMKTextInput) {
        guard let owner = fallbackOwner else {
            resetFallback()
            return
        }
        typedFallback.append(text)
        if typedFallback.count > Self.contextLimit {
            typedFallback.removeFirst(typedFallback.count - Self.contextLimit)
        }
        fallbackOwner = FallbackOwner(
            client: owner.client,
            bundle: owner.bundle,
            caret: owner.caret + text.utf16.count
        )
    }

    private func synchronizeFallback(with client: IMKTextInput) {
        guard let current = fallbackOwner(for: client) else {
            resetFallback()
            return
        }
        if fallbackOwner != current {
            typedFallback = ""
            fallbackOwner = current
        }
    }

    private func resetFallback() {
        typedFallback = ""
        fallbackOwner = nil
    }

    private func fallbackOwner(for client: IMKTextInput) -> FallbackOwner? {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return nil }
        return FallbackOwner(
            client: clientIdentifier(client),
            bundle: client.bundleIdentifier() ?? "",
            caret: selection.location
        )
    }

    private func apply(_ effects: [InlineSuggestionState.Effect], to client: IMKTextInput) {
        for effect in effects {
            switch effect {
            case .hide:
                client.setMarkedText(
                    "",
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: Self.unset
                )
            case let .insert(text):
                client.insertText(text, replacementRange: Self.unset)
            case let .show(text):
                client.setMarkedText(
                    NSAttributedString(string: text, attributes: [
                        .foregroundColor: NSColor.tertiaryLabelColor,
                    ]),
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: Self.unset
                )
            case .schedule:
                scheduleSuggestion(for: client)
            }
        }
    }

    private func dismiss(_ client: IMKTextInput) {
        cancelPendingWork()
        apply(state.reduce(.dismiss), to: client)
    }

    private func acceptSuggestion(_ client: IMKTextInput) -> Bool {
        let current = matchingVisibleTicket(for: client)
        cancelPendingWork()
        let effects = state.reduce(.accept(current))
        guard case let .insert(accepted)? = effects.first(where: {
            if case .insert = $0 { return true }
            return false
        }) else {
            apply(effects, to: client)
            return false
        }
        apply(effects, to: client)
        appendFallback(accepted, for: client)
        GhostStats.recordAccepted(accepted)
        return true
    }

    // MARK: - Tickets and context

    private func clientIdentifier(_ client: IMKTextInput) -> String {
        String(describing: ObjectIdentifier(client as AnyObject))
    }

    private func ticket(for client: IMKTextInput, context: String) -> InlineSuggestionTicket {
        let selection = client.selectedRange()
        return InlineSuggestionTicket(
            clientIdentifier: clientIdentifier(client),
            bundleIdentifier: client.bundleIdentifier() ?? "",
            contextFingerprint: InlineSuggestionTicket.fingerprint(context),
            selectionLocation: selection.location == NSNotFound ? -1 : selection.location,
            selectionLength: selection.length == NSNotFound ? -1 : selection.length,
            requestIdentifier: scheduleRevision
        )
    }

    /// Re-read the bounded context on acceptance so a same-range field change
    /// cannot commit a stale suggestion.
    private func matchingVisibleTicket(for client: IMKTextInput) -> InlineSuggestionTicket? {
        guard let visible = state.visibleTicket else { return nil }
        let current = ticket(for: client, context: contextBeforeCaret(client))
        return current == visible ? visible : nil
    }

    private func contextBeforeCaret(_ client: IMKTextInput) -> String {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return "" }
        if selection.location > 0 {
            let start = max(0, selection.location - Self.contextLimit)
            let range = NSRange(location: start, length: selection.location - start)
            if let text = client.attributedSubstring(from: range)?.string, !text.isEmpty {
                return text
            }
        }
        return fallbackOwner(for: client) == fallbackOwner ? typedFallback : ""
    }

    // MARK: - Suggestion paths

    private func scheduleSuggestion(for client: IMKTextInput) {
        cancelPendingWork()
        scheduleRevision += 1
        let revision = scheduleRevision
        let expectedClient = clientIdentifier(client)
        let expectedBundle = client.bundleIdentifier() ?? ""
        let midWord = typedFallback.last?.isLetter == true
        let delay: UInt64 = midWord ? 10_000_000 : 50_000_000

        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, self.scheduleRevision == revision, let liveClient = self.client() else {
                return
            }
            guard self.clientIdentifier(liveClient) == expectedClient,
                  (liveClient.bundleIdentifier() ?? "") == expectedBundle else { return }
            self.updateSuggestion(for: liveClient)
        }
    }

    private func updateSuggestion(for client: IMKTextInput) {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else {
            dismiss(client)
            resetFallback()
            return
        }
        let context = contextBeforeCaret(client)
        guard SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: context) else {
            dismiss(client)
            return
        }
        let requestTicket = ticket(for: client, context: context)
        apply(state.reduce(.awaitSuggestion(requestTicket)), to: client)

        if context.last?.isLetter == true {
            let suffix = spellCheckerSuffix(for: context)
            apply(state.reduce(.present(suffix, requestTicket)), to: client)
        } else if context.last?.isWhitespace == true {
            requestPhrase(for: client, context: context, ticket: requestTicket)
        }
    }

    /// The only synchronous predictor: one system completion lookup for a 3+
    /// letter partial word, run after the key callback has returned.
    private func spellCheckerSuffix(for context: String) -> String {
        let partial = String(context.reversed().prefix(while: \Character.isLetter).reversed())
        guard partial.count >= 3 else { return "" }
        let range = NSRange(location: 0, length: partial.utf16.count)
        let candidates = NSSpellChecker.shared.completions(
            forPartialWordRange: range,
            in: partial,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []
        guard let match = candidates.first(where: {
            $0.count > partial.count && $0.lowercased().hasPrefix(partial.lowercased())
        }) else { return "" }
        return String(match.dropFirst(partial.count))
    }

    /// Word boundaries make exactly one request to Tilde's app-owned model.
    private func requestPhrase(
        for client: IMKTextInput,
        context: String,
        ticket requestTicket: InlineSuggestionTicket
    ) {
        let tail = String(context.suffix(Self.contextLimit))
        let bundle = client.bundleIdentifier()
        modelTask = Task { [weak self] in
            let result = await GhostBrainClient.complete(context: tail, app: bundle)
            guard !Task.isCancelled else { return }
            switch result.outcome {
            case .suggestion:
                guard let text = result.suggestion else { return }
                await self?.present(text, ticket: requestTicket)
            case .unavailable:
                Self.summonBrainIfNeeded()
            case .silence, .error, .timeout, .invalidRequest:
                break
            }
        }
    }

    @MainActor
    private func present(_ text: String, ticket requestTicket: InlineSuggestionTicket) {
        guard let liveClient = client() else { return }
        let currentContext = contextBeforeCaret(liveClient)
        guard ticket(for: liveClient, context: currentContext) == requestTicket else { return }
        apply(state.reduce(.present(text, requestTicket)), to: liveClient)
    }

    private func cancelPendingWork() {
        scheduleRevision += 1
        revealTask?.cancel()
        revealTask = nil
        modelTask?.cancel()
        modelTask = nil
    }

    // MARK: - App watchdog

    private static var lastBrainSummon = Date.distantPast

    private static func summonBrainIfNeeded() {
        DispatchQueue.main.async {
            guard Date().timeIntervalSince(lastBrainSummon) >= 60 else { return }
            guard !UserDefaults.standard.bool(forKey: "GhostBrainQuietQuit") else { return }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "bar.r3d.tilde") else {
                return
            }
            lastBrainSummon = Date()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }
}
