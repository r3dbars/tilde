import Testing
@testable import AutocompleteLabCore

@Suite("Raw continuation prompt")
struct RawContinuationPromptTests {
    @Test("Scaffold wraps the context tail without trailing whitespace")
    func scaffoldWrapsContextTail() {
        let prompt = RawContinuationPrompt(textBeforeCursor: "My main concern is the timeline, since we ")

        #expect(prompt.prompt.hasPrefix("The following are real documents"))
        #expect(prompt.prompt.hasSuffix("Text: My main concern is the timeline, since we\nContinuation:"))
        #expect(prompt.contextEndedInWhitespace)
    }

    @Test("Long context is trimmed from the left")
    func longContextTrimsFromLeft() {
        let words = (1...600).map { "word\($0)" }.joined(separator: " ")
        let prompt = RawContinuationPrompt(textBeforeCursor: words, maxContextCharacters: 200)

        #expect(!prompt.prompt.contains("word1 "))
        #expect(prompt.prompt.contains("word600"))
    }

    @Test("Normalization strips the duplicate separating space and stops at newlines")
    func normalizationHandlesSpacesAndNewlines() {
        let afterSpace = RawContinuationPrompt(textBeforeCursor: "since we ")
        #expect(afterSpace.normalizedContinuation(" need to hit the Q3 targets.") == "need to hit the Q3 targets.")
        #expect(afterSpace.normalizedContinuation(" first line\nsecond line") == "first line")

        let noSpace = RawContinuationPrompt(textBeforeCursor: "since we")
        #expect(noSpace.normalizedContinuation(" need approval") == " need approval")
    }
}

@Suite("Continuation register")
struct ContinuationRegisterTests {
    @Test("Bundle identity maps to the right register")
    func bundleIdentityMapsToRegister() {
        #expect(ContinuationRegister.from(bundleIdentifier: "com.tinyspeck.slackmacgap") == .chat)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.anthropic.claudefordesktop") == .chat)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.apple.mail") == .email)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.mimestream.Mimestream") == .email)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.apple.TextEdit") == .prose)
        #expect(ContinuationRegister.from(bundleIdentifier: nil) == .prose)
    }

    @Test("Register selects its scaffold voice and token budget")
    func registerSelectsScaffoldAndBudget() {
        let chat = RawContinuationPrompt(textBeforeCursor: "yeah ok ", register: .chat)
        #expect(chat.prompt.contains("Real chat messages"))
        let email = RawContinuationPrompt(textBeforeCursor: "Hi Sarah, ", register: .email)
        #expect(email.prompt.contains("Real emails"))
        let prose = RawContinuationPrompt(textBeforeCursor: "The report ")
        #expect(prose.prompt.contains("real documents"))
    }

    /// Fix for "Classify scenes by geometry, not host app": once the scene
    /// says the user is replying, the completion register must follow that
    /// scene rather than the host app's own default -- a chat conversation
    /// rendered in a browser (not on `ContinuationRegister`'s chat-bundle
    /// list) still gets the chat scaffold.
    @Test("Register follows a replying scene, regardless of the host app's own default register")
    func registerFollowsReplyingSceneOverHostApp() {
        let replyingScene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "hey are you around today")],
            referenceSnippets: []
        )
        // Chrome's own default register is `.prose` -- a chat scene overrides it.
        #expect(ContinuationRegister.following(scene: replyingScene, hostBundleIdentifier: "com.google.Chrome") == .chat)
        // Even a chat app's own bundle stays `.chat` either way.
        #expect(ContinuationRegister.following(scene: replyingScene, hostBundleIdentifier: "com.tinyspeck.slackmacgap") == .chat)
        // No host app at all: scene still wins.
        #expect(ContinuationRegister.following(scene: replyingScene, hostBundleIdentifier: nil) == .chat)
    }

    @Test("Register falls back to the host app's default when the scene is absent, composing, or referencing")
    func registerFallsBackToHostAppWithoutAReplyingScene() {
        let composingScene = ScreenScene.Scene(mode: .composing, conversationTurns: [], referenceSnippets: [])
        let referencingScene = ScreenScene.Scene(mode: .referencing, conversationTurns: [], referenceSnippets: ["a reference"])

        #expect(ContinuationRegister.following(scene: nil, hostBundleIdentifier: "com.apple.mail") == .email)
        #expect(ContinuationRegister.following(scene: composingScene, hostBundleIdentifier: "com.apple.mail") == .email)
        #expect(ContinuationRegister.following(scene: referencingScene, hostBundleIdentifier: "com.apple.TextEdit") == .prose)
        #expect(ContinuationRegister.following(scene: nil, hostBundleIdentifier: nil) == .prose)
    }
}

