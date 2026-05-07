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

    @Test("Retries one unchanged AX value replacement")
    func retriesOneUnchangedAXValueReplacement() {
        let policy = InsertionRetryPolicy(maxRetryCount: 1)

        #expect(policy.shouldRetry(result: .unchanged, insertionMode: .axValueReplacement, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .axValueReplacement, retryCount: 1))
    }

    @Test("Retries unchanged hybrid AX then key-event insertion")
    func retriesUnchangedHybridInsertion() {
        let policy = InsertionRetryPolicy(maxRetryCount: 2)

        #expect(policy.shouldRetry(result: .unchanged, insertionMode: .axThenKeyEvents, retryCount: 0))
        #expect(policy.shouldRetry(result: .unchanged, insertionMode: .axThenKeyEvents, retryCount: 1))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .axThenKeyEvents, retryCount: 2))
    }

    @Test("Does not retry risky or already changed results")
    func doesNotRetryRiskyOrAlreadyChangedResults() {
        let policy = InsertionRetryPolicy(maxRetryCount: 1)

        #expect(!policy.shouldRetry(result: .partial, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .duplicatedAcceptedText, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .insertedAtWrongLocation, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .changedUnexpectedly, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .verified, insertionMode: .keyEvents, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .axSelectedText, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .clipboardFallbackOptIn, retryCount: 0))
        #expect(!policy.shouldRetry(result: .unchanged, insertionMode: .disabled, retryCount: 0))
    }
}
