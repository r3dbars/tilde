import AutocompleteLabCore
import Cocoa
import InputMethodKit
import OSLog

/// A deliberately small IMKit keyboard: marked-text display, type-through,
/// dictionary suffixes, and phrase requests to Tilde's app-owned model.
@objc(GhostInputController)
final class GhostInputController: IMKInputController {
    private static let unset = NSRange(location: NSNotFound, length: NSNotFound)
    private static let contextLimit = 3_000
    private static let trailingContextLimit = 80
    private static let slowKeyThreshold: TimeInterval = 0.050
    private static let slowKeyLogger = Logger(
        subsystem: "bar.r3d.inputmethod.InlineGhost",
        category: "typing-performance"
    )

    struct SlowKeyTiming {
        let totalMilliseconds: Int
        let queuedMilliseconds: Int
        let handlerMilliseconds: Int
    }

    static func slowKeyTiming(
        eventTimestamp: TimeInterval,
        handlerStartedAt: TimeInterval,
        handlerFinishedAt: TimeInterval
    ) -> SlowKeyTiming? {
        let total = max(0, handlerFinishedAt - eventTimestamp)
        guard total >= slowKeyThreshold else { return nil }
        return SlowKeyTiming(
            totalMilliseconds: Int((total * 1_000).rounded()),
            queuedMilliseconds: Int((max(0, handlerStartedAt - eventTimestamp) * 1_000).rounded()),
            handlerMilliseconds: Int((max(0, handlerFinishedAt - handlerStartedAt) * 1_000).rounded())
        )
    }

    static func shouldAcceptWholeSuggestion(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        return keyCode == 50 && modifiers.intersection(shortcutModifiers).isEmpty
    }

    static func trailingContextRange(
        selection: NSRange,
        markedRange: NSRange,
        documentLength: Int
    ) -> NSRange? {
        guard selection.location != NSNotFound,
              selection.length == 0,
              documentLength > selection.location else {
            return nil
        }

        // While a ghost is visible, some clients include Tilde's own marked
        // text in their document length. Skip that range so the acceptance
        // safety check examines only the writer's real trailing content.
        let start: Int
        if markedRange.location == selection.location,
           markedRange.length <= documentLength - selection.location {
            start = NSMaxRange(markedRange)
        } else {
            start = selection.location
        }
        guard documentLength > start else { return nil }
        return NSRange(
            location: start,
            length: min(trailingContextLimit, documentLength - start)
        )
    }

    private struct FallbackOwner: Equatable {
        let bundle: String
        let caret: Int
    }

    private struct InsertionObservation {
        let bundle: String
        let selection: NSRange

        var owner: FallbackOwner? {
            guard selection.location != NSNotFound, selection.length == 0 else { return nil }
            return FallbackOwner(bundle: bundle, caret: selection.location)
        }
    }

    /// IMKit creates one controller for each input session.
    private let suggestionSessionIdentifier = UUID().uuidString
    /// Personal History needs a stricter notion of continuity than IMKit's
    /// unstable client identifiers. Rotate this on known edit/session
    /// boundaries so replay does not join across deletion or navigation.
    private var historySegmentIdentifier = UUID().uuidString
    private var state = InlineSuggestionState()
    private var typedFallback = ""
    private var fallbackOwner: FallbackOwner?
    private var historyOwner: FallbackOwner?
    private var scheduleRevision = 0
    private var revealTask: Task<Void, Never>?
    private var modelTask: Task<Void, Never>?
    private var screenMemoryTypingTask: Task<Void, Never>?
    private var calmRevealByBundle = [String: Bool]()

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else {
            return false
        }
        let handlerStartedAt = ProcessInfo.processInfo.systemUptime
        defer {
            if let timing = Self.slowKeyTiming(
                eventTimestamp: event.timestamp,
                handlerStartedAt: handlerStartedAt,
                handlerFinishedAt: ProcessInfo.processInfo.systemUptime
            ) {
                Self.slowKeyLogger.notice(
                    "slow-key totalMilliseconds=\(timing.totalMilliseconds, privacy: .public) queuedMilliseconds=\(timing.queuedMilliseconds, privacy: .public) handlerMilliseconds=\(timing.handlerMilliseconds, privacy: .public)"
                )
            }
        }
        let secureInput = IsSecureEventInputEnabled()
        if secureInput {
            screenMemoryTypingTask?.cancel()
            screenMemoryTypingTask = nil
            notifyScreenMemory(.textFieldBlurred)
            PersonalHistoryCapture.shared.sensitiveInputBegan()
            breakHistorySegment()
            dismiss(client)
            resetFallback()
            return false
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command)
            || modifiers.contains(.control)
            || modifiers.contains(.function)
            || modifiers.contains(.option) {
            breakHistorySegment()
            dismiss(client)
            resetFallback()
            return false
        }