@Suite("Continuation cutoff repair")
struct ContinuationCutoffRepairTests {
    @Test("Trailing function-word fragments are trimmed")
    func trailingFragmentsAreTrimmed() {
        let recipe = RawContinuationPrompt(textBeforeCursor: "I wanted to ")

        #expect(recipe.normalizedContinuation(" see if you had any thoughts on the") == "see if you had any thoughts")
        #expect(recipe.normalizedContinuation(" still make the meeting if") == "still make the meeting")
    }

    @Test("Finished thoughts are left alone")
    func finishedThoughtsAreLeftAlone() {
        let recipe = RawContinuationPrompt(textBeforeCursor: "I wanted to ")

        #expect(recipe.normalizedContinuation(" discuss the Q3 strategy in more detail.") == "discuss the Q3 strategy in more detail.")
        #expect(recipe.normalizedContinuation(" much more realistic for Q3.") == "much more realistic for Q3.")
    }
}

@Test("Empty context stays silent")
func emptyContextStaysSilent() {
    let empty = RawContinuationPrompt(textBeforeCursor: "", register: .chat)
    #expect(empty.prompt.isEmpty)

    let whitespaceOnly = RawContinuationPrompt(textBeforeCursor: "   ", register: .chat)
    #expect(whitespaceOnly.prompt.isEmpty)
}

/// Screen Memory plan Phase 2 PR 2b: `RawContinuationPrompt`'s screen-context
/// block. Covers per-mode prompt shape, budget math (field text always wins
/// ties, scene capped at 1,000), and that a `nil`/composing scene reproduces
/// today's prompt exactly.
@Suite("Screen context prompt assembly")
struct ScreenContextPromptAssemblyTests {
    private let replyingScene = ScreenScene.Scene(
        mode: .replying,
        conversationTurns: [
            .init(speaker: .other, text: "hey are you around today"),
            .init(speaker: .selfSpeaker, text: "yeah free after 3pm works"),
        ],
        referenceSnippets: []
    )

    private let referencingScene = ScreenScene.Scene(
        mode: .referencing,
        conversationTurns: [],
        referenceSnippets: ["Q3 launch timeline moved to the 14th per the doc"]
    )

    private let composingScene = ScreenScene.Scene(mode: .composing, conversationTurns: [], referenceSnippets: [])

    // MARK: - Per-mode shape

    @Test("A nil scene reproduces today's prompt exactly, byte for byte")
    func nilSceneMatchesLegacyPrompt() {
        let withoutScene = RawContinuationPrompt(textBeforeCursor: "since we ", register: .chat)
        let withNilScene = RawContinuationPrompt(textBeforeCursor: "since we ", register: .chat, scene: nil)
        #expect(withoutScene == withNilScene)
        #expect(liveConversationBlocks(in: withoutScene.prompt) == 0)
        #expect(!withoutScene.prompt.contains("Reference:"))
    }

    @Test("A composing-mode scene contributes no context block")
    func composingSceneContributesNothing() {
        let prompt = RawContinuationPrompt(textBeforeCursor: "since we ", register: .chat, scene: composingScene)
        #expect(liveConversationBlocks(in: prompt.prompt) == 0)
        #expect(!prompt.prompt.contains("Reference:"))
        #expect(prompt.prompt.hasSuffix("Text: since we\nContinuation:"))
    }

