import Foundation

public enum CompletionRuntimeCandidate: String, Equatable, Sendable {
    case liteRTLM
    case mlx
    case mock

    public var displayName: String {
        switch self {
        case .liteRTLM:
            return "LiteRT-LM"
        case .mlx:
            return "MLX"
        case .mock:
            return "mock"
        }
    }
}

public struct CompletionLatencySample: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let milliseconds: Int
    public let tokenCount: Int

    public init(candidate: CompletionRuntimeCandidate, milliseconds: Int, tokenCount: Int) {
        self.candidate = candidate
        self.milliseconds = milliseconds
        self.tokenCount = tokenCount
    }
}

public struct CompletionRuntimeBenchmark: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let samples: [CompletionLatencySample]

    public init(candidate: CompletionRuntimeCandidate, samples: [CompletionLatencySample]) {
        self.candidate = candidate
        self.samples = samples
    }

    public var averageLatencyMilliseconds: Int? {
        guard !samples.isEmpty else {
            return nil
        }

        let total = samples.reduce(0) { $0 + $1.milliseconds }
        return total / samples.count
    }

    public func passesAutocompleteTarget(_ policy: CompletionModelPolicy = .mvp) -> Bool {
        guard let averageLatencyMilliseconds else {
            return false
        }

        return averageLatencyMilliseconds <= policy.targetLatencyMilliseconds
    }
}

public struct EmbeddedRuntimeDecision: Equatable, Sendable {
    public let preferredCandidate: CompletionRuntimeCandidate
    public let fallbackCandidate: CompletionRuntimeCandidate
    public let allowsUserManagedServer: Bool

    public init(
        preferredCandidate: CompletionRuntimeCandidate,
        fallbackCandidate: CompletionRuntimeCandidate,
        allowsUserManagedServer: Bool
    ) {
        self.preferredCandidate = preferredCandidate
        self.fallbackCandidate = fallbackCandidate
        self.allowsUserManagedServer = allowsUserManagedServer
    }

    public static let mvp = EmbeddedRuntimeDecision(
        preferredCandidate: .mlx,
        fallbackCandidate: .liteRTLM,
        allowsUserManagedServer: false
    )
}

public enum LocalRuntimeState: Equatable, Sendable {
    case unavailable(reason: String)
    case warming(candidate: CompletionRuntimeCandidate)
    case ready(candidate: CompletionRuntimeCandidate)
    case failed(candidate: CompletionRuntimeCandidate, reason: String)

    public var statusSummary: String {
        switch self {
        case let .unavailable(reason):
            return "not ready: \(reason)"
        case let .warming(candidate):
            return "warming \(candidate.displayName)"
        case let .ready(candidate):
            return "ready (\(candidate.displayName))"
        case let .failed(candidate, reason):
            return "\(candidate.displayName) failed: \(reason)"
        }
    }

    public var isReady: Bool {
        if case .ready = self {
            return true
        }

        return false
    }
}

public protocol ModelRuntime: Sendable {
    var state: LocalRuntimeState { get async }
    func warm() async throws
    func cancel()
    func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion?
}
