import Testing
@testable import AutocompleteLabCore

@Suite("Retry budget policy")
struct RetryBudgetPolicyTests {
    @Test("Default budget allows a retry while enough time remains")
    func allowsRetryWithinDefaultBudget() {
        let policy = RetryBudgetPolicy()

        #expect(policy.shouldRetry(after: 0))
        #expect(policy.shouldRetry(after: 750))
        #expect(policy.remainingBudgetMilliseconds(after: 750) == 450)
    }

    @Test("Default budget skips a retry after the reserve is spent")
    func skipsRetryOutsideDefaultBudget() {
        let policy = RetryBudgetPolicy()

        #expect(!policy.shouldRetry(after: 751))
        #expect(!policy.shouldRetry(after: 1_200))
        #expect(policy.remainingBudgetMilliseconds(after: 1_500) == 0)
    }

    @Test("Invalid elapsed time fails closed")
    func invalidElapsedTimeFailsClosed() {
        let policy = RetryBudgetPolicy()

        #expect(!policy.shouldRetry(after: -1))
    }

    @Test("Custom budgets keep the decision deterministic")
    func customBudget() {
        let policy = RetryBudgetPolicy(
            totalBudgetMilliseconds: 900,
            minimumRetryBudgetMilliseconds: 300
        )

        #expect(policy.shouldRetry(after: 600))
        #expect(!policy.shouldRetry(after: 601))
    }
}
