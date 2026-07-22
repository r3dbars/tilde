import Testing
@testable import AutocompleteLabCore

@Suite("Insertion verification timing policy")
struct InsertionVerificationTimingPolicyTests {
    @Test("Default apps keep the fast verification delay")
    func defaultAppsKeepFastVerificationDelay() {
        let policy = InsertionVerificationTimingPolicy()
        let profile = CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!

        #expect(policy.delayMilliseconds(for: profile, retryCount: 0) == 140)
        #expect(policy.readOnlyRecheckDelayMilliseconds(
            for: profile,
            result: .unchanged,
            retryCount: 0
        ) == nil)
    }

    @Test("Notes waits longer and rechecks unchanged reads")
    func notesWaitsLongerAndRechecksUnchangedReads() {
        let policy = InsertionVerificationTimingPolicy()
        let profile = CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes")!

        #expect(policy.delayMilliseconds(for: profile, retryCount: 0) == 320)
        #expect(policy.delayMilliseconds(for: profile, retryCount: 1) == 320)
        #expect(policy.readOnlyRecheckDelayMilliseconds(
            for: profile,
            result: .unchanged,
            retryCount: 0
        ) == 280)
        #expect(policy.readOnlyRecheckDelayMilliseconds(
            for: profile,
            result: .verified,
            retryCount: 0
        ) == nil)
    }

}
