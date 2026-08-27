import CryptoKit
import Foundation

public enum LabManifestError: Error, LocalizedError, Sendable {
    case unsupportedSchema
    case invalidName
    case noArms
    case tooManyArms
    case duplicateArmID
    case inconsistentLockedScoring

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The experiment manifest schema is unsupported."
        case .invalidName: "The experiment name must be a short display label."
        case .noArms: "The experiment needs at least one arm."
        case .tooManyArms: "An experiment may contain at most 128 arms."
        case .duplicateArmID: "Every experiment arm must have a unique ID."
        case .inconsistentLockedScoring:
            "Score weights are locked, but the experiment arms use different scoring policies. Unlock scoring on every arm or make the policies identical."
        }
    }
}

public struct LabRuntimeConfiguration: Codable, Equatable, Sendable {
    public var workerCount: Int
    public var slotsPerWorker: Int
    public var repetitions: Int
    public var contextSizePerSlot: Int
    public var cacheReuseTokens: Int
    public var timeoutSeconds: Double
    public var seed: UInt64
    public var generationThreads: Int
    public var batchThreads: Int
    public var HTTPThreads: Int
    public var batchSize: Int
    public var microBatchSize: Int
    public var flashAttention: LabFlashAttention
    public var keyCacheType: LabKVCacheType
    public var valueCacheType: LabKVCacheType
    public var KVOffload: Bool
    public var GPUlayers: String
    public var continuousBatching: Bool
    public var fullSWA: Bool
    public var warmup: Bool
    public var loadMode: LabLoadMode
    public var promptCaching: Bool
    public var slotPromptSimilarity: Double

    public init(
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

    public init(_ configuration: LabExecutionConfiguration) {
        self.init(
            workerCount: configuration.workerCount,
            slotsPerWorker: configuration.slotsPerWorker,
            repetitions: configuration.repetitions,
            contextSizePerSlot: configuration.contextSizePerSlot,
            cacheReuseTokens: configuration.cacheReuseTokens,
            timeoutSeconds: configuration.timeoutSeconds,
            seed: configuration.seed,
            generationThreads: configuration.generationThreads,
            batchThreads: configuration.batchThreads,
            HTTPThreads: configuration.HTTPThreads,
            batchSize: configuration.batchSize,
            microBatchSize: configuration.microBatchSize,
            flashAttention: configuration.flashAttention,
            keyCacheType: configuration.keyCacheType,
            valueCacheType: configuration.valueCacheType,
            KVOffload: configuration.KVOffload,
            GPUlayers: configuration.GPUlayers,
            continuousBatching: configuration.continuousBatching,
            fullSWA: configuration.fullSWA,
            warmup: configuration.warmup,
            loadMode: configuration.loadMode,
            promptCaching: configuration.promptCaching,
            slotPromptSimilarity: configuration.slotPromptSimilarity
        )
    }

    public init(_ snapshot: LabExecutionSnapshot) {
        self.init(
            workerCount: snapshot.workerCount,
            slotsPerWorker: snapshot.slotsPerWorker,
            repetitions: snapshot.repetitions,
            contextSizePerSlot: snapshot.contextSizePerSlot,
            cacheReuseTokens: snapshot.cacheReuseTokens,
            timeoutSeconds: snapshot.timeoutSeconds,
            seed: snapshot.seed,
            generationThreads: snapshot.generationThreads,
            batchThreads: snapshot.batchThreads,
            HTTPThreads: snapshot.HTTPThreads,
            batchSize: snapshot.batchSize,
            microBatchSize: snapshot.microBatchSize,
            flashAttention: snapshot.flashAttention,
            keyCacheType: snapshot.keyCacheType,
            valueCacheType: snapshot.valueCacheType,
            KVOffload: snapshot.KVOffload,
            GPUlayers: snapshot.GPUlayers,
            continuousBatching: snapshot.continuousBatching,
            fullSWA: snapshot.fullSWA,
            warmup: snapshot.warmup,
            loadMode: snapshot.loadMode,
            promptCaching: snapshot.promptCaching,
            slotPromptSimilarity: snapshot.slotPromptSimilarity
        )
    }

    public var concurrency: Int { workerCount * slotsPerWorker }

    /// Validates the serializable runtime controls without requiring the local
    /// helper or model files to exist. Asset existence and hashes remain an
    /// execution-time concern.
    @discardableResult
    public func validated() throws -> LabRuntimeConfiguration {
        guard (1...60).contains(workerCount) else {
            throw LabConfigurationError.invalidWorkerCount
        }
        guard (1...16).contains(slotsPerWorker) else {
            throw LabConfigurationError.invalidSlotCount
        }
        guard (1...1_000).contains(repetitions) else {
            throw LabConfigurationError.invalidRepetitions
        }
        guard (1_024...32_768).contains(contextSizePerSlot),
              contextSizePerSlot.multipliedReportingOverflow(by: slotsPerWorker).overflow == false else {
            throw LabConfigurationError.invalidContextSize
        }
        guard (1...120).contains(timeoutSeconds) else {
            throw LabConfigurationError.invalidTimeout
        }
        guard (0...4_096).contains(cacheReuseTokens) else {
            throw LabConfigurationError.invalidCacheReuse
        }
        let validThreadCounts = [-1, 0] + Array(1...256)
        guard validThreadCounts.contains(generationThreads),
              validThreadCounts.contains(batchThreads),
              validThreadCounts.contains(HTTPThreads),
              (32...8_192).contains(batchSize),
              (32...8_192).contains(microBatchSize),
              microBatchSize <= batchSize,
              GPUlayers.range(
                  of: #"^(auto|all|none|[0-9]{1,4})$"#,
                  options: .regularExpression
              ) != nil,
              (0...1).contains(slotPromptSimilarity) else {
            throw LabConfigurationError.invalidRuntime
        }
        return self
    }

    public func materialize(
        serverExecutable: URL,
        modelFile: URL,
        modelProfile: LabModelProfile = .production
    ) -> LabExecutionConfiguration {
        LabExecutionConfiguration(
            serverExecutable: serverExecutable,
            modelFile: modelFile,
            modelProfile: modelProfile,
            workerCount: workerCount,
            slotsPerWorker: slotsPerWorker,
            repetitions: repetitions,
            contextSizePerSlot: contextSizePerSlot,
            cacheReuseTokens: cacheReuseTokens,
            timeoutSeconds: timeoutSeconds,
            seed: seed,
            generationThreads: generationThreads,
            batchThreads: batchThreads,
            HTTPThreads: HTTPThreads,
            batchSize: batchSize,
            microBatchSize: microBatchSize,
            flashAttention: flashAttention,
            keyCacheType: keyCacheType,
            valueCacheType: valueCacheType,
            KVOffload: KVOffload,
            GPUlayers: GPUlayers,
            continuousBatching: continuousBatching,
            fullSWA: fullSWA,
            warmup: warmup,
            loadMode: loadMode,
            promptCaching: promptCaching,
            slotPromptSimilarity: slotPromptSimilarity
        )
    }
}

public struct LabExperimentManifest: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.experiment-manifest.v2"
    public static let supportedSchemas = [
        "tilde-lab.experiment-manifest.v1",
        currentSchema,
    ]