    @Test("Replying scene renders a labeled Conversation block ahead of Text:")
    func replyingSceneRendersConversationBlock() {
        let prompt = RawContinuationPrompt(textBeforeCursor: "sure, ", register: .chat, scene: replyingScene)

        #expect(prompt.prompt.contains(
            "Conversation:\nThem: hey are you around today\nYou: yeah free after 3pm works\n\n"
        ))
        #expect(liveConversationBlocks(in: prompt.prompt) == 1)
        // Context sits between the scaffold and the field text.
        let conversationRange = prompt.prompt.range(of: "Conversation:", options: .backwards)
        let textRange = prompt.prompt.range(of: "Text: sure,")
        #expect(conversationRange != nil && textRange != nil)
        #expect(conversationRange!.lowerBound < textRange!.lowerBound)
        #expect(prompt.prompt.hasSuffix("Text: sure,\nContinuation:"))
    }

    @Test("Referencing scene renders a labeled Reference block")
    func referencingSceneRendersReferenceBlock() {
        let prompt = RawContinuationPrompt(textBeforeCursor: "as for the ", register: .email, scene: referencingScene)
        #expect(prompt.prompt.contains("Reference:\nQ3 launch timeline moved to the 14th per the doc\n\n"))
        #expect(prompt.prompt.hasSuffix("Text: as for the\nContinuation:"))
    }

    @Test("An empty-turns replying scene and an empty-snippet referencing scene contribute nothing")
    func emptyPayloadScenesContributeNothing() {
        let emptyReplying = ScreenScene.Scene(mode: .replying, conversationTurns: [], referenceSnippets: [])
        let emptyReferencing = ScreenScene.Scene(mode: .referencing, conversationTurns: [], referenceSnippets: [])

        let a = RawContinuationPrompt(textBeforeCursor: "hi ", scene: emptyReplying)
        let b = RawContinuationPrompt(textBeforeCursor: "hi ", scene: emptyReferencing)
        #expect(!a.prompt.contains("Conversation:"))
        #expect(!b.prompt.contains("Reference:"))
    }

    // MARK: - Budget math

    @Test("Field text always wins ties: a long field leaves little or no room for scene context")
    func fieldTextWinsTiesUnderTightBudget() {
        let longTail = String(repeating: "a", count: 2_990) // leaves only 10 of a 3,000 budget
        let prompt = RawContinuationPrompt(textBeforeCursor: longTail, scene: replyingScene)

        // The full field tail always survives untouched...
        #expect(prompt.prompt.hasSuffix("Text: \(longTail)\nContinuation:"))
        // ...and the scene contributes at most the 10 leftover characters,
        // nowhere near its full "Conversation:\n...\n\n" rendering.
        #expect(!prompt.prompt.contains("Conversation:\nThem: hey are you around today"))
    }

    @Test("A field that fully consumes the budget leaves the scene no room at all")
    func fieldTextConsumingWholeBudgetLeavesNoRoomForScene() {
        let tail = String(repeating: "b", count: 3_000)
        let prompt = RawContinuationPrompt(textBeforeCursor: tail, scene: replyingScene)
        #expect(!prompt.prompt.contains("Conversation:"))
        #expect(prompt.prompt.hasSuffix("Text: \(tail)\nContinuation:"))
    }

    @Test("Scene context is capped at its own limit even when far more budget remains")
    func sceneContextCappedAtOneThousandRegardlessOfRemainingBudget() {
        let manyTurns = (1...120).map {
            ScreenScene.ConversationTurn(speaker: $0.isMultiple(of: 2) ? .selfSpeaker : .other, text: "turn number \($0) with some extra words padding it out")
        }
        // ScreenScene itself caps turns to 3 / 600 chars, but this proves
        // RawContinuationPrompt's OWN cap holds independently of that,
        // against a scene built directly (not through ScreenScene.classify).
        let bigScene = ScreenScene.Scene(mode: .replying, conversationTurns: manyTurns, referenceSnippets: [])
        let prompt = RawContinuationPrompt(
            textBeforeCursor: "short ",
            scene: bigScene,
            maxContextCharacters: RawContinuationPrompt.maxSceneContextCharacters + 2_000
        )

        let contextStart = prompt.prompt.range(of: "Conversation:")!.lowerBound
        let textStart = prompt.prompt.range(of: "Text: short")!.lowerBound
        let contextLength = prompt.prompt.distance(from: contextStart, to: textStart)
        #expect(contextLength == RawContinuationPrompt.maxSceneContextCharacters)
    }

    @Test("Shrinking maxContextCharacters shrinks the scene's share, never the field text's")
    func totalBudgetShrinksSceneShareFirst() {
        // 80 is the floor `maxContextCharacters` is clamped to (see the
        // "long context is trimmed from the left" precedent test). A
        // 50-char field tail leaves exactly 30 of that 80 for the scene —
        // well under the untruncated "Reference:\n...\n\n" block's own
        // length, so this proves the shortfall is spent shrinking the
        // scene's share, not the field's.
        let fieldTail = String(repeating: "x", count: 50)
        let prompt = RawContinuationPrompt(
            textBeforeCursor: fieldTail,
            scene: referencingScene,
            maxContextCharacters: 80
        )
        #expect(prompt.prompt.hasSuffix("Text: \(fieldTail)\nContinuation:"))
        let contextStart = prompt.prompt.range(of: "Reference:")!.lowerBound
        let textStart = prompt.prompt.range(of: "Text: \(fieldTail)")!.lowerBound
        let contextLength = prompt.prompt.distance(from: contextStart, to: textStart)
        #expect(contextLength == 30)
    }

    // MARK: - Dedupe stays intact end to end

    @Test("A scene turn identical to the field text (as ScreenScene would already have deduped) still composes a valid prompt")
    func dedupedUpstreamSceneStillComposesCleanly() {
        // ScreenScene.classify is responsible for dropping OCR text that
        // duplicates the field (see ScreenSceneTests); this proves
        // RawContinuationPrompt doesn't reintroduce a duplicate of its own
        // when handed an already-deduped scene whose remaining turn is
        // wholly distinct from the field text.
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "totally different topic")],
            referenceSnippets: []
        )
        let prompt = RawContinuationPrompt(textBeforeCursor: "sure thing ", scene: scene)
        let occurrences = prompt.prompt.components(separatedBy: "sure thing").count - 1
        #expect(occurrences == 1)
    }

    // MARK: - Secret scrubbing (structured secrets must never reach the model)

    @Test("A credit card number OCR'd off screen is scrubbed before it reaches the prompt")
    func creditCardInReferenceSnippetIsScrubbed() {
        let scene = ScreenScene.Scene(
            mode: .referencing,
            conversationTurns: [],
            referenceSnippets: ["card on file is 4111 1111 1111 1111 for the renewal"]
        )
        let prompt = RawContinuationPrompt(textBeforeCursor: "as for the ", scene: scene)
        #expect(!prompt.prompt.contains("4111 1111 1111 1111"))
        #expect(prompt.prompt.contains("\u{27E8}redacted:card\u{27E9}"))
    }

    @Test("An API key OCR'd from a conversation turn is scrubbed before it reaches the prompt")
    func apiKeyInConversationTurnIsScrubbed() {
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [
                .init(speaker: .other, text: "here's the key sk-abcdefghijklmnopqrstuvwxyz123456"),
            ],
            referenceSnippets: []
        )
        let prompt = RawContinuationPrompt(textBeforeCursor: "got it, ", scene: scene)
        #expect(!prompt.prompt.contains("sk-abcdefghijklmnopqrstuvwxyz123456"))
        #expect(prompt.prompt.contains("\u{27E8}redacted:api-key\u{27E9}"))
    }

    @Test("Emails survive scrubbing in prompt context (forPromptContext keeps them as useful vocabulary)")
    func emailInSceneSurvivesPromptScrub() {
        let scene = ScreenScene.Scene(
            mode: .referencing,
            conversationTurns: [],
            referenceSnippets: ["reach out to alex@example.com about the launch"]
        )
        let prompt = RawContinuationPrompt(textBeforeCursor: "as for the ", scene: scene)
        #expect(prompt.prompt.contains("alex@example.com"))
    }

    // MARK: - Truncation safety (never chop the header or drop the trailing separator)

    @Test("A budget too small for the header drops the whole scene block rather than emitting a chopped header")
    func tooSmallBudgetDropsWholeBlockRatherThanChoppingHeader() {
        // "Conversation:\n" is 14 chars; leaving the scene only ~5 spare
        // characters of the 3,000 budget can't fit even the header plus the
        // trailing blank line, so the block must vanish instead of
        // surfacing a truncated "Conve" fused onto "Text:".
        let longTail = String(repeating: "a", count: 3_000 - 5)
        let prompt = RawContinuationPrompt(textBeforeCursor: longTail, scene: replyingScene)
        #expect(!prompt.prompt.contains("Conve"))
        #expect(prompt.prompt.hasSuffix("Text: \(longTail)\nContinuation:"))
    }

    @Test("A budget that fits the header but not the full body truncates only the body, keeping header and trailing blank line intact")
    func partialBudgetKeepsHeaderAndTrailerIntact() {
        // maxContextCharacters is clamped to a floor of 80. A 70-char field
        // tail against a 100-char total budget leaves the scene exactly 30
        // characters — more than the 16-char header+trailer reservation, so
        // the block survives, truncated, with its header and closing blank
        // line both intact (never a mid-header or mid-fusion chop).
        let fieldTail = String(repeating: "z", count: 70)
        let prompt = RawContinuationPrompt(textBeforeCursor: fieldTail, scene: replyingScene, maxContextCharacters: 100)
        #expect(prompt.prompt.contains("Conversation:\n"))
        #expect(prompt.prompt.contains("\n\nText: \(fieldTail)\nContinuation:"))
        #expect(!prompt.prompt.contains("Conversation:\nThem: hey are you around today\nYou: yeah free after 3pm works\n\n"))
    }

    /// The chat scaffold's own examples carry Conversation blocks; only
    /// blocks beyond those come from a live scene.
    private func liveConversationBlocks(in prompt: String) -> Int {
        let scaffoldBlocks = RawContinuationPrompt.scaffold(for: .chat)
            .components(separatedBy: "Conversation:").count - 1
        return prompt.components(separatedBy: "Conversation:").count - 1 - scaffoldBlocks
    }
}
