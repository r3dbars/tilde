import Foundation

public struct CorpusNGramPhrasePredictor: Equatable, Sendable {
    public static let defaultPriors: [CommonPhraseContinuationPrior] = [
        ("we should keep this", "small", 0.30),
        ("the draft is almost", "ready", 0.30),
        ("please make this", "clearer", 0.30),
        ("this feels genuinely", "useful", 0.30),
        ("i just wanted to", "follow up", 0.28),
        ("i think we should", "make sure", 0.28),
        ("sounds good", "to me", 0.28),
        ("that makes sense", "to me", 0.28),
        ("i can take", "a look", 0.28),
        ("can you please", "take a look", 0.26),
        ("let me know", "what you think", 0.26),
        ("we should probably", "keep it simple", 0.26),
        ("it would help to", "make this clearer", 0.26),
        ("thanks for", "sending this over", 0.26),
        ("before we move on", "capture the next step", 0.24),
        ("the main thing is", "to keep this clear", 0.24),
        ("what i need is", "a clearer next step", 0.24),
        ("next step is", "to make this concrete", 0.24),
        ("as soon as", "possible", 0.27),
        ("at the end of", "the day", 0.25),
        ("in order to", "make this work", 0.25),
        ("we need to", "make sure", 0.27),
        ("i would like to", "learn more", 0.25),
        ("thank you for", "your help", 0.27),
        ("please let me know", "if that works", 0.27),
        ("looking forward to", "hearing from you", 0.26),
        ("the best way to", "handle this", 0.24),
        ("one thing to keep", "in mind", 0.26),
        ("for now we can", "keep it simple", 0.25),
        ("the goal is to", "make this easier", 0.25),
        ("it looks like", "this is working", 0.24),
        ("we can start with", "a small test", 0.25)
    ].map { CommonPhraseContinuationPrior(contextSuffix: $0.0, continuation: $0.1, score: $0.2) }

    public let priors: [CommonPhraseContinuationPrior]

    public init(priors: [CommonPhraseContinuationPrior] = Self.defaultPriors) {
        self.priors = priors
    }

    public func selection(
        for textBeforeCursor: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        CommonPhraseContinuationPredictor(priors: priors).selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        )
    }
}
