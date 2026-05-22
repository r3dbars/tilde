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
        let ranker = WordCompletionCandidateRanker(staticWords: [])
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
            #expect(prompt.system.contains("Never output visible window titles"), "missing OCR chrome guardrail for \(scenario.id)")
            #expect(activationDecision.canSuggest, "activation blocked \(scenario.id)")
            guard case .request = triggerDecision else {
                Issue.record("cadence skipped \(scenario.id)")
                continue
            }

            let fastWordSelection = ranker.selection(
                for: scenario.textBeforeCursor,
                recentWords: pageContext.completionCandidateWords
            )
            if let expectedFastSuffix = scenario.expectedFastSuffix {
                #expect(
                    fastWordSelection.suggestion?.visibleText == expectedFastSuffix,
                    "missing instant OCR word completion for \(scenario.id)"
                )
            }

            scores.append(score(
                prompt: prompt,
                scenario: scenario,
                activationDecision: activationDecision,
                fastWordSelection: fastWordSelection
            ))
        }

        let average = scores.reduce(0, +) / Double(scores.count)
        #expect(average >= 0.94)
    }

    private func score(
        prompt: CompletionPrompt,
        scenario: MagicWritingScenario,
        activationDecision: CompletionActivationDecision,
        fastWordSelection: WordCompletionCandidateSelection
    ) -> Double {
        var score = 0.0
        if prompt.user.contains("Active app: \(scenario.appName)") { score += 0.16 }
        if prompt.user.contains("OCR scope: visible_screen") { score += 0.12 }
        if prompt.user.contains(scenario.anchorText) { score += 0.16 }
        if prompt.system.contains("what the user is replying to") { score += 0.14 }
        if prompt.system.contains("Prefer the next word or short phrase") { score += 0.14 }
        if prompt.system.contains("Never output visible window titles") { score += 0.05 }
        if prompt.system.contains("Return only the suffix") { score += 0.05 }
        if activationDecision.canSuggest { score += 0.12 }
        if scenario.expectedFastSuffix == nil || fastWordSelection.suggestion?.visibleText == scenario.expectedFastSuffix { score += 0.06 }
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
    let expectedFastSuffix: String?

    static var hundredCaseCorpus: [MagicWritingScenario] {
        Array(apps.flatMap { app in
            intents.enumerated().map { index, intent in
                let textBeforeCursor = intent.mode == .phraseContinuation
                    ? "\(intent.before) "
                    : intent.before
                return MagicWritingScenario(
                    id: "\(app.id)-\(index + 1)",
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    visibleText: "New chat Search Plugins\nUntitled 13\n\(intent.surface)\n\(intent.anchor)\nDraft\n\(textBeforeCursor)",
                    anchorText: intent.anchor,
                    textBeforeCursor: textBeforeCursor,
                    mode: intent.mode,
                    expectedFastSuffix: intent.expectedFastSuffix
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

    private static let intents: [(surface: String, anchor: String, before: String, mode: CompletionRequestMode, expectedFastSuffix: String?)] = [
        ("Message thread", "Alex: Can you send the launch note today?", "Yeah I can", .phraseContinuation, nil),
        ("Meeting note", "Decision: keep OCR local and fast", "Next step is to", .phraseContinuation, nil),
        ("Project doc", "Goal: make suggestions feel instant", "The fastest way to", .phraseContinuation, nil),
        ("Daily note", "I keep losing the thread when suggestions vanish", "What I want is", .phraseContinuation, nil),
        ("Feedback", "This feels too conservative right now", "Can we make it", .phraseContinuation, nil),
        ("Reply", "Maya: Do you want me to move the review?", "Yes please move", .phraseContinuation, nil),
        ("Launch plan", "Risk: autocomplete answers instead of continuing", "The guardrail should", .phraseContinuation, nil),
        ("Todo list", "- [ ] Verify OCR in Obsidian", "- [ ] Then verify OCR", .phraseContinuation, nil),
        ("Scratchpad", "The visible page mentions Gemma and Qwen", "I think Qwen", .phraseContinuation, nil),
        ("Outline", "Section: why the app feels magical", "The magic is", .phraseContinuation, nil),
        ("Comment", "Please make this paragraph shorter and clearer", "I can tighten", .phraseContinuation, nil),
        ("Status", "Blocked: Screen Recording permission missing", "If permission is", .phraseContinuation, nil),
        ("Research", "Co-typist shows small next-word completions", "We should copy", .phraseContinuation, nil),
        ("Bug note", "Long suggestions disappear too quickly", "The fix should", .phraseContinuation, nil),
        ("Reply draft", "Jordan: Is this good enough to ship?", "I think it", .phraseContinuation, nil),
        ("Prompt draft", "Do not change the AI model", "Keep the current", .phraseContinuation, nil),
        ("Field test", "User is typing around a visible checklist", "This should predict", .phraseContinuation, nil),
        ("Partial word", "SteadyType should recognize Obsidian context", "Obsid", .wordCompletion, "ian"),
        ("Partial word", "Transcripted is the product name on the page", "Transcrip", .wordCompletion, "ted"),
        ("Partial word", "Screen Recording permission appears in Settings", "permis", .wordCompletion, "sion")
    ]
}
