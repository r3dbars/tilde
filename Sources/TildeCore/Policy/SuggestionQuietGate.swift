import Foundation

/// Pure-Swift, sub-millisecond multi-feature logistic Control Brain / Quiet
/// Gate for deciding whether a cleaned candidate suggestion should be displayed
/// or quietly suppressed.
///
/// Every feature is strictly text-free (numeric probabilities, margins,
/// entropy, lengths, and categorical context flags). When token probabilities
/// are absent or cannot be aligned to the suggestion, the gate fails open by
/// default so legacy streams and unit tests without probability telemetry
/// behave predictably.
public enum SuggestionQuietGate {
    public enum CursorBoundary: String, Codable, Equatable, Sendable {
        case wordBoundary = "word-boundary"
        case midWord = "mid-word"
        case punctuation

        public static func classify(_ textBeforeCursor: String) -> CursorBoundary {
            if RawContinuationPrompt.endsMidWord(textBeforeCursor) {
                return .midWord
            }
            if let last = textBeforeCursor.last,
               RawContinuationPrompt.requestPunctuation.contains(last) {
                return .punctuation
            }
            return .wordBoundary
        }
    }

    /// Strictly text-free feature vector for one candidate suggestion.
    public struct Features: Codable, Equatable, Sendable {
        public let firstWordProbability: Double
        public let firstWordMargin: Double?
        public let firstWordEntropy: Double?
        public let firstWordRunnerUpRatio: Double?
        public let secondWordProbability: Double?
        public let meanWordProbability: Double?
        public let minimumWordProbability: Double?
        public let meanWordMargin: Double?
        public let meanWordEntropy: Double?
        public let wordCount: Int
        public let characterCount: Int
        public let sceneGrounded: Bool
        public let hasReplyCue: Bool
        public let register: ContinuationRegister
        public let cursorBoundary: CursorBoundary
        public let personalVocabularyAgreement: Bool
        public let personalPhraseAgreement: Bool
        public let personalPhraseLogSupport: Double

        public init(
            firstWordProbability: Double,
            firstWordMargin: Double? = nil,
            firstWordEntropy: Double? = nil,
            firstWordRunnerUpRatio: Double? = nil,
            secondWordProbability: Double? = nil,
            meanWordProbability: Double? = nil,
            minimumWordProbability: Double? = nil,
            meanWordMargin: Double? = nil,
            meanWordEntropy: Double? = nil,
            wordCount: Int,
            characterCount: Int,
            sceneGrounded: Bool,
            hasReplyCue: Bool,
            register: ContinuationRegister,
            cursorBoundary: CursorBoundary,
            personalVocabularyAgreement: Bool = false,
            personalPhraseAgreement: Bool = false,
            personalPhraseLogSupport: Double = 0.0
        ) {
            self.firstWordProbability = min(1.0, max(1e-6, firstWordProbability))
            self.firstWordMargin = firstWordMargin.flatMap { $0.isFinite ? min(1.0, max(0.0, $0)) : nil }
            self.firstWordEntropy = firstWordEntropy.flatMap { $0.isFinite ? max(0.0, $0) : nil }
            self.firstWordRunnerUpRatio = firstWordRunnerUpRatio.flatMap {
                $0.isFinite ? min(1.0, max(0.0, $0)) : nil
            }
            self.secondWordProbability = secondWordProbability.flatMap {
                $0.isFinite ? min(1.0, max(1e-6, $0)) : nil
            }
            self.meanWordProbability = meanWordProbability.flatMap {
                $0.isFinite ? min(1.0, max(1e-6, $0)) : nil
            }
            self.minimumWordProbability = minimumWordProbability.flatMap {
                $0.isFinite ? min(1.0, max(1e-6, $0)) : nil
            }
            self.meanWordMargin = meanWordMargin.flatMap { $0.isFinite ? min(1.0, max(0.0, $0)) : nil }
            self.meanWordEntropy = meanWordEntropy.flatMap { $0.isFinite ? max(0.0, $0) : nil }
            self.wordCount = max(0, wordCount)
            self.characterCount = max(0, characterCount)
            self.sceneGrounded = sceneGrounded
            self.hasReplyCue = hasReplyCue
            self.register = register
            self.cursorBoundary = cursorBoundary
            self.personalVocabularyAgreement = personalVocabularyAgreement
            self.personalPhraseAgreement = personalPhraseAgreement
            self.personalPhraseLogSupport = personalPhraseLogSupport.isFinite
                ? max(0.0, personalPhraseLogSupport)
                : 0.0
        }

