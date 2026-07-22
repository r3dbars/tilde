import Testing
@testable import AutocompleteLabCore

@Suite("Insertion failure suppression policy")
struct InsertionFailureSuppressionPolicyTests {
    private let policy = InsertionFailureSuppressionPolicy()

    @Test("Suppresses fields for profiles that fail closed after insertion failures")
    func suppressesFailClosedProfiles() {
        #expect(policy.shouldSuppressField(
            profile: CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop")!,
            failureReason: "insert-failed"
        ))
    }

    @Test("Does not suppress profiles that opted out")
    func respectsProfileOptOut() {
        let profile = CompatibilityProfile(
            bundleIdentifier: "com.example.relaxed",
            displayName: "Relaxed Editor",
            supportLevel: .green,
            supportReason: "Test profile",
            renderMode: .inlineAdjacent,
            insertionMode: .axSelectedText,
            suppressesAfterInsertionFailure: false,
            notes: "Test profile"
        )

        #expect(!policy.shouldSuppressField(
            profile: profile,
            failureReason: "insert-failed"
        ))
    }

    @Test("Requires a concrete failure reason")
    func requiresFailureReason() {
        #expect(!policy.shouldSuppressField(
            profile: CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claudefordesktop")!,
            failureReason: ""
        ))
    }
}
