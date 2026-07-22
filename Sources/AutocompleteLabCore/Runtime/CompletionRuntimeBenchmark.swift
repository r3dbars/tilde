import Foundation

public enum CompletionRuntimeCandidate: String, Equatable, Sendable {
    case liteRTLM
    case mlx
    case mock
    case unavailable

    public var displayName: String {
        switch self {
        case .liteRTLM:
            return "LiteRT-LM"
        case .mlx:
            return "MLX"
        case .mock:
            return "mock"
        case .unavailable:
            return "unavailable"
        }
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
        fallbackCandidate: .unavailable,
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
    func complete(
        _ request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion?
}

public extension ModelRuntime {
    func complete(
        _ request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        try await complete(request)
    }
}