        let typedGrapheme = printableGrapheme(from: event)
        let defaults = UserDefaults.standard
        let suggestionsEnabled = defaults.object(forKey: "GhostSuggestionsEnabled") as? Bool ?? true
        let paused = defaults.double(forKey: "GhostPausedUntil") > Date().timeIntervalSince1970
        guard suggestionsEnabled, !paused else {
            dismiss(client)
            resetFallback()
            if let typedGrapheme {
                capturePersonalHistory(
                    typedGrapheme,
                    source: .typed,
                    client: client,
                    secureInput: secureInput,
                    observation: nil
                )
            } else {
                breakHistorySegment()
            }
            return false
        }
        let previousOwner = fallbackOwner
        let insertionObservation = synchronizeFallback(with: client)
        if previousOwner != insertionObservation.owner {
            notifyScreenMemory(.textFieldFocused)
        }
        if typedGrapheme != nil {
            scheduleScreenMemoryTypingPause()
        }

        switch event.keyCode {
        case 48: // Plain Tab accepts one word. Shift-Tab remains the host app's key.
            guard !modifiers.contains(.shift) else {
                breakHistorySegment()
                dismiss(client)
                return false
            }
            let accepted = acceptSuggestion(client, observation: insertionObservation)
            if !accepted { breakHistorySegment() }
            return accepted

        case 50: // The physical backtick/tilde key accepts the whole visible suggestion.
            guard Self.shouldAcceptWholeSuggestion(
                keyCode: event.keyCode,
                modifiers: modifiers
            ) else { break }
            let accepted = acceptAllSuggestion(client, observation: insertionObservation)
            if !accepted { breakHistorySegment() }
            return accepted

        case 53: // Escape dismisses only when something is visible.
            let wasVisible = state.isVisible
            dismiss(client)
            if !wasVisible { breakHistorySegment() }
            return wasVisible

        case 51: // The host owns deletion; wait for the next typed character.
            breakHistorySegment()
            dismiss(client)
            resetFallback()
            return false

        default:
            break
        }

        if let grapheme = typedGrapheme {
            let match = matchingVisibleState(for: client)
            cancelPendingWork()
            let advanced = match.map { match in
                match.ticket.advancing(
                    with: grapheme,
                    boundedContext: match.context,
                    utf16Limit: Self.contextLimit
                )
            }
            let current = match?.ticket
            let effects = state.reduce(.type(grapheme, current: current, advanced: advanced))
            apply(effects, to: client)
            appendFallback(grapheme, for: client)
            capturePersonalHistory(
                grapheme,
                source: .typed,
                client: client,
                secureInput: secureInput,
                observation: insertionObservation
            )
            return true
        }

