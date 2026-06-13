import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility router")
struct CompatibilityRouterTests {
    @Test("TextEdit can request and accept suggestions")
    func textEditCanRequestAndAccept() {
        let decision = CompatibilityRouter().decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.apple.TextEdit",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                isSecureTextEntry: false,
                textBeforeCursor: "This should",
                hasCaretRect: true
            )
        )

        #expect(decision.profile.id == "textedit")
        #expect(decision.rung == .stableBeta)
        #expect(decision.shouldRequestSuggestion)
        #expect(decision.canAcceptSuggestion)
        #expect(decision.acceptMode == .directAccessibility)
        #expect(!decision.allowsClipboardFallback)
    }

    @Test("Unsupported apps are blocked instead of treated as default editors")
    func unsupportedAppsAreBlocked() {
        let decision = CompatibilityRouter().decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.example.UnknownWriter",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                isSecureTextEntry: false,
                textBeforeCursor: "This should",
                hasCaretRect: true
            )
        )

        #expect(!decision.shouldRequestSuggestion)
        #expect(decision.rung == .blocked)
        #expect(decision.suppressionReason == .unsupportedApp("com.example.UnknownWriter"))
    }

    @Test("Browser and editor adapters start detect-only until real integrations exist")
    func adapterTargetsStartDetectOnly() {
        let router = CompatibilityRouter()
        let chrome = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.google.Chrome",
                elementRole: "AXWebArea",
                elementSubrole: nil,
                fieldClassifierInput: AXFieldClassifierInput(
                    role: "AXWebArea",
                    placeholder: "Write a reply",
                    textBeforeCursorLength: 11
                ),
                isSecureTextEntry: false,
                textBeforeCursor: "This should",
                hasCaretRect: true
            )
        )
        let obsidian = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "md.obsidian",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                isSecureTextEntry: false,
                textBeforeCursor: "This should",
                hasCaretRect: true
            )
        )

        #expect(chrome.textPath == .webExtension)
        #expect(chrome.suppressionReason == .detectOnly("browser-composer"))
        #expect(!chrome.shouldRequestSuggestion)

        #expect(obsidian.textPath == .editorPlugin)
        #expect(obsidian.suppressionReason == .detectOnly("obsidian"))
        #expect(!obsidian.shouldRequestSuggestion)
    }

    @Test("Secure and missing geometry contexts are suppressed")
    func unsafeContextsAreSuppressed() {
        let router = CompatibilityRouter()
        let secure = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.apple.TextEdit",
                elementRole: "AXTextArea",
                elementSubrole: "AXSecureTextField",
                isSecureTextEntry: true,
                textBeforeCursor: "secret",
                hasCaretRect: true
            )
        )
        let missingCaret = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.apple.TextEdit",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                isSecureTextEntry: false,
                textBeforeCursor: "safe text",
                hasCaretRect: false
            )
        )

        #expect(secure.suppressionReason == .secureTextEntry)
        #expect(!secure.shouldRequestSuggestion)
        #expect(missingCaret.suppressionReason == .missingCaretRect)
        #expect(!missingCaret.shouldRequestSuggestion)
    }

    @Test("Unsafe field kinds are blocked before suggestions")
    func unsafeFieldKindsAreBlocked() {
        let router = CompatibilityRouter()
        let cases: [(AXFieldClassifierInput, AXFieldKind)] = [
            (AXFieldClassifierInput(role: "AXSearchField"), .search),
            (AXFieldClassifierInput(role: "AXURLField"), .url),
            (AXFieldClassifierInput(role: "AXTextField", identifier: "username", placeholder: "Username"), .form),
            (AXFieldClassifierInput(role: "AXTextField", identifier: "card-number", placeholder: "Card number"), .form),
            (AXFieldClassifierInput(role: "AXTextField", identifier: "shipping-address", placeholder: "Shipping address"), .form),
            (AXFieldClassifierInput(role: "AXTextField", identifier: "terminal-command", placeholder: "Command line"), .unprovenSurface)
        ]

        for (input, expectedKind) in cases {
            let decision = router.decision(
                for: CompatibilityEvaluationContext(
                    bundleIdentifier: "com.apple.TextEdit",
                    elementRole: input.role,
                    elementSubrole: input.subrole,
                    fieldClassifierInput: input,
                    isSecureTextEntry: false,
                    textBeforeCursor: "safe fixture text",
                    hasCaretRect: true
                )
            )

            #expect(!decision.shouldRequestSuggestion)
            #expect(decision.rung == .blocked)
            guard case let .unsafeFieldKind(reason) = decision.suppressionReason else {
                Issue.record("Expected unsafe field suppression, got \(String(describing: decision.suppressionReason))")
                continue
            }
            #expect(AXFieldClassifier().classification(for: input).kind == expectedKind)
            #expect(!reason.isEmpty)
        }
    }
}
