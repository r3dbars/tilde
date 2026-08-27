import TildeCore
import Foundation

public protocol LabNamedOption: RawRepresentable, Codable, CaseIterable, Hashable, Identifiable, Sendable
where RawValue == String {
    var title: String { get }
}

public extension LabNamedOption {
    var id: String { rawValue }
}

public enum LabSamplerPreset: String, LabNamedOption {
    case productionGreedy = "production-greedy"
    case conservative
    case exploratory
    case custom

    public var title: String {
        switch self {
        case .productionGreedy: "Production · Greedy"
        case .conservative: "Conservative"
        case .exploratory: "Exploratory"
        case .custom: "Custom"
        }
    }
}

public enum LabStopRule: String, LabNamedOption {
    case newline
    case sentence
    case characterLimit = "character-limit"
    case natural

    public var title: String {
        switch self {
        case .newline: "First newline"
        case .sentence: "First sentence"
        case .characterLimit: "Character limit"
        case .natural: "Natural model stop"
        }
    }
}

public enum LabRequestMode: String, LabNamedOption {
    case productionStreaming = "production-streaming"
    case finalResponse = "final-response"

    public var title: String {
        switch self {
        case .productionStreaming: "Production streaming"
        case .finalResponse: "Final response throughput"
        }
    }
}

public enum LabGrammarMode: String, LabNamedOption {
    case none
    case json

    public var title: String {
        switch self {
        case .none: "None"
        case .json: "JSON object"
        }
    }
}

public struct LabAdvancedSamplingConfiguration: Codable, Equatable, Sendable {
    public var samplerOrder: String
    public var topNSigma: Double
    public var xtcProbability: Double
    public var xtcThreshold: Double
    public var dryMultiplier: Double
    public var dryBase: Double
    public var dryAllowedLength: Int
    public var dryPenaltyLastN: Int
    public var dynamicTemperatureRange: Double
    public var dynamicTemperatureExponent: Double
    public var mirostatMode: Int
    public var mirostatTau: Double
    public var mirostatEta: Double
    public var ignoreEndOfSequence: Bool
    public var grammarMode: LabGrammarMode
    public var logitBiasRules: String

    public init(
        samplerOrder: String = "penalties;dry;top_n_sigma;top_k;typ_p;top_p;min_p;xtc;temperature",
        topNSigma: Double = -1,
        xtcProbability: Double = 0,
        xtcThreshold: Double = 0.1,
        dryMultiplier: Double = 0,
        dryBase: Double = 1.75,
        dryAllowedLength: Int = 2,
        dryPenaltyLastN: Int = -1,
        dynamicTemperatureRange: Double = 0,
        dynamicTemperatureExponent: Double = 1,
        mirostatMode: Int = 0,
        mirostatTau: Double = 5,
        mirostatEta: Double = 0.1,
        ignoreEndOfSequence: Bool = false,
        grammarMode: LabGrammarMode = .none,
        logitBiasRules: String = ""
    ) {
        self.samplerOrder = samplerOrder
        self.topNSigma = topNSigma
        self.xtcProbability = xtcProbability
        self.xtcThreshold = xtcThreshold
        self.dryMultiplier = dryMultiplier
        self.dryBase = dryBase
        self.dryAllowedLength = dryAllowedLength
        self.dryPenaltyLastN = dryPenaltyLastN
        self.dynamicTemperatureRange = dynamicTemperatureRange
        self.dynamicTemperatureExponent = dynamicTemperatureExponent
        self.mirostatMode = mirostatMode
        self.mirostatTau = mirostatTau
        self.mirostatEta = mirostatEta
        self.ignoreEndOfSequence = ignoreEndOfSequence
        self.grammarMode = grammarMode
        self.logitBiasRules = logitBiasRules
    }

    /// The manifest keeps sampler order human-editable; llama-server's JSON
    /// API requires a string array. Accept separators people naturally type.
    public var parsedSamplerOrder: [String] {
        samplerOrder
            .split { character in
                character == ";" || character == "," || character.isWhitespace
            }
            .map(String.init)
    }
}

public struct LabGenerationConfiguration: Codable, Equatable, Sendable {
    public var preset: LabSamplerPreset
    public var temperature: Double
    public var topK: Int
    public var topP: Double
    public var minP: Double
    public var typicalP: Double
    public var repeatLastTokens: Int
    public var repeatPenalty: Double
    public var presencePenalty: Double
    public var frequencyPenalty: Double
    public var predictionTokens: Int
    public var seed: Int
    public var stopRule: LabStopRule
    public var stopCharacterLimit: Int
    public var requestMode: LabRequestMode
    public var cachePrompt: Bool
    public var probabilityCount: Int
    public var minimumMeanTokenProbability: Double
    public var advanced: LabAdvancedSamplingConfiguration

