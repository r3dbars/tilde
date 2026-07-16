import Testing
@testable import AutocompleteLabCore

@Suite("Personalization context policy")
struct PersonalizationContextPolicyTests {
    @Test("Requires opt in, capture permission, and continuation mode")
    func requiresEveryGate() {
        let policy = PersonalizationContextPolicy()
        let allowed = PersonalCaptureDecision.allowed(metadata: [:])
        let blocked = PersonalCaptureDecision.blocked(.secureContext, metadata: [:])

        #expect(policy.allows(personalCaptureEnabled: true, captureDecision: allowed, requestMode: .phraseContinuation))
        #expect(!policy.allows(personalCaptureEnabled: false, captureDecision: allowed, requestMode: .phraseContinuation))
        #expect(!policy.allows(personalCaptureEnabled: true, captureDecision: blocked, requestMode: .phraseContinuation))
        #expect(!policy.allows(personalCaptureEnabled: true, captureDecision: allowed, requestMode: .wordCompletion))
    }
}
