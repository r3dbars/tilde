import Testing
@testable import AutocompleteLabCore

@Suite("Magic writing OCR prompt eval")
struct MagicWritingOCRPromptEvalTests {
    @Test("Screen-aware prompt and max cadence cover one hundred writing situations")
    func screenAwarePromptAndMaxCadenceCoverOneHundredWritingSituations() throws {
        let scenarios = MagicWritingScenario.hundredCaseCorpus
        #expect(scenarios.count == 100)

        let builder = CompletionPromptBuilder(maxVisibleWords: 8)
        let tuning = SuggestionTuning(aggressivenessLevel: 5, maxVisibleWords: 8)
        let activation = tuning.activationPolicy(supportPace: .eager)
        let trigger = tuning.triggerPolicy(supportPace: .eager)
        var scores: [Double] = []

        for scenario in scenarios {
            let pageContext = try #require(VisiblePageContext(
                captureScope: .visibleScreen,
                activeApplicationName: scenario.appName,
                text: scenario.visibleText
            ))
            let request = CompletionRequest(
                textBeforeCursor: scenario.textBeforeCursor,
                appBundleIdentifier: scenario.bundleIdentifier,
                visiblePageContext: pageContext,
                maxVisibleWords: 8,
                mode: scenario.mode
            )
            let prompt = builder.prompt(for: request)
            let activationDecision = activation.decision(
                textBeforeCursor: scenario.textBeforeCursor,
                textAfterCursor: "",
                isSecure: false,
                isFieldSuppressed: false,
                fieldKind: .multilineCompose
            )
            let triggerDecision = trigger.decision(
                previousTextBeforeCursor: nil,
                currentTextBeforeCursor: scenario.textBeforeCursor,
                lineStartBehavior: .plain,
                behaviorProfileID: request.behaviorProfile.id
            )

            #expect(prompt.user.contains("Active app: \(scenario.appName)"), "missing app context for \(scenario.id)")
            #expect(prompt.user.contains(scenario.anchorText), "missing OCR anchor for \(scenario.id)")
            #expect(prompt.system.contains("local writing companion"), "missing companion guidance for \(scenario.id)")
            #expect(activationDecision.canSuggest, "activation blocked \(scenario.id)")
            guard case .request = triggerDecision else {
                Issue.record("cadence skipped \(scenario.id)")
                continue
            }

            scores.append(score(prompt: prompt, scenario: scenario, activationDecision: activationDecision))
        }

        let average = scores.reduce(0, +) / Double(scores.count)
        #expect(average >= 0.92)
    }

    private func score(
        prompt: CompletionPrompt,
        scenario: MagicWritingScenario,
        activationDecision: CompletionActivationDecision
    ) -> Double {
        var score = 0.0
        if prompt.user.contains("Active app: \(scenario.appName)") { score += 0.18 }
        if prompt.user.contains("OCR scope: visible_screen") { score += 0.14 }
        if prompt.user.contains(scenario.anchorText) { score += 0.18 }
        if prompt.system.contains("what the user is replying to") { score += 0.14 }
        if prompt.system.contains("Prefer the next word or short phrase") { score += 0.14 }
        if prompt.system.contains("Return only the suffix") { score += 0.10 }
        if activationDecision.canSuggest { score += 0.12 }
        return score
    }
}

private struct MagicWritingScenario {
    let id: String
    let appName: String
    let bundleIdentifier: String
    let visibleText: String
    let anchorText: String
    let textBeforeCursor: String
    let mode: CompletionRequestMode

    static var hundredCaseCorpus: [MagicWritingScenario] {
        Array(apps.flatMap { app in
            intents.enumerated().map { index, intent in
                MagicWritingScenario(
                    id: "\(app.id)-\(index + 1)",
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    visibleText: "\(intent.surface)\n\(intent.anchor)\nDraft\n\(intent.before)",
                    anchorText: intent.anchor,
                    textBeforeCursor: intent.before,
                    mode: intent.mode
                )
            }
        }.prefix(100))
    }

    private static let apps: [(id: String, name: String, bundleIdentifier: String)] = [
        ("textedit", "TextEdit", "com.apple.TextEdit"),
        ("notes", "Notes", "com.apple.Notes"),
        ("obsidian", "Obsidian", "md.obsidian"),
        ("codex", "Codex", "com.openai.codex"),
        ("chatgpt", "ChatGPT", "com.openai.ChatGPT")
    ]

    private static let intents: [(surface: String, anchor: String, before: String, mode: CompletionRequestMode)] = [
        ("Message thread", "Alex: Can you send the launch note today?", "Yeah I can", .phraseContinuation),
        ("Meeting note", "Decision: keep OCR local and fast", "Next step is to", .phraseContinuation),
        ("Project doc", "Goal: make suggestions feel instant", "The fastest way to", .phraseContinuation),
        ("Daily note", "I keep losing the thread when suggestions vanish", "What I want is", .phraseContinuation),
        ("Feedback", "This feels too conservative right now", "Can we make it", .phraseContinuation),
        ("Reply", "Maya: Do you want me to move the review?", "Yes please move", .phraseContinuation),
        ("Launch plan", "Risk: autocomplete answers instead of continuing", "The guardrail should", .phraseContinuation),
        ("Todo list", "- [ ] Verify OCR in Obsidian", "- [ ] Then", .phraseContinuation),
        ("Scratchpad", "The visible page mentions Gemma and Qwen", "I think Qwen", .phraseContinuation),
        ("Outline", "Section: why the app feels magical", "The magic is", .phraseContinuation),
        ("Comment", "Please make this paragraph shorter and clearer", "I can tighten", .phraseContinuation),
        ("Status", "Blocked: Screen Recording permission missing", "If permission is", .phraseContinuation),
        ("Research", "Co-typist shows small next-word completions", "We should copy", .phraseContinuation),
        ("Bug note", "Long suggestions disappear too quickly", "The fix should", .phraseContinuation),
        ("Reply draft", "Jordan: Is this good enough to ship?", "I think it", .phraseContinuation),
        ("Prompt draft", "Do not change the AI model", "Keep the current", .phraseContinuation),
        ("Field test", "User is typing around a visible checklist", "This should predict", .phraseContinuation),
        ("Partial word", "Autocomplete Lab should recognize Obsidian context", "Obsid", .wordCompletion),
        ("Partial word", "Transcripted is the product name on the page", "Transcrip", .wordCompletion),
        ("Partial word", "Screen Recording permission appears in Settings", "permis", .wordCompletion)
    ]
}
