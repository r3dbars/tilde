import Foundation

/// 2026-08-16 trust-critical fix (build 2705 dogfood): a demo conversation
/// carried "my dad passed away this morning" / "funeral is going to be next
/// week" in the other party's messages. Two live failures followed —
/// Case A: the user typed "I am so sorry, I will be at the funeral" and the
/// ghost offered "of my friend, I will be there" (garbled relationship: it
/// was Alex's dad, not the user's friend, plus a redundant echo). Case B,
/// worse: the user typed "I'm so" and the ghost offered "sorry I'm late, I"
/// — a lateness cliché completing over visible grief context. Owner verdict:
/// "this doesn't work well."
///
/// Small on-device models cannot reliably do relationship reasoning or match
/// register in a grief/crisis conversation, so the correct product behavior
/// is suppression, not a better guess. This is consistent with the repo's
/// top rule ("silence and noise are both failures" — here noise is a
/// catastrophic failure and silence is the respectful one).
///
/// `SensitiveScenePolicy` is pure, deterministic, and Core-only (no AppKit,
/// no I/O): it looks at a classified `ScreenScene.Scene`'s conversation
/// turns for phrases that mark an emotionally sensitive context and, if any
/// match, tells the caller to withhold the suggestion entirely rather than
/// try to produce one.
///
/// Deliberately blunt v1: word-boundary, case-insensitive substring matching
/// against a single flat phrase table, no NLP, no LLM call. It will both
/// miss sensitive scenes phrased unusually and occasionally fire on
/// look-alike phrasing (see `SensitiveScenePolicyTests` for the accepted
/// "surgical strike" false-positive tradeoff). Given the asymmetry — a wrong
/// suggestion in a grief conversation is a product-killing event, an
/// unnecessary silence is invisible — erring toward suppression is the
/// correct v1 shape. Keep the phrase table data-driven and easy to extend
/// rather than growing per-category special-casing.
public enum SensitiveScenePolicy {
    /// One sensitivity class and the phrases that mark it. Data-driven by
    /// design: adding a new sensitive-context class is "add a case and a
    /// phrase list," never new matching logic.
    public enum Category: String, CaseIterable, Equatable, Sendable {
        case bereavement
        case medicalCrisis
        case emergency
        case relationshipEnding
        case jobLoss
    }

    /// Phrases are matched case-insensitively with word/phrase boundaries
    /// (see `containsPhrase`), so entries should be written lowercase and as
    /// their natural reading form — no need to hand-author regex.
    static let phrasesByCategory: [Category: [String]] = [
        .bereavement: [
            "passed away", "passed on", "passing away",
            "funeral", "funeral home", "memorial service",
            "condolences", "my condolences",
            "loss of my", "loss of her", "loss of his", "loss of our",
            "rip", "rest in peace",
            "he died", "she died", "they died", "he's dead", "she's dead",
            "in loving memory",
        ],
        .medicalCrisis: [
            "in the hospital", "in the er", "in the emergency room",
            "rushed to the hospital",
            "diagnosis", "diagnosed with",
            "surgery went", "went into surgery", "emergency surgery",
            "in the icu", "intensive care",
            "terminal", "stage 4", "stage four",
            "biopsy",
        ],
        .emergency: [
            "car accident", "car crash", "was in an accident",
            "911", "ambulance",
            "house fire", "in a fire",
            "missing person", "went missing",
        ],
        .relationshipEnding: [
            "we broke up", "breaking up with", "broke up with me",
            "filing for divorce", "getting a divorce", "we're divorcing",
            "separated from", "left me",
        ],
        .jobLoss: [
            "got laid off", "laid off from", "was laid off",
            "lost my job", "got fired", "was fired",
            "let go from work",
        ],
    ]

    /// Whether the classified scene should suppress this completion entirely.
    ///
    /// `scene == nil` (no Screen Memory context available for this request,
    /// e.g. plain typing with no screen capture) never fires — the policy
    /// only reasons about text it was actually handed via Screen Memory, so
    /// ordinary context-free typing is completely unaffected.
    ///
    /// Every conversation turn is checked regardless of speaker, but the
    /// policy is deliberately conservative toward suppression on the OTHER
    /// speaker's turns in particular: it's the other party's disclosure
    /// (grief, a diagnosis, a breakup) that small models are least equipped
    /// to reason about correctly, and that's exactly what happened in both
    /// live failure cases above.
    public static func isSensitive(scene: ScreenScene.Scene?) -> Bool {
        guard let scene else { return false }
        return scene.conversationTurns.contains { turn in
            matchedCategory(in: turn.text) != nil
        }
    }

    /// Same decision as `isSensitive`, but also returns which category
    /// fired first (deterministic `Category.allCases` order) — useful for
    /// diagnostics or future tuning, though today's caller only logs a
    /// count, never the category or the matched text.
    static func matchedCategory(scene: ScreenScene.Scene?) -> Category? {
        guard let scene else { return nil }
        for turn in scene.conversationTurns {
            if let category = matchedCategory(in: turn.text) {
                return category
            }
        }
        return nil
    }

    private static func matchedCategory(in text: String) -> Category? {
        for category in Category.allCases {
            guard let phrases = phrasesByCategory[category] else { continue }
            if phrases.contains(where: { containsPhrase($0, in: text) }) {
                return category
            }
        }
        return nil
    }

    /// Case-insensitive containment with word/phrase boundaries: the phrase
    /// must not be immediately preceded or followed by another letter or
    /// digit, so e.g. "rip" doesn't match inside "ripe" or "stripped", and
    /// "died" doesn't match inside "died-in-the-wool" (not a real word, but
    /// illustrates the guard). This is intentionally simple substring/regex
    /// matching, not tokenization, so multi-word phrases ("passed away")
    /// still match across normal whitespace but not across punctuation-glued
    /// runs.
    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
