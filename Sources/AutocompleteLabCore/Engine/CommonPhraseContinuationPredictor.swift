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
        CommonPhraseContinuationPrior(contextSuffix: "make this setting the feature", continuation: "configurable", score: 0.28),
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
        CommonPhraseContinuationPrior(contextSuffix: "the difference is", continuation: "whether it feels magical", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "what would make me install it is", continuation: "predicting my exact next words", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "this breaks trust when", continuation: "it appears in the wrong field", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the reach test is", continuation: "whether i keep using it", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i would miss it if", continuation: "it disappeared tomorrow", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the fastest version is", continuation: "already waiting with the phrase", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "when suggestions are wrong they", continuation: "break trust immediately", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "the daily driver bar is", continuation: "would i miss it tomorrow", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "i should be able to", continuation: "keep typing without thinking", score: 0.28),
        CommonPhraseContinuationPrior(contextSuffix: "a useful autocomplete should", continuation: "finish the thought in motion", score: 0.28),
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
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CompletionSuggestion? {
        selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        ).suggestion
    }

    public func selection(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(
            for: behaviorProfileID,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        ) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "unsupported-profile"
            )
        }

        let trimmed = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        let clampedMaxWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        guard let last = trimmed.last, last.isLetter || last.isNumber else {
            if let candidate = markdownLabelCandidate(
                for: trimmed,
                behaviorProfileID: behaviorProfileID
            ) {
                return selection(for: candidate, maxVisibleWords: clampedMaxWords)
            }

            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "not-word-boundary"
            )
        }

        let context = normalizedPhrase(trimmed)
        let words = words(in: context)
        guard !context.isEmpty else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "empty-context"
            )
        }

        guard let candidate = bestCandidate(
            for: context,
            rawContext: trimmed,
            words: words,
            behaviorProfileID: behaviorProfileID
        ) else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "no-match"
            )
        }

        return selection(for: candidate, maxVisibleWords: clampedMaxWords)
    }

    private func selection(
        for candidate: CommonPhraseContinuationCandidate,
        maxVisibleWords: Int
    ) -> CommonPhraseContinuationSelection {
        let suggestion = CompletionSuggestion(
            text: " \(candidate.continuation)",
            maxVisibleWords: maxVisibleWords
        )

        return CommonPhraseContinuationSelection(
            suggestion: suggestion,
            matchedContextSuffix: candidate.matchLabel,
            score: candidate.score,
            suppressionReason: nil
        )
    }

    private func bestCandidate(
        for context: String,
        rawContext: String,
        words: [String],
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> CommonPhraseContinuationCandidate? {
        if let prior = bestPrior(for: context) {
            return CommonPhraseContinuationCandidate(
                continuation: prior.continuation,
                matchLabel: prior.contextSuffix,
                score: prior.score
            )
        }

        if let markdownCandidate = markdownLineCandidate(
            for: rawContext,
            words: words,
            behaviorProfileID: behaviorProfileID
        ) {
            return markdownCandidate
        }

        if let writingFlowCandidate = writingFlowCandidate(
            for: words,
            behaviorProfileID: behaviorProfileID
        ) {
            return writingFlowCandidate
        }

        if let dailyDriverFeelingCandidate = dailyDriverFeelingCandidate(for: words) {
            return dailyDriverFeelingCandidate
        }

        if let replyCandidate = messageReplyCandidate(for: words) {
            return replyCandidate
        }

        return intentPatternCandidate(for: words)
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

    private func intentPatternCandidate(for words: [String]) -> CommonPhraseContinuationCandidate? {
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
        if hasSuffix(["because"], in: words), containsDailyDriverTopic(words) {
            return intentCandidate("daily-driver-because", "it saves real time")
        }
        if hasSuffix(["so", "that"], in: words), containsWritingMotionTopic(words) {
            return intentCandidate("daily-driver-so-that", "writing keeps moving forward")
        }
        if hasSuffix(["which", "means"], in: words) {
            if containsAny(["late", "slow", "wrong", "timid", "miss", "misses", "fails", "failure"], in: words) {
                return intentCandidate("daily-driver-which-means-trust", "it loses trust quickly")
            }
            if containsDailyDriverTopic(words) {
                return intentCandidate("daily-driver-which-means", "next step is clear")
            }
        }
        if hasSuffix(["the", "reason", "is"], in: words), containsDailyDriverTopic(words) {
            return intentCandidate("daily-driver-reason-is", "it feels genuinely useful")
        }
        if hasAnySuffix([["the", "fix", "is"], ["fix", "is"]], in: words), containsDailyDriverTopic(words) {
            return intentCandidate("daily-driver-fix-is", "to make it predictable")
        }
        if hasSuffix(["we", "should", "prove"], in: words), containsDailyDriverTopic(words) {
            return intentCandidate("daily-driver-prove", "it works while writing")
        }

        return nil
    }

    private func writingFlowCandidate(
        for words: [String],
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> CommonPhraseContinuationCandidate? {
        guard allowsWritingFlowPrediction(for: behaviorProfileID),
              words.count >= 3 else {
            return nil
        }

        if hasSuffix(["one", "thing", "i", "noticed", "is"], in: words) {
            return intentCandidate("writing-flow-one-thing-i-noticed", "that the flow breaks there")
        }
        if hasSuffix(["what", "i", "know", "so", "far", "is"], in: words) {
            return intentCandidate("writing-flow-what-i-know", "the next step is clear")
        }
        if hasSuffix(["i", "do", "not", "want", "to"], in: words) {
            return intentCandidate("writing-flow-do-not-want-to", "lose the thread here")
        }
        if hasSuffix(["this", "is", "probably", "worth"], in: words) {
            return intentCandidate("writing-flow-probably-worth", "turning into a small test")
        }
        if hasSuffix(["the", "thing", "to", "watch", "is"], in: words) {
            return intentCandidate("writing-flow-thing-to-watch", "where trust breaks first")
        }
        if hasSuffix(["i", "keep", "coming", "back", "to"], in: words) {
            return intentCandidate("writing-flow-coming-back-to", "the same core problem")
        }
        if hasSuffix(["the", "useful", "version", "is"], in: words) {
            return intentCandidate("writing-flow-useful-version", "small fast and reliable")
        }
        if hasSuffix(["before", "i", "move", "on", "i", "should"], in: words) {
            return intentCandidate("writing-flow-before-moving-on", "capture the next step")
        }
        if hasSuffix(["this", "note", "is", "really", "about"], in: words) {
            return intentCandidate("writing-flow-note-about", "the decision we need")
        }
        if hasSuffix(["the", "next", "pass", "should"], in: words) {
            return intentCandidate("writing-flow-next-pass", "make the point clearer")
        }
        if hasSuffix(["the", "thing", "i", "keep", "missing", "is"], in: words) {
            return intentCandidate("writing-flow-thing-i-keep-missing", "the shape of the problem")
        }
        if hasSuffix(["what", "i", "need", "next", "is"], in: words) {
            return intentCandidate("writing-flow-what-i-need-next", "a clearer path forward")
        }
        if hasSuffix(["the", "part", "that", "matters", "is"], in: words) {
            return intentCandidate("writing-flow-part-that-matters", "where the user gets stuck")
        }
        if hasSuffix(["a", "better", "way", "to", "say", "this", "is"], in: words) {
            return intentCandidate("writing-flow-better-way-to-say-this", "keep it simple and direct")
        }
        if hasSuffix(["the", "tradeoff", "is"], in: words) {
            return intentCandidate("writing-flow-tradeoff-is", "speed without losing trust")
        }

        return nil
    }

    private func dailyDriverFeelingCandidate(for words: [String]) -> CommonPhraseContinuationCandidate? {
        guard words.count >= 3,
              containsDailyDriverTopic(words) || containsWritingMotionTopic(words) || containsFeelingTopic(words) else {
            return nil
        }

        if hasAnySuffix([
            ["feels", "wrong"],
            ["feels", "off"],
            ["feels", "weird"]
        ], in: words) {
            return intentCandidate("daily-driver-feels-wrong", "when placement breaks trust")
        }
        if hasAnySuffix([
            ["fall", "short"],
            ["falls", "short"],
            ["falling", "short"]
        ], in: words) {
            return intentCandidate("daily-driver-falls-short", "when suggestions feel generic")
        }
        if hasAnySuffix([
            ["not", "quite", "there"],
            ["not", "there", "yet"]
        ], in: words) {
            return intentCandidate("daily-driver-not-there-yet", "because trust still breaks")
        }
        if hasSuffix(["use", "this", "every", "day"], in: words) {
            return intentCandidate("daily-driver-use-every-day", "if it predicts my next thought")
        }
        if hasAnySuffix([
            ["make", "me", "use", "this"],
            ["make", "me", "install", "this"],
            ["make", "me", "keep", "this", "on"]
        ], in: words) {
            return intentCandidate("daily-driver-make-me-use-this", "is trusting the next phrase")
        }
        if hasAnySuffix([
            ["keep", "reaching", "for", "it", "when"],
            ["reach", "for", "it", "when"],
            ["reaching", "for", "it", "when"]
        ], in: words) {
            return intentCandidate("daily-driver-reach-for-it-when", "it predicts my next thought")
        }
        if hasAnySuffix([
            ["as", "a", "daily", "driver"],
            ["like", "a", "daily", "driver"]
        ], in: words) {
            return intentCandidate("daily-driver-as-daily-driver", "it has to feel effortless")
        }
        if hasAnySuffix([
            ["feels", "slow"],
            ["feels", "heavy"]
        ], in: words) {
            return intentCandidate("daily-driver-feels-slow", "enough to break flow")
        }

        return nil
    }

    private func messageReplyCandidate(for words: [String]) -> CommonPhraseContinuationCandidate? {
        guard words.count >= 2 else {
            return nil
        }

        if hasSuffix(["sounds", "good"], in: words) {
            return intentCandidate("reply-sounds-good", "to me")
        }
        if hasSuffix(["that", "makes", "sense"], in: words) {
            return intentCandidate("reply-that-makes-sense", "to me")
        }
        if hasAnySuffix([["i", "can"], ["let", "me"], ["happy", "to"]], in: words) {
            return intentCandidate("reply-take-a-look", "take a look")
        }
        if hasSuffix(["i", "can", "take"], in: words) {
            return intentCandidate("reply-take-a-look", "a look")
        }
        if hasSuffix(["thanks", "for"], in: words) {
            return intentCandidate("reply-thanks-for", "sending this over")
        }
        if hasSuffix(["yes", "please"], in: words) {
            return intentCandidate("reply-yes-please", "that works for me")
        }
        if hasSuffix(["no", "worries"], in: words) {
            return intentCandidate("reply-no-worries", "at all")
        }

        return nil
    }

    private func markdownLabelCandidate(
        for rawContext: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> CommonPhraseContinuationCandidate? {
        guard allowsMarkdownNotePrediction(for: behaviorProfileID) else {
            return nil
        }

        let line = currentLine(in: rawContext)
        guard line.hasSuffix(":") else {
            return nil
        }

        return markdownCandidate(forLine: String(line.dropLast()))
    }

    private func markdownLineCandidate(
        for rawContext: String,
        words: [String],
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> CommonPhraseContinuationCandidate? {
        guard allowsMarkdownNotePrediction(for: behaviorProfileID) else {
            return nil
        }

        if let candidate = markdownCandidate(forLine: currentLine(in: rawContext)) {
            return candidate
        }

        if hasSuffix(["what", "matters", "today"], in: words) {
            return intentCandidate("markdown-what-matters-today", "is the next clear step")
        }
        if hasSuffix(["before", "i", "forget"], in: words) {
            return intentCandidate("markdown-before-i-forget", "capture the important detail")
        }
        if hasSuffix(["follow", "up", "on"], in: words) {
            return intentCandidate("markdown-follow-up-on", "the open thread today")
        }

        return nil
    }

    private func markdownCandidate(forLine rawLine: String) -> CommonPhraseContinuationCandidate? {
        let line = normalizedMarkdownLine(rawLine)
        guard !line.isEmpty else {
            return nil
        }

        switch line {
        case "next", "next step", "next steps":
            return intentCandidate("markdown-next", "write the smallest concrete action")
        case "todo", "todos", "to do", "action", "action item", "action items":
            return intentCandidate("markdown-action-items", "make the next step concrete")
        case "decision", "decisions", "decision log":
            return intentCandidate("markdown-decisions", "capture what changed today")
        case "open question", "open questions", "questions":
            return intentCandidate("markdown-open-questions", "capture what still feels unclear")
        case "meeting note", "meeting notes", "notes":
            return intentCandidate("markdown-meeting-notes", "capture decisions and next steps")
        case "today", "daily note", "daily notes":
            return intentCandidate("markdown-daily-note", "focus on the highest leverage fix")
        case "focus", "focus today":
            return intentCandidate("markdown-focus", "the next useful writing pass")
        case "blocked", "blocker", "blockers":
            return intentCandidate("markdown-blocked", "by the missing proof")
        case "waiting", "waiting on":
            return intentCandidate("markdown-waiting-on", "the response before moving forward")
        case "risk", "risks":
            return intentCandidate("markdown-risks", "the part that could break trust")
        case "done", "shipped":
            return intentCandidate("markdown-done", "capture what actually shipped today")
        case "idea", "ideas":
            return intentCandidate("markdown-ideas", "turn this into a small test")
        case "note to self", "notes to self":
            return intentCandidate("markdown-note-to-self", "keep the next step visible")
        case "why", "why this matters":
            return intentCandidate("markdown-why-this-matters", "connect it to the user")
        default:
            return nil
        }
    }

    private func intentCandidate(_ label: String, _ continuation: String) -> CommonPhraseContinuationCandidate {
        CommonPhraseContinuationCandidate(
            continuation: continuation,
            matchLabel: "intent-\(label)",
            score: 0.27
        )
    }

    private func allowsPrediction(
        for behaviorProfileID: AutocompleteBehaviorProfileID?,
        allowsPromptAppPrediction: Bool
    ) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat):
            allowsPromptAppPrediction
        case .some(.coding), .some(.forms), .some(.search):
            false
        case .some, .none:
            true
        }
    }

    private func allowsMarkdownNotePrediction(for behaviorProfileID: AutocompleteBehaviorProfileID?) -> Bool {
        switch behaviorProfileID {
        case .some(.docsProse), .some(.notes), .some(.bullets), .none:
            true
        case .some:
            false
        }
    }

    private func allowsWritingFlowPrediction(for behaviorProfileID: AutocompleteBehaviorProfileID?) -> Bool {
        switch behaviorProfileID {
        case .some(.docsProse), .some(.notes), .some(.bullets), .none:
            true
        case .some:
            false
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

    private func currentLine(in text: String) -> String {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func normalizedMarkdownLine(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"^\s*(#{1,6}\s*)?([-*+]\s*)?(\[[ xX]\]\s*)?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+[\.)]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\[[ xX]\]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":")))
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

    private func containsDailyDriverTopic(_ words: [String]) -> Bool {
        containsAny(
            [
                "app",
                "autocomplete",
                "caret",
                "daily",
                "driver",
                "field",
                "fields",
                "phrase",
                "phrases",
                "steadytype",
                "suggestion",
                "suggestions",
                "tab",
                "trust",
                "typing",
                "words",
                "writing"
            ],
            in: words
        )
    }

    private func containsWritingMotionTopic(_ words: [String]) -> Bool {
        containsAny(
            [
                "app",
                "autocomplete",
                "draft",
                "note",
                "notes",
                "phrase",
                "steadytype",
                "suggestion",
                "suggestions",
                "typing",
                "words",
                "write",
                "writing"
            ],
            in: words
        )
    }

    private func containsFeelingTopic(_ words: [String]) -> Bool {
        containsAny(
            [
                "daily",
                "driver",
                "feel",
                "feeling",
                "feels",
                "flow",
                "install",
                "magical",
                "placement",
                "reach",
                "reaching",
                "reliable",
                "trust",
                "use",
                "useful"
            ],
            in: words
        )
    }

    private func containsAny(_ candidates: [String], in words: [String]) -> Bool {
        let wordSet = Set(words)
        return candidates.contains { wordSet.contains($0) }
    }
}
