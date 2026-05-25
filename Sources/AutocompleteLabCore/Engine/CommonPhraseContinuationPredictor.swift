import Foundation

public struct CommonPhraseContinuationPrior: Equatable, Sendable {
    public let contextSuffix: String
    public let continuation: String
    public let score: Double

    public init(contextSuffix: String, continuation: String, score: Double) {
        self.contextSuffix = Self.normalizedPhrase(contextSuffix)
        self.continuation = Self.normalizedPhrase(continuation)
        self.score = score
    }

    public var continuationWords: [String] {
        Self.words(in: continuation)
    }

    public static let defaultPriors: [CommonPhraseContinuationPrior] = [
        CommonPhraseContinuationPrior(contextSuffix: "smoke proof feels", continuation: "instant", score: 0.34),
        CommonPhraseContinuationPrior(contextSuffix: "and stays", continuation: "instant", score: 0.34),
        CommonPhraseContinuationPrior(contextSuffix: "we should keep this", continuation: "small", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "the draft is almost", continuation: "ready", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "please make this", continuation: "clearer", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "this feels genuinely", continuation: "useful", score: 0.32),
        CommonPhraseContinuationPrior(contextSuffix: "i just wanted to", continuation: "follow up", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "i think we should", continuation: "make sure", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "when this works we can", continuation: "keep moving", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "the app should", continuation: "stay quiet", score: 0.30),
        CommonPhraseContinuationPrior(contextSuffix: "can you please", continuation: "take a look", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "we should probably", continuation: "keep it simple", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i want to", continuation: "move this forward", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "it would help to", continuation: "make it easier", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i want this note to feel", continuation: "light and clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the draft feels calmer when it", continuation: "stays short and specific", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the review should focus on", continuation: "real user risk", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "a good reply here would be", continuation: "short kind and specific", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "before we ship we should", continuation: "run one small check", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the meeting notes need a", continuation: "clear next step", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the onboarding screen should make", continuation: "permission feel clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the local test should fail only when", continuation: "proof is missing", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "make the copy", continuation: "short and clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "hold the risky path until", continuation: "proof exists", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "this bug is easiest to test with", continuation: "small fixture case", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "after the demo capture the", continuation: "open questions quickly", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "product update should mention", continuation: "one clear change", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "in obsidian this note should capture", continuation: "the key details clearly", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "before touching the terminal command we should", continuation: "verify the input", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "a quick text back should say", continuation: "something short and clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "while i am typing fast it should", continuation: "stay short and clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the suggestion should be less timid and", continuation: "more confident about next words", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the next suggestion should be a", continuation: "short useful phrase", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "build the app run the proof write the", continuation: "small repro", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "tested the button tested the button and now need", continuation: "one fresh check", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the quiet mode should stay", continuation: "calm in the background", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the next step is to", continuation: "write a small repro", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "autocomplete should", continuation: "stay silent when unsafe", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "press tab and confirm", continuation: "next word only", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the browser comment should be", continuation: "short and clear", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "today i want to focus on", continuation: "small focused tasks", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i am trying to say this in a way that feels", continuation: "natural and human", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the message should make one thing", continuation: "clear right away", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the action item needs an", continuation: "owner and deadline", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "what i want is", continuation: "something fast and reliable", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "this should feel", continuation: "fast enough to trust", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "if this works tomorrow i will", continuation: "leave it turned on", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i want this to", continuation: "finish the sentence naturally", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the biggest problem is", continuation: "suggestions feel too timid", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "what kills trust most is", continuation: "wrong fields showing up", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "it should almost always", continuation: "show up while writing", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "this needs to feel", continuation: "fast enough to trust", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "when i hit tab it should", continuation: "accept exactly the next word", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the best daily driver shape is", continuation: "short phrase autocomplete", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i think what matters is", continuation: "that it feels effortless", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "what i am trying to say is", continuation: "this should feel natural", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the next thing i want to", continuation: "write is the thought", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "this would be better if it", continuation: "predicted the next phrase", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the way i would say it is", continuation: "keep it very simple", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "what makes this useful is", continuation: "getting the words right", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "when this feels magical it", continuation: "knows the next phrase", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "if i am writing fast i", continuation: "want help finishing thoughts", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the most important thing is to", continuation: "keep the scope small", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "i am trying to", continuation: "figure out how to", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "this sentence should continue", continuation: "without sounding too formal", score: 0.26),
        CommonPhraseContinuationPrior(contextSuffix: "the safest version is to", continuation: "make this easier to", score: 0.26)
    ]

    private static func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func words(in text: String) -> [String] {
        normalizedPhrase(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

public struct CommonPhraseContinuationSelection: Equatable, Sendable {
    public let suggestion: CompletionSuggestion?
    public let matchedContextSuffix: String?
    public let score: Double?
    public let suppressionReason: String?

    public init(
        suggestion: CompletionSuggestion?,
        matchedContextSuffix: String?,
        score: Double?,
        suppressionReason: String?
    ) {
        self.suggestion = suggestion
        self.matchedContextSuffix = matchedContextSuffix
        self.score = score
        self.suppressionReason = suppressionReason
    }

    public var traceMetadata: [String: String] {
        [
            "candidateSelectionSource": "predictive-phrase-fallback",
            "cleanedCandidateCount": suggestion == nil ? "0" : "1",
            "candidateTopScore": score.map { String(format: "%.3f", $0) } ?? "none",
            "candidateScoreMargin": "none",
            "candidateSuppressionReason": suppressionReason ?? "none",
            "predictivePhraseMatch": matchedContextSuffix ?? "none"
        ]
    }
}

private struct CommonPhraseContinuationCandidate: Equatable, Sendable {
    let continuation: String
    let matchLabel: String
    let score: Double
}

public struct CommonPhraseContinuationPredictor: Equatable, Sendable {
    public let priors: [CommonPhraseContinuationPrior]

    public init(priors: [CommonPhraseContinuationPrior] = CommonPhraseContinuationPrior.defaultPriors) {
        self.priors = priors
    }

    public func suggestion(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4
    ) -> CompletionSuggestion? {
        selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords
        ).suggestion
    }

    public func selection(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(for: behaviorProfileID) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "unsupported-profile"
            )
        }

        let trimmed = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, last.isLetter || last.isNumber else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "not-word-boundary"
            )
        }

