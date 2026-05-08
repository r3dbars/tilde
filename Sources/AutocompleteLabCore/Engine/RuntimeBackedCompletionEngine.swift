import Foundation

public struct RuntimeFailureBackoffPolicy: Equatable, Sendable {
    public let failureThreshold: Int
    public let cooldownMilliseconds: Int

    public init(failureThreshold: Int, cooldownMilliseconds: Int) {
        self.failureThreshold = max(1, failureThreshold)
        self.cooldownMilliseconds = max(0, cooldownMilliseconds)
    }

    public static let mvp = RuntimeFailureBackoffPolicy(
        failureThreshold: 2,
        cooldownMilliseconds: 5_000
    )
}

public final class RuntimeBackedCompletionEngine: CompletionEngine, @unchecked Sendable {
    private let runtime: any ModelRuntime
    private let failureBackoffPolicy: RuntimeFailureBackoffPolicy
    private let nowMilliseconds: @Sendable () -> Int
    private let lock = NSLock()
    private var consecutiveFailureCount = 0
    private var suspendedUntilMilliseconds: Int?

    public init(
        runtime: any ModelRuntime,
        failureBackoffPolicy: RuntimeFailureBackoffPolicy = .mvp,
        nowMilliseconds: @escaping @Sendable () -> Int = {
            Int(ProcessInfo.processInfo.systemUptime * 1_000)
        }
    ) {
        self.runtime = runtime
        self.failureBackoffPolicy = failureBackoffPolicy
        self.nowMilliseconds = nowMilliseconds
    }

    public func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await completeWithBackoff {
            try await runtime.complete(request)
        }
    }

    public func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        try await completeWithBackoff {
            try await runtime.complete(request, onPartialSuggestion: onPartialSuggestion)
        }
    }

    private func completeWithBackoff(
        _ operation: () async throws -> CompletionSuggestion?
    ) async throws -> CompletionSuggestion? {
        let now = nowMilliseconds()
        guard !isSuspended(nowMilliseconds: now) else {
            return nil
        }

        do {
            let suggestion = try await operation()
            recordSuccess()
            return suggestion
        } catch {
            recordFailure(nowMilliseconds: now)
            throw error
        }
    }

    private func isSuspended(nowMilliseconds: Int) -> Bool {
        lock.withLock {
            guard let suspendedUntilMilliseconds else {
                return false
            }

            if nowMilliseconds < suspendedUntilMilliseconds {
                return true
            }

            self.suspendedUntilMilliseconds = nil
            return false
        }
    }

    private func recordSuccess() {
        lock.withLock {
            consecutiveFailureCount = 0
            suspendedUntilMilliseconds = nil
        }
    }

    private func recordFailure(nowMilliseconds: Int) {
        lock.withLock {
            consecutiveFailureCount += 1
            guard consecutiveFailureCount >= failureBackoffPolicy.failureThreshold else {
                return
            }

            suspendedUntilMilliseconds = nowMilliseconds + failureBackoffPolicy.cooldownMilliseconds
        }
    }
}
