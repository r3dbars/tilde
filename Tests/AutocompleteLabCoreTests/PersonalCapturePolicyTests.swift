import Testing
@testable import AutocompleteLabCore

@Suite("Personal capture policy")
struct PersonalCapturePolicyTests {
    private let policy = PersonalCapturePolicy()

    @Test("Allows ordinary compose fields")
    func allowsOrdinaryComposeFields() throws {
        let decision = policy.decision(for: PersonalCaptureInput(
            bundleIdentifier: "com.apple.TextEdit",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Write"),
            isSecure: false,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
        ))

        #expect(decision.canCapture)
        #expect(decision.metadata["personalCaptureDecision"] == "allowed")
    }

    @Test("Blocks required sensitive field categories")
    func blocksRequiredSensitiveFieldCategories() throws {
        let cases: [(FocusedElementFingerprint, PersonalCaptureBlockReason)] = [
            (FocusedElementFingerprint(placeholder: "Password"), .sensitiveField(.password)),
            (FocusedElementFingerprint(placeholder: "Verification code"), .sensitiveField(.otp)),
            (FocusedElementFingerprint(placeholder: "Credit card"), .sensitiveField(.payment)),
            (FocusedElementFingerprint(placeholder: "Username", windowTitle: "Sign in"), .sensitiveField(.login)),
            (FocusedElementFingerprint(placeholder: "API key"), .sensitiveField(.apiKeyLikeText)),
            (FocusedElementFingerprint(placeholder: "Private prompt"), .sensitiveField(.privatePrompt)),
            (FocusedElementFingerprint(placeholder: "Private search"), .sensitiveField(.privateSearch))
        ]

        for (fingerprint, expectedReason) in cases {
            let decision = policy.decision(for: PersonalCaptureInput(
                bundleIdentifier: "com.apple.TextEdit",
                role: "AXTextArea",
                subrole: nil,
                fingerprint: fingerprint,
                isSecure: false,
                fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
            ))

            #expect(!decision.canCapture)
            #expect(decision.blockReason == expectedReason)
            #expect(decision.metadata["personalCaptureDecision"] == "blocked")
        }
    }

    @Test("Blocks secure search url form unknown and unproven fields")
    func blocksSuppressedFieldKinds() throws {
        let kinds: [AXFieldKind] = [.secure, .search, .url, .form, .unknown, .unprovenSurface]

        for kind in kinds {
            let decision = policy.decision(for: PersonalCaptureInput(
                bundleIdentifier: "com.apple.TextEdit",
                role: "AXTextField",
                subrole: nil,
                fingerprint: FocusedElementFingerprint(placeholder: "Plain"),
                isSecure: false,
                fieldClassification: AXFieldClassification(kind: kind, reason: "test")
            ))

            #expect(!decision.canCapture)
            #expect(decision.blockReason == .suppressedFieldKind(kind))
        }
    }

    @Test("Blocks browser chat and unproven surfaces before local capture")
    func blocksBrowserHostedSurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "ChatGPT"), .chatGPT),
            (FocusedElementFingerprint(windowTitle: "Unknown writing page"), .unproven)
        ]

        for (fingerprint, surface) in cases {
            let decision = policy.decision(for: PersonalCaptureInput(
                bundleIdentifier: "com.google.Chrome",
                role: "AXTextArea",
                subrole: nil,
                fingerprint: fingerprint,
                isSecure: false,
                fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
            ))

            #expect(!decision.canCapture)
            #expect(decision.blockReason == .browserHostedSurface(surface))
        }
    }

    @Test("Sensitive browser fields block before hosted-surface classification")
    func sensitiveBrowserFieldsBlockBeforeHostedSurfaceClassification() throws {
        let decision = policy.decision(for: PersonalCaptureInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(help: "Search Google or type a URL"),
            isSecure: false,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
        ))

        #expect(!decision.canCapture)
        #expect(decision.blockReason == .sensitiveField(.urlAddress))
    }

    @Test("Secure AX contexts block before labels")
    func secureAXContextsBlockBeforeLabels() throws {
        let decision = policy.decision(for: PersonalCaptureInput(
            bundleIdentifier: "com.apple.TextEdit",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Write"),
            isSecure: true,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
        ))

        #expect(!decision.canCapture)
        #expect(decision.blockReason == .secureContext)
    }
}
