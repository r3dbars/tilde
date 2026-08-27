import TildeCore
import Foundation

public enum LabConfigurationError: Error, LocalizedError, Sendable {
    case invalidArmID
    case invalidTemperature
    case invalidPredictionTokens
    case invalidVisibleWords
    case invalidWorkerCount
    case invalidSlotCount
    case invalidRepetitions
    case invalidContextSize
    case invalidTimeout
    case invalidCacheReuse
    case invalidSampling
    case invalidPrompt
    case invalidJudgment
    case invalidSceneBench
    case invalidPersonalization
    case invalidInteraction
    case invalidScenarios
    case invalidRuntime
    case invalidModelProfile
    case missingServer
    case missingModel

    public var errorDescription: String? {
        switch self {
        case .invalidArmID: "The arm ID must be a short stable identifier."
        case .invalidTemperature: "Temperature must be between 0 and 2."
        case .invalidPredictionTokens: "Prediction tokens must be between 1 and 128."
        case .invalidVisibleWords: "Visible words must be between 1 and 20."
        case .invalidWorkerCount: "Worker count must be between 1 and 60."
        case .invalidSlotCount: "Slots per worker must be between 1 and 16."
        case .invalidRepetitions: "Repetitions must be between 1 and 1,000."
        case .invalidContextSize: "Context size per slot must be between 1,024 and 32,768."
        case .invalidTimeout: "Request timeout must be between 1 and 120 seconds."
        case .invalidCacheReuse: "Cache reuse must be between 0 and 4,096 tokens."
        case .invalidSampling: "One or more sampling controls are outside their safe Lab range."
        case .invalidPrompt: "One or more prompt/context controls are outside their bounded Lab range."
        case .invalidJudgment: "One or more judgment controls are outside their bounded Lab range."
        case .invalidSceneBench: "One or more Scene Memory controls are outside their bounded Lab range."
        case .invalidPersonalization: "One or more synthetic personalization controls are invalid."
        case .invalidInteraction: "One or more Interaction Bench controls are invalid."
        case .invalidScenarios: "One or more scenario selection controls are invalid."
        case .invalidRuntime: "One or more advanced llama runtime controls are invalid."
        case .invalidModelProfile: "The selected Lab model identity is invalid."
        case .missingServer: "The selected llama-server executable is unavailable."
        case .missingModel: "The selected local model is unavailable."
        }
    }
}

public struct LabArmConfiguration: Codable, Equatable, Sendable {
    public var id: String
    public var generation: LabGenerationConfiguration
    public var prompt: LabPromptConfiguration
    public var judgment: LabJudgmentConfiguration
    public var sceneBench: LabSceneBenchConfiguration
    public var personalization: LabPersonalizationConfiguration
    public var interaction: LabInteractionConfiguration
    public var scenarios: LabScenarioVariationConfiguration
    public var scoring: LabScoringConfiguration

    public init(
        id: String = "baseline-v1",
        generation: LabGenerationConfiguration = .init(),
        prompt: LabPromptConfiguration = .init(),
        judgment: LabJudgmentConfiguration = .init(),
        sceneBench: LabSceneBenchConfiguration = .init(),
        personalization: LabPersonalizationConfiguration = .init(),
        interaction: LabInteractionConfiguration = .init(),
        scenarios: LabScenarioVariationConfiguration = .init(),
        scoring: LabScoringConfiguration = .init()
    ) {
        self.id = id
        self.generation = generation
        self.prompt = prompt
        self.judgment = judgment
        self.sceneBench = sceneBench
        self.personalization = personalization
        self.interaction = interaction
        self.scenarios = scenarios
        self.scoring = scoring
    }

    /// Compatibility initializer for the first Reply Bench UI and CLI.
    public init(
        id: String,
        temperature: Double,
        predictionTokens: Int = 20,
        maxVisibleWords: Int = CompletionSuggestion.defaultMaxVisibleWords,
        includesScene: Bool = true,
        suppressesSensitiveScenes: Bool = true
    ) {
        self.init(id: id)
        generation.temperature = temperature
        generation.predictionTokens = predictionTokens
        generation.preset = temperature == 0 ? .productionGreedy : .custom
        prompt.includesScene = includesScene
        judgment.maximumVisibleWords = maxVisibleWords
        judgment.maximumVisibleCharacters = CompletionSuggestion.defaultMaxVisibleCharacters(
            forVisibleWords: maxVisibleWords
        )
        judgment.suppressesSensitiveScenes = suppressesSensitiveScenes
    }

