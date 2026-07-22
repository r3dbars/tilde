import Cocoa
import InputMethodKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Spike phase 2: real (lightweight) predictions instead of a hardcoded table.
///
/// Questions this phase answers across real apps:
///   1. Can an input method READ the surrounding document via
///      `IMKTextInput.attributedSubstring(from:)` (needed for real context)?
///   2. Does per-keystroke commit + re-mark feel instant at full typing speed?
///   3. Do doc-learned completions make the channel feel alive?
///
/// The predictor is deliberately tiny (word completion from document vocabulary +
/// next-word bigrams + a few phrase openers) so any perceived lag is the CHANNEL,
/// not the model. Tab accepts, Esc dismisses.
@objc(GhostInputController)
final class GhostInputController: IMKInputController {

    /// Fallback context accumulated from keystrokes, for clients that refuse
    /// `attributedSubstring(from:)`. Bounded.
    private var typedFallback = ""
    /// The ghost currently shown as marked text (empty when none).
    private var ghost = ""
    /// Whether the current client answered a context read this session (for feel
    /// debugging: apps that do give dramatically better suggestions).
    private var clientGivesContext = false
    /// Monotonic keystroke generation; async model results for a stale generation
    /// are dropped instead of clobbering a newer ghost.
    private var generation = 0
    private var modelTask: Task<Void, Never>?
    /// True right after an accept added a trailing space the user didn't type.
    /// Typing punctuation next swallows that space (like iOS smart punctuation).
    private var pendingAutoSpace = false
    #if canImport(FoundationModels)
    private var modelSession: LanguageModelSession?
    #endif

    private static let unset = NSRange(location: NSNotFound, length: NSNotFound)

