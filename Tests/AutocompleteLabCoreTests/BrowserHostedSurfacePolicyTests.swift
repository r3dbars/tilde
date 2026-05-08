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

    @Test("Browser Slack and Discord are blocked until no-submit proof exists")
    func blocksBrowserChatSurfaces() throws {
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

        #expect(try #require(blockedSurface(from: slackDecision)).surface == .slack)
        #expect(try #require(blockedSurface(from: discordDecision)).surface == .discord)
    }

    @Test("Browser action-bearing surfaces are blocked until no-submit proof exists")
    func blocksActionBearingBrowserSurfaces() throws {
        let cases: [(String, FocusedElementFingerprint, BrowserHostedSurface)] = [
            (
                "gmail",
                FocusedElementFingerprint(windowTitle: "Inbox - Gmail"),
                .gmail
            ),
            (
                "chatgpt",
                FocusedElementFingerprint(windowTitle: "ChatGPT"),
                .chatGPT
            ),
            (
                "claude web",
                FocusedElementFingerprint(windowTitle: "Claude"),
                .claudeWeb
            ),
            (
                "codex web",
                FocusedElementFingerprint(windowTitle: "OpenAI Codex"),
                .codexWeb
            ),
            (
                "gemini web",
                FocusedElementFingerprint(windowTitle: "Gemini"),
                .geminiWeb
            ),
            (
                "perplexity web",
                FocusedElementFingerprint(windowTitle: "Perplexity"),
                .perplexityWeb
            ),
            (
                "copilot web",
                FocusedElementFingerprint(windowTitle: "Microsoft Copilot"),
                .copilotWeb
            ),
            (
                "poe web",
                FocusedElementFingerprint(windowTitle: "Poe"),
                .poeWeb
            ),
            (
                "telegram web",
                FocusedElementFingerprint(windowTitle: "Telegram"),
                .telegramWeb
            ),
            (
                "teams web",
                FocusedElementFingerprint(windowTitle: "Microsoft Teams"),
                .teamsWeb
            ),
            (
                "whatsapp web",
                FocusedElementFingerprint(windowTitle: "WhatsApp"),
                .whatsAppWeb
            ),
            (
                "messenger web",
                FocusedElementFingerprint(windowTitle: "Messenger"),
                .messengerWeb
            )
        ]

        for (label, fingerprint, expectedSurface) in cases {
            let block = try #require(blockedSurface(from: policy.decision(
                bundleIdentifier: "com.google.Chrome",
                fingerprint: fingerprint
            )), "\(label) should be blocked")

            #expect(block.surface == expectedSurface)
            #expect(block.reason == .actionBearingNeedsNoSubmitProof)
            #expect(block.userFacingReason.contains("no-submit proof"))
            #expect(block.traceMetadata["browserSurfaceKind"] != "production-rich-editor")
            #expect(block.traceMetadata["browserSurfaceActionBearing"] == "true")
            #expect(block.traceMetadata["browserSurfaceReason"] == "action-bearing-needs-no-submit-proof")
        }
    }

    @Test("Chrome local editor fixtures stay eligible")
    func allowsChromeLocalEditorFixtures() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local ProseMirror-like smoke fixture",
                description: "Real ProseMirror smoke editor",
                windowTitle: "Autocomplete Lab Chrome Real ProseMirror Smoke [ready=1]"
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
        #expect(metadata["browserSurfaceKind"] == "production-rich-editor")
        #expect(metadata["browserSurfaceActionBearing"] == "false")
        #expect(metadata["browserSurfaceDecision"] == "blocked")
        #expect(metadata["browserSurfaceReason"] == "unsupported-surface-needs-proof")
        #expect(!metadata.values.contains(secretTitle))
        #expect(!metadata.values.contains("https://docs.google.com/document/d/private-id/edit"))
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
