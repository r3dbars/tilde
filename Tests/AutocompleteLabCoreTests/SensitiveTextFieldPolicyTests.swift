import Testing
@testable import AutocompleteLabCore

@Suite("Sensitive text field policy")
struct SensitiveTextFieldPolicyTests {
    private let policy = SensitiveTextFieldPolicy()

    @Test("Blocks native secure text subroles")
    func blocksSecureSubrole() {
        #expect(policy.isSensitive(
            role: "AXTextField",
            subrole: "AXSecureTextField",
            fingerprint: FocusedElementFingerprint()
        ))
    }

    @Test("Blocks browser and Electron password-like fields")
    func blocksPasswordLikeFingerprints() {
        let fingerprint = FocusedElementFingerprint(
            identifier: "login-password",
            title: "Password",
            description: "Enter your password",
            help: nil,
            placeholder: "Password",
            windowTitle: "Sign in"
        )

        #expect(policy.isSensitive(
            role: "AXTextField",
            subrole: nil,
            fingerprint: fingerprint
        ))
    }

    @Test("Blocks token and API key fields")
    func blocksTokenFields() {
        #expect(policy.isSensitive(
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "personal-access-token",
                title: nil,
                description: "API key",
                help: "Paste a secret token",
                placeholder: "sk-...",
                windowTitle: "Developer settings"
            )
        ))
    }

    @Test("Allows ordinary writing fields")
    func allowsOrdinaryWritingFields() {
        #expect(!policy.isSensitive(
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "message-composer",
                title: "Message",
                description: "Write a reply",
                help: nil,
                placeholder: "Type a message",
                windowTitle: "Notes"
            )
        ))
    }
}
