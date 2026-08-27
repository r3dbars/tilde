import TildeCore
import Foundation

public enum LabDecisionReason: String, Codable, CaseIterable, Sendable {
    case shown
    case sensitiveScene = "sensitive-scene"
    case emptyPrompt = "empty-prompt"
    case unsafeCharacter = "unsafe-character"
    case emptyOutput = "empty-output"
    case noSuggestion = "no-suggestion"
    case promptLeak = "prompt-leak"
    case prefixReplay = "prefix-replay"
    case contextReplay = "context-replay"
    case selfRepetition = "self-repetition"
    case sceneEcho = "scene-echo"
    case unsupportedFact = "unsupported-fact"
    case promptInjectionScene = "prompt-injection-scene"
    case noIncomingTurn = "no-incoming-turn"
    case resolvedConversation = "resolved-conversation"
    case ambiguousChoice = "ambiguous-choice"
    case lowConfidence = "low-confidence"
    case timeout
    case protocolError = "protocol-error"
}

extension LabDecisionReason {
    static func sceneSuppression(_ reason: SceneSuggestionPolicy.SuppressionReason) -> Self {
        switch reason {
        case .promptInjection: .promptInjectionScene
        case .noIncomingTurn: .noIncomingTurn
        case .resolvedConversation: .resolvedConversation
        case .ambiguousChoice: .ambiguousChoice
        }
    }
}

public struct LabSuggestionDecision: Sendable {
    public let suggestion: String?
    public let reason: LabDecisionReason

    public init(suggestion: String?, reason: LabDecisionReason) {
        self.suggestion = suggestion
        self.reason = reason
    }
}

public enum LabOutputJudge {
    public static func judge(
        rawOutput: String,
        preparedPrompt: LabPreparedPrompt,
        scenario: LabScenario,
        configuration: LabArmConfiguration,
        meanTokenProbability: Double?
    ) -> LabSuggestionDecision {
        if configuration.judgment.lengthPolicy == .confidenceBased,
           let meanTokenProbability,
           meanTokenProbability < configuration.judgment.dynamicLength.silenceBelowConfidence {
            return LabSuggestionDecision(suggestion: nil, reason: .lowConfidence)
        }
        let normalized = preparedPrompt.normalizedContinuation(rawOutput)
        let policy = cleaningPolicy(configuration.judgment)
        let visibleWords = visibleWordLimit(
            configuration.judgment,
            meanTokenProbability: meanTokenProbability
        )
        let clean = CompletionOutputCleaner(
            maxVisibleWords: visibleWords,
            maxVisibleCharacters: min(
                configuration.judgment.maximumVisibleCharacters,
                CompletionSuggestion.defaultMaxVisibleCharacters(forVisibleWords: visibleWords)
            ),
            policy: policy
        ).cleanWithReason(normalized, after: scenario.typedContext)
        guard let candidate = clean.suggestion?.visibleText else {
            return LabSuggestionDecision(
                suggestion: nil,
                reason: decisionReason(clean.rejectionReason)
            )
        }

        if configuration.judgment.rejectsSceneEcho,
           isSceneEcho(
               candidate,
               scene: preparedPrompt.scene,
               minimumWords: configuration.judgment.sceneEchoMinimumWords,
               minimumCharacters: configuration.judgment.sceneEchoMinimumCharacters
           ) {
            return LabSuggestionDecision(suggestion: nil, reason: .sceneEcho)
        }

        let grounding = effectiveGrounding(configuration.judgment)
        if grounding != .off,
           containsUnsupportedFact(
               candidate,
               typedContext: scenario.typedContext,
               scene: preparedPrompt.scene,
               mode: grounding
           ) {
            return LabSuggestionDecision(suggestion: nil, reason: .unsupportedFact)
        }

        let threshold = configuration.generation.minimumMeanTokenProbability
        if threshold > 0, let meanTokenProbability, meanTokenProbability < threshold {
            return LabSuggestionDecision(suggestion: nil, reason: .lowConfidence)
        }

        return LabSuggestionDecision(suggestion: candidate, reason: .shown)
    }

