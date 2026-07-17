import Testing
@testable import AutocompleteLabCore

// Locks the invariants recorded in docs/product/adr/0001-breadth-vs-depth.md.
//
// ADR-0001 decided that generic / broad autocomplete support is ON (as of
// 2026-06-13): apps with no custom profile fall through to the "Generic App"
// fallback at the `.accept` rung, and routing does not restrict itself to a
// known-apps allowlist. That breadth is only legitimate because a fixed set of
// safety guardrails holds REGARDLESS of breadth. This suite fails loudly if a
// future change flips the decision, or relaxes a guardrail, without first
// updating the ADR.
//
// If you are here because this suite failed: do not weaken the assertions to go
// green. Either you did not mean to change the covenant (revert), or you did —
// in which case supersede ADR-0001 and update this suite in the same change.
@Suite("ADR-0001 breadth vs depth invariants")
struct BreadthVsDepthADRTests {

    // MARK: Decision — broad support is ON

    @Test("Generic fallback profile stays at the accept rung (broad support ON)")
    func genericFallbackProfileStaysAtAcceptRung() {
        let fallback = AppCompatibilityProfile.fallback

        // Identity of the broad-support profile.
        #expect(fallback.id == "fallback")
        #expect(fallback.displayName == "Generic App")

        // The decision of record: unprofiled apps reach the `.accept` rung — not
        // `.blocked` (the narrow / covenant-restored value) and not merely
        // `.detect`. Over the native Accessibility path with direct insertion.
        #expect(fallback.defaultRung == .accept)
        #expect(fallback.textPath == .nativeAccessibility)
        #expect(fallback.acceptMode == .directAccessibility)
    }

    @Test("Routing does not enforce a known-apps allowlist (broad support ON)")
    func routingDoesNotEnforceKnownApps() {
        // `enforceKnownApps == true` is the narrow posture; ADR-0001 keeps it off
        // so unprofiled apps route to the generic fallback instead of being
        // rejected as unsupported.
        #expect(CompatibilityRoutingSettings.mvp.enforceKnownApps == false)
    }

    // MARK: Guardrails — always on, regardless of breadth

    @Test("Secure-field suppression is always on")
    func secureFieldSuppressionIsAlwaysOn() {
        // Non-negotiable guardrail: secure fields are suppressed before the
        // fallback rung is ever consulted.
        #expect(CompatibilityRoutingSettings.mvp.suppressSecureFields == true)
    }

    @Test("Control-character filtering protects experimentally enabled send surfaces")
    func controlCharacterFilteringProtectsSendSurfaces() throws {
        // The broad-coverage experiment deliberately classifies collaboration
        // apps as not-prompt. Submission safety is instead locked by the
        // unconditional accepted-text newline, Tab, and control-character gate.
        let sendSurfaceBundleIdentifiers = [
            "com.tinyspeck.slackmacgap", // Slack
            "com.hnc.Discord"            // Discord
        ]

        let profiles = CompatibilityProfileStore.mvp.profiles
        let policies = HostCompatibilityPolicyCatalog.mvp.policies

        for bundleIdentifier in sendSurfaceBundleIdentifiers {
            let profile = try #require(profiles[bundleIdentifier])
            #expect(profile.promptAppSafetyMode == .notPrompt)

            let policy = try #require(policies[bundleIdentifier])
            #expect(policy.safetyMode == .notPrompt)
        }

        let safety = AcceptedTextSafetyPolicy()
        let textEdit = try #require(profiles["com.apple.TextEdit"])
        #expect(!safety.decision(acceptedText: "hello\n", profile: textEdit).canInsert)
        #expect(!safety.decision(acceptedText: "hello\t", profile: textEdit).canInsert)
    }

    // MARK: Behavior — breadth and guardrails meet at the router

    @Test("An arbitrary app reaches the accept rung through the generic fallback")
    func arbitraryAppReachesAcceptRungThroughGenericFallback() {
        let router = CompatibilityRouter()
        let decision = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.example.some-unprofiled-app",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                fieldClassifierInput: AXFieldClassifierInput(
                    role: "AXTextArea",
                    textBeforeCursorLength: 18,
                    lineCount: 1
                ),
                isSecureTextEntry: false,
                textBeforeCursor: "Hello there friend",
                hasCaretRect: true
            )
        )

        // Broad support: an unknown app routes to the generic fallback and is NOT
        // rejected as unsupported (that suppression reason only appears under the
        // narrow `enforceKnownApps` posture).
        #expect(decision.profile.id == AppCompatibilityProfile.fallback.id)
        #expect(decision.suppressionReason == nil)
        #expect(decision.rung == .accept)
        #expect(decision.shouldRequestSuggestion)
        #expect(decision.canAcceptSuggestion)
    }

    @Test("Guardrails win over breadth: a secure field on the generic fallback is blocked")
    func guardrailsWinOverBreadthForSecureFields() {
        let router = CompatibilityRouter()
        let decision = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.example.some-unprofiled-app",
                elementRole: nil,
                elementSubrole: nil,
                isSecureTextEntry: true,
                textBeforeCursor: "Hello there friend",
                hasCaretRect: true
            )
        )

        // Even though the same app reaches `.accept` on a normal compose field,
        // a secure field is hard-blocked regardless of breadth.
        #expect(decision.profile.id == AppCompatibilityProfile.fallback.id)
        #expect(decision.rung == .blocked)
        #expect(decision.suppressionReason == .secureTextEntry)
        #expect(!decision.canShowSuggestion)
    }
}
