public enum InsertionFailureAutoDemotionDecision: String, Equatable, Sendable {
    case unchanged
    case demoteToWordOnly
    case disableForSession
}

public struct InsertionFailureAutoDemotionPolicy: Equatable, Sendable {
    public let failureThreshold: Int
    private var consecutiveFailuresByBundleIdentifier: [String: Int] = [:]

    public init(failureThreshold: Int = 3) {
        self.failureThreshold = max(1, failureThreshold)
    }

    @discardableResult
    public mutating func record(
        result: InsertionVerificationResult,
        bundleIdentifier: String
    ) -> InsertionFailureAutoDemotionDecision {
        guard !bundleIdentifier.isEmpty else {
            return .unchanged
        }
        if result.isVerified {
            consecutiveFailuresByBundleIdentifier[bundleIdentifier] = nil
            return .unchanged
        }

        let failureCount = (consecutiveFailuresByBundleIdentifier[bundleIdentifier] ?? 0) + 1
        consecutiveFailuresByBundleIdentifier[bundleIdentifier] = failureCount
        return decision(for: bundleIdentifier)
    }

    public func decision(for bundleIdentifier: String) -> InsertionFailureAutoDemotionDecision {
        let failureCount = consecutiveFailuresByBundleIdentifier[bundleIdentifier] ?? 0
        if failureCount >= failureThreshold * 2 {
            return .disableForSession
        }
        if failureCount >= failureThreshold {
            return .demoteToWordOnly
        }
        return .unchanged
    }

    public func consecutiveFailureCount(for bundleIdentifier: String) -> Int {
        consecutiveFailuresByBundleIdentifier[bundleIdentifier] ?? 0
    }

    public mutating func reset(bundleIdentifier: String) {
        consecutiveFailuresByBundleIdentifier[bundleIdentifier] = nil
    }
}
