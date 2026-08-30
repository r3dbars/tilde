import Foundation

/// Rejects a suggestion that invents a fact the writer never saw. A
/// suggestion may only carry factual anchors — numbers, addresses, dates,
/// names — that already appear in what the writer typed or in the scene on
/// screen. Anything else is the model asserting something on the writer's
/// behalf, and the honest answer to that is silence.
///
/// This was Tilde Lab's `LabOutputJudge` grounding rule first; Q12 measured
/// it offline and on the development partition (35 unsupported-fact wrongs
/// removed at zero useful displays lost) and nominated it as a validation
/// candidate. The rule lives here so the product path and the Lab judge
/// share one implementation rather than two that can drift; the Lab judge
/// calls straight into it.
public enum FactualGroundingPolicy {
    public enum Mode: String, Equatable, Sendable {
        case off
        case numbersAndNames = "numbers-and-names"
        case allAnchors = "all-anchors"
    }

    /// True when the candidate carries a factual anchor that neither the
    /// typed context nor the scene supports. Fails closed: an unsupported
    /// anchor means no suggestion.
    public static func containsUnsupportedFact(
        _ candidate: String,
        typedContext: String,
        scene: ScreenScene.Scene?,
        mode: Mode
    ) -> Bool {
        guard mode != .off else { return false }
        let source = ([typedContext]
            + (scene?.conversationTurns.map(\.text) ?? [])
            + (scene?.referenceSnippets ?? []))
            .joined(separator: " ")
        let allowed = factualAnchors(in: source, mode: mode, dropsLeadingCapital: false)
        let offered = factualAnchors(in: candidate, mode: mode, dropsLeadingCapital: true)
        return !offered.isSubset(of: allowed)
    }

    /// The anchors a piece of text asserts, folded to lowercase.
    ///
    /// `dropsLeadingCapital` is set for the candidate side only: a
    /// continuation's first token is capitalized by sentence position, not
    /// because it names anything.
    public static func factualAnchors(
        in text: String,
        mode: Mode,
        dropsLeadingCapital: Bool
    ) -> Set<String> {
        let tokens = text.split { !$0.isLetter && !$0.isNumber && $0 != "@" }
        var result = Set<String>()
        for (index, tokenValue) in tokens.enumerated() {
            let token = String(tokenValue)
            let folded = token.lowercased()
            let hasDigit = token.contains(where: \.isNumber)
            let isCapitalized = token.first?.isUppercase == true && !(dropsLeadingCapital && index == 0)
            let isKnownFactWord = factWords.contains(folded)
            let isEmailish = token.contains("@")
            if hasDigit || isEmailish || isKnownFactWord || isCapitalized {
                if !ignoredCapitalizedWords.contains(folded) { result.insert(folded) }
            } else if mode == .allAnchors, token.count >= 7 {
                result.insert(folded)
            }
        }
        return result
    }

    static let factWords: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december", "today", "tomorrow", "yesterday",
        "am", "pm", "noon", "midnight",
    ]

    static let ignoredCapitalizedWords: Set<String> = [
        "i", "yes", "no", "okay", "ok", "thanks", "thank", "sure", "sounds", "sorry",
    ]
}