        private enum CodingKeys: String, CodingKey {
            case firstWordProbability, firstWordMargin, firstWordEntropy, firstWordRunnerUpRatio
            case secondWordProbability, meanWordProbability, minimumWordProbability
            case meanWordMargin, meanWordEntropy
            case wordCount, characterCount, sceneGrounded, hasReplyCue
            case register, cursorBoundary
            case personalVocabularyAgreement, personalPhraseAgreement, personalPhraseLogSupport
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                firstWordProbability: try c.decode(Double.self, forKey: .firstWordProbability),
                firstWordMargin: try c.decodeIfPresent(Double.self, forKey: .firstWordMargin),
                firstWordEntropy: try c.decodeIfPresent(Double.self, forKey: .firstWordEntropy),
                firstWordRunnerUpRatio: try c.decodeIfPresent(Double.self, forKey: .firstWordRunnerUpRatio),
                secondWordProbability: try c.decodeIfPresent(Double.self, forKey: .secondWordProbability),
                meanWordProbability: try c.decodeIfPresent(Double.self, forKey: .meanWordProbability),
                minimumWordProbability: try c.decodeIfPresent(Double.self, forKey: .minimumWordProbability),
                meanWordMargin: try c.decodeIfPresent(Double.self, forKey: .meanWordMargin),
                meanWordEntropy: try c.decodeIfPresent(Double.self, forKey: .meanWordEntropy),
                wordCount: try c.decode(Int.self, forKey: .wordCount),
                characterCount: try c.decode(Int.self, forKey: .characterCount),
                sceneGrounded: try c.decode(Bool.self, forKey: .sceneGrounded),
                hasReplyCue: try c.decode(Bool.self, forKey: .hasReplyCue),
                register: try c.decode(ContinuationRegister.self, forKey: .register),
                cursorBoundary: try c.decode(CursorBoundary.self, forKey: .cursorBoundary),
                personalVocabularyAgreement: try c.decodeIfPresent(
                    Bool.self,
                    forKey: .personalVocabularyAgreement
                ) ?? false,
                personalPhraseAgreement: try c.decodeIfPresent(
                    Bool.self,
                    forKey: .personalPhraseAgreement
                ) ?? false,
                personalPhraseLogSupport: try c.decodeIfPresent(
                    Double.self,
                    forKey: .personalPhraseLogSupport
                ) ?? 0.0
            )
        }
    }

    /// Linear scorecard weights feeding a logistic sigmoid `1 / (1 + exp(-z))`.
    /// Optional distribution features (`margin`, `entropy`, `runnerUpRatio`,
    /// `secondWordProbability`, phrase means) are centered around neutral
    /// reference points so absent telemetry contributes exactly `0.0`
    /// (fail-neutral). Default weights are monotonic, sign-consistent, and
    /// scene-invariant, calibrated jointly across open-ended prose and the
    /// Certified Corpus V2 Development split.
    public struct Weights: Codable, Equatable, Sendable {
        public static let neutralMargin = 0.25
        public static let neutralEntropy = 1.0
        public static let neutralRunnerUpRatio = 0.50
        public static let neutralSecondWordProbability = 0.50
        public static let neutralMeanWordProbability = 0.50
        public static let neutralMinimumWordProbability = 0.30

        public var bias: Double
        public var firstWordLogProbability: Double
        public var firstWordProbability: Double
        public var firstWordMargin: Double
        public var firstWordEntropy: Double
        public var firstWordRunnerUpRatio: Double
        public var secondWordProbability: Double
        public var meanWordProbability: Double
        public var minimumWordProbability: Double
        public var meanWordMargin: Double
        public var meanWordEntropy: Double
        public var wordCount: Double
        public var characterCount: Double
        public var sceneGrounded: Double
        public var hasReplyCue: Double
        public var chatRegister: Double
        public var emailRegister: Double
        public var midWordBoundary: Double
        public var punctuationBoundary: Double
        public var personalVocabularyAgreement: Double
        public var personalPhraseAgreement: Double
        public var personalPhraseLogSupport: Double

        public init(
            bias: Double = 0.50,
            firstWordLogProbability: Double = 0.45,
            firstWordProbability: Double = 0.40,
            firstWordMargin: Double = 0.35,
            firstWordEntropy: Double = -0.10,
            firstWordRunnerUpRatio: Double = -0.15,
            secondWordProbability: Double = 0.90,
            meanWordProbability: Double = 1.40,
            minimumWordProbability: Double = 2.20,
            meanWordMargin: Double = 2.00,
            meanWordEntropy: Double = -2.00,
            wordCount: Double = -0.02,
            characterCount: Double = 0.15,
            // Kept at 0.0 (scene-invariant): counterfactual wrong-scene stress
            // tests showed positive scene/reply-cue weights let 92-100% of
            // wrong-scene entity hallucinations bypass the gate.
            sceneGrounded: Double = 0.0,
            hasReplyCue: Double = 0.0,
            // Chat replies have much narrower branching (higher baseline p1)
            // and higher interruption risk than open-ended prose, so `.chat`
            // is strictly more conservative than `.prose` (also making wrong
            // `.replying` scenes strictly harder to leak).
            chatRegister: Double = -1.85,
            emailRegister: Double = -0.30,
            midWordBoundary: Double = 0.20,
            punctuationBoundary: Double = -0.10,
            personalVocabularyAgreement: Double = 0.45,
            personalPhraseAgreement: Double = 0.45,
            personalPhraseLogSupport: Double = 0.10
        ) {
            self.bias = bias
            self.firstWordLogProbability = firstWordLogProbability
            self.firstWordProbability = firstWordProbability
            self.firstWordMargin = firstWordMargin
            self.firstWordEntropy = firstWordEntropy
            self.firstWordRunnerUpRatio = firstWordRunnerUpRatio
            self.secondWordProbability = secondWordProbability
            self.meanWordProbability = meanWordProbability
            self.minimumWordProbability = minimumWordProbability
            self.meanWordMargin = meanWordMargin
            self.meanWordEntropy = meanWordEntropy
            self.wordCount = wordCount
            self.characterCount = characterCount
            self.sceneGrounded = sceneGrounded
            self.hasReplyCue = hasReplyCue
            self.chatRegister = chatRegister
            self.emailRegister = emailRegister
            self.midWordBoundary = midWordBoundary
            self.punctuationBoundary = punctuationBoundary
            self.personalVocabularyAgreement = personalVocabularyAgreement
            self.personalPhraseAgreement = personalPhraseAgreement
            self.personalPhraseLogSupport = personalPhraseLogSupport
        }

        public static let `default` = Weights()

        private enum CodingKeys: String, CodingKey {
            case bias, firstWordLogProbability, firstWordProbability
            case firstWordMargin, firstWordEntropy, firstWordRunnerUpRatio
            case secondWordProbability, meanWordProbability, minimumWordProbability
            case meanWordMargin, meanWordEntropy
            case wordCount, characterCount
            case sceneGrounded, hasReplyCue, chatRegister, emailRegister
            case midWordBoundary, punctuationBoundary, personalVocabularyAgreement
            case personalPhraseAgreement, personalPhraseLogSupport
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Weights.default
            bias = try c.decodeIfPresent(Double.self, forKey: .bias) ?? d.bias
            firstWordLogProbability = try c.decodeIfPresent(Double.self, forKey: .firstWordLogProbability)
                ?? d.firstWordLogProbability
            firstWordProbability = try c.decodeIfPresent(Double.self, forKey: .firstWordProbability)
                ?? d.firstWordProbability
            firstWordMargin = try c.decodeIfPresent(Double.self, forKey: .firstWordMargin)
                ?? d.firstWordMargin
            firstWordEntropy = try c.decodeIfPresent(Double.self, forKey: .firstWordEntropy)
                ?? d.firstWordEntropy
            firstWordRunnerUpRatio = try c.decodeIfPresent(Double.self, forKey: .firstWordRunnerUpRatio)
                ?? d.firstWordRunnerUpRatio
            secondWordProbability = try c.decodeIfPresent(Double.self, forKey: .secondWordProbability)
                ?? d.secondWordProbability
            meanWordProbability = try c.decodeIfPresent(Double.self, forKey: .meanWordProbability)
                ?? d.meanWordProbability
            minimumWordProbability = try c.decodeIfPresent(Double.self, forKey: .minimumWordProbability)
                ?? d.minimumWordProbability
            meanWordMargin = try c.decodeIfPresent(Double.self, forKey: .meanWordMargin)
                ?? d.meanWordMargin
            meanWordEntropy = try c.decodeIfPresent(Double.self, forKey: .meanWordEntropy)
                ?? d.meanWordEntropy
            wordCount = try c.decodeIfPresent(Double.self, forKey: .wordCount) ?? d.wordCount
            characterCount = try c.decodeIfPresent(Double.self, forKey: .characterCount) ?? d.characterCount
            sceneGrounded = try c.decodeIfPresent(Double.self, forKey: .sceneGrounded) ?? d.sceneGrounded
            hasReplyCue = try c.decodeIfPresent(Double.self, forKey: .hasReplyCue) ?? d.hasReplyCue
            chatRegister = try c.decodeIfPresent(Double.self, forKey: .chatRegister) ?? d.chatRegister
            emailRegister = try c.decodeIfPresent(Double.self, forKey: .emailRegister) ?? d.emailRegister
            midWordBoundary = try c.decodeIfPresent(Double.self, forKey: .midWordBoundary) ?? d.midWordBoundary
            punctuationBoundary = try c.decodeIfPresent(Double.self, forKey: .punctuationBoundary)
                ?? d.punctuationBoundary
            personalVocabularyAgreement = try c.decodeIfPresent(
                Double.self,
                forKey: .personalVocabularyAgreement
            ) ?? d.personalVocabularyAgreement
            personalPhraseAgreement = try c.decodeIfPresent(
                Double.self,
                forKey: .personalPhraseAgreement
            ) ?? d.personalPhraseAgreement
            personalPhraseLogSupport = try c.decodeIfPresent(
                Double.self,
                forKey: .personalPhraseLogSupport
            ) ?? d.personalPhraseLogSupport
        }
    }

    public struct Configuration: Codable, Equatable, Sendable {
        public var enabled: Bool
        /// Logistic probability cutoff in `[0, 1]`. Candidates with
        /// `score >= threshold` are shown; strictly lower scores are suppressed.
        public var threshold: Double
        /// Optional hard floor on `firstWordProbability` (in `[0, 1]`). Zero
        /// disables the hard floor and delegates entirely to the logistic score.
        public var hardFirstWordFloor: Double
        public var weights: Weights
        public var failOpenWhenUnavailable: Bool

        public init(
            enabled: Bool = true,
            threshold: Double = 0.50,
            hardFirstWordFloor: Double = 0.0,
            weights: Weights = .default,
            failOpenWhenUnavailable: Bool = true
        ) {
            self.enabled = enabled
            self.threshold = threshold
            self.hardFirstWordFloor = hardFirstWordFloor
            self.weights = weights
            self.failOpenWhenUnavailable = failOpenWhenUnavailable
        }

        public static let disabled = Configuration(enabled: false)

        /// Scene-invariant multi-feature Quiet Gate calibrated jointly across
        /// open-ended prose (18–22% live display band) and Certified Corpus V2
        /// Dev (`0.10 / 0.50`, <20% BWS, 96.7% silence restraint, 100%
        /// factuality, 61.0% CF pair pass on Qwen 3.5 4B Base).
        public static let production = Configuration(
            enabled: true,
            threshold: 0.50,
            hardFirstWordFloor: WordConfidenceTruncator.defaultFirstWordFloor,
            weights: .default,
            failOpenWhenUnavailable: true
        )
        public static let balanced = Configuration(enabled: true, threshold: 0.50, weights: .default)

        private enum CodingKeys: String, CodingKey {
            case enabled, threshold, hardFirstWordFloor, weights, failOpenWhenUnavailable
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            threshold = try c.decodeIfPresent(Double.self, forKey: .threshold) ?? 0.50
            hardFirstWordFloor = try c.decodeIfPresent(Double.self, forKey: .hardFirstWordFloor) ?? 0.0
            weights = try c.decodeIfPresent(Weights.self, forKey: .weights) ?? .default
            failOpenWhenUnavailable = try c.decodeIfPresent(Bool.self, forKey: .failOpenWhenUnavailable) ?? true
        }
    }

    public struct Decision: Equatable, Sendable {
        public let allow: Bool
        public let score: Double?
        public let logit: Double?
        public let failedOpen: Bool

        public init(allow: Bool, score: Double?, logit: Double?, failedOpen: Bool) {
            self.allow = allow
            self.score = score
            self.logit = logit
            self.failedOpen = failedOpen
        }
    }

    /// Computes `(logit, sigmoid(logit))` for a strictly text-free feature vector.
    public static func score(_ features: Features, weights: Weights = .default) -> (logit: Double, score: Double) {
        let clampedLogP = max(-6.0, log(features.firstWordProbability))
        var z = weights.bias
        z += weights.firstWordLogProbability * clampedLogP
        z += weights.firstWordProbability * features.firstWordProbability
        if let margin = features.firstWordMargin {
            z += weights.firstWordMargin * (margin - Weights.neutralMargin)
        }
        if let entropy = features.firstWordEntropy {
            z += weights.firstWordEntropy * (entropy - Weights.neutralEntropy)
        }
        if let ratio = features.firstWordRunnerUpRatio {
            z += weights.firstWordRunnerUpRatio * (ratio - Weights.neutralRunnerUpRatio)
        }
        if let secondP = features.secondWordProbability {
            z += weights.secondWordProbability * (secondP - Weights.neutralSecondWordProbability)
        }
        if let meanP = features.meanWordProbability {
            z += weights.meanWordProbability * (meanP - Weights.neutralMeanWordProbability)
        }
        if let minP = features.minimumWordProbability {
            z += weights.minimumWordProbability * (minP - Weights.neutralMinimumWordProbability)
        }
        if let meanMargin = features.meanWordMargin {
            z += weights.meanWordMargin * (meanMargin - Weights.neutralMargin)
        }
        if let meanEntropy = features.meanWordEntropy {
            z += weights.meanWordEntropy * (meanEntropy - Weights.neutralEntropy)
        }
        z += weights.wordCount * Double(min(features.wordCount, 8))
        z += weights.characterCount * (Double(min(features.characterCount, 48)) / 48.0)
        if features.sceneGrounded { z += weights.sceneGrounded }
        if features.hasReplyCue { z += weights.hasReplyCue }
        switch features.register {
        case .chat: z += weights.chatRegister
        case .email: z += weights.emailRegister
        case .prose: break
        }
        switch features.cursorBoundary {
        case .midWord: z += weights.midWordBoundary
        case .punctuation: z += weights.punctuationBoundary
        case .wordBoundary: break
        }
        if features.personalVocabularyAgreement { z += weights.personalVocabularyAgreement }
        if features.personalPhraseAgreement { z += weights.personalPhraseAgreement }
        if features.personalPhraseLogSupport > 0 {
            z += weights.personalPhraseLogSupport * min(features.personalPhraseLogSupport, 6.0)
        }
        return (z, sigmoid(z))
    }

    /// Extracts strictly text-free features from a candidate suggestion,
    /// aligned token probabilities, and request context. Returns `nil` when
    /// token probabilities are missing or unaligned (allowing callers to fail
    /// open cleanly).
    public static func extractFeatures(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        textBeforeCursor: String,
        register: ContinuationRegister,
        scene: ScreenScene.Scene?,
        personalBiasTerms: [WeightedBiasTerm] = [],
        replyCueAnchoredToCurrentSentence: Bool = true,
        personalPhraseAgreement: Bool = false,
        personalPhraseLogSupport: Double = 0.0
    ) -> Features? {
        guard let profile = WordConfidenceTruncator.confidenceProfile(
            for: suggestion,
            tokens: tokens
        ) else {
            return nil
        }
        let visibleWords = CompletionContextWords.wordRanges(in: suggestion.visibleText)
        let firstWordNormalized = visibleWords.first.map {
            CompletionContextWords.normalized(String(suggestion.visibleText[$0]))
        } ?? ""
        let personalAgreement: Bool
        if !firstWordNormalized.isEmpty, !personalBiasTerms.isEmpty {
            personalAgreement = personalBiasTerms.contains {
                CompletionContextWords.normalized($0.term) == firstWordNormalized
            }
        } else {
            personalAgreement = false
        }
        let sceneGrounded = scene.map {
            !$0.conversationTurns.isEmpty || !$0.referenceSnippets.isEmpty
        } ?? false
        let hasReplyCue = scene?.mode == .replying && SceneSuggestionPolicy.hasStartedReplyCue(
            textBeforeCursor,
            anchoredToCurrentSentence: replyCueAnchoredToCurrentSentence
        )
        return Features(
            firstWordProbability: profile.firstWordProbability,
            firstWordMargin: profile.firstWordMargin,
            firstWordEntropy: profile.firstWordEntropy,
            firstWordRunnerUpRatio: profile.firstWordRunnerUpRatio,
            secondWordProbability: profile.secondWordProbability,
            meanWordProbability: profile.meanWordProbability,
            minimumWordProbability: profile.minimumWordProbability,
            meanWordMargin: profile.meanWordMargin,
            meanWordEntropy: profile.meanWordEntropy,
            wordCount: visibleWords.count,
            characterCount: suggestion.visibleText.trimmingCharacters(in: .whitespaces).count,
            sceneGrounded: sceneGrounded,
            hasReplyCue: hasReplyCue,
            register: register,
            cursorBoundary: CursorBoundary.classify(textBeforeCursor),
            personalVocabularyAgreement: personalAgreement,
            personalPhraseAgreement: personalPhraseAgreement,
            personalPhraseLogSupport: personalPhraseLogSupport
        )
    }

    /// Evaluates whether `suggestion` should be displayed under `configuration`.
    public static func evaluate(
        features: Features?,
        configuration: Configuration
    ) -> Decision {
        guard configuration.enabled else {
            return Decision(allow: true, score: nil, logit: nil, failedOpen: false)
        }
        guard let features else {
            return Decision(
                allow: configuration.failOpenWhenUnavailable,
                score: nil,
                logit: nil,
                failedOpen: configuration.failOpenWhenUnavailable
            )
        }
        if configuration.hardFirstWordFloor > 0,
           features.firstWordProbability < configuration.hardFirstWordFloor {
            let result = score(features, weights: configuration.weights)
            return Decision(allow: false, score: result.score, logit: result.logit, failedOpen: false)
        }
        let result = score(features, weights: configuration.weights)
        let allowed = result.score >= configuration.threshold
        return Decision(allow: allowed, score: result.score, logit: result.logit, failedOpen: false)
    }

    /// Convenience end-to-end evaluation from raw candidate + aligned token
    /// probabilities.
    public static func evaluate(
        suggestion: CompletionSuggestion,
        tokens: [StreamedTokenProbability],
        textBeforeCursor: String,
        register: ContinuationRegister,
        scene: ScreenScene.Scene?,
        personalBiasTerms: [WeightedBiasTerm] = [],
        replyCueAnchoredToCurrentSentence: Bool = true,
        configuration: Configuration,
        personalPhraseAgreement: Bool = false,
        personalPhraseLogSupport: Double = 0.0
    ) -> Decision {
        guard configuration.enabled else {
            return Decision(allow: true, score: nil, logit: nil, failedOpen: false)
        }
        let features = extractFeatures(
            suggestion: suggestion,
            tokens: tokens,
            textBeforeCursor: textBeforeCursor,
            register: register,
            scene: scene,
            personalBiasTerms: personalBiasTerms,
            replyCueAnchoredToCurrentSentence: replyCueAnchoredToCurrentSentence,
            personalPhraseAgreement: personalPhraseAgreement,
            personalPhraseLogSupport: personalPhraseLogSupport
        )
        return evaluate(features: features, configuration: configuration)
    }

    private static func sigmoid(_ z: Double) -> Double {
        if z >= 0 {
            let e = exp(-z)
            return 1.0 / (1.0 + e)
        } else {
            let e = exp(z)
            return e / (1.0 + e)
        }
    }
}
