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
            return "Install Local Model"
        case .repairModel:
            return "Repair Local Model"
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
        if let sourceRevisionError = source?.immutableRevisionError {
            return .invalid(path: path, reason: sourceRevisionError)
        }

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
    public struct ExpectedFile: Equatable, Sendable {
        public let path: String
        public let byteCount: Int64
        public let sha256: String

        public init(path: String, byteCount: Int64, sha256: String) {
            self.path = path
            self.byteCount = byteCount
            self.sha256 = sha256.lowercased()
        }
    }

    public let repoID: String
    public let revision: String
    public let allowPatterns: [String]
    public let estimatedBytes: Int64?
    public let licenseURL: String?
    public let expectedFiles: [ExpectedFile]
    public static let immutableRevisionRequirement = "model source revision must be pinned to an immutable 40-character commit SHA"

    public init(
        repoID: String,
        revision: String,
        allowPatterns: [String],
        estimatedBytes: Int64? = nil,
        licenseURL: String? = nil,
        expectedFiles: [ExpectedFile] = []
    ) {
        self.repoID = repoID
        self.revision = revision
        self.allowPatterns = allowPatterns
        self.estimatedBytes = estimatedBytes
        self.licenseURL = licenseURL
        self.expectedFiles = expectedFiles
    }

    public var immutableRevisionError: String? {
        let trimmed = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == revision,
              revision.unicodeScalars.count == 40,
              revision.unicodeScalars.allSatisfy(Self.isCommitSHAScalar) else {
            return Self.immutableRevisionRequirement
        }

        return nil
    }

    private static func isCommitSHAScalar(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...70).contains(scalar.value)
            || (97...102).contains(scalar.value)
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
        revision: "32f3e8ecf65426fc3306969496342d504bfa13f3",
        allowPatterns: defaultMLXAllowPatterns,
        estimatedBytes: 3_030_000_000,
        licenseURL: "https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit",
        expectedFiles: [
            .init(path: "chat_template.jinja", byteCount: 7_756, sha256: "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
            .init(path: "config.json", byteCount: 3_366, sha256: "f3efc81b2ea8d96a45301037d3ccccbcccdef44a961845c87f286aaddbc6eaaa"),
            .init(path: "model.safetensors", byteCount: 3_034_300_695, sha256: "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db"),
            .init(path: "model.safetensors.index.json", byteCount: 101_944, sha256: "52e534c41f7b97708329c85f762e5882bf48bd5955a422c6ae74eba321e6048a"),
            .init(path: "preprocessor_config.json", byteCount: 390, sha256: "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
            .init(path: "processor_config.json", byteCount: 1_300, sha256: "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
            .init(path: "tokenizer.json", byteCount: 19_989_343, sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
            .init(path: "tokenizer_config.json", byteCount: 1_139, sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
            .init(path: "video_preprocessor_config.json", byteCount: 385, sha256: "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13"),
            .init(path: "vocab.json", byteCount: 6_722_759, sha256: "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003")
        ]
    )

    public var displaySummary: String {
        guard let estimatedBytes else {
            return repoID
        }

        return "\(repoID) • about \(Self.formatBytes(estimatedBytes))"
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var size = Double(max(bytes, 0))
        for unit in units {
            if size < 1024 || unit == units.last {
                if unit == "B" {
                    return "\(Int(size)) \(unit)"
                }

                return String(format: "%.1f %@", size, unit)
            }
            size /= 1024
        }

        return "\(bytes) B"
    }
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
        canWarmPreferredRuntime ? decision.preferredCandidate : .unavailable
    }

    public var canWarmPreferredRuntime: Bool {
        nativeRuntimeAvailable && assetState.isUsable
    }

    public var unavailableReason: String? {
        if !nativeRuntimeAvailable {
            return "\(decision.preferredCandidate.displayName) runtime is not linked yet"
        }

        if !assetState.isUsable {
            return assetState.statusSummary
        }

        return nil
    }

    public var fallbackReason: String? {
        unavailableReason
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
                summary: "download needed (\(preferredAsset.model.rawValue))",
                detail: "The local model is not installed yet. Expected folder: \(expectedPath)",
                action: preferredAsset.source == nil ? .revealModelFolder : .installModel
            )

        case let .invalid(path, reason):
            return RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: "model folder needs repair",
                detail: "The local model folder is incomplete: \(reason). Folder: \(path)",
                action: .repairModel
            )

        case .available:
            break
        }

        if case let .failed(_, reason) = runtimeState,
           Self.isRepairableModelAssetFailure(reason) {
            return RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: "model folder needs repair",
                detail: "The local model failed integrity validation: \(reason)",
                action: .repairModel
            )
        }

        guard nativeRuntimeAvailable else {
            return RuntimeReadinessReport(
                stage: .runtimeUnavailable,
                summary: "runtime unavailable (\(decision.preferredCandidate.displayName))",
                detail: "This build is missing its local model engine. A separate model server will not fix it.",
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

    public static func isRepairableModelAssetFailure(_ reason: String) -> Bool {
        let lowercased = reason.lowercased()
        return lowercased.contains("model asset integrity failed")
            || lowercased.contains("integrity receipt")
    }
}