    public init(
        preset: LabSamplerPreset = .productionGreedy,
        temperature: Double = 0,
        topK: Int = 40,
        topP: Double = 0.95,
        minP: Double = 0.05,
        typicalP: Double = 1,
        repeatLastTokens: Int = 64,
        repeatPenalty: Double = 1,
        presencePenalty: Double = 0,
        frequencyPenalty: Double = 0,
        predictionTokens: Int = 20,
        seed: Int = 0,
        stopRule: LabStopRule = .newline,
        stopCharacterLimit: Int = 96,
        requestMode: LabRequestMode = .finalResponse,
        cachePrompt: Bool = true,
        probabilityCount: Int = 0,
        minimumMeanTokenProbability: Double = 0,
        advanced: LabAdvancedSamplingConfiguration = .init()
    ) {
        self.preset = preset
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.minP = minP
        self.typicalP = typicalP
        self.repeatLastTokens = repeatLastTokens
        self.repeatPenalty = repeatPenalty
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.predictionTokens = predictionTokens
        self.seed = seed
        self.stopRule = stopRule
        self.stopCharacterLimit = stopCharacterLimit
        self.requestMode = requestMode
        self.cachePrompt = cachePrompt
        self.probabilityCount = probabilityCount
        self.minimumMeanTokenProbability = minimumMeanTokenProbability
        self.advanced = advanced
    }

    public mutating func apply(_ preset: LabSamplerPreset) {
        self.preset = preset
        switch preset {
        case .productionGreedy:
            temperature = 0
            topK = 40
            topP = 0.95
            minP = 0.05
            typicalP = 1
            repeatPenalty = 1
            presencePenalty = 0
            frequencyPenalty = 0
        case .conservative:
            temperature = 0.2
            topK = 20
            topP = 0.8
            minP = 0.1
            typicalP = 1
            repeatPenalty = 1.05
            presencePenalty = 0
            frequencyPenalty = 0
        case .exploratory:
            temperature = 0.7
            topK = 40
            topP = 0.95
            minP = 0.05
            typicalP = 1
            repeatPenalty = 1.1
            presencePenalty = 0
            frequencyPenalty = 0
        case .custom:
            break
        }
    }
}

public enum LabRegisterOverride: String, LabNamedOption {
    case automatic
    case chat
    case email
    case prose

    public var title: String { rawValue.capitalized }

    public func resolve(scene: ScreenScene.Scene?, bundleIdentifier: String?) -> ContinuationRegister {
        switch self {
        case .automatic:
            ContinuationRegister.following(scene: scene, hostBundleIdentifier: bundleIdentifier)
        case .chat: .chat
        case .email: .email
        case .prose: .prose
        }
    }
}

public enum LabPromptRecipe: String, LabNamedOption {
    case production
    case minimal
    case noExamples = "no-examples"

    public var title: String {
        switch self {
        case .production: "Production"
        case .minimal: "Minimal instruction"
        case .noExamples: "Instruction only"
        }
    }
}

public enum LabConversationSelection: String, LabNamedOption {
    case production
    case newestIncoming = "newest-incoming"
    case lastTurns = "last-n-turns"
    case allBounded = "all-bounded"

    public var title: String {
        switch self {
        case .production: "Production relevance"
        case .newestIncoming: "Newest incoming only"
        case .lastTurns: "Last N turns"
        case .allBounded: "All bounded turns"
        }
    }
}

public enum LabConversationFormat: String, LabNamedOption {
    case productionJSON = "production-json"
    case roleLabels = "role-labels"
    case compact

    public var title: String {
        switch self {
        case .productionJSON: "Production JSON"
        case .roleLabels: "Role-labelled text"
        case .compact: "Compact transcript"
        }
    }
}

public enum LabScenePlacement: String, LabNamedOption {
    case beforeText = "before-text"
    case afterText = "after-text"

    public var title: String {
        switch self {
        case .beforeText: "Before typed text"
        case .afterText: "After typed text"
        }
    }
}

