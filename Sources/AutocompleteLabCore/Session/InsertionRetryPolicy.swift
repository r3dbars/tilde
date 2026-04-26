import Foundation

public struct InsertionRetryPolicy: Equatable, Sendable {
    public let maxRetryCount: Int

    public init(maxRetryCount: Int = 1) {
        self.maxRetryCount = maxRetryCount
    }

    public func shouldRetry(
        result: InsertionVerificationResult,
        insertionMode: InsertionMode,
        retryCount: Int
    ) -> Bool {
        guard retryCount < maxRetryCount,
              result == .unchanged else {
            return false
        }

        switch insertionMode {
        case .keyEvents, .axThenKeyEvents:
            return true
        case .axSelectedText, .axValueReplacement, .clipboardFallbackOptIn, .disabled:
            return false
        }
    }
}
