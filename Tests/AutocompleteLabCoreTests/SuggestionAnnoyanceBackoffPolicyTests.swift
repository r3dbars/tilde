import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion annoyance backoff policy")
struct SuggestionAnnoyanceBackoffPolicyTests {
    @Test("Combines decaying repetition misses with prefix cooldown")
    func combinesRepetitionAndPrefixBackoff() throws {
        let now = Date(timeIntervalSince1970: 100)
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let input = PrefixFamilyCooldownInput(
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentifier: field.traceDescription,
            requestMode: .phraseContinuation,
            textBeforeCursor: "Can we make this safer today"
        )
        var policy = SuggestionAnnoyanceBackoffPolicy(
            prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy(
                typedOverCooldownMilliseconds: 1_000,
                repeatedTypedOverCooldownMilliseconds: 1_000,
                typedOverEagernessThreshold: 1,
                traceFingerprintSecret: Data("unit-test-secret".utf8)
            )
        )

        #expect(!policy.shouldSuppressRepetition("use the same phrase", mode: .phraseContinuation, now: now))
        for _ in 0..<3 {
            _ = policy.recordRepetitionMiss("use the same phrase", mode: .phraseContinuation, now: now)
        }
        #expect(policy.shouldSuppressRepetition("use the same phrase", mode: .phraseContinuation, now: now))

        #expect(policy.prefixCooldownDecision(for: input, now: now).canRequest)
        _ = policy.recordPrefixCooldown(.typedOver, input: input, now: now)
        #expect(!policy.prefixCooldownDecision(for: input, now: now).canRequest)
    }

    @Test("Reset clears both annoyance layers")
    func resetClearsBothLayers() throws {
        let now = Date(timeIntervalSince1970: 100)
        let input = PrefixFamilyCooldownInput(
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentifier: "field",
            requestMode: .phraseContinuation,
            textBeforeCursor: "same prefix"
        )
        var policy = SuggestionAnnoyanceBackoffPolicy()
        for _ in 0..<3 {
            _ = policy.recordRepetitionMiss("same phrase", mode: .phraseContinuation, now: now)
        }
        _ = policy.recordPrefixCooldown(.typedOver, input: input, now: now)

        policy.reset()

        #expect(!policy.shouldSuppressRepetition("same phrase", mode: .phraseContinuation, now: now))
        #expect(policy.prefixCooldownDecision(for: input, now: now).canRequest)
    }
}