public struct LabPromptConfiguration: Codable, Equatable, Sendable {
    public var registerOverride: LabRegisterOverride
    public var recipe: LabPromptRecipe
    public var includesScene: Bool
    public var maximumContextCharacters: Int
    public var maximumSceneCharacters: Int
    public var replyReserveCharacters: Int
    public var sceneBudgetQuantum: Int
    public var conversationTurnLimit: Int
    public var conversationCharacterBudget: Int
    public var referenceCharacterBudget: Int
    public var conversationSelection: LabConversationSelection
    public var conversationFormat: LabConversationFormat
    public var scenePlacement: LabScenePlacement
    public var includesIntentFutures: Bool
    public var maximumIntentFutures: Int
    public var intentPriorWeight: Double

    public init(
        registerOverride: LabRegisterOverride = .automatic,
        recipe: LabPromptRecipe = .production,
        includesScene: Bool = true,
        maximumContextCharacters: Int = 3_000,
        maximumSceneCharacters: Int = 3_000,
        replyReserveCharacters: Int = 1_200,
        sceneBudgetQuantum: Int = 250,
        conversationTurnLimit: Int = 8,
        conversationCharacterBudget: Int = 2_000,
        referenceCharacterBudget: Int = 1_000,
        conversationSelection: LabConversationSelection = .production,
        conversationFormat: LabConversationFormat = .productionJSON,
        scenePlacement: LabScenePlacement = .beforeText,
        includesIntentFutures: Bool = false,
        maximumIntentFutures: Int = 4,
        intentPriorWeight: Double = 0.35
    ) {
        self.registerOverride = registerOverride
        self.recipe = recipe
        self.includesScene = includesScene
        self.maximumContextCharacters = maximumContextCharacters
        self.maximumSceneCharacters = maximumSceneCharacters
        self.replyReserveCharacters = replyReserveCharacters
        self.sceneBudgetQuantum = sceneBudgetQuantum
        self.conversationTurnLimit = conversationTurnLimit
        self.conversationCharacterBudget = conversationCharacterBudget
        self.referenceCharacterBudget = referenceCharacterBudget
        self.conversationSelection = conversationSelection
        self.conversationFormat = conversationFormat
        self.scenePlacement = scenePlacement
        self.includesIntentFutures = includesIntentFutures
        self.maximumIntentFutures = maximumIntentFutures
        self.intentPriorWeight = intentPriorWeight
    }
}

public enum LabCleanerPreset: String, LabNamedOption {
    case production
    case strict
    case diagnostic

    public var title: String { rawValue.capitalized }
}

public enum LabFactualGroundingMode: String, LabNamedOption {
    case off
    case numbersAndNames = "numbers-and-names"
    case allAnchors = "all-anchors"

    public var title: String {
        switch self {
        case .off: "Off"
        case .numbersAndNames: "Numbers and names"
        case .allAnchors: "All factual anchors"
        }
    }
}

public enum LabSuggestionLengthPolicy: String, LabNamedOption {
    case fixed
    case confidenceBased = "confidence-based"

    public var title: String {
        switch self {
        case .fixed: "Fixed cap"
        case .confidenceBased: "Confidence-based"
        }
    }
}

public struct LabDynamicLengthConfiguration: Codable, Equatable, Sendable {
    public var silenceBelowConfidence: Double
    public var highConfidence: Double
    public var veryHighConfidence: Double
    public var shortMaximumWords: Int
    public var clauseMaximumWords: Int
    public var sentenceMaximumWords: Int

    public init(
        silenceBelowConfidence: Double = 0.20,
        highConfidence: Double = 0.50,
        veryHighConfidence: Double = 0.75,
        shortMaximumWords: Int = 3,
        clauseMaximumWords: Int = 8,
        sentenceMaximumWords: Int = 16
    ) {
        self.silenceBelowConfidence = silenceBelowConfidence
        self.highConfidence = highConfidence
        self.veryHighConfidence = veryHighConfidence
        self.shortMaximumWords = shortMaximumWords
        self.clauseMaximumWords = clauseMaximumWords
        self.sentenceMaximumWords = sentenceMaximumWords
    }
}

public struct LabJudgmentConfiguration: Codable, Equatable, Sendable {
    public var cleanerPreset: LabCleanerPreset
    public var maximumVisibleWords: Int
    public var maximumVisibleCharacters: Int
    public var rejectsSceneEcho: Bool
    public var sceneEchoMinimumWords: Int
    public var sceneEchoMinimumCharacters: Int
    public var repairsDanglingTail: Bool
    public var factualGrounding: LabFactualGroundingMode
    public var suppressesSensitiveScenes: Bool
    public var rejectsPromptLeaks: Bool
    public var rejectsContextReplay: Bool
    public var rejectsSelfRepetition: Bool
    public var lengthPolicy: LabSuggestionLengthPolicy
    public var dynamicLength: LabDynamicLengthConfiguration

