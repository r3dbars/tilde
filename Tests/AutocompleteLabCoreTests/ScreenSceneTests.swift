import Testing
@testable import AutocompleteLabCore

/// Synthetic OCR-block fixtures standing in for real Vision output. Coordinates
/// are normalized (0...1, top-left origin) to match `ScreenScene.NormalizedRect`.
private func block(
    _ text: String,
    x: Double,
    y: Double,
    width: Double = 0.35,
    window: String? = nil,
    title: String? = nil
) -> ScreenScene.OCRBlock {
    ScreenScene.OCRBlock(
        text: text,
        boundingBox: ScreenScene.NormalizedRect(x: x, y: y, width: width, height: 0.05),
        windowOwnerBundleID: window,
        windowTitle: title
    )
}

private let slack = "com.tinyspeck.slackmacgap"
private let textEdit = "com.apple.TextEdit"
private let notes = "com.apple.Notes"

@Suite("Screen scene classification")
struct ScreenSceneTests {
    // MARK: - Composing (no signal / edge inputs)

    @Test("No OCR blocks at all classifies as composing")
    func emptyBlocksIsComposing() {
        let scene = ScreenScene.classify(blocks: [], frontmostBundleID: textEdit, fieldText: "hello")
        #expect(scene == .init(mode: .composing, conversationTurns: [], referenceSnippets: []))
    }