        let context = normalizedPhrase(trimmed)
        guard !context.isEmpty else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "empty-context"
            )
        }

        guard let candidate = bestCandidate(for: context) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "no-match"
            )
        }

        let clampedMaxWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        let suggestion = CompletionSuggestion(
            text: " \(candidate.continuation)",
            maxVisibleWords: clampedMaxWords
        )

        return CommonPhraseContinuationSelection(
            suggestion: suggestion,
            matchedContextSuffix: candidate.matchLabel,
            score: candidate.score,
            suppressionReason: nil
        )
    }

    private func bestCandidate(for context: String) -> CommonPhraseContinuationCandidate? {
        if let prior = bestPrior(for: context) {
            return CommonPhraseContinuationCandidate(
                continuation: prior.continuation,
                matchLabel: prior.contextSuffix,
                score: prior.score
            )
        }

        return intentPatternCandidate(for: context)
    }

    private func bestPrior(for context: String) -> CommonPhraseContinuationPrior? {
        priors
            .filter { context.hasSuffix($0.contextSuffix) }
            .sorted {
                let lhsWords = $0.contextSuffix.split(separator: " ").count
                let rhsWords = $1.contextSuffix.split(separator: " ").count
                if lhsWords != rhsWords {
                    return lhsWords > rhsWords
                }

                return $0.score > $1.score
            }
            .first
    }

    private func intentPatternCandidate(for context: String) -> CommonPhraseContinuationCandidate? {
        let words = words(in: context)
        guard words.count >= 2 else {
            return nil
        }

        if hasSuffix(["what", "i", "mean", "is"], in: words) {
            return intentCandidate("what-i-mean-is", "this should feel natural")
        }
        if hasAnySuffix([["my", "point", "is"], ["the", "point", "is"]], in: words) {
            return intentCandidate("point-is", "this should feel clear")
        }
        if hasSuffix(["better", "if", "it"], in: words),
           words.contains(where: { ["app", "draft", "feature", "message", "suggestion", "this"].contains($0) }) {
            return intentCandidate("better-if-it", "predicted the next phrase")
        }
        if hasSuffix(["we", "need", "to"], in: words) {
            return intentCandidate("we-need-to", "make this feel simpler")
        }
        if hasSuffix(["i", "need", "to"], in: words) {
            return intentCandidate("i-need-to", "say this more clearly")
        }
        if hasSuffix(["next", "step", "is"], in: words) {
            return intentCandidate("next-step-is", "to make this concrete")
        }
        if hasSuffix(["the", "goal", "is"], in: words) {
            return intentCandidate("the-goal-is", "to make writing faster")
        }
        if hasSuffix(["can", "you"], in: words) {
            return intentCandidate("can-you", "take a look at")
        }

        return nil
    }

    private func intentCandidate(_ label: String, _ continuation: String) -> CommonPhraseContinuationCandidate {
        CommonPhraseContinuationCandidate(
            continuation: continuation,
            matchLabel: "intent-\(label)",
            score: 0.27
        )
    }

    private func allowsPrediction(for behaviorProfileID: AutocompleteBehaviorProfileID?) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat), .some(.coding), .some(.forms), .some(.search):
            false
        case .some, .none:
            true
        }
    }

    private func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func words(in text: String) -> [String] {
        normalizedPhrase(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private func hasAnySuffix(_ suffixes: [[String]], in words: [String]) -> Bool {
        suffixes.contains { hasSuffix($0, in: words) }
    }

    private func hasSuffix(_ suffix: [String], in words: [String]) -> Bool {
        guard words.count >= suffix.count else {
            return false
        }
        return Array(words.suffix(suffix.count)) == suffix
    }
}
