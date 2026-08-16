import Foundation

/// Turns raw on-device OCR blocks (Screen Memory's capture output, Phase 1)
/// into a bounded, classified `Scene` the completion engine can fold into a
/// prompt (Phase 2b). Pure and deterministic — no LLM, no I/O, no knowledge
/// of ScreenCaptureKit, Vision, or persistence. The App target owns turning
/// pixels into `OCRBlock`s; this type only reasons about the blocks it is
/// handed.
///
/// Screen Memory plan, Phase 2 PR 2a (`docs/plans/screen-memory.md`).
public enum ScreenScene {
    /// A unit-square rectangle in the display's coordinate space, origin at
    /// the top-left, matching Vision's normalized `boundingBox` convention
    /// (x/y/width/height all in `0...1`). No AppKit/CoreGraphics dependency —
    /// Core stays framework-free.
    public struct NormalizedRect: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        /// Horizontal midpoint — the input to left/right speaker bucketing.
        var centerX: Double { x + width / 2 }
    }

    /// One block of OCR'd text from a full-display capture, as Phase 1's
    /// `ScreenCaptureService` would emit it: text plus where on screen it
    /// sat and, where SCWindow metadata resolved it, which window it came
    /// from. `windowOwnerBundleID` is `nil` when attribution wasn't
    /// possible — callers should treat that as "unknown", not "frontmost".
    public struct OCRBlock: Equatable, Sendable {
        public let text: String
        public let boundingBox: NormalizedRect
        public let windowOwnerBundleID: String?
        public let windowTitle: String?

        public init(
            text: String,
            boundingBox: NormalizedRect,
            windowOwnerBundleID: String? = nil,
            windowTitle: String? = nil
        ) {
            self.text = text
            self.boundingBox = boundingBox
            self.windowOwnerBundleID = windowOwnerBundleID
            self.windowTitle = windowTitle
        }
    }

    /// What the screen appears to be doing right now.
    public enum Mode: String, Equatable, Sendable {
        /// Frontmost app is a chat register and its own window shows a
        /// vertical message list: the user is replying to a conversation.
        case replying
        /// A non-frontmost window shows text that shares vocabulary with
        /// what's being typed: the user is composing while referencing it.
        case referencing
        /// Neither signal fired. Exactly today's (no-context) behavior.
        case composing
    }

    /// Who plausibly said a conversation turn. Attribution is a left/right
    /// alignment guess, not identity — `other` is also the fallback for
    /// "couldn't tell," so an unreadable layout never gets misread as the
    /// user's own words.
    public enum Speaker: String, Equatable, Sendable {
        case selfSpeaker = "self"
        case other
    }

    public struct ConversationTurn: Equatable, Sendable {
        public let speaker: Speaker
        public let text: String

        public init(speaker: Speaker, text: String) {
            self.speaker = speaker
            self.text = text
        }
    }

    public struct Scene: Equatable, Sendable {
        public let mode: Mode
        public let conversationTurns: [ConversationTurn]
        public let referenceSnippets: [String]

        public init(mode: Mode, conversationTurns: [ConversationTurn], referenceSnippets: [String]) {
            self.mode = mode
            self.conversationTurns = conversationTurns
            self.referenceSnippets = referenceSnippets
        }

        static let empty = Scene(mode: .composing, conversationTurns: [], referenceSnippets: [])
    }

    // MARK: - Caps (plan: "Everything capped")

    /// At most this many conversation turns survive into the scene.
    public static let maxTurns = 3
    /// Combined character budget across every surviving turn's text.
    public static let maxTurnsCharacterBudget = 600
    /// Character cap on the single reference snippet.
    public static let maxReferenceCharacters = 400

    // MARK: - Classification

    /// - Parameters:
    ///   - blocks: every OCR block from the latest snapshot, full-display.
    ///   - frontmostBundleID: the app the user is typing into right now.
    ///   - fieldText: the text already in the field (IMKit already has
    ///     this; used only to dedupe and to find "the current sentence").
    public static func classify(
        blocks: [OCRBlock],
        frontmostBundleID: String?,
        fieldText: String
    ) -> Scene {
        if let frontmostBundleID, ContinuationRegister.from(bundleIdentifier: frontmostBundleID) == .chat {
            let ownWindowBlocks = blocks.filter {
                $0.windowOwnerBundleID == nil || $0.windowOwnerBundleID == frontmostBundleID
            }
            if looksLikeMessageList(ownWindowBlocks) {
                let turns = conversationTurns(from: ownWindowBlocks, fieldText: fieldText)
                if !turns.isEmpty {
                    return Scene(mode: .replying, conversationTurns: turns, referenceSnippets: [])
                }
            }
        }

        let snippets = referenceSnippets(from: blocks, frontmostBundleID: frontmostBundleID, fieldText: fieldText)
        if !snippets.isEmpty {
            return Scene(mode: .referencing, conversationTurns: [], referenceSnippets: snippets)
        }

        return .empty
    }

    // MARK: - Replying: message-list geometry + speaker attribution

    /// A message list is at least two bubble-width (not full-bleed) blocks
    /// spread across at least two distinct vertical bands. Full-width blocks
    /// (toolbars, banners, a single huge paste) don't count as bubbles.
    private static let bubbleMaxWidth = 0.85
    private static let verticalBandCount = 10

    private static func looksLikeMessageList(_ blocks: [OCRBlock]) -> Bool {
        let bubbleBlocks = blocks.filter { $0.boundingBox.width <= bubbleMaxWidth && !$0.text.isEmpty }
        guard bubbleBlocks.count >= 2 else { return false }
        let bands = Set(bubbleBlocks.map { verticalBand(of: $0.boundingBox) })
        return bands.count >= 2
    }

    private static func verticalBand(of rect: NormalizedRect) -> Int {
        Int((rect.y * Double(verticalBandCount)).rounded(.down))
    }

    /// Left-aligned bubbles are read as the other party, right-aligned as
    /// the user, matching the near-universal iMessage/Slack/WhatsApp DM
    /// convention. A block straddling the middle (or left of it) is
    /// ambiguous and falls back to `other` per the plan ("else mark speaker
    /// unknown-other").
    private static let rightBucketMin = 0.58

    private static func speaker(for block: OCRBlock) -> Speaker {
        let center = block.boundingBox.centerX
        if center >= rightBucketMin { return .selfSpeaker }
        return .other
    }

    /// Bottom-most blocks are the most recent messages (the compose field
    /// sits below them). Selects up to `maxTurns`, orders them oldest→newest
    /// for a naturally-readable transcript, and spends the shared character
    /// budget from the newest turn backward so the freshest message never
    /// gets truncated ahead of older ones.
    private static func conversationTurns(from blocks: [OCRBlock], fieldText: String) -> [ConversationTurn] {
        let usable = blocks
            .filter { $0.boundingBox.width <= bubbleMaxWidth && !isDuplicate($0.text, of: fieldText) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.boundingBox.y < $1.boundingBox.y }

        let mostRecent = Array(usable.suffix(maxTurns))

        var remainingBudget = maxTurnsCharacterBudget
        var truncated: [(block: OCRBlock, text: String)] = []
        for block in mostRecent.reversed() {
            guard remainingBudget > 0 else { break }
            let text = String(block.text.prefix(remainingBudget))
            guard !text.isEmpty else { break }
            truncated.append((block, text))
            remainingBudget -= text.count
        }

        return truncated.reversed().map { ConversationTurn(speaker: speaker(for: $0.block), text: $0.text) }
    }

    // MARK: - Referencing: cross-window shared-rare-word snippet

    /// Finds the largest OCR block that (a) confidently comes from a window
    /// other than the frontmost app, (b) isn't already visible in the field
    /// text, and (c) shares at least one rare word with the sentence
    /// currently being typed. Returns at most one snippet — the plan
    /// specifies picking "the largest" qualifying block, not merging many.
    private static func referenceSnippets(
        from blocks: [OCRBlock],
        frontmostBundleID: String?,
        fieldText: String
    ) -> [String] {
        guard let frontmostBundleID else { return [] }
        let sentenceWords = rareWords(in: currentSentence(of: fieldText))
        guard !sentenceWords.isEmpty else { return [] }

        let candidates = blocks.filter { block in
            guard let owner = block.windowOwnerBundleID, owner != frontmostBundleID else { return false }
            guard !isDuplicate(block.text, of: fieldText) else { return false }
            return !rareWords(in: block.text).isDisjoint(with: sentenceWords)
        }

        guard let best = candidates.max(by: { lhs, rhs in
            lhs.text.count == rhs.text.count
                ? lhs.text > rhs.text // deterministic tiebreak, no reliance on input order
                : lhs.text.count < rhs.text.count
        }) else {
            return []
        }

        return [String(best.text.prefix(maxReferenceCharacters))]
    }

    /// The sentence-in-progress: everything after the last sentence
    /// terminator (or the whole field if there isn't one yet).
    private static func currentSentence(of fieldText: String) -> String {
        let terminators: Set<Character> = [".", "!", "?", "\n"]
        if let index = fieldText.lastIndex(where: terminators.contains) {
            let after = fieldText.index(after: index)
            return String(fieldText[after...]).trimmingCharacters(in: .whitespaces)
        }
        return fieldText.trimmingCharacters(in: .whitespaces)
    }

    /// Words that carry topical signal: lowercase, letters/digits only,
    /// long enough to be distinctive, and not on the stopword list. This is
    /// a deliberately simple stand-in for tf-idf (no corpus to compute
    /// document frequency against) — length + stopwords gets most of the
    /// same signal for short chat/prose snippets.
    private static let minimumRareWordLength = 4
    private static func rareWords(in text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count >= minimumRareWordLength && !stopwords.contains($0) }
        )
    }

    private static let stopwords: Set<String> = [
        "this", "that", "these", "those", "with", "from", "your", "have",
        "will", "would", "could", "should", "about", "there", "their",
        "which", "when", "where", "what", "just", "like", "know", "think",
        "want", "need", "going", "gonna", "really", "also", "then", "than",
        "them", "they", "were", "been", "being", "into", "over", "some",
        "more", "most", "much", "very", "here", "okay", "right", "good",
        "well", "sure", "yeah", "yes", "no", "not", "the", "and", "for",
        "are", "was", "you", "our", "his", "her", "its", "can",
    ]

    // MARK: - Dedupe

    /// Skips OCR text that's already visible in the field — no double-
    /// feeding what IMKit already sees. Short strings are exempted from the
    /// containment check (e.g. "ok", "yes") since they'd trivially "match"
    /// almost any field text without actually being the same message.
    private static let dedupeMinimumLength = 6
    private static func isDuplicate(_ candidateText: String, of fieldText: String) -> Bool {
        let trimmed = candidateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= dedupeMinimumLength, !fieldText.isEmpty else { return false }
        return fieldText.contains(trimmed)
    }
}