    private static func visibleWordLimit(
        _ configuration: LabJudgmentConfiguration,
        meanTokenProbability: Double?
    ) -> Int {
        guard configuration.lengthPolicy == .confidenceBased,
              let meanTokenProbability else {
            return configuration.maximumVisibleWords
        }
        let dynamic = configuration.dynamicLength
        let limit: Int
        if meanTokenProbability >= dynamic.veryHighConfidence {
            limit = dynamic.sentenceMaximumWords
        } else if meanTokenProbability >= dynamic.highConfidence {
            limit = dynamic.clauseMaximumWords
        } else {
            limit = dynamic.shortMaximumWords
        }
        return min(configuration.maximumVisibleWords, limit)
    }

    private static func cleaningPolicy(_ configuration: LabJudgmentConfiguration) -> CompletionCleaningPolicy {
        switch configuration.cleanerPreset {
        case .production, .strict:
            return .production
        case .diagnostic:
            return CompletionCleaningPolicy(
                rejectsPromptInstructionEcho: configuration.rejectsPromptLeaks,
                rejectsContextReplay: configuration.rejectsContextReplay,
                trimsSelfRepetition: configuration.rejectsSelfRepetition,
                repairsDanglingTail: configuration.repairsDanglingTail
            )
        }
    }

    private static func effectiveGrounding(
        _ configuration: LabJudgmentConfiguration
    ) -> LabFactualGroundingMode {
        if configuration.cleanerPreset == .strict, configuration.factualGrounding == .off {
            return .numbersAndNames
        }
        return configuration.factualGrounding
    }

    private static func decisionReason(_ reason: CompletionCleanRejectionReason?) -> LabDecisionReason {
        switch reason {
        case .unsafeHiddenOrControlCharacter: .unsafeCharacter
        case .emptyOutput: .emptyOutput
        case .noSuggestionSentinel: .noSuggestion
        case .promptInstructionEcho: .promptLeak
        case .emptyAfterPrefixTrimming: .prefixReplay
        case .replaysContext: .contextReplay
        case .repeatsItself: .selfRepetition
        case nil: .emptyOutput
        }
    }

    private static func isSceneEcho(
        _ candidate: String,
        scene: ScreenScene.Scene?,
        minimumWords: Int,
        minimumCharacters: Int
    ) -> Bool {
        guard let scene else { return false }
        let normalizedCandidate = normalized(candidate)
        guard normalizedCandidate.count >= minimumCharacters,
              normalizedCandidate.split(separator: " ").count >= minimumWords else { return false }
        return (scene.conversationTurns.map(\.text) + scene.referenceSnippets)
            .map(normalized)
            .contains(where: { $0.contains(normalizedCandidate) })
    }

    private static func containsUnsupportedFact(
        _ candidate: String,
        typedContext: String,
        scene: ScreenScene.Scene?,
        mode: LabFactualGroundingMode
    ) -> Bool {
        let source = ([typedContext]
            + (scene?.conversationTurns.map(\.text) ?? [])
            + (scene?.referenceSnippets ?? []))
            .joined(separator: " ")
        let allowed = factualAnchors(in: source, mode: mode, dropsLeadingCapital: false)
        let offered = factualAnchors(in: candidate, mode: mode, dropsLeadingCapital: true)
        return !offered.isSubset(of: allowed)
    }

    private static func factualAnchors(
        in text: String,
        mode: LabFactualGroundingMode,
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

    private static let factWords: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december", "today", "tomorrow", "yesterday",
        "am", "pm", "noon", "midnight",
    ]

    private static let ignoredCapitalizedWords: Set<String> = [
        "i", "yes", "no", "okay", "ok", "thanks", "thank", "sure", "sounds", "sorry",
    ]

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}