    public var schema: String
    public var name: String
    public var enabledBenches: Set<LabBenchKind>
    public var arms: [LabArmConfiguration]
    public var runtime: LabRuntimeConfiguration
    /// Nil means a fixed development diagnostic. Validation and holdout still
    /// require an explicit protocol and can never be reached through this
    /// compatibility path.
    public var research: LabResearchProtocol?

    public init(
        schema: String = Self.currentSchema,
        name: String = "Tilde experiment",
        enabledBenches: Set<LabBenchKind> = Set(LabBenchKind.allCases),
        arms: [LabArmConfiguration] = [LabArmConfiguration()],
        runtime: LabRuntimeConfiguration = .init(),
        research: LabResearchProtocol? = nil
    ) {
        self.schema = schema
        self.name = name
        self.enabledBenches = enabledBenches
        self.arms = arms
        self.runtime = runtime
        self.research = research
    }

    @discardableResult
    public func validated() throws -> LabExperimentManifest {
        guard Self.supportedSchemas.contains(schema) else { throw LabManifestError.unsupportedSchema }
        guard name.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9 ._:+-]{0,99}$"#,
            options: .regularExpression
        ) != nil else { throw LabManifestError.invalidName }
        guard !arms.isEmpty else { throw LabManifestError.noArms }
        guard arms.count <= 128 else { throw LabManifestError.tooManyArms }
        try runtime.validated()
        var identifiers = Set<String>()
        for arm in arms {
            try arm.validated()
            guard identifiers.insert(arm.id).inserted else { throw LabManifestError.duplicateArmID }
        }
        try Self.validateScoringLock(arms)
        if let research {
            try LabResearchProtocolValidator.validate(research, arms: arms)
            if research.experimentClass == .runtime,
               research.runtimeByArm?[research.baselineArmID] != runtime {
                throw LabResearchProtocolError.runtimeConfigurationRequired
            }
        } else if arms.contains(where: {
            $0.scenarios.partition == .validation || $0.scenarios.partition == .holdout
        }) {
            throw LabResearchProtocolError.protectedPartitionRequiresRegistration
        }
        return self
    }

    /// Prevents an A/B winner from being manufactured by changing the
    /// scorecard between arms. Deliberate scorecard research remains possible
    /// only when every arm explicitly unlocks the comparison.
    public static func validateScoringLock(_ arms: [LabArmConfiguration]) throws {
        guard arms.contains(where: { $0.scoring.weightsLockedDuringComparison }),
              let policy = arms.first?.scoring else { return }
        guard arms.allSatisfy({ $0.scoring == policy }) else {
            throw LabManifestError.inconsistentLockedScoring
        }
    }

    public func digestSHA256() throws -> String {
        try LabCanonicalDigest.sha256(self)
    }

    private enum CodingKeys: String, CodingKey {
        case schema, name, enabledBenches, arms, runtime, research
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decodeIfPresent(String.self, forKey: .schema)
            ?? "tilde-lab.experiment-manifest.v1"
        name = try values.decode(String.self, forKey: .name)
        enabledBenches = try values.decode(Set<LabBenchKind>.self, forKey: .enabledBenches)
        arms = try values.decode([LabArmConfiguration].self, forKey: .arms)
        runtime = try values.decode(LabRuntimeConfiguration.self, forKey: .runtime)
        research = try values.decodeIfPresent(LabResearchProtocol.self, forKey: .research)
    }
}
