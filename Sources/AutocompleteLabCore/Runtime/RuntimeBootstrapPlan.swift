import Foundation

public enum LocalModelAssetState: Equatable, Sendable {
    case missing(expectedPath: String)
    case available(path: String)
    case invalid(path: String, reason: String)

    public var isUsable: Bool {
        if case .available = self {
            return true
        }

        return false
    }

    public var statusSummary: String {
        switch self {
        case let .missing(expectedPath):
            return "missing model asset at \(expectedPath)"
        case let .available(path):
            return "model asset available at \(path)"
        case let .invalid(path, reason):
            return "model asset invalid at \(path): \(reason)"
        }
    }
}

public enum RuntimeReadinessStage: String, Equatable, Sendable {
    case downloadNeeded
    case repairNeeded
    case runtimeUnavailable
    case warming
    case ready
    case failed
}

public enum RuntimeReadinessAction: String, Equatable, Sendable {
    case installModel
    case repairModel
    case cancelModelInstall
    case revealModelFolder
    case wait
    case retry
    case none

    public var displayName: String {
        switch self {
        case .installModel:
            return "Install Model"
        case .repairModel:
            return "Repair Model"
        case .cancelModelInstall:
            return "Cancel Model Install"
        case .revealModelFolder:
            return "Reveal Model Folder"
        case .wait:
            return "Wait"
        case .retry:
            return "Retry"
        case .none:
            return "None"
        }
    }
}

public struct RuntimeReadinessReport: Equatable, Sendable {
    public let stage: RuntimeReadinessStage
    public let summary: String
    public let detail: String?
    public let action: RuntimeReadinessAction
    public let isReady: Bool

    public init(
        stage: RuntimeReadinessStage,
        summary: String,
        detail: String? = nil,
        action: RuntimeReadinessAction,
        isReady: Bool = false
    ) {
        self.stage = stage
        self.summary = summary
        self.detail = detail
        self.action = action
        self.isReady = isReady
    }

    public var allowsSuggestions: Bool {
        isReady
    }
}

public struct LocalModelAssetManifest: Equatable, Sendable {
    public let model: LocalModelID
    public let runtimeCandidate: CompletionRuntimeCandidate
    public let cacheDirectoryName: String
    public let fileName: String
    public let source: LocalModelAssetSource?
    public let expectedMinimumBytes: Int64
    public let requiredFileNames: Set<String>
    public let requiredModelFileExtension: String
    public let requiresVisionLanguageFactory: Bool

    public init(
        model: LocalModelID,
        runtimeCandidate: CompletionRuntimeCandidate,
        cacheDirectoryName: String,
        fileName: String,
        source: LocalModelAssetSource? = nil,
        expectedMinimumBytes: Int64,
        requiredFileNames: Set<String> = ["config.json"],
        requiredModelFileExtension: String = "safetensors",
        requiresVisionLanguageFactory: Bool = false
    ) {
        self.model = model
        self.runtimeCandidate = runtimeCandidate
        self.cacheDirectoryName = cacheDirectoryName
        self.fileName = fileName
        self.source = source
        self.expectedMinimumBytes = max(1, expectedMinimumBytes)
        self.requiredFileNames = requiredFileNames
        self.requiredModelFileExtension = requiredModelFileExtension
        self.requiresVisionLanguageFactory = requiresVisionLanguageFactory
    }

    public static let gemma4E2BMLX = LocalModelAssetManifest(
        model: .gemma4E2B,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Gemma4E2B/MLX",
        fileName: "gemma-4-e2b-mlx",
        expectedMinimumBytes: 1024 * 1024
    )

    public static let gemma4E4BMLX = LocalModelAssetManifest(
        model: .gemma4E4B,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Gemma4E4B/MLX",
        fileName: "gemma-4-e4b-4bit",
        expectedMinimumBytes: 4 * 1024 * 1024 * 1024,
        requiredFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"],
        requiresVisionLanguageFactory: true
    )

    public static let gemma4E4BItOptiQMLX = LocalModelAssetManifest(
        model: .gemma4E4BItOptiQ,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Gemma4E4BItOptiQ/MLX",
        fileName: "gemma-4-e4b-it-OptiQ-4bit",
        expectedMinimumBytes: 5 * 1024 * 1024 * 1024,
        requiredFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"]
    )

