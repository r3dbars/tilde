import Testing
@testable import AutocompleteLabCore

@Suite("Insertion retry policy")
struct InsertionRetryPolicyTests {
    @Test("Retries one unchanged key-event insertion")
    func retriesOneUnchangedKeyEventInsertion() {
        let policy = InsertionRetryPolicy(maxRetryCount: 1)

        #expect(policy.shouldRetry(result: .unchanged, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .keyEvents, retryCount: 1))
    }

    @Test("Does not retry risky or already changed results")
    func doesNotRetryRiskyOrAlreadyChangedResults() {
        let policy = InsertionRetryPolicy(maxRetryCount: 1)

        #expect(!policy.shouldRetry(result: .partial, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .duplicateText, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .changedUnexpectedly, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .verified, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .axSelectedText, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .axValueReplacement, retryCount: 0))
    }
}
