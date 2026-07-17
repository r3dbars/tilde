import Testing
@testable import AutocompleteLabCore

@Suite("Insertion failure suppression policy")
struct InsertionFailureSuppressionPolicyTests {
    @Test("Suppresses fields for profiles that fail closed after insertion failures")
    func suppressesFailClosedProfiles() {
        let policy = InsertionFailureSuppressionPolicy(automaticSuppressionEnabled: true)
        #expect(policy.shouldSuppressField(
            profile: ClaudeCodeTerminalHostProofPolicy.proofProfile,
            failureReason: "insert-failed"
        ))
    }

    @Test("Does not suppress profiles that opted out")
    func respectsProfileOptOut() {
        let policy = InsertionFailureSuppressionPolicy(automaticSuppressionEnabled: true)
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
        let policy = InsertionFailureSuppressionPolicy(automaticSuppressionEnabled: true)
        #expect(!policy.shouldSuppressField(
            profile: ClaudeCodeTerminalHostProofPolicy.proofProfile,
            failureReason: ""
        ))
    }

    @Test("Production defaults never suppress a field automatically")
    func productionDefaultsNeverSuppressFieldAutomatically() {
        let policy = InsertionFailureSuppressionPolicy()

        #expect(!policy.shouldSuppressField(
            profile: ClaudeCodeTerminalHostProofPolicy.proofProfile,
            failureReason: "insert-failed"
        ))
    }
}