    public static let gemma4A4BMLX = LocalModelAssetManifest(
        model: .gemma4A4B,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Gemma4A4B/MLX",
        fileName: "gemma-4-26b-a4b-it-4bit",
        expectedMinimumBytes: 14 * 1024 * 1024 * 1024,
        requiredFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"],
        requiresVisionLanguageFactory: true
    )

    public static let qwen3SmallMLX = LocalModelAssetManifest(
        model: .qwen3Small,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Qwen3Small/MLX",
        fileName: "qwen3-0.6b-4bit",
        expectedMinimumBytes: 256 * 1024 * 1024
    )

    public static let qwen3MediumMLX = LocalModelAssetManifest(
        model: .qwen3Medium,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Qwen3Medium/MLX",
        fileName: "qwen3-1.7b-4bit",
        expectedMinimumBytes: 768 * 1024 * 1024
    )

    public static let qwen35NineBMLX = LocalModelAssetManifest(
        model: .qwen35NineB,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Qwen35NineB/MLX",
        fileName: "Qwen3.5-9B-MLX-4bit",
        expectedMinimumBytes: 5 * 1024 * 1024 * 1024,
        requiredFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"]
    )

    public static let qwen35FourBMLX = LocalModelAssetManifest(
        model: .qwen35FourB,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Qwen35FourB/MLX",
        fileName: "Qwen3.5-4B-4bit",
        source: .qwen35FourBMLX4Bit,
        expectedMinimumBytes: 2 * 1024 * 1024 * 1024,
        requiredFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"]
    )

    public static let preferredMLX = qwen35FourBMLX

    public static let selectableMLXManifests: [String: LocalModelAssetManifest] = [
        "gemma-4-e2b": .gemma4E2BMLX,
        "gemma-4-e4b": .gemma4E4BMLX,
        "gemma4-e4b": .gemma4E4BMLX,
        "gemma-4-e4b-4bit": .gemma4E4BMLX,
        "gemma-4-e4b-it-optiq": .gemma4E4BItOptiQMLX,
        "gemma-4-e4b-it-optiq-4bit": .gemma4E4BItOptiQMLX,
        "gemma4-e4b-it-optiq": .gemma4E4BItOptiQMLX,
        "gemma-4-26b": .gemma4A4BMLX,
        "qwen3-0.6b": .qwen3SmallMLX,
        "qwen3-1.7b": .qwen3MediumMLX,
        "qwen35-4b": .qwen35FourBMLX,
        "qwen3.5-4b": .qwen35FourBMLX,
        "qwen35-9b": .qwen35NineBMLX,
        "qwen3.5-9b": .qwen35NineBMLX
    ]

    public static func mlxManifest(named rawName: String?) -> LocalModelAssetManifest {
        guard let rawName else {
            return preferredMLX
        }

        let name = rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !name.isEmpty else {
            return preferredMLX
        }

        return selectableMLXManifests[name] ?? preferredMLX
    }

    public func validatedDirectoryState(
        path: String,
        isDirectory: Bool,
        childFileNames: Set<String>,
        modelBytes: Int64
    ) -> LocalModelAssetState {
        guard isDirectory else {
            return .invalid(path: path, reason: "expected a model directory")
        }

        let missingRequiredFile = requiredFileNames
            .sorted()
            .first { !childFileNames.contains($0) }

        if let missingRequiredFile {
            return .invalid(path: path, reason: "missing \(missingRequiredFile)")
        }

        let hasModelWeights = childFileNames.contains { fileName in
            fileName.lowercased().hasSuffix(".\(requiredModelFileExtension.lowercased())")
        }

        guard hasModelWeights else {
            return .invalid(path: path, reason: "missing .\(requiredModelFileExtension) weights")
        }

        guard modelBytes >= expectedMinimumBytes else {
            return .invalid(path: path, reason: "model weights are too small")
        }

        return .available(path: path)
    }
}

public struct LocalModelAssetSource: Equatable, Sendable {
    public let repoID: String
    public let revision: String
    public let allowPatterns: [String]
    public let estimatedBytes: Int64?
    public let licenseURL: String?

    public init(
        repoID: String,
        revision: String = "main",
        allowPatterns: [String],
        estimatedBytes: Int64? = nil,
        licenseURL: String? = nil
    ) {
        self.repoID = repoID
        self.revision = revision
        self.allowPatterns = allowPatterns
        self.estimatedBytes = estimatedBytes
        self.licenseURL = licenseURL
    }

