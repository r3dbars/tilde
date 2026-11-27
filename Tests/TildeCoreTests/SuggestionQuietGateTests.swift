import Foundation
import Testing
@testable import TildeCore

@Suite("SuggestionQuietGate and n_probs=3 token distribution metrics")
struct SuggestionQuietGateTests {
    @Test("distributionMetrics computes top-1 margin, local entropy, and runner-up ratio from n_probs=3")
    func distributionMetricsMath() throws {
        let metrics = try #require(
            StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: [0.60, 0.20, 0.10])
        )
        #expect(abs(metrics.top1Margin - 0.40) < 1e-12)
        #expect(abs(metrics.runnerUpRatio - (0.20 / 0.60)) < 1e-12)
        // Remainder mass is 0.10 -> entropy = -(0.6 ln 0.6 + 0.2 ln 0.2 + 0.1 ln 0.1 + 0.1 ln 0.1)
        let expectedEntropy = -(0.60 * log(0.60) + 0.20 * log(0.20) + 2.0 * 0.10 * log(0.10))
        #expect(abs(metrics.entropy - expectedEntropy) < 1e-12)

        // Fewer than 2 valid alternatives fail open (return nil).
        #expect(StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: [0.85]) == nil)
        #expect(StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: []) == nil)
        #expect(StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: [0.5, .nan]) == nil)
        #expect(StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: [0.5, -0.1]) == nil)
    }

    @Test("WordConfidenceTruncator.confidenceProfile aligns multi-subword words and preserves n_probs=3 metrics")
    func wordConfidenceProfileAlignment() throws {
        let suggestion = CompletionSuggestion(text: " tomorrow morning", maxVisibleWords: 8)
        let tokens = [
            StreamedTokenProbability(piece: " tom", probability: 0.64, top1Margin: 0.42, entropy: 0.72, runnerUpRatio: 0.34),
            StreamedTokenProbability(piece: "orrow", probability: 0.96, top1Margin: 0.90, entropy: 0.15, runnerUpRatio: 0.04),
            StreamedTokenProbability(piece: " morning", probability: 0.81, top1Margin: 0.65, entropy: 0.45, runnerUpRatio: 0.20),
        ]
        let profile = try #require(WordConfidenceTruncator.confidenceProfile(for: suggestion, tokens: tokens))
        let expectedWord1 = exp((log(0.64) + log(0.96)) / 2.0)
        #expect(abs(profile.firstWordProbability - expectedWord1) < 1e-9)
        #expect(abs(try #require(profile.firstWordMargin) - 0.42) < 1e-9)
        #expect(abs(try #require(profile.firstWordEntropy) - 0.72) < 1e-9)
        #expect(abs(try #require(profile.firstWordRunnerUpRatio) - 0.34) < 1e-9)
        #expect(abs(try #require(profile.secondWordProbability) - 0.81) < 1e-9)
        #expect(abs(try #require(profile.meanWordMargin) - ((0.42 + 0.65) / 2.0)) < 1e-9)
        #expect(abs(try #require(profile.meanWordEntropy) - ((0.72 + 0.45) / 2.0)) < 1e-9)
        #expect(profile.alignedWordCount == 2)

        // Unaligned tokens fail open with nil.
        let mismatched = [StreamedTokenProbability(piece: " elephant", probability: 0.90)]
        #expect(WordConfidenceTruncator.confidenceProfile(for: suggestion, tokens: mismatched) == nil)
        #expect(WordConfidenceTruncator.confidenceProfile(for: suggestion, tokens: []) == nil)
    }

    @Test("SuggestionQuietGate rewards margin, low entropy, word 2 confidence, scene/reply cues, and personal agreement")
    func quietGateMonotonicity() {
        let base = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.10,
            firstWordEntropy: 1.40,
            firstWordRunnerUpRatio: 0.70,
            secondWordProbability: 0.30,
            meanWordProbability: 0.32,
            minimumWordProbability: 0.30,
            meanWordMargin: 0.12,
            meanWordEntropy: 1.35,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: false,
            hasReplyCue: false,
            register: .prose,
            cursorBoundary: .wordBoundary,
            personalVocabularyAgreement: false
        )
        let baseScore = SuggestionQuietGate.score(base).score

        let sharperMargin = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.55,
            firstWordEntropy: 0.50,
            firstWordRunnerUpRatio: 0.20,
            secondWordProbability: 0.85,
            meanWordProbability: 0.75,
            minimumWordProbability: 0.35,
            meanWordMargin: 0.60,
            meanWordEntropy: 0.45,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: false,
            hasReplyCue: false,
            register: .prose,
            cursorBoundary: .wordBoundary,
            personalVocabularyAgreement: false
        )
        #expect(SuggestionQuietGate.score(sharperMargin).score > baseScore)

        // Scene flags must remain neutral (scene-invariant) to block wrong-scene spoofing.
        let sceneOnly = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.10,
            firstWordEntropy: 1.40,
            firstWordRunnerUpRatio: 0.70,
            secondWordProbability: 0.30,
            meanWordProbability: 0.32,
            minimumWordProbability: 0.30,
            meanWordMargin: 0.12,
            meanWordEntropy: 1.35,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: true,
            hasReplyCue: true,
            register: .prose,
            cursorBoundary: .wordBoundary,
            personalVocabularyAgreement: false
        )
        #expect(abs(SuggestionQuietGate.score(sceneOnly).score - baseScore) < 1e-12)

        let personalAndMidWord = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.10,
            firstWordEntropy: 1.40,
            firstWordRunnerUpRatio: 0.70,
            secondWordProbability: 0.30,
            meanWordProbability: 0.32,
            minimumWordProbability: 0.30,
            meanWordMargin: 0.12,
            meanWordEntropy: 1.35,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: true,
            hasReplyCue: true,
            register: .prose,
            cursorBoundary: .midWord,
            personalVocabularyAgreement: true
        )
        #expect(SuggestionQuietGate.score(personalAndMidWord).score > baseScore)

        // Personal phrase agreement + log support lift score monotonically and stay neutral at defaults.
        let phraseAgreement = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.10,
            firstWordEntropy: 1.40,
            firstWordRunnerUpRatio: 0.70,
            secondWordProbability: 0.30,
            meanWordProbability: 0.32,
            minimumWordProbability: 0.30,
            meanWordMargin: 0.12,
            meanWordEntropy: 1.35,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: false,
            hasReplyCue: false,
            register: .prose,
            cursorBoundary: .wordBoundary,
            personalVocabularyAgreement: false,
            personalPhraseAgreement: true,
            personalPhraseLogSupport: 2.0
        )
        #expect(SuggestionQuietGate.score(phraseAgreement).score > baseScore)

        // Chat register is strictly more conservative than open-ended prose (and never rewards wrong-scene replies).
        let chatRegister = SuggestionQuietGate.Features(
            firstWordProbability: 0.35,
            firstWordMargin: 0.10,
            firstWordEntropy: 1.40,
            firstWordRunnerUpRatio: 0.70,
            secondWordProbability: 0.30,
            meanWordProbability: 0.32,
            minimumWordProbability: 0.30,
            meanWordMargin: 0.12,
            meanWordEntropy: 1.35,
            wordCount: 2,
            characterCount: 12,
            sceneGrounded: false,
            hasReplyCue: false,
            register: .chat,
            cursorBoundary: .wordBoundary,
            personalVocabularyAgreement: false
        )
        #expect(SuggestionQuietGate.score(chatRegister).score < baseScore)
    }

    @Test("SuggestionQuietGate Features and Weights decode legacy JSON without personalPhrase fields")
    func quietGateBackwardCompatibleCodable() throws {
        let legacyFeaturesJSON = Data("""
        {
          "firstWordProbability": 0.4,
          "wordCount": 2,
          "characterCount": 10,
          "sceneGrounded": false,
          "hasReplyCue": false,
          "register": "prose",
          "cursorBoundary": "word-boundary",
          "personalVocabularyAgreement": false
        }
        """.utf8)
        let decodedFeatures = try JSONDecoder().decode(SuggestionQuietGate.Features.self, from: legacyFeaturesJSON)
        #expect(!decodedFeatures.personalPhraseAgreement)
        #expect(decodedFeatures.personalPhraseLogSupport == 0.0)

        let legacyWeightsJSON = Data("""
        {
          "bias": 0.50,
          "sceneGrounded": 0.0,
          "hasReplyCue": 0.0
        }
        """.utf8)
        let decodedWeights = try JSONDecoder().decode(SuggestionQuietGate.Weights.self, from: legacyWeightsJSON)
        #expect(decodedWeights.personalPhraseAgreement == 0.45)
        #expect(decodedWeights.personalPhraseLogSupport == 0.10)
        #expect(decodedWeights.sceneGrounded == 0.0)
        #expect(decodedWeights.hasReplyCue == 0.0)
    }

    @Test("SuggestionQuietGate fails open when telemetry is absent and honors hardFirstWordFloor and personal vocab agreement")
    func quietGateFailOpenAndEvaluation() throws {
        let suggestion = CompletionSuggestion(text: " transcripted pipeline", maxVisibleWords: 8)
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "Did you check the pipeline?")],
            referenceSnippets: []
        )
        let config = SuggestionQuietGate.Configuration(enabled: true, threshold: 0.50)

        // Empty tokens -> fail open by default.
        let openDecision = SuggestionQuietGate.evaluate(
            suggestion: suggestion,
            tokens: [],
            textBeforeCursor: "Sounds good, checking ",
            register: .chat,
            scene: scene,
            configuration: config
        )
        #expect(openDecision.allow)
        #expect(openDecision.failedOpen)
        #expect(openDecision.score == nil)

        // Explicit fail-closed when requested.
        var closedConfig = config
        closedConfig.failOpenWhenUnavailable = false
        let closedDecision = SuggestionQuietGate.evaluate(
            suggestion: suggestion,
            tokens: [],
            textBeforeCursor: "Sounds good, checking ",
            register: .chat,
            scene: scene,
            configuration: closedConfig
        )
        #expect(!closedDecision.allow)
        #expect(!closedDecision.failedOpen)

        // Feature extraction detects sceneGrounded, hasReplyCue, and personalVocabularyAgreement.
        let tokens = [
            StreamedTokenProbability(piece: " transcripted", probability: 0.45, top1Margin: 0.30, entropy: 0.80, runnerUpRatio: 0.33),
            StreamedTokenProbability(piece: " pipeline", probability: 0.82, top1Margin: 0.65, entropy: 0.40, runnerUpRatio: 0.18),
        ]
        let features = try #require(SuggestionQuietGate.extractFeatures(
            suggestion: suggestion,
            tokens: tokens,
            textBeforeCursor: "Sounds good, checking ",
            register: .chat,
            scene: scene,
            personalBiasTerms: [WeightedBiasTerm(term: "Transcripted", weight: 0.65)]
        ))
        #expect(features.sceneGrounded)
        #expect(features.hasReplyCue)
        #expect(features.personalVocabularyAgreement)
        #expect(features.register == .chat)
        #expect(features.cursorBoundary == .wordBoundary)

        // Hard first-word floor overrides strong tail features.
        let floorConfig = SuggestionQuietGate.Configuration(
            enabled: true,
            threshold: 0.10,
            hardFirstWordFloor: 0.50
        )
        let floorDecision = SuggestionQuietGate.evaluate(features: features, configuration: floorConfig)
        #expect(!floorDecision.allow)
        #expect(floorDecision.score != nil)
    }

    @Test("DecisionPolicy Codable stays backward-compatible when quietGate is omitted or present")
    func decisionPolicyQuietGateCodable() throws {
        let legacyJSON = Data("""
        {
          "maximumVisibleWords": 8,
          "sceneEchoMinimumWords": 3,
          "sceneEchoMinimumCharacters": 10,
          "factualGrounding": "off",
          "replyCueAnchoredToCurrentSentence": true,
          "extendedOrdinarySilenceGate": false,
          "includesWindowTitleInScene": true
        }
        """.utf8)
        let decodedLegacy = try JSONDecoder().decode(DecisionPolicy.self, from: legacyJSON)
        #expect(decodedLegacy.minimumFirstWordProbability == 0.0)
        #expect(decodedLegacy.quietGate == nil)

        let withGate = DecisionPolicy(
            maximumVisibleWords: 8,
            sceneEchoMinimumWords: 3,
            sceneEchoMinimumCharacters: 10,
            factualGrounding: .off,
            replyCueAnchoredToCurrentSentence: true,
            extendedOrdinarySilenceGate: false,
            includesWindowTitleInScene: true,
            minimumFirstWordProbability: 0.18,
            quietGate: .balanced
        )
        let roundTripped = try JSONDecoder().decode(
            DecisionPolicy.self,
            from: JSONEncoder().encode(withGate)
        )
        #expect(roundTripped == withGate)
        #expect(roundTripped.quietGate == .balanced)
    }
}
