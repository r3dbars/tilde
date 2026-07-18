public struct RetryBudgetPolicy: Equatable, Sendable {
    public let totalBudgetMilliseconds: Int
    public let minimumRetryBudgetMilliseconds: Int

    public init(
        totalBudgetMilliseconds: Int = 1_200,
        minimumRetryBudgetMilliseconds: Int = 450
    ) {
        self.totalBudgetMilliseconds = max(0, totalBudgetMilliseconds)
        self.minimumRetryBudgetMilliseconds = max(0, minimumRetryBudgetMilliseconds)
    }

    public func remainingBudgetMilliseconds(after elapsedMilliseconds: Int) -> Int {
        max(0, totalBudgetMilliseconds - max(0, elapsedMilliseconds))
    }

    public func shouldRetry(after elapsedMilliseconds: Int) -> Bool {
        guard elapsedMilliseconds >= 0 else {
            return false
        }

        return remainingBudgetMilliseconds(after: elapsedMilliseconds) >= minimumRetryBudgetMilliseconds
    }
}
