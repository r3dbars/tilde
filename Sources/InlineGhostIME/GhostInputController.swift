import TildeCore
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
    /// Chained accept: once the ghost is fully consumed by Tab or the whole-
    /// accept key, ask for the next continuation right away. See
    /// `TildeProductProfile.chainsCompletionAfterAccept`.
    private static let chainsAfterAccept = TildeProductProfile.current.chainsCompletionAfterAccept
    /// The schedule revision of the request a consumed accept chained, while
    /// it is still the live one. A Tab that lands before that ghost appears
    /// is held rather than handed to the host: the writer is mid-chain, and
    /// in an Electron composer a stray Tab moves focus out of the field.
    private var chainedRequestRevision: Int?
    private static let slowKeyLogger = Logger(
        subsystem: TildeProductProfile.current.inputMethodBundleIdentifier,
        category: "typing-performance"
    )
    private static let roundTripLogger = Logger(
        subsystem: TildeProductProfile.current.inputMethodBundleIdentifier,
        category: "suggestion-latency"
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
    /// H01 block-randomization arm for this typing session, resolved once so
    /// visible length cannot change mid-sentence, and `nil` for every build
    /// except a Model Preview whose owner turned the harness on.
    private var h01ArmResolved = false
    private var h01SessionArmValue: H01Arm?
    /// Personal History needs a stricter notion of continuity than IMKit's
    /// unstable client identifiers. Rotate this on known edit/session
    /// boundaries so replay does not join across deletion or navigation.
    private var historySegmentIdentifier = UUID().uuidString
    private var state = InlineSuggestionState()
    private var typedFallback = ""
    private var fallbackOwner: FallbackOwner?
    private var historyOwner: FallbackOwner?
    private var scheduleRevision = 0
    private var lastScheduledContextTail = ""
    private var revealTask: Task<Void, Never>?
    private var modelTask: Task<Void, Never>?
    private var bufferedReveal: (text: String, ticket: InlineSuggestionTicket)?
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
            GhostOutcomeLedger.markPrivacyExcluded()
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
            if !accepted {
                if awaitingChainedGhost() { return true }
                breakHistorySegment()
            }
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
            if wasVisible {
                GhostOutcomeLedger.noteDismissed()
            } else {
                breakHistorySegment()
            }
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
            GhostOutcomeLedger.noteTyped()
            GhostOutcomeLedger.closeIfGhostGone(stillVisible: state.isVisible)
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
        GhostOutcomeLedger.closeOpenGhost()
        breakHistorySegment()
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        GhostOutcomeLedger.configure { [weak self] in
            guard let self, let liveClient = self.client() else { return nil }
            if IsSecureEventInputEnabled() { return nil }
            return self.contextBeforeCaret(liveClient)
        }
        guard !IsSecureEventInputEnabled() else { return }
        notifyScreenMemory(.textFieldFocused)
    }

    override func deactivateServer(_ sender: Any!) {
        screenMemoryTypingTask?.cancel()
        screenMemoryTypingTask = nil
        notifyScreenMemory(.textFieldBlurred)
        GhostStats.flush(force: true)
        PersonalHistoryCapture.shared.flush()
        GhostOutcomeLedger.closeSegment()
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
        GhostOutcomeLedger.markPrivacyExcluded()
        breakHistorySegment()
        dismiss(client)
        resetFallback()
        return true
    }

    /// One read per typing session. While the harness is off this stays
    /// `nil`, no schedule is created, and nothing downstream changes.
    private func h01SessionArm() -> H01Arm? {
        if h01ArmResolved { return h01SessionArmValue }
        h01ArmResolved = true
        h01SessionArmValue = H01BlockRandomization.arm(
            profile: .current,
            defaults: UserDefaults.standard
        )
        return h01SessionArmValue
    }

    private func recordOutcomeShown(_ client: IMKTextInput) {
        let field = fieldSnapshot(client)
        guard !Self.isOutcomeExcluded(bundleIdentifier: field.bundleIdentifier) else { return }
        let context = contextBeforeCaret(client, selection: field.selection)
        GhostOutcomeLedger.noteShown(
            sessionIdentifier: suggestionSessionIdentifier,
            bundleIdentifier: field.bundleIdentifier,
            candidateCharacters: state.visibleText.count,
            candidateWordCount: state.visibleText.split(whereSeparator: \Character.isWhitespace).count,
            opportunityCharacters: max(1, context.count),
            precedingCharacter: context.last,
            excluded: false,
            variant: h01SessionArm()?.eventVariant ?? "champion"
        )
    }

    static func isOutcomeExcluded(
        bundleIdentifier: String,
        secureInput: Bool = IsSecureEventInputEnabled()
    ) -> Bool {
        if secureInput { return true }
        let configured = Set(
            UserDefaults.standard.stringArray(
                forKey: PersonalHistorySettingsContract.excludedAppsKey
            ) ?? []
        )
        return DefaultExcludedApps.isExcluded(
            bundleIdentifier,
            configuredExcludedApps: configured
        )
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
                GhostOutcomeLedger.noteVisibleCandidate(
                    characters: text.count,
                    wordCount: text.split(whereSeparator: \Character.isWhitespace).count
                )
            case let .schedule(afterTyping: grapheme):
                scheduleSuggestion(for: client, afterUserTyped: grapheme)
            case .shown:
                GhostStats.recordSuggestionShown()
                recordOutcomeShown(client)
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
        GhostOutcomeLedger.noteAccepted(
            accepted,
            kind: .word,
            remainderVisible: state.isVisible
        )
        chainAfterAcceptIfConsumed(client)
        return true
    }

    /// The reward for a correct ghost used to be silence: accepting its last
    /// word left the caret at a word boundary with nothing scheduled until
    /// the next keystroke. When the profile chains, the accepted text (which
    /// ends in the separator) is the new context and the next three words
    /// are requested at once, through the ordinary schedule path with its
    /// reveal delay, activation checks, and ticket rules intact.
    private func chainAfterAcceptIfConsumed(_ client: IMKTextInput) {
        guard Self.chainsAfterAccept, !state.isVisible else { return }
        scheduleSuggestion(for: client, afterUserTyped: " ", chained: true)
        chainedRequestRevision = scheduleRevision
    }

    /// True while the request a consumed accept chained is still pending.
    /// Any newer schedule (a keystroke, a dismissal) moves the revision on,
    /// so an ordinary Tab is never held.
    private func awaitingChainedGhost() -> Bool {
        guard Self.chainsAfterAccept,
              let chained = chainedRequestRevision,
              chained == scheduleRevision,
              state.pendingTicket != nil else { return false }
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
        let effects = state.reduce(.acceptAll(
            current: match?.ticket,
            appendsSeparator: Self.chainsAfterAccept
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
        GhostOutcomeLedger.noteAccepted(
            accepted,
            kind: .all,
            remainderVisible: state.isVisible
        )
        chainAfterAcceptIfConsumed(client)
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

    /// One read of the client's cursor and identity, shared by everything
    /// that needs it within a single synchronous turn.
    ///
    /// Every `selectedRange()` / `bundleIdentifier()` is a cross-process call
    /// into the app being typed into, made on the same main thread that has to
    /// service the next keystroke — and `contextBeforeCaret`,
    /// ticket construction and `trailingTextAfterCaret` each used to make
    /// those calls independently, so one `present()` paid for three
    /// `selectedRange()` round trips and `updateSuggestion` for four. The
    /// client cannot change underneath us mid-turn, so reading once is exactly
    /// equivalent and materially cheaper — most of all in Electron hosts,
    /// whose own main thread is often already busy.
    struct FieldSnapshot {
        let selection: NSRange
        let bundleIdentifier: String
    }

    private func fieldSnapshot(_ client: IMKTextInput) -> FieldSnapshot {
        // Secure Event Input first, before any read. The readers below checked
        // this before touching the client at all, and routing them through a
        // snapshot must not quietly invert that ordering: in a password field
        // Tilde reads nothing, not even the caret or the host identity.
        guard !IsSecureEventInputEnabled() else {
            return FieldSnapshot(selection: Self.unset, bundleIdentifier: "")
        }
        return FieldSnapshot(
            selection: client.selectedRange(),
            bundleIdentifier: client.bundleIdentifier() ?? ""
        )
    }

    private func ticket(context: String, field: FieldSnapshot) -> InlineSuggestionTicket {
        InlineSuggestionTicket(
            clientIdentifier: suggestionSessionIdentifier,
            bundleIdentifier: field.bundleIdentifier,
            contextFingerprint: InlineSuggestionTicket.fingerprint(context),
            selectionLocation: field.selection.location == NSNotFound ? -1 : field.selection.location,
            selectionLength: field.selection.length == NSNotFound ? -1 : field.selection.length,
            requestIdentifier: scheduleRevision
        )
    }

    /// Re-read the bounded context on acceptance so a same-range field change
    /// cannot commit a stale suggestion.
    private func matchingVisibleState(
        for client: IMKTextInput
    ) -> (ticket: InlineSuggestionTicket, context: String)? {
        guard let visible = state.visibleTicket else { return nil }
        let field = fieldSnapshot(client)
        let context = contextBeforeCaret(client, selection: field.selection)
        let current = ticket(context: context, field: field)
        return visible.matchesFieldState(of: current) ? (visible, context) : nil
    }

    private func contextBeforeCaret(_ client: IMKTextInput) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
        return contextBeforeCaret(client, selection: client.selectedRange())
    }

    /// Takes the caret alone, never a whole `FieldSnapshot`: this reader has no
    /// use for the bundle identifier, and making it demand one would add a
    /// cross-process call per keystroke rather than remove one.
    private func contextBeforeCaret(_ client: IMKTextInput, selection: NSRange) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
        guard selection.location != NSNotFound, selection.length == 0 else { return "" }
        if selection.location > 0 {
            // Quantized start: once the field is past the limit, a window
            // that slides one character per keystroke moves every byte of
            // the prompt behind the scaffold and defeats the helper's
            // prompt-cache reuse for the rest of the session. The window is
            // never longer than the limit and never more than one quantum
            // shorter.
            let start = RawContinuationPrompt.stableWindowStart(
                end: selection.location,
                limit: Self.contextLimit
            )
            let range = NSRange(location: start, length: selection.location - start)
            if let text = client.attributedSubstring(from: range)?.string, !text.isEmpty {
                return text
            }
        }
        return fallbackOwner(for: client) == fallbackOwner ? typedFallback : ""
    }

    private func trailingTextAfterCaret(_ client: IMKTextInput) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
        return trailingTextAfterCaret(client, selection: client.selectedRange())
    }

    private func trailingTextAfterCaret(_ client: IMKTextInput, selection: NSRange) -> String {
        guard !IsSecureEventInputEnabled() else { return "" }
        guard let range = Self.trailingContextRange(
            selection: selection,
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

    private func scheduleSuggestion(
        for client: IMKTextInput,
        afterUserTyped grapheme: String,
        chained: Bool = false
    ) {
        // Same field, different conversation: tell Screen Memory so the
        // next capture happens now-ish instead of serving the old thread.
        let contextTail = String(contextBeforeCaret(client).suffix(Self.contextLimit))
        if ContextResetDetector.isReset(previous: lastScheduledContextTail, current: contextTail) {
            notifyScreenMemory(.contentReset)
        }
        lastScheduledContextTail = contextTail
        cancelPendingWork()
        scheduleRevision += 1
        let revision = scheduleRevision
        let expectedBundle = client.bundleIdentifier() ?? ""
        let timing = SuggestionRevealDelayPolicy.schedule(
            afterUserTyped: grapheme,
            calmMarkedText: usesCalmReveal(for: expectedBundle),
            chained: chained
        )
        guard scheduleRevision == revision,
              (client.bundleIdentifier() ?? "") == expectedBundle else { return }
        let revealNotBefore = Date().addingTimeInterval(
            Double(timing.revealDelayNanoseconds) / 1_000_000_000
        )
        // Yield only until the key callback returns; there is no timing
        // sleep before inference. Only marked-text presentation waits for
        // the calm-caret window in Chromium/Electron editors.
        Task { @MainActor [weak self] in
            guard let self,
                  self.scheduleRevision == revision,
                  let liveClient = self.client(),
                  (liveClient.bundleIdentifier() ?? "") == expectedBundle else { return }
            self.updateSuggestion(for: liveClient, revealNotBefore: revealNotBefore)
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

    private func updateSuggestion(for client: IMKTextInput, revealNotBefore: Date) {
        guard !stopForSecureInput(client) else { return }
        let field = fieldSnapshot(client)
        let selection = field.selection
        guard selection.location != NSNotFound, selection.length == 0 else {
            breakHistorySegment()
            dismiss(client)
            resetFallback()
            return
        }
        let context = contextBeforeCaret(client, selection: field.selection)
        let trailingText = trailingTextAfterCaret(client, selection: field.selection)
        guard SuggestionActivationPolicy.allowsSuggestions(
            afterUserTyped: typedFallback,
            trailingTextAfterCaret: trailingText
        ) else {
            dismiss(client)
            return
        }
        let requestTicket = ticket(context: context, field: field)
        apply(state.reduce(.awaitSuggestion(requestTicket)), to: client)

        if context.last?.isLetter == true {
            let suffix = spellCheckerSuffix(for: context)
            Task { @MainActor [weak self] in
                self?.present(
                    suffix,
                    ticket: requestTicket,
                    revealNotBefore: revealNotBefore
                )
            }
        } else if context.last?.isWhitespace == true {
            requestPhrase(
                bundleIdentifier: field.bundleIdentifier,
                context: context,
                ticket: requestTicket,
                revealNotBefore: revealNotBefore
            )
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

    /// The IME-to-app socket round trip, measured from this side.
    ///
    /// This was the one segment of the suggestion path with no timing
    /// anywhere — `script/latency_report.py`'s own docstring names it as the
    /// known gap. The app times from its side of the socket inward
    /// (`ghost-request-timing`), so the connect, the peer code-signature
    /// handshake, and the wire read on this side were invisible, and a
    /// regression in them could ship without tripping any budget.
    ///
    /// Cancelled requests are deliberately not recorded: the user typed past
    /// them, so their truncated durations would understate the real tail.
    ///
    /// Aggregate duration and a fixed outcome word only, never context and
    /// never a suggestion. `InlineGhostIME` does not depend on the app target
    /// and so cannot reach `DiagnosticsLog`; this goes to the same OSLog
    /// subsystem `slow-key` already writes to. Read it with:
    /// `log show --predicate 'subsystem == "bar.r3d.inputmethod.InlineGhost"'`
    private static func logRoundTrip(startedAt: TimeInterval, outcome: GhostBrainResponse.Outcome) {
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let milliseconds = Int((elapsed * 1_000).rounded())
        roundTripLogger.notice(
            "ghost-round-trip roundTripMilliseconds=\(milliseconds, privacy: .public) outcome=\(outcome.rawValue, privacy: .public)"
        )
    }

    /// Word boundaries make exactly one request to Tilde's app-owned model.
    private func requestPhrase(
        bundleIdentifier: String,
        context: String,
        ticket requestTicket: InlineSuggestionTicket,
        revealNotBefore: Date
    ) {
        let tail = String(context.suffix(Self.contextLimit))
        let bundle = bundleIdentifier.isEmpty ? nil : bundleIdentifier
        let fieldSessionIdentifier = requestTicket.clientIdentifier
        // Session-pinned, and nil unless the H01 harness is explicitly on.
        let experimentArm = h01SessionArm()?.rawValue
        modelTask = Task { [weak self] in
            let startedAt = ProcessInfo.processInfo.systemUptime
            let result = await GhostBrainClient.complete(
                context: tail,
                app: bundle,
                fieldSessionIdentifier: fieldSessionIdentifier,
                experimentArm: experimentArm,
                onPartial: { [weak self] text in
                    // Called on the socket worker; the ticket check in
                    // `present` is what discards a partial that arrives late.
                    Task { @MainActor [weak self] in
                        self?.present(
                            text,
                            ticket: requestTicket,
                            revealNotBefore: revealNotBefore
                        )
                    }
                }
            )
            guard !Task.isCancelled else { return }
            Self.logRoundTrip(startedAt: startedAt, outcome: result.outcome)
            switch result.outcome {
            case .suggestion:
                if let text = result.suggestion {
                    await self?.present(
                        text,
                        ticket: requestTicket,
                        revealNotBefore: revealNotBefore
                    )
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
    private func present(
        _ text: String,
        ticket requestTicket: InlineSuggestionTicket,
        revealNotBefore: Date = .distantPast
    ) {
        guard let liveClient = client() else { return }
        guard !stopForSecureInput(liveClient) else { return }
        let field = fieldSnapshot(liveClient)
        let currentContext = contextBeforeCaret(liveClient, selection: field.selection)
        guard ticket(context: currentContext, field: field) == requestTicket else {
            apply(state.reduce(.dismissTicket(requestTicket)), to: liveClient)
            return
        }
        guard SuggestionActivationPolicy.isAtGrowingEdge(
            trailingTextAfterCaret: trailingTextAfterCaret(liveClient, selection: field.selection)
        ) else {
            dismiss(liveClient)
            return
        }
        if Date() < revealNotBefore {
            bufferReveal(text, ticket: requestTicket, until: revealNotBefore)
            return
        }
        if bufferedReveal?.ticket == requestTicket { bufferedReveal = nil }
        apply(state.reduce(.update(text, requestTicket)), to: liveClient)
    }

    @MainActor
    private func bufferReveal(
        _ text: String,
        ticket: InlineSuggestionTicket,
        until deadline: Date
    ) {
        guard !text.isEmpty else { return }
        if let bufferedReveal, bufferedReveal.ticket == ticket {
            guard text.count > bufferedReveal.text.count,
                  text.hasPrefix(bufferedReveal.text) else { return }
        }
        bufferedReveal = (text, ticket)
        revealTask?.cancel()
        let nanoseconds = UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000)
        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled,
                  let self,
                  let buffered = self.bufferedReveal,
                  buffered.ticket == ticket else { return }
            self.bufferedReveal = nil
            self.present(buffered.text, ticket: buffered.ticket)
        }
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
        bufferedReveal = nil
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
            guard let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: TildeProductProfile.current.appBundleIdentifier
            ) else {
                return
            }
            lastBrainSummon = Date()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }
}