        dismiss(client)
        breakHistorySegment()
        resetFallback()
        return false
    }

    /// Client-driven composition endings must never commit an unaccepted ghost.
    override func commitComposition(_ sender: Any!) {
        if let client = sender as? IMKTextInput { dismiss(client) }
        breakHistorySegment()
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        guard !IsSecureEventInputEnabled() else { return }
        notifyScreenMemory(.textFieldFocused)
    }

    override func deactivateServer(_ sender: Any!) {
        screenMemoryTypingTask?.cancel()
        screenMemoryTypingTask = nil
        notifyScreenMemory(.textFieldBlurred)
        GhostStats.flush(force: true)
        PersonalHistoryCapture.shared.flush()
        if let client = sender as? IMKTextInput { dismiss(client) }
        breakHistorySegment()
        resetFallback()
        super.deactivateServer(sender)
    }

    private func scheduleScreenMemoryTypingPause() {
        screenMemoryTypingTask?.cancel()
        let delay = UInt64(CaptureTriggerPolicy.typingPauseThresholdSeconds * 1_000_000_000)
        screenMemoryTypingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.notifyScreenMemory(.typingPaused)
        }
    }

    private func notifyScreenMemory(_ kind: ScreenMemoryInputEvent.Kind) {
        let event = ScreenMemoryInputEvent(
            kind: kind,
            sessionIdentifier: suggestionSessionIdentifier
        )
        Task { _ = await GhostBrainClient.notifyScreenMemory(event) }
    }

    // MARK: - Input and effects

    private func printableGrapheme(from event: NSEvent) -> String? {
        guard let characters = event.characters, characters.count == 1 else { return nil }
        guard characters.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
            return nil
        }
        return characters
    }

    /// IMKit exposes no field semantics. Fail closed when the host protects a
    /// field with macOS secure event input.
    private func stopForSecureInput(_ client: IMKTextInput) -> Bool {
        guard IsSecureEventInputEnabled() else { return false }
        PersonalHistoryCapture.shared.sensitiveInputBegan()
        breakHistorySegment()
        dismiss(client)
        resetFallback()
        return true
    }

    private func appendFallback(_ text: String, for client: IMKTextInput) {
        guard let owner = fallbackOwner else {
            resetFallback()
            return
        }
        typedFallback = InlineSuggestionTicket.boundedContext(
            typedFallback + text,
            utf16Limit: Self.contextLimit
        )
        fallbackOwner = FallbackOwner(
            bundle: owner.bundle,
            caret: owner.caret + text.utf16.count
        )
    }

    private func synchronizeFallback(with client: IMKTextInput) -> InsertionObservation {
        let observation = InsertionObservation(
            bundle: client.bundleIdentifier() ?? "",
            selection: client.selectedRange()
        )
        guard let current = observation.owner else {
            resetFallback()
            return observation
        }
        if fallbackOwner != current {
            typedFallback = ""
            fallbackOwner = current
        }
        return observation
    }

    private func resetFallback() {
        typedFallback = ""
        fallbackOwner = nil
    }

    private func fallbackOwner(for client: IMKTextInput) -> FallbackOwner? {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return nil }
        return FallbackOwner(
            bundle: client.bundleIdentifier() ?? "",
            caret: selection.location
        )
    }

    /// Resolved once per visible suggestion chain because querying the host's
    /// text attributes is synchronous cross-process work.
    private var cachedGhostStyle: [NSAttributedString.Key: Any]?

    private func apply(_ effects: [InlineSuggestionState.Effect], to client: IMKTextInput) {
        for effect in effects {
            switch effect {
            case .hide:
                cachedGhostStyle = nil
                client.setMarkedText(
                    "",
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: Self.unset
                )
            case let .insert(text):
                client.insertText(text, replacementRange: Self.unset)
            case let .show(text):
                client.setMarkedText(
                    NSAttributedString(string: text, attributes: ghostStyle(client)),
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: Self.unset
                )
            case let .schedule(afterTyping: grapheme):
                scheduleSuggestion(for: client, afterUserTyped: grapheme)
            case .shown:
                GhostStats.recordSuggestionShown()
            case .accepted:
                GhostStats.recordSuggestionAccepted()
            }
        }
    }

    private func ghostStyle(_ client: IMKTextInput) -> [NSAttributedString.Key: Any] {
        if let cachedGhostStyle { return cachedGhostStyle }

        var lineRect = NSRect.zero
        let reported = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineRect)
        let reportedFont = (reported?[NSAttributedString.Key.font.rawValue]
            ?? reported?[NSAttributedString.Key.font]) as? NSFont

        let pointSize = CGFloat(InlineGhostFontPolicy.resolvedPointSize(
            reportedPointSize: reportedFont.map { Double($0.pointSize) },
            measuredLineHeight: lineRect.height.isFinite ? Double(lineRect.height) : nil,
            fallbackPointSize: Double(NSFont.systemFontSize)
        ))
        let font: NSFont
        if let reportedFont, reportedFont.pointSize == pointSize {
            font = reportedFont
        } else if let reportedFont {
            font = NSFont(descriptor: reportedFont.fontDescriptor, size: pointSize)
                ?? .systemFont(ofSize: pointSize)
        } else {
            font = .systemFont(ofSize: pointSize)
        }

        let spec = InlineGhostColorSpec.markedText
        let style: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                calibratedWhite: CGFloat(spec.fillWhite),
                alpha: CGFloat(spec.fillAlpha)
            ),
        ]
        cachedGhostStyle = style
        return style
    }

    private func dismiss(_ client: IMKTextInput) {
        cancelPendingWork()
        apply(state.reduce(.dismiss), to: client)
    }

    private func acceptSuggestion(
        _ client: IMKTextInput,
        observation: InsertionObservation
    ) -> Bool {
        guard canAcceptSuggestion(in: client) else {
            dismiss(client)
            return false
        }
        let match = matchingVisibleState(for: client)
        cancelPendingWork()
        let effects = state.reduce(.acceptNextWord(
            current: match?.ticket,
            boundedContext: match?.context ?? "",
            utf16Limit: Self.contextLimit
        ))
        guard case let .insert(accepted)? = effects.first(where: {
            if case .insert = $0 { return true }
            return false
        }) else {
            apply(effects, to: client)
            return false
        }
        apply(effects, to: client)
        appendFallback(accepted, for: client)
        capturePersonalHistory(
            accepted,
            source: .acceptedSuggestion,
            client: client,
            secureInput: IsSecureEventInputEnabled(),
            observation: observation
        )
        GhostStats.recordAccepted(accepted)
        return true
    }

    private func acceptAllSuggestion(
        _ client: IMKTextInput,
        observation: InsertionObservation
    ) -> Bool {
        guard canAcceptSuggestion(in: client) else {
            dismiss(client)
            return false
        }
        let match = matchingVisibleState(for: client)
        cancelPendingWork()
        let effects = state.reduce(.acceptAll(current: match?.ticket))
        guard case let .insert(accepted)? = effects.first(where: {
            if case .insert = $0 { return true }
            return false
        }) else {
            apply(effects, to: client)
            return false
        }
        apply(effects, to: client)
        appendFallback(accepted, for: client)
        capturePersonalHistory(
            accepted,
            source: .acceptedSuggestion,
            client: client,
            secureInput: IsSecureEventInputEnabled(),
            observation: observation
        )
        GhostStats.recordAccepted(accepted)
        return true
    }

    private func capturePersonalHistory(
        _ text: String,
        source: PersonalHistoryEventSource,
        client: IMKTextInput,
        secureInput: Bool,
        observation: InsertionObservation?
    ) {
        let bundle = observation?.bundle ?? client.bundleIdentifier()
        guard let permit = PersonalHistoryCapture.shared.permit(
            appBundleIdentifier: bundle,
            secureInput: secureInput
        ) else {
            invalidateHistoryContinuity()
            return
        }
        let observed = observation ?? InsertionObservation(
            bundle: permit.appBundleIdentifier,
            selection: client.selectedRange()
        )
        guard prepareHistoryInsertion(text, observation: observed) else { return }
        PersonalHistoryCapture.shared.record(
            text: text,
            source: source,
            sessionIdentifier: historySegmentIdentifier,
            permit: permit
        )
    }

    // MARK: - Tickets and context

    private func ticket(for client: IMKTextInput, context: String) -> InlineSuggestionTicket {
        let selection = client.selectedRange()
        return InlineSuggestionTicket(
            clientIdentifier: suggestionSessionIdentifier,
            bundleIdentifier: client.bundleIdentifier() ?? "",
            contextFingerprint: InlineSuggestionTicket.fingerprint(context),
            selectionLocation: selection.location == NSNotFound ? -1 : selection.location,
            selectionLength: selection.length == NSNotFound ? -1 : selection.length,
            requestIdentifier: scheduleRevision
        )
    }

    /// Re-read the bounded context on acceptance so a same-range field change
    /// cannot commit a stale suggestion.
    private func matchingVisibleState(
        for client: IMKTextInput
    ) -> (ticket: InlineSuggestionTicket, context: String)? {
        guard let visible = state.visibleTicket else { return nil }
        let context = contextBeforeCaret(client)
        let current = ticket(for: client, context: context)
        return visible.matchesFieldState(of: current) ? (visible, context) : nil
    }

    private func contextBeforeCaret(_ client: IMKTextInput) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
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

    private func trailingTextAfterCaret(_ client: IMKTextInput) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
        guard let range = Self.trailingContextRange(
            selection: client.selectedRange(),
            markedRange: client.markedRange(),
            documentLength: client.length()
        ) else {
            return ""
        }
        return client.attributedSubstring(from: range)?.string ?? ""
    }

    private func canAcceptSuggestion(in client: IMKTextInput) -> Bool {
        SuggestionActivationPolicy.isAtGrowingEdge(
            trailingTextAfterCaret: trailingTextAfterCaret(client)
        )
    }

    // MARK: - Suggestion paths

    private func scheduleSuggestion(for client: IMKTextInput, afterUserTyped grapheme: String) {
        cancelPendingWork()
        scheduleRevision += 1
        let revision = scheduleRevision
        let expectedBundle = client.bundleIdentifier() ?? ""
        let delay = SuggestionRevealDelayPolicy.nanoseconds(
            afterUserTyped: grapheme,
            calmMarkedText: usesCalmReveal(for: expectedBundle)
        )

        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, self.scheduleRevision == revision, let liveClient = self.client() else {
                return
            }
            guard (liveClient.bundleIdentifier() ?? "") == expectedBundle else { return }
            self.updateSuggestion(for: liveClient)
        }
    }

    /// Chromium browsers and Electron apps render marked-text carets at the
    /// ghost's end. Their longer pause prevents visible caret ping-pong while
    /// keeping native editors on the near-instant path.
    private func usesCalmReveal(for bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        if let cached = calmRevealByBundle[bundleIdentifier] { return cached }
        let electronFramework = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.bundleURL?
            .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        let electron = electronFramework.map {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? false
        let calm = SuggestionRevealDelayPolicy.requiresCalmMarkedText(
            bundleIdentifier: bundleIdentifier,
            hasElectronFramework: electron
        )
        calmRevealByBundle[bundleIdentifier] = calm
        return calm
    }

    private func updateSuggestion(for client: IMKTextInput) {
        guard !stopForSecureInput(client) else { return }
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else {
            breakHistorySegment()
            dismiss(client)
            resetFallback()
            return
        }
        let context = contextBeforeCaret(client)
        let trailingText = trailingTextAfterCaret(client)
        guard SuggestionActivationPolicy.allowsSuggestions(
            afterUserTyped: typedFallback,
            trailingTextAfterCaret: trailingText
        ) else {
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
        return Self.dictionarySuffix(for: partial, candidates: candidates)
    }

    static func dictionarySuffix(for partial: String, candidates: [String]) -> String {
        guard partial.count >= 3 else { return "" }
        let normalizedPartial = partial.lowercased()
        guard !candidates.contains(where: { $0.lowercased() == normalizedPartial }) else {
            return ""
        }
        guard let match = candidates.first(where: {
            $0.count > partial.count && $0.lowercased().hasPrefix(normalizedPartial)
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
            let result = await GhostBrainClient.complete(
                context: tail,
                app: bundle,
                onPartial: { [weak self] text in
                    // Called on the socket worker; the ticket check in
                    // `present` is what discards a partial that arrives late.
                    Task { @MainActor [weak self] in
                        self?.present(text, ticket: requestTicket)
                    }
                }
            )
            guard !Task.isCancelled else { return }
            switch result.outcome {
            case .suggestion:
                if let text = result.suggestion {
                    await self?.present(text, ticket: requestTicket)
                } else {
                    await self?.settle(ticket: requestTicket)
                }
            case .unavailable:
                await self?.settle(ticket: requestTicket)
                Self.summonBrainIfNeeded()
            case .error, .timeout, .invalidRequest:
                await self?.settle(ticket: requestTicket)
                GhostStats.recordFailure(result.outcome)
            case .silence, .recorded:
                await self?.settle(ticket: requestTicket)
            }
        }
    }

    /// Shows a streamed or final suggestion for `requestTicket`. The reducer
    /// only ever grows the visible text, so a final that equals or trims the
    /// streamed prefix leaves the ghost exactly where the writer saw it.
    @MainActor
    private func present(_ text: String, ticket requestTicket: InlineSuggestionTicket) {
        guard let liveClient = client() else { return }
        guard !stopForSecureInput(liveClient) else { return }
        let currentContext = contextBeforeCaret(liveClient)
        guard ticket(for: liveClient, context: currentContext) == requestTicket else {
            apply(state.reduce(.dismissTicket(requestTicket)), to: liveClient)
            return
        }
        guard SuggestionActivationPolicy.isAtGrowingEdge(
            trailingTextAfterCaret: trailingTextAfterCaret(liveClient)
        ) else {
            dismiss(liveClient)
            return
        }
        apply(state.reduce(.update(text, requestTicket)), to: liveClient)
    }

    /// The request ended without a longer suggestion. A partial that is
    /// already visible stays — it passed the same cleaner — and silence and
    /// retraction are both worse than a shorter word-boundary ghost. Only a
    /// still-pending ticket is released.
    @MainActor
    private func settle(ticket requestTicket: InlineSuggestionTicket) {
        guard state.visibleTicket != requestTicket, let liveClient = client() else { return }
        apply(state.reduce(.dismissTicket(requestTicket)), to: liveClient)
    }

    private func cancelPendingWork() {
        scheduleRevision += 1
        revealTask?.cancel()
        revealTask = nil
        modelTask?.cancel()
        modelTask = nil
    }

    private func breakHistorySegment() {
        historySegmentIdentifier = UUID().uuidString
        historyOwner = nil
    }

    private func invalidateHistoryContinuity() {
        if historyOwner != nil { breakHistorySegment() }
    }

    /// Tracks only known app/caret boundaries. IMKit cannot distinguish two
    /// same-app fields at the same caret without broader system permissions.
    private func prepareHistoryInsertion(
        _ text: String,
        observation: InsertionObservation
    ) -> Bool {
        let selection = observation.selection
        guard selection.location != NSNotFound else {
            breakHistorySegment()
            return false
        }
        let current = FallbackOwner(bundle: observation.bundle, caret: selection.location)
        if selection.length != 0 || (historyOwner != nil && historyOwner != current) {
            breakHistorySegment()
        }
        historyOwner = FallbackOwner(
            bundle: current.bundle,
            caret: current.caret + text.utf16.count
        )
        return true
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