    // MARK: - Event handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else {
            return false
        }

        // Never eat shortcuts (Cmd/Control/Fn) — drop the ghost and pass through.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) || mods.contains(.control) || mods.contains(.function) {
            clearGhost(client)
            return false
        }

        switch event.keyCode {
        case 48: // Tab — accept next word; Shift-Tab — accept the whole ghost.
            guard !ghost.isEmpty else { return false }
            if mods.contains(.shift) {
                acceptWholeGhost(client)
            } else {
                acceptOneWord(client)
            }
            return true
        case 53: // Escape — dismiss the ghost if present.
            guard !ghost.isEmpty else { return false }
            clearGhost(client)
            return true
        case 51: // Delete/Backspace — drop ghost, let the app delete normally.
            pendingAutoSpace = false
            clearGhost(client)
            if !typedFallback.isEmpty { typedFallback.removeLast() }
            return false
        default:
            break
        }

        // Printable single characters (incl. space): commit them, then re-offer a ghost
        // after a short pause. While fingers are moving there is NO marked text — the
        // caret renders normally and the ghost only appears when typing rests.
        if let chars = event.characters,
           chars.count == 1,
           let scalar = chars.unicodeScalars.first,
           scalar.value >= 0x20, scalar.value != 0x7F {
            clearGhost(client)
            let swallowAutoSpace = pendingAutoSpace && ".,!?;:".contains(chars)
            pendingAutoSpace = false
            let selection = client.selectedRange()
            if swallowAutoSpace, selection.location != NSNotFound, selection.location > 0 {
                // "word ." → "word." — replace the auto-space with the punctuation.
                client.insertText(chars, replacementRange: NSRange(location: selection.location - 1, length: 1))
                if typedFallback.hasSuffix(" ") { typedFallback.removeLast() }
            } else {
                client.insertText(chars, replacementRange: Self.unset)
            }
            typedFallback.append(chars)
            if typedFallback.count > 2000 { typedFallback.removeFirst(500) }
            scheduleGhostAfterPause(client)
            return true
        }

        // Return, arrows, anything else: drop the ghost and let the app handle it.
        pendingAutoSpace = false
        clearGhost(client)
        if let chars = event.characters, chars.contains("\r") || chars.contains("\n") {
            typedFallback.append("\n")
        }
        return false
    }

    /// Called when focus leaves; make sure no ghost is stranded.
    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? IMKTextInput { clearGhost(client) }
        typedFallback = ""
        ghost = ""
        generation += 1
        modelTask?.cancel()
        super.deactivateServer(sender)
    }

    // MARK: - Context

    /// Text before the caret, preferring a real read from the client document and
    /// falling back to the keystroke accumulator.
    private func contextBeforeCaret(_ client: IMKTextInput) -> String {
        let selection = client.selectedRange()
        if selection.location != NSNotFound, selection.location > 0 {
            let start = max(0, selection.location - 1000)
            let range = NSRange(location: start, length: selection.location - start)
            if let text = client.attributedSubstring(from: range)?.string, !text.isEmpty {
                clientGivesContext = true
                return text
            }
        }
        clientGivesContext = false
        return typedFallback
    }

    // MARK: - Prediction (deliberately tiny — the channel is what's under test)

    private static let commonNextWord: [String: String] = [
        "i": "think", "you": "can", "we": "should", "it": "is", "this": "is",
        "that": "would", "the": "same", "to": "the", "of": "the", "in": "the",
        "and": "then", "for": "the", "is": "a", "are": "you", "will": "be",
        "would": "be", "can": "be", "let": "me", "thank": "you", "thanks": "for",
        "please": "let", "looking": "forward", "feel": "free", "make": "sure",
        "as": "soon", "be": "able", "want": "to", "need": "to", "going": "to",
        "have": "a", "just": "wanted", "should": "be", "could": "be", "there": "is",
    ]

    private static let phraseOpeners: [(prefix: String, suffix: String)] = [
        ("thank you", " so much"),
        ("looking forward", " to hearing from you"),
        ("let me know", " what you think"),
        ("as soon as", " possible"),
        ("feel free to", " reach out"),
    ]

    /// Chain up to four words so Tab-per-word acceptance has a runway. The chain is
    /// computed ONCE per keystroke — tabbing through it never re-rolls the words.
    private func predict(context: String) -> String {
        var ghostText = ""
        var ctx = context
        for _ in 0..<4 {
            let piece = predictOne(context: ctx)
            guard !piece.isEmpty else { break }
            ghostText += piece
            ctx += piece
            ghostText += " "
            ctx += " "
        }
        while ghostText.hasSuffix(" ") { ghostText.removeLast() }
        return ghostText
    }

    private func predictOne(context: String) -> String {
        let tail = String(context.suffix(400))
        let lowerTail = tail.lowercased()

        // 1. Phrase openers on exact tail match.
        for (prefix, suffix) in Self.phraseOpeners where lowerTail.hasSuffix(prefix) {
            return suffix
        }

        let separators = CharacterSet.alphanumerics.inverted
        let words = context.components(separatedBy: separators).filter { !$0.isEmpty }

        // 2. Mid-word: the document's own vocabulary wins; otherwise fall back to the
        //    system dictionary, which ranks completions by likelihood ("wh" → "what").
        if let last = tail.unicodeScalars.last, !separators.contains(last) {
            guard let partial = words.last, partial.count >= 2 else { return "" }
            let lowerPartial = partial.lowercased()
            var counts: [String: Int] = [:]
            for word in words.dropLast() where word.count > partial.count {
                let lower = word.lowercased()
                if lower.hasPrefix(lowerPartial) { counts[lower, default: 0] += 1 }
            }
            if let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key {
                return String(best.dropFirst(partial.count))
            }
            return dictionaryCompletion(for: partial)
        }

        return nextWordPrediction(lowerTail: lowerTail, words: words)
    }

    /// macOS's spell checker returns completions for a partial word ranked by
    /// likelihood — an instant, real English vocabulary with zero shipped data.
    private func dictionaryCompletion(for partial: String) -> String {
        guard partial.count >= 3 else { return "" }
        let range = NSRange(location: 0, length: (partial as NSString).length)
        let candidates = NSSpellChecker.shared.completions(
            forPartialWordRange: range,
            in: partial,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []
        let lowerPartial = partial.lowercased()
        for candidate in candidates
        where candidate.count > partial.count && candidate.lowercased().hasPrefix(lowerPartial) {
            return String(candidate.dropFirst(partial.count))
        }
        return ""
    }

    private func nextWordPrediction(lowerTail: String, words: [String]) -> String {
        // 3. After a space: next word from the document's bigrams, else common English.
        guard lowerTail.hasSuffix(" "), let previous = words.last?.lowercased() else { return "" }
        var bigrams: [String: Int] = [:]
        if words.count >= 2 {
            for i in 0..<(words.count - 1) where words[i].lowercased() == previous {
                bigrams[words[i + 1].lowercased(), default: 0] += 1
            }
        }
        if let best = bigrams.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), best.value >= 2 {
            return best.key
        }
        return Self.commonNextWord[previous] ?? ""
    }

    // MARK: - Ghost lifecycle

    /// Debounce: the ghost appears only after typing rests for a beat. Fresh
    /// keystrokes bump `generation`, so pending reveals cancel themselves.
    private func scheduleGhostAfterPause(_ client: IMKTextInput) {
        generation += 1
        let gen = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard let self, self.generation == gen else { return }
            guard let liveClient = self.client() else { return }
            self.updateGhost(liveClient)
        }
    }

    private func updateGhost(_ client: IMKTextInput) {
        generation += 1
        let context = contextBeforeCaret(client)

        // Fast layer: instant word/bigram chain from the tiny predictor.
        let suffix = predict(context: context)
        ghost = suffix
        if !suffix.isEmpty { show(suffix, client) }

        // Smart layer: Apple's on-device model refines the ghost when it's ready
        // (only at word boundaries; mid-word stays the fast layer's job).
        requestModelGhost(client, context: context)
    }

    /// Present ghost text as marked text. Styling is app-controlled (proven in
    /// phase 1) — grey is sent anyway for the rare client that honors it.
    private func show(_ suffix: String, _ client: IMKTextInput) {
        client.setMarkedText(
            NSAttributedString(string: suffix, attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]),
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: Self.unset
        )
    }

    // MARK: - Model layer: SteadyType MLX brain first, Apple on-device model fallback

    private func requestModelGhost(_ client: IMKTextInput, context: String) {
        // Mid-word AND word-boundary contexts both go to the brain; the server picks
        // the engine mode. The prompt KV cache makes long context cheap after the
        // first request, so send generously. Require a little so answers aren't wild.
        let tail = String(context.suffix(1000))
        guard tail.count >= 12 else { return }

        let gen = generation
        let hostApp = client.bundleIdentifier()
        let fieldIdentity = client.uniqueClientIdentifierString()
        modelTask?.cancel()
        modelTask = Task { [weak self] in
            // 1) SteadyType's own MLX model, served by the menu-bar app over a local
            //    socket. Blocking client with its own timeouts, kept off this task.
            let mlx = await Task.detached(priority: .userInitiated) {
                GhostBrainClient.complete(context: tail, app: hostApp, field: fieldIdentity)
            }.value
            if Task.isCancelled { return }
            if let mlx {
                let text = Self.cleanedModelOutput(mlx)
                if !text.isEmpty {
                    await self?.present(text, ifStill: gen)
                    return
                }
            }
            // 2) Apple's on-device model, when the app isn't running.
            await self?.appleModelGhost(tail: tail, gen: gen)
        }
    }

    @MainActor
    private func present(_ text: String, ifStill gen: Int) {
        guard generation == gen, let liveClient = client() else { return }
        ghost = text
        show(text, liveClient)
    }

    private func appleModelGhost(tail: String, gen: Int) async {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { return }
        // Continuation prompt only makes sense at word boundaries.
        guard tail.hasSuffix(" ") || tail.hasSuffix("\n") else { return }
        guard case .available = SystemLanguageModel.default.availability else { return }
        if modelSession == nil {
            modelSession = LanguageModelSession(instructions: """
            You silently continue the user's document. Given the end of a text, reply with \
            ONLY the most likely next 2-8 words that continue it seamlessly. No quotes, \
            no commentary, no leading/trailing whitespace. Match the text's tone and language.
            """)
            modelSession?.prewarm()
        }
        guard let session = modelSession, !session.isResponding else { return }
        let text: String
        do {
            let response = try await session.respond(
                to: tail,
                options: GenerationOptions(maximumResponseTokens: 16)
            )
            text = Self.cleanedModelOutput(response.content)
        } catch {
            return // guardrail refusal / cancellation / transient — fast layer stands
        }
        guard !text.isEmpty else { return }
        await present(text, ifStill: gen)
        #endif
    }

    /// One line, at most 8 words, no wrapping quotes.
    private static func cleanedModelOutput(_ raw: String) -> String {
        let flattened = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'`“”"))
        let words = flattened.split(separator: " ").filter { !$0.isEmpty }
        return words.prefix(8).joined(separator: " ")
    }

    private func clearGhost(_ client: IMKTextInput) {
        generation += 1
        modelTask?.cancel()
        guard !ghost.isEmpty else { return }
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: Self.unset
        )
        ghost = ""
    }

    /// Accept everything, then predict a fresh chain. A trailing space is added so
    /// typing continues with the NEXT word instead of extending the accepted one.
    private func acceptWholeGhost(_ client: IMKTextInput) {
        var accepted = ghost
        clearGhost(client)
        if !accepted.hasSuffix(" ") {
            accepted += " "
            pendingAutoSpace = true
        }
        client.insertText(accepted, replacementRange: Self.unset)
        typedFallback.append(accepted)
        updateGhost(client)
    }

    /// Accept just the first word (with its surrounding spaces) and KEEP the rest of
    /// the chain marked — Tab-Tab-Tab walks a stable sentence, no re-rolling.
    private func acceptOneWord(_ client: IMKTextInput) {
        var chunk = ""
        var sawWord = false
        for character in ghost {
            if character == " " {
                chunk.append(character)
                if sawWord { break }
            } else {
                sawWord = true
                chunk.append(character)
            }
        }
        let remainder = String(ghost.dropFirst(chunk.count))
        ghost = ""
        var insertion = chunk
        if remainder.isEmpty, !insertion.hasSuffix(" ") {
            // Last word of the chain: auto-space so typing moves to the next word.
            insertion += " "
            pendingAutoSpace = true
        }
        client.insertText(insertion, replacementRange: Self.unset)
        typedFallback.append(insertion)
        guard !remainder.isEmpty else { updateGhost(client); return }
        ghost = remainder
        client.setMarkedText(
            NSAttributedString(string: remainder, attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]),
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: Self.unset
        )
    }
}
