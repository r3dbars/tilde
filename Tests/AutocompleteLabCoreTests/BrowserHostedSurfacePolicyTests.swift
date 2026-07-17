import Testing
@testable import AutocompleteLabCore

@Suite("Browser hosted surface policy")
struct BrowserHostedSurfacePolicyTests {
    private let policy = BrowserHostedSurfacePolicy()

    @Test("Chrome Google Docs is allowed while proof remains pending")
    func allowsChromeGoogleDocs() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Editing project plan",
                windowTitle: "Project plan - Google Docs"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Known browsers all use the hosted surface policy")
    func knownBrowsersAllUseHostedSurfacePolicy() {
        for bundleIdentifier in BrowserHostedSurfacePolicy.browserBundleIdentifiers {
            let decision = policy.decision(
                bundleIdentifier: bundleIdentifier,
                fingerprint: FocusedElementFingerprint(
                    title: "Draft",
                    windowTitle: "Private writing app"
                )
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Known browsers allow writing services but block browser chrome and developer tools")
    func knownBrowsersApplySensitiveBoundary() throws {
        let allowedServices = [
            FocusedElementFingerprint(windowTitle: "Project plan - Google Docs"),
            FocusedElementFingerprint(windowTitle: "Roadmap - Notion"),
            FocusedElementFingerprint(windowTitle: "ChatGPT"),
            FocusedElementFingerprint(windowTitle: "Transcripted | Slack"),
            FocusedElementFingerprint(windowTitle: "Discord"),
            FocusedElementFingerprint(windowTitle: "Outlook - Mail")
        ]

        for browserBundleIdentifier in BrowserHostedSurfacePolicy.browserBundleIdentifiers {
            for fingerprint in allowedServices {
                #expect(policy.decision(
                    bundleIdentifier: browserBundleIdentifier,
                    fingerprint: fingerprint
                ).canSuggest)
            }
            #expect(try #require(blockedSurface(from: policy.decision(
                bundleIdentifier: browserBundleIdentifier,
                fingerprint: FocusedElementFingerprint(help: "Search Google or type a URL")
            ))).surface == .browserSearchOrAddressBar)
            #expect(try #require(blockedSurface(from: policy.decision(
                bundleIdentifier: browserBundleIdentifier,
                fingerprint: FocusedElementFingerprint(windowTitle: "github.dev - Visual Studio Code")
            ))).surface == .browserDeveloperTool)
        }
    }

    @Test("Chrome Notion is allowed while proof remains pending")
    func allowsChromeNotion() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Roadmap - Notion"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Browser ChatGPT, Slack, and Discord are allowed")
    func allowsBrowserChatSurfaces() {
        let chatGPTDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "ChatGPT"
            )
        )
        let slackDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Transcripted | Slack"
            )
        )
        let discordDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Discord"
            )
        )

        #expect(chatGPTDecision.canSuggest)
        #expect(slackDecision.canSuggest)
        #expect(discordDecision.canSuggest)
    }

    @Test("Browser webmail writing surfaces are allowed")
    func allowsBrowserWebmail() {
        let cases = [
            FocusedElementFingerprint(windowTitle: "Inbox - Gmail"),
            FocusedElementFingerprint(windowTitle: "Outlook - Mail"),
            FocusedElementFingerprint(windowTitle: "outlook.office.com/mail/inbox"),
            FocusedElementFingerprint(windowTitle: "outlook.office365.com/owa"),
            FocusedElementFingerprint(windowTitle: "office.com/mail"),
            FocusedElementFingerprint(windowTitle: "Yahoo Mail"),
            FocusedElementFingerprint(windowTitle: "Fastmail"),
            FocusedElementFingerprint(windowTitle: "Proton Mail"),
            FocusedElementFingerprint(windowTitle: "iCloud Mail"),
            FocusedElementFingerprint(title: "Email reply", windowTitle: "Office 365 Mail")
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome local textarea and contenteditable fixtures stay eligible")
    func allowsChromeLocalTextareaAndContenteditableFixtures() {
        let cases = [
            FocusedElementFingerprint(
                title: "Local smoke textarea fixture",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Local smoke contenteditable fixture",
                windowTitle: "SteadyType Chrome Contenteditable Fixture Smoke [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Local smoke contenteditable fixture",
                windowTitle: "Autocomplete Lab Chrome Contenteditable Fixture Smoke file:///tmp/fixture.html"
            )
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome local editor and chat fixtures are allowed")
    func allowsChromeLocalEditorAndChatFixtures() {
        let cases = [
            FocusedElementFingerprint(
                title: "Local CodeMirror-style smoke fixture editor",
                windowTitle: "SteadyType Chrome Local Editor-Like Fixture Smoke [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Local Monaco-like smoke fixture editor input",
                windowTitle: "SteadyType Chrome Local Monaco-Like Fixture Smoke [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Local ProseMirror-like smoke fixture editor",
                windowTitle: "SteadyType Chrome Local ProseMirror-Like Fixture Smoke [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Local chat-like smoke fixture message composer contenteditable",
                windowTitle: "SteadyType Chrome Local Chat-Like Fixture No-Submit Smoke [ready=1 submits=0]"
            )
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome public text field pages are allowed")
    func allowsChromePublicTextFieldPages() {
        let cases = [
            FocusedElementFingerprint(
                title: "Public textarea proof field",
                windowTitle: "Editpad - Online Notepad & Wordpad (Text Editor) for Notes"
            ),
            FocusedElementFingerprint(
                title: "Public contenteditable proof field",
                windowTitle: "MediumEditor - The dead simple inline editor toolbar"
            )
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome ordinary external writing pages no longer need fixture tokens")
    func allowsExternalWritingPagesWithoutFixtureTokens() {
        let cases = [
            FocusedElementFingerprint(
                title: "Remote smoke textarea fixture",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke"
            ),
            FocusedElementFingerprint(
                title: "Remote smoke textarea fixture",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke [ready=1]"
            )
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome sensitive pages block before local fixture allowlist")
    func blocksSensitiveBrowserPagesBeforeFixtureAllowlists() throws {
        let payment = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "SteadyType Chrome Smoke payment fixture",
                windowTitle: "Local checkout smoke [ready=1]"
            )
        )
        let login = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Autocomplete Lab Chrome smoke login fixture",
                windowTitle: "Local sign in smoke [ready=1]"
            )
        )
        let addressBar = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local smoke textarea fixture",
                placeholder: "Search Google or type a URL",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke [ready=1]"
            )
        )
        let terminal = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local smoke textarea fixture",
                placeholder: "sudo command",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke [ready=1]"
            )
        )

        #expect(try #require(blockedSurface(from: payment)).surface == .payment)
        #expect(try #require(blockedSurface(from: login)).surface == .login)
        #expect(try #require(blockedSurface(from: addressBar)).surface == .browserSearchOrAddressBar)
        #expect(try #require(blockedSurface(from: terminal)).surface == .browserDeveloperTool)
    }

    @Test("Chrome real hosted services are allowed regardless of fixture tokens")
    func allowsRealHostedServicesWithFixtureTokens() {
        let cases: [FocusedElementFingerprint] = [
            FocusedElementFingerprint(
                title: "Autocomplete Lab Chrome smoke local fixture",
                windowTitle: "https://docs.google.com/document/d/disposable/edit [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "SteadyType Chrome smoke local fixture",
                windowTitle: "Disposable proof - Notion [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "Autocomplete Lab Chrome browser-chat smoke local fixture",
                windowTitle: "ChatGPT [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "SteadyType Chrome browser-chat smoke local fixture",
                windowTitle: "Transcripted | Slack [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "SteadyType Chrome browser-chat smoke local fixture",
                windowTitle: "Discord [ready=1]"
            ),
            FocusedElementFingerprint(
                title: "SteadyType Chrome smoke local fixture",
                windowTitle: "Gmail - Inbox [ready=1]"
            )
        ]

        for fingerprint in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(decision.canSuggest)
        }
    }

    @Test("Chrome risky browser-hosted fields stay blocked")
    func blocksRiskyBrowserHostedFields() throws {
        let cases: [(BrowserHostedSurface, FocusedElementFingerprint)] = [
            (.login, FocusedElementFingerprint(placeholder: "Passkey", windowTitle: "Sign in")),
            (.login, FocusedElementFingerprint(title: "Sign in with SSO", windowTitle: "OAuth consent")),
            (.login, FocusedElementFingerprint(placeholder: "One-time code", windowTitle: "Account authentication")),
            (.payment, FocusedElementFingerprint(placeholder: "Apple Pay", windowTitle: "Checkout")),
            (.payment, FocusedElementFingerprint(title: "PayPal", windowTitle: "Billing")),
            (.payment, FocusedElementFingerprint(placeholder: "IBAN", windowTitle: "Bank transfer")),
            (.payment, FocusedElementFingerprint(help: "Routing number", windowTitle: "Payment")),
            (.passwordManager, FocusedElementFingerprint(title: "Autofill", windowTitle: "1Password")),
            (.privateSearch, FocusedElementFingerprint(placeholder: "Private search", windowTitle: "Incognito")),
            (.browserSearchOrAddressBar, FocusedElementFingerprint(placeholder: "Search Google or type a URL", windowTitle: "Google Chrome")),
            (.browserSearchOrAddressBar, FocusedElementFingerprint(title: "Omnibox", windowTitle: "Google Chrome")),
            (.browserDeveloperTool, FocusedElementFingerprint(placeholder: "sudo command", windowTitle: "Web terminal")),
            (.browserDeveloperTool, FocusedElementFingerprint(title: "GitHub Codespaces", windowTitle: "github.dev")),
            (.browserDeveloperTool, FocusedElementFingerprint(placeholder: "StackBlitz terminal", windowTitle: "StackBlitz")),
            (.browserDeveloperTool, FocusedElementFingerprint(help: "PowerShell prompt", windowTitle: "Replit"))
        ]

        for (surface, fingerprint) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            let block = try #require(blockedSurface(from: decision))
            #expect(block.surface == surface)
            #expect(block.traceMetadata["browserSurfaceSafetyClass"] == "browser-sensitive")
            #expect(block.traceMetadata["promptSafetyMetricSurface"] == "browser-sensitive")
        }
    }

    @Test("Chrome sensitive pages outrank service fingerprints")
    func sensitiveBrowserPagesOutrankServiceFingerprints() throws {
        let slackLogin = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Sign in - Slack")
        )
        let docsCheckout = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Checkout - Google Docs")
        )
        let outlookLogin = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Sign in - Outlook Mail")
        )

        #expect(try #require(blockedSurface(from: slackLogin)).surface == .login)
        #expect(try #require(blockedSurface(from: docsCheckout)).surface == .payment)
        #expect(try #require(blockedSurface(from: outlookLogin)).surface == .login)
    }

    @Test("Chrome login, sign-in, and passkey surfaces are sensitive")
    func blocksLoginSignInAndPasskeySurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "Log in to example.com"), .login),
            (FocusedElementFingerprint(title: "Sign-in with SSO"), .login),
            (FocusedElementFingerprint(placeholder: "Use passkey"), .login)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome checkout, payment, PayPal, IBAN, and routing surfaces are sensitive")
    func blocksPaymentAndBankingSurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "Secure checkout"), .payment),
            (FocusedElementFingerprint(title: "Payment details"), .payment),
            (FocusedElementFingerprint(title: "PayPal"), .payment),
            (FocusedElementFingerprint(placeholder: "IBAN"), .payment),
            (FocusedElementFingerprint(placeholder: "Routing number"), .payment)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome password manager and autofill surfaces are sensitive")
    func blocksPasswordManagerAndAutofillSurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "1Password"), .passwordManager),
            (FocusedElementFingerprint(title: "Password manager"), .passwordManager),
            (FocusedElementFingerprint(description: "Autofill suggestion"), .passwordManager)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome private search surfaces are sensitive")
    func blocksPrivateSearchSurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "Private search"), .privateSearch),
            (FocusedElementFingerprint(title: "Incognito search"), .privateSearch),
            (FocusedElementFingerprint(description: "Private browsing search field"), .privateSearch)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome search and address bars are sensitive")
    func blocksBrowserSearchAndAddressBars() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(title: "Address bar"), .browserSearchOrAddressBar),
            (FocusedElementFingerprint(description: "Location bar"), .browserSearchOrAddressBar),
            (FocusedElementFingerprint(help: "Search Google or type a URL"), .browserSearchOrAddressBar),
            (FocusedElementFingerprint(placeholder: "Search or enter address"), .browserSearchOrAddressBar)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome dev terminals, consoles, and hosted coding surfaces are sensitive")
    func blocksBrowserDeveloperSurfaces() throws {
        let cases: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(title: "Dev terminal"), .browserDeveloperTool),
            (FocusedElementFingerprint(description: "Developer console"), .browserDeveloperTool),
            (FocusedElementFingerprint(windowTitle: "Codespaces"), .browserDeveloperTool),
            (FocusedElementFingerprint(windowTitle: "github.dev - Visual Studio Code"), .browserDeveloperTool),
            (FocusedElementFingerprint(windowTitle: "Replit"), .browserDeveloperTool),
            (FocusedElementFingerprint(windowTitle: "StackBlitz"), .browserDeveloperTool)
        ]

        for (fingerprint, expectedSurface) in cases {
            let decision = policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )

            #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
        }
    }

    @Test("Chrome ordinary browser pages are allowed")
    func allowsUnknownChromePages() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Draft",
                windowTitle: "Private writing app"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Non-browser apps are not filtered by hosted surface fingerprints")
    func allowsNonBrowserApps() {
        let decision = policy.decision(
            bundleIdentifier: "md.obsidian",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Project - Notion"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Trace metadata is safe and does not include raw fingerprints")
    func traceMetadataIsSafe() throws {
        let secretTitle = "Private payment details"
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: secretTitle,
                placeholder: "Credit card number",
                windowTitle: "Checkout"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(metadata["browserSurface"] == "browser-payment")
        #expect(metadata["browserSurfaceDecision"] == "blocked")
        #expect(metadata["browserSurfaceReason"] == "unsupported-surface-needs-proof")
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-sensitive")
        #expect(
            metadata["browserSurfaceRequiredProof"]
                == "blocked-sensitive-browser-surface"
        )
        #expect(metadata["localFixtureProofCountsForProduction"] == "false")
        #expect(!metadata.values.contains(secretTitle))
        #expect(!metadata.values.contains("Checkout"))
    }

    @Test("Blocked browser metadata can record lengths without raw cursor text")
    func blockedBrowserMetadataCanRecordLengthsWithoutRawCursorText() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(placeholder: "Credit card number", windowTitle: "Checkout")
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.redactedTraceMetadata(
            textBeforeCursorLength: 21,
            textAfterCursorLength: 8
        )

        #expect(metadata["blockedSurfaceTextRedacted"] == "true")
        #expect(metadata["textBeforeCursorChars"] == "21")
        #expect(metadata["textAfterCursorChars"] == "8")
        #expect(!metadata.values.contains("Checkout"))
    }

    @Test("Browser chat classifications remain available for telemetry")
    func browserChatClassificationsRemainAvailable() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Transcripted - Slack")
        )

        #expect(decision.canSuggest)
        #expect(BrowserHostedSurface.slack.safetyClass == "browser-chat")
        #expect(BrowserHostedSurface.slack.requiredProofKind == "exact-disposable-real-service-one-word-no-submit-screenshot-insertion")
    }

    @Test("Browser webmail classification remains distinct")
    func browserWebmailClassificationRemainsDistinct() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Outlook - Mail")
        )

        #expect(decision.canSuggest)
        #expect(BrowserHostedSurface.webmail.safetyClass == "browser-webmail")
        #expect(BrowserHostedSurface.webmail.requiredProofKind == "exact-disposable-webmail-reply-safe-tab-screenshot-insertion-undo-latency")
    }

    @Test("Browser sensitive blocks are tagged separately")
    func sensitiveBrowserBlocksAreTagged() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Checkout - payment")
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(block.surface == .payment)
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-sensitive")
        #expect(metadata["promptSafetyMetricSurface"] == "browser-sensitive")
    }

    private func blockedSurface(
        from decision: BrowserHostedSurfaceDecision
    ) -> BrowserHostedSurfaceBlock? {
        guard case let .blocked(block) = decision else {
            return nil
        }

        return block
    }
}