    public var temperature: Double { generation.temperature }
    public var predictionTokens: Int { generation.predictionTokens }
    public var maxVisibleWords: Int { judgment.maximumVisibleWords }
    public var includesScene: Bool { prompt.includesScene }
    public var suppressesSensitiveScenes: Bool { judgment.suppressesSensitiveScenes }

    @discardableResult
    public func validated() throws -> LabArmConfiguration {
        guard id.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$"#,
            options: .regularExpression
        ) == id.startIndex..<id.endIndex else { throw LabConfigurationError.invalidArmID }
        guard (0...2).contains(generation.temperature) else {
            throw LabConfigurationError.invalidTemperature
        }
        guard (1...128).contains(generation.predictionTokens) else {
            throw LabConfigurationError.invalidPredictionTokens
        }
        guard (1...CompletionSuggestion.maximumVisibleWords).contains(judgment.maximumVisibleWords) else {
            throw LabConfigurationError.invalidVisibleWords
        }
        guard (0...10_000).contains(generation.topK),
              (0...1).contains(generation.topP),
              (0...1).contains(generation.minP),
              (0...1).contains(generation.typicalP),
              (0...8_192).contains(generation.repeatLastTokens),
              (0...3).contains(generation.repeatPenalty),
              (-2...2).contains(generation.presencePenalty),
              (-2...2).contains(generation.frequencyPenalty),
              (0...20).contains(generation.probabilityCount),
              (0...1).contains(generation.minimumMeanTokenProbability),
              (1...4_096).contains(generation.stopCharacterLimit),
              !generation.advanced.parsedSamplerOrder.isEmpty,
              (-1...8_192).contains(generation.advanced.dryPenaltyLastN),
              (0...2).contains(generation.advanced.mirostatMode) else {
            throw LabConfigurationError.invalidSampling
        }
        guard (80...24_000).contains(prompt.maximumContextCharacters),
              (0...24_000).contains(prompt.maximumSceneCharacters),
              (0...12_000).contains(prompt.replyReserveCharacters),
              (1...4_096).contains(prompt.sceneBudgetQuantum),
              (1...100).contains(prompt.conversationTurnLimit),
              (1...24_000).contains(prompt.conversationCharacterBudget),
              (1...24_000).contains(prompt.referenceCharacterBudget),
              (0...12).contains(prompt.maximumIntentFutures),
              (0...1).contains(prompt.intentPriorWeight) else {
            throw LabConfigurationError.invalidPrompt
        }
        guard (1...1_000).contains(judgment.maximumVisibleCharacters),
              (1...20).contains(judgment.sceneEchoMinimumWords),
              (1...500).contains(judgment.sceneEchoMinimumCharacters),
              (0...1).contains(judgment.dynamicLength.silenceBelowConfidence),
              (0...1).contains(judgment.dynamicLength.highConfidence),
              (0...1).contains(judgment.dynamicLength.veryHighConfidence),
              judgment.dynamicLength.silenceBelowConfidence <= judgment.dynamicLength.highConfidence,
              judgment.dynamicLength.highConfidence <= judgment.dynamicLength.veryHighConfidence,
              (1...20).contains(judgment.dynamicLength.shortMaximumWords),
              (1...20).contains(judgment.dynamicLength.clauseMaximumWords),
              (1...20).contains(judgment.dynamicLength.sentenceMaximumWords),
              judgment.dynamicLength.shortMaximumWords <= judgment.dynamicLength.clauseMaximumWords,
              judgment.dynamicLength.clauseMaximumWords <= judgment.dynamicLength.sentenceMaximumWords else {
            throw LabConfigurationError.invalidJudgment
        }
        guard (0...300).contains(sceneBench.freshnessSeconds),
              (1...100).contains(sceneBench.maximumTurns),
              sceneBench.bubbleMinimumWidth >= 0,
              sceneBench.bubbleMinimumWidth < sceneBench.bubbleMaximumWidth,
              sceneBench.bubbleMaximumWidth <= 1,
              sceneBench.otherSpeakerMaximumX < sceneBench.selfSpeakerMinimumX,
              (0...1).contains(sceneBench.ocrNoiseRate),
              (1...256).contains(sceneBench.gridWidth),
              (1...256).contains(sceneBench.gridHeight) else {
            throw LabConfigurationError.invalidSceneBench
        }
        guard (1...100).contains(personalization.minimumSupport),
              (0...1).contains(personalization.minimumConfidence),
              (1...20).contains(personalization.maximumTailWords),
              (0...1).contains(personalization.recencyWeight),
              (0...1).contains(personalization.frequencyWeight),
              personalization.recencyWeight + personalization.frequencyWeight > 0,
              (1...10_000).contains(personalization.lookupDeadlineMilliseconds) else {
            throw LabConfigurationError.invalidPersonalization
        }
        guard (1...20).contains(interaction.minimumTypedCharacters),
              interaction.typingCharactersPerSecond > 0,
              (1...60_000).contains(interaction.socketTimeoutMilliseconds),
              interaction.contextCharacterLimit >= interaction.trailingContextCharacterLimit,
              !interaction.hosts.isEmpty else {
            throw LabConfigurationError.invalidInteraction
        }
        if let maximumDistinctSituations = scenarios.maximumDistinctSituations,
           !(1...10_000).contains(maximumDistinctSituations) {
            throw LabConfigurationError.invalidScenarios
        }
        return self
    }

    private enum CodingKeys: String, CodingKey {
        case id, generation, prompt, judgment, sceneBench, personalization, interaction, scenarios, scoring
        case temperature, predictionTokens, maxVisibleWords, includesScene, suppressesSensitiveScenes
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        generation = try values.decodeIfPresent(LabGenerationConfiguration.self, forKey: .generation)
            ?? LabGenerationConfiguration(
                temperature: try values.decodeIfPresent(Double.self, forKey: .temperature) ?? 0,
                predictionTokens: try values.decodeIfPresent(Int.self, forKey: .predictionTokens) ?? 20
            )
        prompt = try values.decodeIfPresent(LabPromptConfiguration.self, forKey: .prompt)
            ?? LabPromptConfiguration(
                includesScene: try values.decodeIfPresent(Bool.self, forKey: .includesScene) ?? true
            )
        let legacyWords = try values.decodeIfPresent(Int.self, forKey: .maxVisibleWords)
            ?? CompletionSuggestion.defaultMaxVisibleWords
        judgment = try values.decodeIfPresent(LabJudgmentConfiguration.self, forKey: .judgment)
            ?? LabJudgmentConfiguration(
                maximumVisibleWords: legacyWords,
                maximumVisibleCharacters: CompletionSuggestion.defaultMaxVisibleCharacters(
                    forVisibleWords: legacyWords
                ),
                suppressesSensitiveScenes: try values.decodeIfPresent(
                    Bool.self,
                    forKey: .suppressesSensitiveScenes
                ) ?? true
            )
        sceneBench = try values.decodeIfPresent(LabSceneBenchConfiguration.self, forKey: .sceneBench) ?? .init()
        personalization = try values.decodeIfPresent(
            LabPersonalizationConfiguration.self,
            forKey: .personalization
        ) ?? .init()
        interaction = try values.decodeIfPresent(LabInteractionConfiguration.self, forKey: .interaction) ?? .init()
        scenarios = try values.decodeIfPresent(LabScenarioVariationConfiguration.self, forKey: .scenarios) ?? .init()
        scoring = try values.decodeIfPresent(LabScoringConfiguration.self, forKey: .scoring) ?? .init()
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(generation, forKey: .generation)
        try values.encode(prompt, forKey: .prompt)
        try values.encode(judgment, forKey: .judgment)
        try values.encode(sceneBench, forKey: .sceneBench)
        try values.encode(personalization, forKey: .personalization)
        try values.encode(interaction, forKey: .interaction)
        try values.encode(scenarios, forKey: .scenarios)
        try values.encode(scoring, forKey: .scoring)
    }
}