    public init(
        cleanerPreset: LabCleanerPreset = .production,
        maximumVisibleWords: Int = CompletionSuggestion.defaultMaxVisibleWords,
        maximumVisibleCharacters: Int = CompletionSuggestion.defaultMaxVisibleCharacters,
        rejectsSceneEcho: Bool = true,
        sceneEchoMinimumWords: Int = 3,
        sceneEchoMinimumCharacters: Int = 10,
        repairsDanglingTail: Bool = true,
        factualGrounding: LabFactualGroundingMode = .off,
        suppressesSensitiveScenes: Bool = true,
        rejectsPromptLeaks: Bool = true,
        rejectsContextReplay: Bool = true,
        rejectsSelfRepetition: Bool = true,
        lengthPolicy: LabSuggestionLengthPolicy = .fixed,
        dynamicLength: LabDynamicLengthConfiguration = .init()
    ) {
        self.cleanerPreset = cleanerPreset
        self.maximumVisibleWords = maximumVisibleWords
        self.maximumVisibleCharacters = maximumVisibleCharacters
        self.rejectsSceneEcho = rejectsSceneEcho
        self.sceneEchoMinimumWords = sceneEchoMinimumWords
        self.sceneEchoMinimumCharacters = sceneEchoMinimumCharacters
        self.repairsDanglingTail = repairsDanglingTail
        self.factualGrounding = factualGrounding
        self.suppressesSensitiveScenes = suppressesSensitiveScenes
        self.rejectsPromptLeaks = rejectsPromptLeaks
        self.rejectsContextReplay = rejectsContextReplay
        self.rejectsSelfRepetition = rejectsSelfRepetition
        self.lengthPolicy = lengthPolicy
        self.dynamicLength = dynamicLength
    }

    private enum CodingKeys: String, CodingKey {
        case cleanerPreset, maximumVisibleWords, maximumVisibleCharacters
        case rejectsSceneEcho, sceneEchoMinimumWords, sceneEchoMinimumCharacters
        case repairsDanglingTail, factualGrounding, suppressesSensitiveScenes
        case rejectsPromptLeaks, rejectsContextReplay, rejectsSelfRepetition
        case lengthPolicy, dynamicLength
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cleanerPreset = try values.decodeIfPresent(LabCleanerPreset.self, forKey: .cleanerPreset)
            ?? .production
        maximumVisibleWords = try values.decodeIfPresent(Int.self, forKey: .maximumVisibleWords)
            ?? CompletionSuggestion.defaultMaxVisibleWords
        maximumVisibleCharacters = try values.decodeIfPresent(
            Int.self,
            forKey: .maximumVisibleCharacters
        ) ?? CompletionSuggestion.defaultMaxVisibleCharacters(
            forVisibleWords: maximumVisibleWords
        )
        rejectsSceneEcho = try values.decodeIfPresent(Bool.self, forKey: .rejectsSceneEcho) ?? true
        sceneEchoMinimumWords = try values.decodeIfPresent(Int.self, forKey: .sceneEchoMinimumWords) ?? 3
        sceneEchoMinimumCharacters = try values.decodeIfPresent(
            Int.self,
            forKey: .sceneEchoMinimumCharacters
        ) ?? 10
        repairsDanglingTail = try values.decodeIfPresent(Bool.self, forKey: .repairsDanglingTail) ?? true
        factualGrounding = try values.decodeIfPresent(
            LabFactualGroundingMode.self,
            forKey: .factualGrounding
        ) ?? .off
        suppressesSensitiveScenes = try values.decodeIfPresent(
            Bool.self,
            forKey: .suppressesSensitiveScenes
        ) ?? true
        rejectsPromptLeaks = try values.decodeIfPresent(Bool.self, forKey: .rejectsPromptLeaks) ?? true
        rejectsContextReplay = try values.decodeIfPresent(Bool.self, forKey: .rejectsContextReplay) ?? true
        rejectsSelfRepetition = try values.decodeIfPresent(
            Bool.self,
            forKey: .rejectsSelfRepetition
        ) ?? true
        lengthPolicy = try values.decodeIfPresent(
            LabSuggestionLengthPolicy.self,
            forKey: .lengthPolicy
        ) ?? .fixed
        dynamicLength = try values.decodeIfPresent(
            LabDynamicLengthConfiguration.self,
            forKey: .dynamicLength
        ) ?? .init()
    }
}
