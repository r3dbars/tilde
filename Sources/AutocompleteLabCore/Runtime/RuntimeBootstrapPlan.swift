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

public struct LocalModelAssetManifest: Equatable, Sendable {
    public let model: LocalModelID
    public let runtimeCandidate: CompletionRuntimeCandidate
    public let cacheDirectoryName: String
    public let fileName: String
    public let expectedMinimumBytes: Int64

    public init(
        model: LocalModelID,
        runtimeCandidate: CompletionRuntimeCandidate,
        cacheDirectoryName: String,
        fileName: String,
        expectedMinimumBytes: Int64
    ) {
        self.model = model
        self.runtimeCandidate = runtimeCandidate
        self.cacheDirectoryName = cacheDirectoryName
        self.fileName = fileName
        self.expectedMinimumBytes = max(1, expectedMinimumBytes)
    }

    public static let gemma4E2BMLX = LocalModelAssetManifest(
        model: .gemma4E2B,
        runtimeCandidate: .mlx,
        cacheDirectoryName: "Models/Gemma4E2B/MLX",
        fileName: "gemma-4-e2b-mlx",
        expectedMinimumBytes: 1024 * 1024
    )
}

public struct RuntimeBootstrapPlan: Equatable, Sendable {
    public let decision: EmbeddedRuntimeDecision
    public let preferredAsset: LocalModelAssetManifest
    public let assetState: LocalModelAssetState
    public let nativeRuntimeAvailable: Bool

    public init(
        decision: EmbeddedRuntimeDecision = .mvp,
        preferredAsset: LocalModelAssetManifest = .gemma4E2BMLX,
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

    public func readinessSummary(for runtimeState: LocalRuntimeState) -> String {
        guard let fallbackReason,
              activeCandidate == .mock else {
            return runtimeState.statusSummary
        }

        return "\(runtimeState.statusSummary); fallback: \(fallbackReason)"
    }
}