public enum LabFlashAttention: String, LabNamedOption {
    case automatic = "auto"
    case on
    case off

    public var title: String { rawValue.capitalized }
}

public enum LabKVCacheType: String, LabNamedOption {
    case f32, f16, bf16, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1
    public var title: String { rawValue }
}

public enum LabLoadMode: String, LabNamedOption {
    case automatic = "auto"
    case none
    case mmap
    case mlock
    case mmapAndMlock = "mmap+mlock"
    case directIO = "dio"

    public var title: String { rawValue }
}

public enum LabModelVerificationMode: String, LabNamedOption {
    case productionPinned = "production-pinned"
    case experimentalLocal = "experimental-local"

    public var title: String {
        switch self {
        case .productionPinned: "Production E2B"
        case .experimentalLocal: "Experimental local model"
        }
    }
}

/// Model identity is intentionally kept outside experiment manifests because
/// manifests are safe to share while model paths are local. Production runs
/// retain the immutable asset pin; alternate bytes require an explicit Lab-only
/// profile and are fingerprinted into every aggregate report.
public struct LabModelProfile: Equatable, Sendable {
    public let verificationMode: LabModelVerificationMode
    public let identifier: String
    public let revision: String

    public init(
        verificationMode: LabModelVerificationMode,
        identifier: String,
        revision: String
    ) {
        self.verificationMode = verificationMode
        self.identifier = identifier
        self.revision = revision
    }

