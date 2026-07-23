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
    /// What produced the ghost currently on screen (for per-source accept stats).
    private enum GhostSource: String { case fast, model }
    private var ghostSource: GhostSource = .fast
    #if canImport(FoundationModels)
    private var modelSession: LanguageModelSession?
    #endif

    private static let unset = NSRange(location: NSNotFound, length: NSNotFound)

    // MARK: - Stats (privacy-clean: COUNTS ONLY, never text)

    /// Daily counters, buffered in memory and flushed to the IME's own defaults.
    /// Read back by the input menu ("Today: SteadyType wrote N% of your words").
    private enum Stats {
        static var wordsAccepted = 0
        static var charactersAccepted = 0
        static var wordsTyped = 0
        static var ghostsShown = 0
        static var ghostsAccepted = 0
        static var fastAccepts = 0
        static var modelAccepts = 0
        static var lastFlush = Date.distantPast

        static var dayKey: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "stats." + formatter.string(from: Date())
        }

        static func flushIfDue(force: Bool = false) {
            guard force || Date().timeIntervalSince(lastFlush) > 20 else { return }
            lastFlush = Date()
            let defaults = UserDefaults.standard
            var day = defaults.dictionary(forKey: dayKey) as? [String: Int] ?? [:]
            day["wordsAccepted", default: 0] += wordsAccepted
            day["charactersAccepted", default: 0] += charactersAccepted
            day["wordsTyped", default: 0] += wordsTyped
            day["ghostsShown", default: 0] += ghostsShown
            day["ghostsAccepted", default: 0] += ghostsAccepted
            day["fastAccepts", default: 0] += fastAccepts
            day["modelAccepts", default: 0] += modelAccepts
            defaults.set(day, forKey: dayKey)
            wordsAccepted = 0; charactersAccepted = 0; wordsTyped = 0
            ghostsShown = 0; ghostsAccepted = 0; fastAccepts = 0; modelAccepts = 0
        }

        static func todaySummary() -> String {
            flushIfDue(force: true)
            let day = UserDefaults.standard.dictionary(forKey: dayKey) as? [String: Int] ?? [:]
            let accepted = day["wordsAccepted"] ?? 0
            let typed = day["wordsTyped"] ?? 0
            let total = accepted + typed
            guard total > 0 else { return "Today: no typing yet" }
            let percent = Int((Double(accepted) / Double(total) * 100).rounded())
            return "Today: wrote \(accepted) words for you (\(percent)%)"
        }
    }

    private func recordAccept(_ text: String) {
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        Stats.wordsAccepted += words
        Stats.charactersAccepted += text.count
        Stats.ghostsAccepted += 1
        switch ghostSource {
        case .fast: Stats.fastAccepts += 1
        case .model: Stats.modelAccepts += 1
        }
        Stats.flushIfDue()
    }

    // MARK: - Event handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else {
            return false
        }

        // Never eat shortcuts (Cmd/Control/Fn) or Option combos — drop the ghost
        // and pass through. Option must reach the app untouched so dead-key
        // accents (Option-E, e → é) and special characters (©, ñ, ø) compose
        // normally.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) || mods.contains(.control) || mods.contains(.function) || mods.contains(.option) {
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
        case 50: // ` / ~ — one press accepts the whole ghost. Only swallowed
            // while a ghost is showing; otherwise falls through and types a
            // normal backtick/tilde via the printable-character path below.
            if !ghost.isEmpty {
                acceptWholeGhost(client)
                return true
            }
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
            if chars == " ", typedFallback.dropLast().last?.isLetter == true {
                Stats.wordsTyped += 1
                Stats.flushIfDue()
            }
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

    /// Called when the client ends composition (mouse click, caret move, focus
    /// shift, programmatic edits). The default can COMMIT marked text — which
    /// would turn an unaccepted ghost into real inserted text. Never allow that:
    /// the ghost is only ever inserted by an explicit Tab/Shift-Tab/tilde.
    override func commitComposition(_ sender: Any!) {
        if let client = sender as? IMKTextInput {
            clearGhost(client)
        }
        ghost = ""
    }

    /// Called when focus leaves; make sure no ghost is stranded.
    override func deactivateServer(_ sender: Any!) {
        Stats.flushIfDue(force: true)
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
            let start = max(0, selection.location - 3000)
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

        // 2. Mid-word: the system dictionary LEADS (likelihood-ranked English —
        //    owner preference: real words over echoing the document's own
        //    vocabulary); doc words only fill in when the dictionary is silent,
        //    which keeps rare personal/project terms completing.
        if let last = tail.unicodeScalars.last, !separators.contains(last) {
            guard let partial = words.last, partial.count >= 2 else { return "" }
            let fromDictionary = dictionaryCompletion(for: partial)
            if !fromDictionary.isEmpty { return fromDictionary }
            let lowerPartial = partial.lowercased()
            var counts: [String: Int] = [:]
            for word in words.dropLast() where word.count > partial.count {
                let lower = word.lowercased()
                if lower.hasPrefix(lowerPartial) { counts[lower, default: 0] += 1 }
            }
            if let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key {
                return String(best.dropFirst(partial.count))
            }
            return ""
        }

        return nextWordPrediction(lowerTail: lowerTail, words: words)
    }

    /// Everyday words the dictionary should prefer completing TO — and never
    /// try to extend when the user has already typed one completely ("the" →
    /// "theory" is noise, not help).
    private static let commonWords: Set<String> = Set("""
    about after again always another anything around because become before being \
    better between change coming could different does doing done during actually \
    everything example experience feeling first friend getting going great group \
    happen having hello help home hope house idea important interest interesting \
    into just keep know language large last later learn least leave life little \
    long look love make making many maybe mean meaning meeting might minute moment \
    money month more morning most much music must need never new next night nothing \
    now number office only other our over own part people perfect person place plan \
    please point possible probably problem project put question quick really reason \
    remember right same school second see seem send should since small some someone \
    something sometimes soon sorry sound start still story sure system take talk \
    team tell thank thanks their them then there these thing think this those thought \
    three through time today together tomorrow tonight understand until update use \
    very want week welcome well what when where which while will with without word \
    work working world would write writing wrong year
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    /// macOS's spell checker returns completions ranked by likelihood; we layer
    /// two quality rules on top: don't extend an already-complete common word,
    /// and prefer completing TO a common word over an obscure dictionary find.
    private func dictionaryCompletion(for partial: String) -> String {
        guard partial.count >= 2 else { return "" }
        let lowerPartial = partial.lowercased()
        if Self.commonWords.contains(lowerPartial) { return "" }
        let range = NSRange(location: 0, length: (partial as NSString).length)
        let candidates = (NSSpellChecker.shared.completions(
            forPartialWordRange: range,
            in: partial,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []).filter { candidate in
            candidate.count >= partial.count + 2
                && candidate.lowercased().hasPrefix(lowerPartial)
        }
        if let common = candidates.first(where: { Self.commonWords.contains($0.lowercased()) }) {
            return String(common.dropFirst(partial.count))
        }
        if let first = candidates.first, first.count <= partial.count + 9 {
            return String(first.dropFirst(partial.count))
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
        // Doc-bigram evidence only — no generic common-word fallback. Dogfood
        // verdict: statistically-plausible generic chains read as junk; silence
        // beats filler, and confident model phrases replace silence anyway.
        if let best = bigrams.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), best.value >= 2 {
            return best.key
        }
        return ""
    }

    // MARK: - Ghost lifecycle

    /// Debounce: the ghost appears only after typing rests for a beat. Fresh
    /// keystrokes bump `generation`, so pending reveals cancel themselves.
    ///
    /// Per-app rhythm: native text views keep the caret at the ghost's start,
    /// so near-instant reveals (10ms mid-word / 50ms boundary — owner: "insane,
    /// I want this speed to stay") are pure win. Chromium/Electron surfaces draw
    /// the caret at the ghost's END, so instant reveals make the cursor
    /// ping-pong mid-burst — those apps get calm reveals (120/200ms) that only
    /// fire when the fingers genuinely rest.
    private func scheduleGhostAfterPause(_ client: IMKTextInput) {
        generation += 1
        let gen = generation
        let midWord = typedFallback.unicodeScalars.last.map(CharacterSet.alphanumerics.contains) ?? false
        let jumpyCaret = hostAppHasJumpyCaret(client.bundleIdentifier())
        let delay: UInt64
        if jumpyCaret {
            delay = midWord ? 120_000_000 : 200_000_000
        } else {
            delay = midWord ? 10_000_000 : 50_000_000
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, self.generation == gen else { return }
            guard let liveClient = self.client() else { return }
            self.updateGhost(liveClient)
        }
    }

    private var caretJumpyByBundleID: [String: Bool] = [:]

    /// Chromium-family detection at runtime: browsers by bundle-id prefix,
    /// Electron apps by the framework inside their bundle — no app list to
    /// maintain for the endless stream of Electron chat clients.
    private func hostAppHasJumpyCaret(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        if let cached = caretJumpyByBundleID[bundleIdentifier] { return cached }
        let jumpy = Self.isChromiumFamily(bundleIdentifier: bundleIdentifier)
        caretJumpyByBundleID[bundleIdentifier] = jumpy
        return jumpy
    }

    private static let chromiumBrowserPrefixes = [
        "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
        "company.thebrowser.Browser", "com.openai.atlas",
        "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    ]

    private static func isChromiumFamily(bundleIdentifier: String) -> Bool {
        if chromiumBrowserPrefixes.contains(where: bundleIdentifier.hasPrefix) {
            return true
        }
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier).first,
            let bundleURL = app.bundleURL else { return false }
        let electronFramework = bundleURL
            .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        return FileManager.default.fileExists(atPath: electronFramework.path)
    }

    private func updateGhost(_ client: IMKTextInput) {
        generation += 1
        let context = contextBeforeCaret(client)

        // Fast layer: instant completions with real evidence (doc vocabulary,
        // dictionary, doc bigrams) — no generic filler.
        let suffix = predict(context: context)
        ghost = suffix
        if !suffix.isEmpty {
            ghostSource = .fast
            show(suffix, client)
        }

        // Smart layer. Mid-word, the dictionary/doc completion is precise — when
        // it produced one, the model does NOT get to overwrite it (small-model
        // word suffixes are erratic). The model fills mid-word gaps and offers
        // phrase continuations at word boundaries.
        let midWord = !(context.hasSuffix(" ") || context.hasSuffix("\n"))
        if midWord, !suffix.isEmpty { return }
        requestModelGhost(client, context: context)
    }

    // MARK: - Display modes

    /// "inline" (default): marked text in the sentence, composing underline.
    /// "panel": the system candidate window — the user's text stays pristine.
    /// Toggled from the input menu (menu-bar keyboard icon); persisted in the
    /// IME's own defaults domain.
    private static let displayModeKey = "GhostDisplayMode"

    private var panelMode: Bool {
        UserDefaults.standard.string(forKey: Self.displayModeKey) == "panel"
    }

    /// Whether an inline marked-text ghost is currently rendered (needed so a
    /// mid-session mode switch still clears the right surface).
    private var inlineGhostVisible = false

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let stats = NSMenuItem(title: Stats.todaySummary(), action: nil, keyEquivalent: "")
        stats.isEnabled = false
        menu.addItem(stats)
        menu.addItem(.separator())
        let inline = NSMenuItem(
            title: "Inline suggestions (underlined)",
            action: #selector(selectInlineMode(_:)),
            keyEquivalent: ""
        )
        inline.target = self
        inline.state = panelMode ? .off : .on
        menu.addItem(inline)
        let panel = NSMenuItem(
            title: "Panel suggestions (clean text)",
            action: #selector(selectPanelMode(_:)),
            keyEquivalent: ""
        )
        panel.target = self
        panel.state = panelMode ? .on : .off
        menu.addItem(panel)
        return menu
    }

    @objc private func selectInlineMode(_ sender: Any?) {
        UserDefaults.standard.set("inline", forKey: Self.displayModeKey)
        GhostPanel.candidates?.hide()
    }

    @objc private func selectPanelMode(_ sender: Any?) {
        UserDefaults.standard.set("panel", forKey: Self.displayModeKey)
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        ghost.isEmpty ? [] : [ghost]
    }

    /// Present the ghost in the active display mode. Inline styling is
    /// app-controlled (proven in phase 1) — grey is sent anyway for the rare
    /// client that honors it.
    private func show(_ suffix: String, _ client: IMKTextInput) {
        Stats.ghostsShown += 1
        if panelMode {
            if inlineGhostVisible {
                client.setMarkedText(
                    "",
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: Self.unset
                )
                inlineGhostVisible = false
            }
            GhostPanel.candidates?.update()
            GhostPanel.candidates?.show(kIMKLocateCandidatesBelowHint)
            return
        }
        client.setMarkedText(
            NSAttributedString(string: suffix, attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]),
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: Self.unset
        )
        inlineGhostVisible = true
    }

    // MARK: - Model layer: SteadyType MLX brain first, Apple on-device model fallback

    private func requestModelGhost(_ client: IMKTextInput, context: String) {
        // Mid-word AND word-boundary contexts both go to the brain; the server picks
        // the engine mode. The prompt KV cache makes long context cheap after the
        // first request, so send generously. Require a little so answers aren't wild.
        let tail = String(context.suffix(3000))
        guard tail.count >= 12 else { return }

        let gen = generation
        let hostApp = client.bundleIdentifier()
        let fieldIdentity = client.uniqueClientIdentifierString()
        modelTask?.cancel()
        modelTask = Task { [weak self] in
            // 1) SteadyType's own MLX model, served by the menu-bar app over a local
            //    socket. Streaming: partials show the first words near time-to-
            //    first-token; the stale-guard in present() drops late arrivals.
            let mlx = await Task.detached(priority: .userInitiated) {
                GhostBrainClient.complete(context: tail, app: hostApp, field: fieldIdentity) { partial in
                    let text = Self.cleanedModelOutput(partial)
                    guard !text.isEmpty else { return }
                    Task { @MainActor in self?.present(text, ifStill: gen) }
                }
            }.value
            if Task.isCancelled { return }
            if let mlx {
                // The brain answered. Empty = its confidence gate chose silence —
                // RESPECT it. Falling back to another model here was the bug that
                // let unfiltered Apple-model refusals ("as an AI chatbot…") reach
                // the screen whenever the brain stayed quiet.
                let text = Self.cleanedModelOutput(mlx)
                if !text.isEmpty {
                    await self?.present(text, ifStill: gen)
                }
                return
            }
            // 2) Apple's on-device model — ONLY when the brain is unreachable.
            await self?.appleModelGhost(tail: tail, gen: gen)
        }
    }

    @MainActor
    private func present(_ text: String, ifStill gen: Int) {
        guard generation == gen, let liveClient = client() else { return }
        ghost = text
        ghostSource = .model
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
            You silently continue the user's document IN THE USER'S OWN VOICE, as the \
            human author. You are never a chatbot: never answer, refuse, apologize, or \
            disclaim being an AI — even when the text is a question or addresses an \
            assistant, continue the user's own words. Reply with ONLY the most likely \
            next 2-8 words that continue the text seamlessly. No quotes, no commentary, \
            no leading/trailing whitespace. Match the text's tone and language.
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

    /// One line, at most 8 words, no wrapping quotes — and never assistant-persona
    /// leakage (the app-side engine filters these too; this protects the Apple
    /// fallback path, which bypasses the engine's cleaner).
    private static func cleanedModelOutput(_ raw: String) -> String {
        let flattened = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'`“”"))
        let lowered = flattened.lowercased()
        let personaMarkers = [
            "as an ai", "as a language model", "as an assistant", "ai chatbot",
            "ai assistant", "language model", "i cannot assist", "i can't assist",
        ]
        if personaMarkers.contains(where: lowered.contains) { return "" }
        let words = flattened.split(separator: " ").filter { !$0.isEmpty }
        return words.prefix(8).joined(separator: " ")
    }

    private func clearGhost(_ client: IMKTextInput) {
        generation += 1
        modelTask?.cancel()
        guard !ghost.isEmpty else { return }
        GhostPanel.candidates?.hide()
        if inlineGhostVisible {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: Self.unset
            )
            inlineGhostVisible = false
        }
        ghost = ""
    }

    /// Accept everything, then predict a fresh chain. A trailing space is added so
    /// typing continues with the NEXT word instead of extending the accepted one.
    private func acceptWholeGhost(_ client: IMKTextInput) {
        var accepted = ghost
        recordAccept(accepted)
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
        recordAccept(chunk)
        ghost = ""
        inlineGhostVisible = false
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
        show(remainder, client)
    }
}
