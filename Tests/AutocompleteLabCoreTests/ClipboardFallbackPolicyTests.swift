import Testing
@testable import AutocompleteLabCore

@Suite("Clipboard fallback policy")
struct ClipboardFallbackPolicyTests {
    private let policy = ClipboardFallbackPolicy()

    @Test("Runtime flag must be enabled before clipboard fallback can run")
    func runtimeFlagMustBeEnabled() {
        let profile = profile(fallbackInsertionMode: .clipboardFallbackOptIn)

        #expect(policy.decision(
            profile: profile,
            runtimeEnabled: false
        ) == .blocked(.runtimeDisabled))
    }

    @Test("Profiles must explicitly opt in to clipboard fallback")
    func profilesMustExplicitlyOptIn() {
        let profile = profile(
            insertionMode: .axSelectedText,
            fallbackInsertionMode: .axValueReplacement
        )

        let decision = policy.decision(
            profile: profile,
            runtimeEnabled: true
        )

        #expect(decision == .blocked(.profileNotOptedIn))
        #expect(decision.message.contains("did not opt in"))
    }

    @Test("Sensitive profiles cannot use clipboard fallback")
    func sensitiveProfilesCannotUseClipboardFallback() {
        let profile = profile(
            fallbackInsertionMode: .clipboardFallbackOptIn,
            isSensitive: true
        )

        #expect(policy.decision(
            profile: profile,
            runtimeEnabled: true
        ) == .blocked(.sensitiveProfile))
    }

    @Test("Non-sensitive opted-in profiles can use clipboard fallback")
    func optedInProfilesCanUseClipboardFallback() {
        let primaryOptIn = profile(insertionMode: .clipboardFallbackOptIn)
        let fallbackOptIn = profile(fallbackInsertionMode: .clipboardFallbackOptIn)

        #expect(policy.decision(
            profile: primaryOptIn,
            runtimeEnabled: true
        ) == .allowed)
        #expect(policy.decision(
            profile: fallbackOptIn,
            runtimeEnabled: true
        ) == .allowed)
    }

    private func profile(
        insertionMode: InsertionMode = .axSelectedText,
        fallbackInsertionMode: InsertionMode? = nil,
        isSensitive: Bool = false
    ) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Editor",
            displayName: "Editor",
            supportLevel: .yellow,
            supportReason: "Test profile",
            renderMode: .inlineAdjacent,
            insertionMode: insertionMode,
            fallbackInsertionMode: fallbackInsertionMode,
            isSensitive: isSensitive,
            notes: "Test profile"
        )
    }
}