    public static let production = LabModelProfile(
        verificationMode: .productionPinned,
        identifier: ProductionModelAsset.identifier,
        revision: ProductionModelAsset.revision
    )

    public static func experimental(
        identifier: String,
        revision: String = "local"
    ) -> LabModelProfile {
        LabModelProfile(
            verificationMode: .experimentalLocal,
            identifier: identifier,
            revision: revision
        )
    }

    @discardableResult
    public func validated() throws -> LabModelProfile {
        guard identifier.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._/+-]{0,127}$"#,
            options: .regularExpression
        ) == identifier.startIndex..<identifier.endIndex,
        revision.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$"#,
            options: .regularExpression
        ) == revision.startIndex..<revision.endIndex else {
            throw LabConfigurationError.invalidModelProfile
        }
        if verificationMode == .productionPinned,
           self != .production {
            throw LabConfigurationError.invalidModelProfile
        }
        return self
    }
}

public struct LabExecutionConfiguration: Equatable, Sendable {
    public let serverExecutable: URL
    public let modelFile: URL
    public let modelProfile: LabModelProfile
    public let workerCount: Int
    public let slotsPerWorker: Int
    public let repetitions: Int
    public let contextSizePerSlot: Int
    public let cacheReuseTokens: Int
    public let timeoutSeconds: Double
    public let seed: UInt64
    public let generationThreads: Int
    public let batchThreads: Int
    public let HTTPThreads: Int
    public let batchSize: Int
    public let microBatchSize: Int
    public let flashAttention: LabFlashAttention
    public let keyCacheType: LabKVCacheType
    public let valueCacheType: LabKVCacheType
    public let KVOffload: Bool
    public let GPUlayers: String
    public let continuousBatching: Bool
    public let fullSWA: Bool
    public let warmup: Bool
    public let loadMode: LabLoadMode
    public let promptCaching: Bool
    public let slotPromptSimilarity: Double

    public init(
        serverExecutable: URL,
        modelFile: URL,
        modelProfile: LabModelProfile = .production,
        workerCount: Int = 2,
        slotsPerWorker: Int = 4,
        repetitions: Int = 10,
        contextSizePerSlot: Int = 4_096,
        cacheReuseTokens: Int = 256,
        timeoutSeconds: Double = 30,
        seed: UInt64 = 0x5449_4C44_454C_4142,
        generationThreads: Int = -1,
        batchThreads: Int = -1,
        HTTPThreads: Int = -1,
        batchSize: Int = 2_048,
        microBatchSize: Int = 512,
        flashAttention: LabFlashAttention = .automatic,
        keyCacheType: LabKVCacheType = .f16,
        valueCacheType: LabKVCacheType = .f16,
        KVOffload: Bool = true,
        GPUlayers: String = "auto",
        continuousBatching: Bool = true,
        fullSWA: Bool = true,
        warmup: Bool = true,
        loadMode: LabLoadMode = .automatic,
        promptCaching: Bool = true,
        slotPromptSimilarity: Double = 0.10
    ) {
        self.serverExecutable = serverExecutable
        self.modelFile = modelFile
        self.modelProfile = modelProfile
        self.workerCount = workerCount
        self.slotsPerWorker = slotsPerWorker
        self.repetitions = repetitions
        self.contextSizePerSlot = contextSizePerSlot
        self.cacheReuseTokens = cacheReuseTokens
        self.timeoutSeconds = timeoutSeconds
        self.seed = seed
        self.generationThreads = generationThreads
        self.batchThreads = batchThreads
        self.HTTPThreads = HTTPThreads
        self.batchSize = batchSize
        self.microBatchSize = microBatchSize
        self.flashAttention = flashAttention
        self.keyCacheType = keyCacheType
        self.valueCacheType = valueCacheType
        self.KVOffload = KVOffload
        self.GPUlayers = GPUlayers
        self.continuousBatching = continuousBatching
        self.fullSWA = fullSWA
        self.warmup = warmup
        self.loadMode = loadMode
        self.promptCaching = promptCaching
        self.slotPromptSimilarity = slotPromptSimilarity
    }

