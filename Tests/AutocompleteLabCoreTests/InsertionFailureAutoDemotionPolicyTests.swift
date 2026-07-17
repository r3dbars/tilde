import Testing
@testable import AutocompleteLabCore

@Suite("Insertion failure auto-demotion policy")
struct InsertionFailureAutoDemotionPolicyTests {
    @Test("Consecutive failures demote then disable one bundle")
    func failuresDemoteThenDisable() {
        var policy = InsertionFailureAutoDemotionPolicy(failureThreshold: 2)

        #expect(policy.record(result: .unchanged, bundleIdentifier: "app.a") == .unchanged)
        #expect(policy.record(result: .partial, bundleIdentifier: "app.a") == .demoteToWordOnly)
        #expect(policy.record(result: .literalTab, bundleIdentifier: "app.a") == .demoteToWordOnly)
        #expect(policy.record(result: .changedUnexpectedly, bundleIdentifier: "app.a") == .disableForSession)
    }

    @Test("Verified insertion resets only its bundle")
    func verifiedInsertionResetsOneBundle() {
        var policy = InsertionFailureAutoDemotionPolicy(failureThreshold: 2)
        _ = policy.record(result: .unchanged, bundleIdentifier: "app.a")
        _ = policy.record(result: .unchanged, bundleIdentifier: "app.a")
        _ = policy.record(result: .unchanged, bundleIdentifier: "app.b")

        #expect(policy.record(result: .verified, bundleIdentifier: "app.a") == .unchanged)
        #expect(policy.decision(for: "app.a") == .unchanged)
        #expect(policy.consecutiveFailureCount(for: "app.a") == 0)
        #expect(policy.consecutiveFailureCount(for: "app.b") == 1)
    }

    @Test("Manual reset resumes a session-disabled bundle")
    func manualResetResumesBundle() {
        var policy = InsertionFailureAutoDemotionPolicy(failureThreshold: 1)
        _ = policy.record(result: .unchanged, bundleIdentifier: "app.a")
        _ = policy.record(result: .unchanged, bundleIdentifier: "app.a")
        #expect(policy.decision(for: "app.a") == .disableForSession)

        policy.reset(bundleIdentifier: "app.a")

        #expect(policy.decision(for: "app.a") == .unchanged)
    }

    @Test("Threshold clamps and empty bundle identifiers are ignored")
    func thresholdClampsAndEmptyBundleIsIgnored() {
        var policy = InsertionFailureAutoDemotionPolicy(failureThreshold: 0)
        #expect(policy.failureThreshold == 1)
        #expect(policy.record(result: .unchanged, bundleIdentifier: "") == .unchanged)
        #expect(policy.consecutiveFailureCount(for: "") == 0)
    }
}
