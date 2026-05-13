import Testing
@testable import AutocompleteLabCore

@Suite("Browser hosted surface policy")
struct BrowserHostedSurfacePolicyTests {
    private let policy = BrowserHostedSurfacePolicy()

    @Test("Chrome Google Docs is blocked until real production proof exists")
    func blocksChromeGoogleDocs() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Editing project plan",
                windowTitle: "Project plan - Google Docs"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .googleDocs)
        #expect(block.traceReason == "unsupported-browser-surface")
        #expect(block.userFacingReason == "Google Docs needs proof first")
    }

    @Test("Known browsers all use the hosted surface policy")
    func knownBrowsersAllUseHostedSurfacePolicy() throws {
        for bundleIdentifier in BrowserHostedSurfacePolicy.browserBundleIdentifiers {
            let decision = policy.decision(
                bundleIdentifier: bundleIdentifier,
                fingerprint: FocusedElementFingerprint(
                    title: "Draft",
                    windowTitle: "Private writing app"
                )
            )

            let block = try #require(blockedSurface(from: decision))
            #expect(block.surface == .unproven)
            #expect(block.traceMetadata["browserSurfaceDecision"] == "blocked")
        }
    }

    @Test("Known browsers all block risky hosted services")
    func knownBrowsersAllBlockRiskyHostedServices() throws {
        let services: [(FocusedElementFingerprint, BrowserHostedSurface)] = [
            (FocusedElementFingerprint(windowTitle: "Project plan - Google Docs"), .googleDocs),
            (FocusedElementFingerprint(windowTitle: "Roadmap - Notion"), .notion),
            (FocusedElementFingerprint(windowTitle: "ChatGPT"), .chatGPT),
            (FocusedElementFingerprint(windowTitle: "Transcripted | Slack"), .slack),
            (FocusedElementFingerprint(windowTitle: "Discord"), .discord),
            (FocusedElementFingerprint(help: "Search Google or type a URL"), .browserSearchOrAddressBar),
            (FocusedElementFingerprint(windowTitle: "github.dev - Visual Studio Code"), .browserDeveloperTool)
        ]

        for browserBundleIdentifier in BrowserHostedSurfacePolicy.browserBundleIdentifiers {
            for (fingerprint, expectedSurface) in services {
                let decision = policy.decision(
                    bundleIdentifier: browserBundleIdentifier,
                    fingerprint: fingerprint
                )

                #expect(try #require(blockedSurface(from: decision)).surface == expectedSurface)
            }
        }
    }

    @Test("Chrome Notion is blocked until real production proof exists")
    func blocksChromeNotion() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Roadmap - Notion"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .notion)
    }

    @Test("Browser ChatGPT, Slack, and Discord are blocked until no-submit proof exists")
    func blocksBrowserChatSurfaces() throws {
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

        #expect(try #require(blockedSurface(from: chatGPTDecision)).surface == .chatGPT)
        #expect(try #require(blockedSurface(from: slackDecision)).surface == .slack)
        #expect(try #require(blockedSurface(from: discordDecision)).surface == .discord)
    }

    @Test("Chrome local editor fixtures stay eligible")
    func allowsChromeLocalEditorFixtures() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local ProseMirror-like smoke fixture",
                description: "Real ProseMirror smoke editor",
                windowTitle: "SteadyType Chrome Real ProseMirror Smoke [ready=1]"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Chrome local textarea smoke fixture stays eligible")
    func allowsChromeLocalTextareaSmokeFixture() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local smoke textarea fixture",
                windowTitle: "SteadyType Chrome Textarea Fixture Smoke [ready=1]"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Chrome fixture titles need local proof tokens")
    func blocksSpoofedExternalFixtureTitles() throws {
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

            #expect(try #require(blockedSurface(from: decision)).surface == .unproven)
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

        #expect(try #require(blockedSurface(from: slackLogin)).surface == .login)
        #expect(try #require(blockedSurface(from: docsCheckout)).surface == .payment)
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

    @Test("Chrome unknown browser pages fail closed until proofed")
    func blocksUnknownChromePages() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Draft",
                windowTitle: "Private writing app"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .unproven)
        #expect(block.userFacingReason == "This browser page needs proof first")
        #expect(block.traceMetadata["browserSurfaceSafetyClass"] == "browser-unknown")
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
        let secretTitle = "Private roadmap - Google Docs"
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: secretTitle,
                windowTitle: "https://docs.google.com/document/d/private-id/edit"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(metadata["browserSurface"] == "google-docs")
        #expect(metadata["browserSurfaceDecision"] == "blocked")
        #expect(metadata["browserSurfaceReason"] == "unsupported-surface-needs-proof")
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-editor")
        #expect(!metadata.values.contains(secretTitle))
        #expect(!metadata.values.contains("https://docs.google.com/document/d/private-id/edit"))
    }

    @Test("Blocked browser metadata can record lengths without raw cursor text")
    func blockedBrowserMetadataCanRecordLengthsWithoutRawCursorText() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Private roadmap - Google Docs")
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.redactedTraceMetadata(
            textBeforeCursorLength: 21,
            textAfterCursorLength: 8
        )

        #expect(metadata["blockedSurfaceTextRedacted"] == "true")
        #expect(metadata["textBeforeCursorChars"] == "21")
        #expect(metadata["textAfterCursorChars"] == "8")
        #expect(!metadata.values.contains("Private roadmap"))
    }

    @Test("Browser chat blocks are tagged for no-submit metrics")
    func browserChatBlocksAreTaggedForNoSubmitMetrics() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Transcripted - Slack")
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(metadata["browserSurface"] == "slack")
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-chat")
        #expect(metadata["promptSafetyMetricSurface"] == "browser-chat")
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