    public var concurrency: Int { workerCount * slotsPerWorker }

    /// Upper-bound model weight footprint if the OS cannot share mapped pages.
    public var independentModelFootprintBytes: UInt64 {
        UInt64(workerCount) * modelFileBytes
    }

    public var pressureWarning: String? {
        let physical = ProcessInfo.processInfo.physicalMemory
        guard independentModelFootprintBytes > physical * 3 / 4 else { return nil }
        return "Independent model workers alone can address more than 75% of physical memory before KV caches. Prefer more slots per worker or calibrate upward gradually."
    }

    @discardableResult
    public func validated() throws -> LabExecutionConfiguration {
        try modelProfile.validated()
        guard FileManager.default.isExecutableFile(atPath: serverExecutable.path) else {
            throw LabConfigurationError.missingServer
        }
        guard FileManager.default.fileExists(atPath: modelFile.path) else {
            throw LabConfigurationError.missingModel
        }
        guard (1...60).contains(workerCount) else { throw LabConfigurationError.invalidWorkerCount }
        guard (1...16).contains(slotsPerWorker) else { throw LabConfigurationError.invalidSlotCount }
        guard (1...1_000).contains(repetitions) else { throw LabConfigurationError.invalidRepetitions }
        guard (1_024...32_768).contains(contextSizePerSlot) else {
            throw LabConfigurationError.invalidContextSize
        }
        guard (1...120).contains(timeoutSeconds) else { throw LabConfigurationError.invalidTimeout }
        guard (0...4_096).contains(cacheReuseTokens) else {
            throw LabConfigurationError.invalidCacheReuse
        }
        guard contextSizePerSlot.multipliedReportingOverflow(by: slotsPerWorker).overflow == false else {
            throw LabConfigurationError.invalidContextSize
        }
        let validThreadCounts = [-1, 0] + Array(1...256)
        guard validThreadCounts.contains(generationThreads),
              validThreadCounts.contains(batchThreads),
              validThreadCounts.contains(HTTPThreads),
              (32...8_192).contains(batchSize),
              (32...8_192).contains(microBatchSize),
              microBatchSize <= batchSize,
              GPUlayers.range(of: #"^(auto|all|none|[0-9]{1,4})$"#, options: .regularExpression) != nil,
              (0...1).contains(slotPromptSimilarity) else {
            throw LabConfigurationError.invalidRuntime
        }
        return self
    }

    private var modelFileBytes: UInt64 {
        let values = try? modelFile.resourceValues(forKeys: [.fileSizeKey])
        if let size = values?.fileSize, size > 0 { return UInt64(size) }
        return modelProfile.verificationMode == .productionPinned
            ? UInt64(ProductionModelAsset.expectedBytes)
            : 0
    }
}

public struct LabExecutionSnapshot: Codable, Equatable, Sendable {
    public let workerCount: Int
    public let slotsPerWorker: Int
    public let repetitions: Int
    public let contextSizePerSlot: Int
    public let cacheReuseTokens: Int
    public let timeoutSeconds: Double
    public let seed: UInt64
    public let generationThreads: Int
    public let batchThreads: Int
    public let HTTPThreads: Int
    public let batchSize: Int
    public let microBatchSize: Int
    public let flashAttention: LabFlashAttention
    public let keyCacheType: LabKVCacheType
    public let valueCacheType: LabKVCacheType
    public let KVOffload: Bool
    public let GPUlayers: String
    public let continuousBatching: Bool
    public let fullSWA: Bool
    public let warmup: Bool
    public let loadMode: LabLoadMode
    public let promptCaching: Bool
    public let slotPromptSimilarity: Double

