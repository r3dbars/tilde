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

    @Test("Blocks native secure text roles before text reads")
    func blocksSecureRole() {
        #expect(policy.isSensitive(
            role: "AXSecureTextField",
            subrole: nil,
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
        let assessment = policy.assessment(
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
        )

        #expect(assessment.isSensitive)
        #expect(assessment.category == .apiKeyLikeText)
        #expect(assessment.traceMetadata["sensitiveSuppressionCategory"] == "api-key-like-text")
    }

    @Test("Classifies required beta sensitive categories")
    func classifiesRequiredBetaSensitiveCategories() {
        let cases: [(SensitiveFieldProofCategory, FocusedElementFingerprint)] = [
            (.otp, FocusedElementFingerprint(placeholder: "One time code", windowTitle: "Sign in")),
            (.payment, FocusedElementFingerprint(identifier: "card-number", placeholder: "Credit card", windowTitle: "Checkout")),
            (.login, FocusedElementFingerprint(identifier: "username", placeholder: "Username", windowTitle: "Login")),
            (.address, FocusedElementFingerprint(identifier: "shipping-address", placeholder: "Shipping address", windowTitle: "Checkout")),
            (.commandLine, FocusedElementFingerprint(identifier: "terminal-command", placeholder: "Command line", windowTitle: "Web terminal")),
            (.passwordManager, FocusedElementFingerprint(title: "1Password", placeholder: "Search 1Password", windowTitle: "1Password")),
            (.privatePrompt, FocusedElementFingerprint(placeholder: "Private prompt", windowTitle: "Private chat")),
            (.privateSearch, FocusedElementFingerprint(placeholder: "Private search", windowTitle: "Private Browsing"))
        ]

        for (category, fingerprint) in cases {
            let assessment = policy.assessment(role: "AXTextField", subrole: nil, fingerprint: fingerprint)
            #expect(assessment.isSensitive)
            #expect(assessment.category == category)
        }
    }

    @Test("Classifies expanded sensitive label variants")
    func classifiesExpandedSensitiveLabelVariants() {
        let cases: [(SensitiveFieldProofCategory, FocusedElementFingerprint)] = [
            (.password, FocusedElementFingerprint(placeholder: "Passkey", windowTitle: "Sign in")),
            (.password, FocusedElementFingerprint(help: "Paste recovery key", windowTitle: "Wallet")),
            (.password, FocusedElementFingerprint(title: "SSH private key", windowTitle: "Deploy key")),
            (.otp, FocusedElementFingerprint(placeholder: "SSO code", windowTitle: "Identity provider")),
            (.otp, FocusedElementFingerprint(placeholder: "OAuth code", windowTitle: "Authorize app")),
            (.payment, FocusedElementFingerprint(placeholder: "IBAN", windowTitle: "Bank transfer")),
            (.payment, FocusedElementFingerprint(help: "Routing number", windowTitle: "Payment")),
            (.payment, FocusedElementFingerprint(title: "PayPal", windowTitle: "Checkout")),
            (.address, FocusedElementFingerprint(placeholder: "Address line 2", windowTitle: "Shipping")),
            (.address, FocusedElementFingerprint(placeholder: "Postal code", windowTitle: "Address")),
            (.address, FocusedElementFingerprint(placeholder: "Email address", windowTitle: "Contact")),
            (.address, FocusedElementFingerprint(placeholder: "Phone number", windowTitle: "Contact")),
            (.commandLine, FocusedElementFingerprint(placeholder: "sudo command", windowTitle: "Web terminal")),
            (.commandLine, FocusedElementFingerprint(placeholder: "SSH command", windowTitle: "Codespaces")),
            (.commandLine, FocusedElementFingerprint(windowTitle: "StackBlitz terminal")),
            (.privatePrompt, FocusedElementFingerprint(placeholder: "Confidential instructions", windowTitle: "Internal prompt"))
        ]

        for (category, fingerprint) in cases {
            let assessment = policy.assessment(role: "AXTextField", subrole: nil, fingerprint: fingerprint)
            #expect(assessment.isSensitive)
            #expect(assessment.category == category)
        }
    }

    @Test("Sensitive proof harness keeps all beta fixtures silent")
    func proofHarnessKeepsAllBetaFixturesSilent() {
        let results = SensitiveFieldProofHarness().run()
        let categories = Set(results.map(\.fixture.category))

        #expect(results.allSatisfy { $0.isSilent })
        #expect(categories == Set(SensitiveFieldProofCategory.allCases))
        #expect(results.allSatisfy { $0.traceMetadata["rawTextIncluded"] == "false" })
        #expect(results.allSatisfy {
            $0.assessment.category == $0.fixture.category
                || $0.fieldClassification.suppressesSuggestionsByDefault
        })
        #expect(results.allSatisfy {
            guard let policyCategory = $0.assessment.category else {
                return $0.traceMetadata["sensitivePolicyCategory"] == "none"
            }
            return $0.traceMetadata["sensitivePolicyCategory"] == policyCategory.rawValue
        })
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