    @Test("Chat frontmost with no vertical message-list geometry falls back to composing")
    func chatWithoutMessageListIsComposing() {
        // Only one bubble-shaped block -- a list needs at least two.
        let blocks = [block("hey are you around", x: 0.05, y: 0.3, window: slack)]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .composing)
        #expect(scene.conversationTurns.isEmpty)
    }

    @Test("Two blocks in the same vertical band do not form a message list")
    func sameBandDoesNotFormList() {
        let blocks = [
            block("hey are you around", x: 0.05, y: 0.30, window: slack),
            block("for a call today?", x: 0.50, y: 0.31, window: slack), // same decile band as above
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .composing)
    }

    @Test("A full-width block never counts as a bubble, even paired with a real one")
    func fullWidthBlockIsNotABubble() {
        let blocks = [
            block("hey are you around", x: 0.05, y: 0.3, width: 0.35, window: slack),
            block("Slack — #general — 40 members online", x: 0.0, y: 0.0, width: 0.98, window: slack),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .composing)
    }

    @Test("Message-list geometry in a non-chat-register app never triggers replying")
    func nonChatAppNeverReplies() {
        let blocks = [
            block("hey are you around", x: 0.05, y: 0.30, window: textEdit),
            block("yeah free after 3", x: 0.55, y: 0.60, window: textEdit),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: "")
        #expect(scene.mode == .composing)
    }

    // MARK: - Replying: mode, ordering, speaker attribution

    @Test("Chat register + vertical message list classifies as replying with ordered turns")
    func chatMessageListIsReplying() {
        let blocks = [
            block("hey are you around today", x: 0.05, y: 0.30, window: slack), // left -> other, oldest
            block("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack), // right -> self, newest
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 2)
        #expect(scene.conversationTurns[0].speaker == .other)
        #expect(scene.conversationTurns[0].text == "hey are you around today")
        #expect(scene.conversationTurns[1].speaker == .selfSpeaker)
        #expect(scene.conversationTurns[1].text == "yeah free after 3pm works")
        #expect(scene.referenceSnippets.isEmpty)
    }

    @Test("A block straddling the horizontal center is ambiguous and attributed to other")
    func ambiguousAlignmentFallsBackToOther() {
        let blocks = [
            block("centered system message", x: 0.30, y: 0.30, width: 0.40, window: slack), // center 0.50
            block("clearly on the right", x: 0.60, y: 0.60, width: 0.35, window: slack), // center 0.775 -> self
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns[0].speaker == .other)
        #expect(scene.conversationTurns[1].speaker == .selfSpeaker)
    }

    @Test("Blocks not attributed to any window still count toward the frontmost app's list")
    func unattributedBlocksCountAsOwnWindow() {
        let blocks = [
            block("hey are you around today", x: 0.05, y: 0.30, window: nil),
            block("yeah free after 3pm works", x: 0.55, y: 0.60, window: nil),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 2)
    }

    @Test("A bubble from a different window is excluded from the reply thread")
    func otherWindowBubbleExcludedFromReplyThread() {
        let blocks = [
            block("hey are you around today", x: 0.05, y: 0.30, window: slack),
            block("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
            block("unrelated note from another app", x: 0.10, y: 0.45, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 2)
        #expect(!scene.conversationTurns.contains { $0.text.contains("unrelated note") })
    }

    // MARK: - Replying: caps

    @Test("At most 3 turns survive, keeping the most recent (bottom-most) ones")
    func capsAtThreeMostRecentTurns() {
        let blocks = [
            block("message one oldest", x: 0.05, y: 0.10, window: slack),
            block("message two", x: 0.55, y: 0.30, window: slack),
            block("message three", x: 0.05, y: 0.50, window: slack),
            block("message four", x: 0.55, y: 0.70, window: slack),
            block("message five newest", x: 0.05, y: 0.90, window: slack),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 3)
        let texts = scene.conversationTurns.map(\.text)
        #expect(texts == ["message three", "message four", "message five newest"])
    }

    @Test("Turn text is capped to a 600-character combined budget, freshest kept fullest")
    func turnsShareA600CharacterBudget() {
        let oldest = String(repeating: "a", count: 300)
        let middle = String(repeating: "b", count: 300)
        let newest = String(repeating: "c", count: 300)
        let blocks = [
            block(oldest, x: 0.05, y: 0.10, window: slack),
            block(middle, x: 0.55, y: 0.40, window: slack),
            block(newest, x: 0.05, y: 0.70, window: slack),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: "")
        let totalChars = scene.conversationTurns.reduce(0) { $0 + $1.text.count }
        #expect(totalChars <= ScreenScene.maxTurnsCharacterBudget)
        // Newest turn is spent first and kept fully intact.
        #expect(scene.conversationTurns.last?.text == newest)
        #expect(scene.conversationTurns.last?.text.count == 300)
        // Combined budget (600) leaves only 300 left for everything older than newest,
        // so the oldest turn is the one that gets dropped or truncated first.
        #expect(scene.conversationTurns.count <= 2)
    }

    @Test("A bubble duplicating field text is excluded from the reply thread (dedupe)")
    func duplicateBubbleExcludedFromTurns() {
        let fieldText = "typing a reply about the schedule"
        let blocks = [
            block("about the schedule", x: 0.05, y: 0.30, window: slack), // substring of fieldText, deduped
            block("yeah free after 3pm works", x: 0.55, y: 0.60, window: slack),
            block("what time were you thinking", x: 0.05, y: 0.80, window: slack),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: fieldText)
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 2)
        #expect(!scene.conversationTurns.contains { $0.text == "about the schedule" })
    }

    @Test("Short bubble text is exempt from dedupe so trivial matches don't vanish")
    func shortBubbleTextExemptFromDedupe() {
        // "ok" would "match" almost any field text if containment applied unconditionally.
        let fieldText = "ok, sounds good, talk soon"
        let blocks = [
            block("ok", x: 0.05, y: 0.30, window: slack),
            block("sounds good, talk soon then", x: 0.55, y: 0.60, window: slack),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: slack, fieldText: fieldText)
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.contains { $0.text == "ok" })
    }

    // MARK: - Referencing

    @Test("Text in a non-frontmost window sharing a rare word with the current sentence is a reference")
    func crossWindowSharedRareWordIsReferencing() {
        let fieldText = "Thanks for sending that over. Let me check the invoice number for acme corp"
        let blocks = [
            block("Invoice #48213 — Acme Corp — due Friday", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .referencing)
        #expect(scene.referenceSnippets == ["Invoice #48213 — Acme Corp — due Friday"])
        #expect(scene.conversationTurns.isEmpty)
    }

    @Test("Among multiple qualifying blocks, the largest by character count is chosen")
    func referencingPicksLargestQualifyingBlock() {
        let fieldText = "checking the invoice details now"
        let blocks = [
            block("invoice #1", x: 0.60, y: 0.20, window: notes),
            block("Invoice #48213 for the Acme Corp account, due Friday next week", x: 0.60, y: 0.40, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .referencing)
        #expect(scene.referenceSnippets == ["Invoice #48213 for the Acme Corp account, due Friday next week"])
    }

    @Test("A block from the frontmost window is never treated as a reference")
    func frontmostWindowBlockExcludedFromReferencing() {
        let fieldText = "checking the invoice details now"
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: textEdit),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    @Test("A block with no window attribution is never treated as a reference")
    func unattributedBlockExcludedFromReferencing() {
        let fieldText = "checking the invoice details now"
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: nil),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    @Test("A block sharing no rare word with the current sentence is not a reference")
    func unrelatedBlockIsNotAReference() {
        let fieldText = "checking the weather forecast for tomorrow"
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    @Test("A block already visible in the field text is deduped out of referencing")
    func referenceBlockDuplicatingFieldTextIsDeduped() {
        let fieldText = "as discussed, the invoice number for acme corp is 48213"
        let blocks = [
            block("the invoice number for acme corp is 48213", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    @Test("Reference snippet is capped at 400 characters")
    func referenceSnippetCappedAt400Characters() {
        let fieldText = "checking the invoice details now"
        let longText = "Invoice details: " + String(repeating: "x", count: 500)
        let blocks = [block(longText, x: 0.60, y: 0.20, window: notes)]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .referencing)
        #expect(scene.referenceSnippets.first?.count == ScreenScene.maxReferenceCharacters)
        #expect(longText.hasPrefix(scene.referenceSnippets.first!))
    }

    @Test("Empty field text has no current sentence, so referencing never fires")
    func emptyFieldTextNeverReferences() {
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: "")
        #expect(scene.mode == .composing)
    }

    @Test("Only stopwords in the current sentence never yields a reference")
    func stopwordOnlySentenceNeverReferences() {
        let fieldText = "well then that would be with them"
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    @Test("Only the sentence currently being typed is matched, not earlier finished sentences")
    func onlyCurrentSentenceIsMatchedAgainst() {
        // "invoice" only appears in the finished first sentence, not the one in progress.
        let fieldText = "The invoice looks correct. Now let's talk about tomorrow's weather"
        let blocks = [
            block("Invoice #48213 for Acme Corp, due Friday", x: 0.60, y: 0.20, window: notes),
        ]
        let scene = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(scene.mode == .composing)
    }

    // MARK: - Determinism

    @Test("Classifying the same snapshot twice yields identical scenes")
    func classificationIsDeterministic() {
        let fieldText = "checking the invoice details now"
        let blocks = [
            block("invoice #1", x: 0.60, y: 0.20, window: notes),
            block("Invoice #48213 for the Acme Corp account, due Friday next week", x: 0.60, y: 0.40, window: notes),
            block("hey are you around today", x: 0.05, y: 0.30, window: slack),
        ]
        let first = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        let second = ScreenScene.classify(blocks: blocks, frontmostBundleID: textEdit, fieldText: fieldText)
        #expect(first == second)
    }
}