    public init(_ configuration: LabExecutionConfiguration) {
        workerCount = configuration.workerCount
        slotsPerWorker = configuration.slotsPerWorker
        repetitions = configuration.repetitions
        contextSizePerSlot = configuration.contextSizePerSlot
        cacheReuseTokens = configuration.cacheReuseTokens
        timeoutSeconds = configuration.timeoutSeconds
        seed = configuration.seed
        generationThreads = configuration.generationThreads
        batchThreads = configuration.batchThreads
        HTTPThreads = configuration.HTTPThreads
        batchSize = configuration.batchSize
        microBatchSize = configuration.microBatchSize
        flashAttention = configuration.flashAttention
        keyCacheType = configuration.keyCacheType
        valueCacheType = configuration.valueCacheType
        KVOffload = configuration.KVOffload
        GPUlayers = configuration.GPUlayers
        continuousBatching = configuration.continuousBatching
        fullSWA = configuration.fullSWA
        warmup = configuration.warmup
        loadMode = configuration.loadMode
        promptCaching = configuration.promptCaching
        slotPromptSimilarity = configuration.slotPromptSimilarity
    }

    public var concurrency: Int { workerCount * slotsPerWorker }

    private enum CodingKeys: String, CodingKey {
        case workerCount, slotsPerWorker, repetitions, contextSizePerSlot, cacheReuseTokens
        case timeoutSeconds, seed, generationThreads, batchThreads, HTTPThreads, batchSize
        case microBatchSize, flashAttention, keyCacheType, valueCacheType, KVOffload, GPUlayers
        case continuousBatching, fullSWA, warmup, loadMode, promptCaching, slotPromptSimilarity
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        workerCount = try values.decode(Int.self, forKey: .workerCount)
        slotsPerWorker = try values.decode(Int.self, forKey: .slotsPerWorker)
        repetitions = try values.decode(Int.self, forKey: .repetitions)
        contextSizePerSlot = try values.decode(Int.self, forKey: .contextSizePerSlot)
        cacheReuseTokens = try values.decode(Int.self, forKey: .cacheReuseTokens)
        timeoutSeconds = try values.decode(Double.self, forKey: .timeoutSeconds)
        seed = try values.decode(UInt64.self, forKey: .seed)
        generationThreads = try values.decodeIfPresent(Int.self, forKey: .generationThreads) ?? -1
        batchThreads = try values.decodeIfPresent(Int.self, forKey: .batchThreads) ?? -1
        HTTPThreads = try values.decodeIfPresent(Int.self, forKey: .HTTPThreads) ?? -1
        batchSize = try values.decodeIfPresent(Int.self, forKey: .batchSize) ?? 2_048
        microBatchSize = try values.decodeIfPresent(Int.self, forKey: .microBatchSize) ?? 512
        flashAttention = try values.decodeIfPresent(LabFlashAttention.self, forKey: .flashAttention) ?? .automatic
        keyCacheType = try values.decodeIfPresent(LabKVCacheType.self, forKey: .keyCacheType) ?? .f16
        valueCacheType = try values.decodeIfPresent(LabKVCacheType.self, forKey: .valueCacheType) ?? .f16
        KVOffload = try values.decodeIfPresent(Bool.self, forKey: .KVOffload) ?? true
        GPUlayers = try values.decodeIfPresent(String.self, forKey: .GPUlayers) ?? "auto"
        continuousBatching = try values.decodeIfPresent(Bool.self, forKey: .continuousBatching) ?? true
        fullSWA = try values.decodeIfPresent(Bool.self, forKey: .fullSWA) ?? true
        warmup = try values.decodeIfPresent(Bool.self, forKey: .warmup) ?? true
        loadMode = try values.decodeIfPresent(LabLoadMode.self, forKey: .loadMode) ?? .automatic
        promptCaching = try values.decodeIfPresent(Bool.self, forKey: .promptCaching) ?? true
        slotPromptSimilarity = try values.decodeIfPresent(Double.self, forKey: .slotPromptSimilarity) ?? 0.10
    }
}