    public static let defaultMLXAllowPatterns = [
        "chat_template.jinja",
        "config.json",
        "generation_config.json",
        "*.safetensors",
        "*.safetensors.index.json",
        "merges.txt",
        "preprocessor_config.json",
        "processor_config.json",
        "special_tokens_map.json",
        "tokenizer.model",
        "tokenizer.json",
        "tokenizer_config.json",
        "video_preprocessor_config.json",
        "vocab.json"
    ]

    public static let qwen35FourBMLX4Bit = LocalModelAssetSource(
        repoID: "mlx-community/Qwen3.5-4B-MLX-4bit",
        allowPatterns: defaultMLXAllowPatterns,
        estimatedBytes: 3_030_000_000,
        licenseURL: "https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit"
    )
}

public struct RuntimeBootstrapPlan: Equatable, Sendable {
    public let decision: EmbeddedRuntimeDecision
    public let preferredAsset: LocalModelAssetManifest
    public let assetState: LocalModelAssetState
    public let nativeRuntimeAvailable: Bool

    public init(
        decision: EmbeddedRuntimeDecision = .mvp,
        preferredAsset: LocalModelAssetManifest = .preferredMLX,
        assetState: LocalModelAssetState,
        nativeRuntimeAvailable: Bool
    ) {
        self.decision = decision
        self.preferredAsset = preferredAsset
        self.assetState = assetState
        self.nativeRuntimeAvailable = nativeRuntimeAvailable
    }

    public var activeCandidate: CompletionRuntimeCandidate {
        guard nativeRuntimeAvailable else {
            return .mock
        }

        guard assetState.isUsable else {
            return .mock
        }

        return decision.preferredCandidate
    }

    public var fallbackReason: String? {
        if !nativeRuntimeAvailable {
            return "\(decision.preferredCandidate.displayName) runtime is not linked yet"
        }

        if !assetState.isUsable {
            return assetState.statusSummary
        }

        return nil
    }

    public func isProductionReady(runtimeState: LocalRuntimeState) -> Bool {
        activeCandidate == decision.preferredCandidate
            && assetState.isUsable
            && nativeRuntimeAvailable
            && runtimeState == .ready(candidate: decision.preferredCandidate)
    }

    public func readinessReport(for runtimeState: LocalRuntimeState) -> RuntimeReadinessReport {
        switch assetState {
        case let .missing(expectedPath):
            return RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: fallbackSummary("download needed (\(preferredAsset.model.rawValue))", runtimeState: runtimeState),
                detail: "Expected MLX model folder at \(expectedPath)",
                action: preferredAsset.source == nil ? .revealModelFolder : .installModel
            )

        case let .invalid(path, reason):
            return RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: fallbackSummary("model folder needs repair", runtimeState: runtimeState),
                detail: "\(path): \(reason)",
                action: preferredAsset.source == nil ? .revealModelFolder : .repairModel
            )

        case .available:
            break
        }

        guard nativeRuntimeAvailable else {
            return RuntimeReadinessReport(
                stage: .runtimeUnavailable,
                summary: fallbackSummary("runtime unavailable (\(decision.preferredCandidate.displayName))", runtimeState: runtimeState),
                detail: "\(decision.preferredCandidate.displayName) runtime is not linked yet",
                action: .none
            )
        }

        switch runtimeState {
        case let .unavailable(reason):
            return RuntimeReadinessReport(
                stage: .warming,
                summary: "warming \(decision.preferredCandidate.displayName)",
                detail: reason,
                action: .wait
            )
        case .warming:
            return RuntimeReadinessReport(
                stage: .warming,
                summary: runtimeState.statusSummary,
                detail: nil,
                action: .wait
            )
        case let .ready(candidate):
            return RuntimeReadinessReport(
                stage: .ready,
                summary: runtimeState.statusSummary,
                detail: nil,
                action: .none,
                isReady: candidate == decision.preferredCandidate
            )
        case let .failed(_, reason):
            return RuntimeReadinessReport(
                stage: .failed,
                summary: runtimeState.statusSummary,
                detail: reason,
                action: .retry
            )
        }
    }

    public func readinessSummary(for runtimeState: LocalRuntimeState) -> String {
        readinessReport(for: runtimeState).summary
    }

    private func fallbackSummary(_ primary: String, runtimeState: LocalRuntimeState) -> String {
        guard activeCandidate == .mock else {
            return primary
        }

        return "\(primary); fallback: \(runtimeState.statusSummary)"
    }
}
